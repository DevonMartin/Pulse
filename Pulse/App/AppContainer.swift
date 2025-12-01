//
//  AppContainer.swift
//  Pulse
//
//  Created by Devon Martin on 12/1/2025.
//

import HealthKit

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
final class AppContainer {

    // MARK: - Services

    /// The health data service. Uses mock in simulator, real HealthKit on device.
    let healthKitService: HealthKitServiceProtocol

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
    init() {
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
    }

    /// Creates a container with custom dependencies (for testing/previews).
    init(healthKitService: HealthKitServiceProtocol) {
        self.healthKitService = healthKitService
    }
}
