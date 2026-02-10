//
//  HealthKitService.swift
//  Pulse
//
//  Created by Devon Martin on 12/1/2025.
//

import HealthKit

// MARK: - Authorization Status

/// Represents the current state of HealthKit authorization.
/// This is our own type - we don't expose HealthKit's types outside this service.
enum HealthKitAuthorizationStatus {
    case notDetermined
    case authorized
    case denied
    case unavailable  // Device doesn't support HealthKit (e.g., iPad)
}

// MARK: - Errors

enum HealthKitServiceError: LocalizedError {
    case healthKitUnavailable
    case authorizationFailed(Error)

    var errorDescription: String? {
        switch self {
        case .healthKitUnavailable:
            return "HealthKit is not available on this device."
        case .authorizationFailed(let underlyingError):
            return "Failed to authorize HealthKit: \(underlyingError.localizedDescription)"
        }
    }
}

// MARK: - Protocol

/// Defines the interface for accessing health data.
/// The app interacts with this protocol, never with HealthKit directly.
/// This allows us to:
/// 1. Test without a real device or HealthKit entitlements
/// 2. Develop in the simulator with mock data
/// 3. Swap implementations without changing any other code
protocol HealthKitServiceProtocol {
    /// Current authorization status for reading health data
    var authorizationStatus: HealthKitAuthorizationStatus { get async }

    /// Request authorization to read health data.
    /// Note: HealthKit never tells us if the user denied specific types -
    /// it only tells us the request was presented. We infer denial by
    /// checking if data comes back empty.
    func requestAuthorization() async throws

    /// Fetch health metrics for a specific date.
    /// Returns a HealthMetrics struct with available data (nil for missing metrics).
    func fetchMetrics(for date: Date) async throws -> HealthMetrics
}

// MARK: - Implementation

/// The real HealthKit service that communicates with Apple's HealthKit framework.
/// This class should only be instantiated on devices that support HealthKit.
final class HealthKitService: HealthKitServiceProtocol {

    // MARK: - Properties

    private let healthStore: HKHealthStore

    /// The types of data we want to read from HealthKit.
    /// These align with what we need for readiness scoring.
    private let typesToRead: Set<HKObjectType> = {
        var types = Set<HKObjectType>()

        // Heart metrics
        if let restingHR = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            types.insert(restingHR)
        }
        if let hrv = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
            types.insert(hrv)
        }

        // Sleep
        if let sleep = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleep)
        }

        // Activity
        if let steps = HKQuantityType.quantityType(forIdentifier: .stepCount) {
            types.insert(steps)
        }
        if let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            types.insert(activeEnergy)
        }

        // Workouts
        types.insert(HKWorkoutType.workoutType())

        return types
    }()

    // MARK: - Initialization

    init() {
        self.healthStore = HKHealthStore()
    }

    // MARK: - HealthKitServiceProtocol

    var authorizationStatus: HealthKitAuthorizationStatus {
        get async {
            // First check if HealthKit is available on this device
            guard HKHealthStore.isHealthDataAvailable() else {
                return .unavailable
            }

            // Check authorization status for our key metric (HRV)
            // We use HRV as the "canary" - if we can read HRV, we likely have
            // the permissions we need
            guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
                return .unavailable
            }

            let status = healthStore.authorizationStatus(for: hrvType)

            switch status {
            case .notDetermined:
                return .notDetermined
            case .sharingAuthorized:
                // Note: This is for writing, but for reading, HealthKit doesn't
                // tell us if denied. We'll assume authorized and verify with data.
                return .authorized
            case .sharingDenied:
                return .denied
            @unknown default:
                return .notDetermined
            }
        }
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitServiceError.healthKitUnavailable
        }

        do {
            // We only request read access (no write)
            try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
        } catch {
            throw HealthKitServiceError.authorizationFailed(error)
        }
    }

    func fetchMetrics(for date: Date) async throws -> HealthMetrics {
        // Create date range for the requested date (start of day to end of day)
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        // Fetch all metrics concurrently.
        // Each fetch returns nil if no data exists (rather than throwing),
        // so a fresh device with no health history still works.
        async let restingHR = fetchRestingHeartRate(start: startOfDay, end: endOfDay)
        async let hrv = fetchHRV(start: startOfDay, end: endOfDay)
        async let sleep = fetchSleepDuration(start: startOfDay, end: endOfDay)
        async let steps = fetchSteps(start: startOfDay, end: endOfDay)
        async let calories = fetchActiveCalories(start: startOfDay, end: endOfDay)

        return HealthMetrics(
            date: date,
            restingHeartRate: await restingHR,
            hrv: await hrv,
            sleepDuration: await sleep,
            steps: await steps,
            activeCalories: await calories
        )
    }

    // MARK: - Private Fetch Methods

    private func fetchRestingHeartRate(start: Date, end: Date) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            return nil
        }
        return try? await fetchMostRecentQuantity(type: type, start: start, end: end, unit: HKUnit.count().unitDivided(by: .minute()))
    }

    private func fetchHRV(start: Date, end: Date) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return nil
        }
        return try? await fetchMostRecentQuantity(type: type, start: start, end: end, unit: HKUnit.secondUnit(with: .milli))
    }

    private func fetchSteps(start: Date, end: Date) async -> Int? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            return nil
        }
        guard let sum = try? await fetchCumulativeSum(type: type, start: start, end: end, unit: .count()) else {
            return nil
        }
        return Int(sum)
    }

    private func fetchActiveCalories(start: Date, end: Date) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return nil
        }
        return try? await fetchCumulativeSum(type: type, start: start, end: end, unit: .kilocalorie())
    }

    private func fetchSleepDuration(start: Date, end: Date) async -> TimeInterval? {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return try? await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let categorySamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: nil)
                    return
                }

                // Sum up all "asleep" samples (excluding inBed, awake, etc.)
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue
                ]

                let totalSleep = categorySamples
                    .filter { asleepValues.contains($0.value) }
                    .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }

                continuation.resume(returning: totalSleep > 0 ? totalSleep : nil)
            }

            healthStore.execute(query)
        }
    }

    /// Fetches the most recent value for a quantity type (used for resting HR, HRV)
    private func fetchMostRecentQuantity(type: HKQuantityType, start: Date, end: Date, unit: HKUnit) async throws -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sortDescriptor]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }

                let value = sample.quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }

            healthStore.execute(query)
        }
    }

    /// Fetches cumulative sum for a quantity type (used for steps, calories)
    private func fetchCumulativeSum(type: HKQuantityType, start: Date, end: Date, unit: HKUnit) async throws -> Double? {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let sum = statistics?.sumQuantity() else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: sum.doubleValue(for: unit))
            }

            healthStore.execute(query)
        }
    }
}
