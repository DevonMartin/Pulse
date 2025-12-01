//
//  MockHealthKitService.swift
//  Pulse
//
//  Created by Devon Martin on 12/1/2025.
//

import Foundation

/// A mock implementation of HealthKitServiceProtocol for development and testing.
///
/// This allows us to:
/// - Run the app in the simulator (HealthKit requires a real device)
/// - Write unit tests without HealthKit entitlements
/// - Control exactly what data is returned for specific test scenarios
///
/// The mock is configurable - you can set what authorization status it should
/// report, whether authorization should succeed or fail, etc.
@MainActor
final class MockHealthKitService: HealthKitServiceProtocol {

    // MARK: - Configurable Behavior

    /// The authorization status this mock will report
    var mockAuthorizationStatus: HealthKitAuthorizationStatus = .notDetermined

    /// If set, requestAuthorization() will throw this error
    var authorizationError: Error?

    /// The metrics to return from fetchMetrics(). If nil, returns realistic sample data.
    var mockMetrics: HealthMetrics?

    /// Tracks whether requestAuthorization() was called (useful for tests)
    private(set) var requestAuthorizationCallCount = 0

    /// Tracks the dates passed to fetchMetrics() (useful for tests)
    private(set) var fetchMetricsDates: [Date] = []

    // MARK: - HealthKitServiceProtocol

    var authorizationStatus: HealthKitAuthorizationStatus {
        get async {
            mockAuthorizationStatus
        }
    }

    func requestAuthorization() async throws {
        requestAuthorizationCallCount += 1

        if let error = authorizationError {
            throw error
        }

        // Simulate successful authorization by updating status
        mockAuthorizationStatus = .authorized
    }

    func fetchMetrics(for date: Date) async throws -> HealthMetrics {
        fetchMetricsDates.append(date)
		try await Task.sleep(nanoseconds: 1_000_000_000)

        // Return custom mock data if set, otherwise return realistic sample data
        if let mockMetrics = mockMetrics {
            return mockMetrics
        }

        // Generate realistic sample data for development
        return Self.sampleMetrics(for: date)
    }

    // MARK: - Sample Data

    /// Generates realistic sample health metrics for development/preview purposes.
    /// Values are randomized within healthy ranges to simulate real data.
    static func sampleMetrics(for date: Date) -> HealthMetrics {
        HealthMetrics(
            date: date,
            restingHeartRate: Double.random(in: 55...70),
            hrv: Double.random(in: 30...60),
            sleepDuration: TimeInterval.random(in: 6*3600...8.5*3600), // 6-8.5 hours
            steps: Int.random(in: 4000...12000),
            activeCalories: Double.random(in: 200...600)
        )
    }
}
