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

    /// The Day repository for user days with check-in slots
    let dayRepository: DayRepositoryProtocol

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
        self.dayRepository = DayRepository(modelContainer: modelContainer)
        self.readinessScoreRepository = ReadinessScoreRepository(modelContainer: modelContainer)
    }

    // MARK: - Sample Data

    /// Populates the repositories with sample data for development in the simulator.
    /// Only runs once per install (checks UserDefaults).
    func populateSampleDataIfNeeded() async {
        guard AppContainer.isSimulator else { return }

        let key = "hasPopulatedSampleDataV2"  // Bumped version for Day-based data
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        // Generate and save sample Days
        let sampleDays = Self.generateSampleDays()
        for day in sampleDays {
            try? await dayRepository.save(day)
        }

        UserDefaults.standard.set(true, forKey: key)
    }

    /// Generates sample historical Days for the past 14 days
    private static func generateSampleDays() -> [Day] {
        let calendar = Calendar.current
        let today = Date()
        var days: [Day] = []

        for daysAgo in 1..<14 {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else {
                continue
            }

            let dayStart = calendar.startOfDay(for: date)

            // First check-in (around 7-9 AM)
            let firstHour = Int.random(in: 7...9)
            let firstMinute = Int.random(in: 0...59)
            guard let firstTimestamp = calendar.date(bySettingHour: firstHour, minute: firstMinute, second: 0, of: date) else {
                continue
            }
            let firstEnergy = Int.random(in: 2...5)

            // Health metrics
            let healthMetrics = HealthMetrics(
                date: date,
                restingHeartRate: Double.random(in: 52...72),
                hrv: Double.random(in: 25...75),
                sleepDuration: TimeInterval.random(in: 5*3600...9*3600),
                steps: Int.random(in: 3000...15000),
                activeCalories: Double.random(in: 150...650)
            )

            // Second check-in (around 8-10 PM) - 80% chance of having one
            var secondCheckIn: CheckInSlot? = nil
            if Int.random(in: 1...10) <= 8 {
                let secondHour = Int.random(in: 20...22)
                let secondMinute = Int.random(in: 0...59)
                if let secondTimestamp = calendar.date(bySettingHour: secondHour, minute: secondMinute, second: 0, of: date) {
                    let secondEnergy = Int.random(in: 2...5)
                    secondCheckIn = CheckInSlot(timestamp: secondTimestamp, energyLevel: secondEnergy)
                }
            }

            // Create readiness score
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

            let readinessScore = ReadinessScore(
                date: date,
                score: score,
                breakdown: ReadinessBreakdown(
                    hrvScore: max(15, min(95, hrvScore)),
                    restingHeartRateScore: max(15, min(95, rhrScore)),
                    sleepScore: max(15, min(95, sleepScore)),
                    energyScore: max(20, min(100, energyScore))
                ),
                confidence: confidence,
                healthMetrics: healthMetrics,
                userEnergyLevel: firstEnergy
            )

            days.append(Day(
                startDate: dayStart,
                firstCheckIn: CheckInSlot(timestamp: firstTimestamp, energyLevel: firstEnergy),
                secondCheckIn: secondCheckIn,
                healthMetrics: healthMetrics,
                readinessScore: readinessScore
            ))
        }

        return days
    }

    /// Creates a container with custom dependencies (for testing/previews).
    init(
        healthKitService: HealthKitServiceProtocol,
        readinessCalculator: ReadinessCalculatorProtocol = ReadinessCalculator(),
        readinessService: ReadinessService? = nil,
        dayRepository: DayRepositoryProtocol? = nil,
        readinessScoreRepository: ReadinessScoreRepositoryProtocol? = nil
    ) {
        self.healthKitService = healthKitService
        self.readinessCalculator = readinessCalculator
        self.readinessService = readinessService ?? ReadinessService(rulesCalculator: readinessCalculator)
        self.dayRepository = dayRepository ?? MockDayRepository()
        self.readinessScoreRepository = readinessScoreRepository ?? MockReadinessScoreRepository()
    }
}
