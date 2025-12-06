//
//  AppContainer.swift
//  Pulse
//
//  Created by Devon Martin on 12/1/2025.
//

import HealthKit
import SwiftData

/// The dependency injection container for the app.
///
/// This is the "composition root" - the single place where all dependencies
/// are created and wired together. Views and view models receive their
/// dependencies from here rather than creating them directly.
///
/// Benefits:
/// - Testability: Tests can create their own container with mock dependencies
/// - Flexibility: Easy to swap implementations (e.g., mock vs real HealthKit)
/// - Clarity: All dependencies visible in one place
@Observable
@MainActor
final class AppContainer {

    // MARK: - Services

    /// The health data service. Uses mock in simulator, real HealthKit on device.
    let healthKitService: HealthKitServiceProtocol

    /// The readiness score calculator (rules-based, used as fallback)
    let readinessCalculator: ReadinessCalculatorProtocol

    /// The readiness service that blends rules + ML for personalized scoring
    let readinessService: ReadinessService

    // MARK: - Repositories

    /// The check-in data repository
    let checkInRepository: CheckInRepositoryProtocol

    /// The readiness score repository for historical data
    let readinessScoreRepository: ReadinessScoreRepositoryProtocol

    // MARK: - Environment Detection

    /// Returns true if running in the iOS Simulator
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    // MARK: - Initialization

    /// Creates the production container with real dependencies.
    /// - Parameter modelContainer: The SwiftData model container for persistence
    init(modelContainer: ModelContainer) {
        // Use mock in simulator (HealthKit auth doesn't work there),
        // real HealthKit on physical devices
        if AppContainer.isSimulator {
            let mock = MockHealthKitService()
            mock.mockAuthorizationStatus = .notDetermined
            self.healthKitService = mock
        } else if HKHealthStore.isHealthDataAvailable() {
            self.healthKitService = HealthKitService()
        } else {
            // iPad or device without HealthKit
            let mock = MockHealthKitService()
            mock.mockAuthorizationStatus = .unavailable
            self.healthKitService = mock
        }

        // Create the readiness calculator
        self.readinessCalculator = ReadinessCalculator()

        // Create the readiness service with ML blending
        self.readinessService = ReadinessService(rulesCalculator: readinessCalculator)

        // Create repositories with the model container
        self.checkInRepository = CheckInRepository(modelContainer: modelContainer)
        self.readinessScoreRepository = ReadinessScoreRepository(modelContainer: modelContainer)
    }

    // MARK: - Sample Data

    /// Populates the repositories with sample data for development in the simulator.
    /// Only runs once per install (checks UserDefaults).
    func populateSampleDataIfNeeded() async {
        guard AppContainer.isSimulator else { return }

        let key = "hasPopulatedSampleData"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        // Generate and save sample check-ins
        let sampleCheckIns = Self.generateSampleCheckIns()
        for checkIn in sampleCheckIns {
            try? await checkInRepository.save(checkIn)
        }

        // Generate and save sample readiness scores
        let sampleScores = Self.generateSampleScores()
        for score in sampleScores {
            try? await readinessScoreRepository.save(score)
        }

        UserDefaults.standard.set(true, forKey: key)
    }

    /// Generates sample historical check-ins for the past 14 days (morning and evening)
    private static func generateSampleCheckIns() -> [CheckIn] {
        let calendar = Calendar.current
        let today = Date()
        var checkIns: [CheckIn] = []

        for daysAgo in 1..<14 {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else {
                continue
            }

            // Morning check-in (around 7-9 AM)
            let morningHour = Int.random(in: 7...9)
            let morningMinute = Int.random(in: 0...59)
            if let morningTimestamp = calendar.date(bySettingHour: morningHour, minute: morningMinute, second: 0, of: date) {
                let energyLevel = Int.random(in: 2...5)

                // Create health snapshot for most check-ins
                let healthSnapshot: HealthMetrics? = Int.random(in: 1...10) <= 8 ? HealthMetrics(
                    date: date,
                    restingHeartRate: Double.random(in: 52...72),
                    hrv: Double.random(in: 25...75),
                    sleepDuration: TimeInterval.random(in: 5*3600...9*3600),
                    steps: Int.random(in: 3000...15000),
                    activeCalories: Double.random(in: 150...650)
                ) : nil

                checkIns.append(CheckIn(
                    timestamp: morningTimestamp,
                    type: .morning,
                    energyLevel: energyLevel,
                    healthSnapshot: healthSnapshot
                ))
            }

            // Evening check-in (around 8-10 PM) - 80% chance of having one
            if Int.random(in: 1...10) <= 8 {
                let eveningHour = Int.random(in: 20...22)
                let eveningMinute = Int.random(in: 0...59)
                if let eveningTimestamp = calendar.date(bySettingHour: eveningHour, minute: eveningMinute, second: 0, of: date) {
                    let energyLevel = Int.random(in: 2...5)

                    // Evening snapshot with full day data
                    let healthSnapshot = HealthMetrics(
                        date: date,
                        restingHeartRate: Double.random(in: 52...72),
                        hrv: Double.random(in: 25...75),
                        sleepDuration: TimeInterval.random(in: 5*3600...9*3600),
                        steps: Int.random(in: 5000...18000),
                        activeCalories: Double.random(in: 200...800)
                    )

                    checkIns.append(CheckIn(
                        timestamp: eveningTimestamp,
                        type: .evening,
                        energyLevel: energyLevel,
                        healthSnapshot: healthSnapshot
                    ))
                }
            }
        }

        return checkIns
    }

    /// Generates sample historical scores for the past 14 days
    private static func generateSampleScores() -> [ReadinessScore] {
        let calendar = Calendar.current
        let today = Date()

        return (1..<14).compactMap { daysAgo -> ReadinessScore? in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else {
                return nil
            }

            // Create varied but realistic scores with a slight upward trend
            let trendBonus = (14 - daysAgo) / 2
            let baseScore = 60 + trendBonus + Int.random(in: -10...15)
            let score = max(35, min(92, baseScore))

            let hrvScore = score + Int.random(in: -8...8)
            let rhrScore = score + Int.random(in: -8...8)
            let sleepScore = score + Int.random(in: -12...12)
            let energyScore = score + Int.random(in: -8...8)

            let confidence: ReadinessConfidence = {
                let roll = Int.random(in: 1...10)
                if roll <= 7 { return .full }
                if roll <= 9 { return .partial }
                return .limited
            }()

            return ReadinessScore(
                date: date,
                score: score,
                breakdown: ReadinessBreakdown(
                    hrvScore: max(15, min(95, hrvScore)),
                    restingHeartRateScore: max(15, min(95, rhrScore)),
                    sleepScore: max(15, min(95, sleepScore)),
                    energyScore: max(20, min(100, energyScore))
                ),
                confidence: confidence
            )
        }
    }

    /// Creates a container with custom dependencies (for testing/previews).
    init(
        healthKitService: HealthKitServiceProtocol,
        readinessCalculator: ReadinessCalculatorProtocol = ReadinessCalculator(),
        readinessService: ReadinessService? = nil,
        checkInRepository: CheckInRepositoryProtocol? = nil,
        readinessScoreRepository: ReadinessScoreRepositoryProtocol? = nil
    ) {
        self.healthKitService = healthKitService
        self.readinessCalculator = readinessCalculator
        self.readinessService = readinessService ?? ReadinessService(rulesCalculator: readinessCalculator)
        self.checkInRepository = checkInRepository ?? MockCheckInRepository()
        self.readinessScoreRepository = readinessScoreRepository ?? MockReadinessScoreRepository()
    }
}
