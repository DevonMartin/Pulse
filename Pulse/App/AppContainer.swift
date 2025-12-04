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

    /// The readiness score calculator
    let readinessCalculator: ReadinessCalculatorProtocol

    // MARK: - Repositories

    /// The check-in data repository
    let checkInRepository: CheckInRepositoryProtocol

    // MARK: - Environment Detection

    /// Returns true if running in the iOS Simulator
    private static var isSimulator: Bool {
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

        // Create repository with the model container
        self.checkInRepository = CheckInRepository(modelContainer: modelContainer)
    }

    /// Creates a container with custom dependencies (for testing/previews).
    init(
        healthKitService: HealthKitServiceProtocol,
        readinessCalculator: ReadinessCalculatorProtocol = ReadinessCalculator(),
        checkInRepository: CheckInRepositoryProtocol? = nil
    ) {
        self.healthKitService = healthKitService
        self.readinessCalculator = readinessCalculator
        self.checkInRepository = checkInRepository ?? MockCheckInRepository()
    }
}
