//
//  MockHealthKitServiceTests.swift
//  PulseTests
//
//  Created by Devon Martin on 12/1/2025.
//

import Testing
@testable import Pulse
import Foundation

@MainActor
struct MockHealthKitServiceTests {

    /// Computes a midnight-to-midnight range for the given date (used as a convenience in tests).
    private func dayRange(for date: Date) -> (start: Date, end: Date) {
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        return (start, end)
    }

    // MARK: - Authorization Status Tests

    @Test func initialStatusIsNotDetermined() async {
        let service = MockHealthKitService()

        let status = await service.authorizationStatus

        #expect(status == .notDetermined)
    }

    @Test func mockStatusCanBeConfiguredToDenied() async {
        let service = MockHealthKitService()
        await MainActor.run {
            service.mockAuthorizationStatus = .denied
        }

        let status = await service.authorizationStatus

        #expect(status == .denied)
    }

    @Test func mockStatusCanBeConfiguredToAuthorized() async {
        let service = MockHealthKitService()
        await MainActor.run {
            service.mockAuthorizationStatus = .authorized
        }

        let status = await service.authorizationStatus

        #expect(status == .authorized)
    }

    @Test func mockStatusCanBeConfiguredToUnavailable() async {
        let service = MockHealthKitService()
        await MainActor.run {
            service.mockAuthorizationStatus = .unavailable
        }

        let status = await service.authorizationStatus

        #expect(status == .unavailable)
    }

    // MARK: - Request Authorization Tests

    @Test func requestAuthorizationUpdatesStatusToAuthorized() async throws {
        let service = MockHealthKitService()

        try await service.requestAuthorization()

        let status = await service.authorizationStatus
        #expect(status == .authorized)
    }

    @Test func requestAuthorizationIncrementsCallCount() async throws {
        let service = MockHealthKitService()

        try await service.requestAuthorization()
        try await service.requestAuthorization()
        try await service.requestAuthorization()

        #expect(service.requestAuthorizationCallCount == 3)
    }

    @Test func requestAuthorizationThrowsConfiguredError() async {
        let service = MockHealthKitService()
        let expectedError = NSError(domain: "TestError", code: 42)
        await MainActor.run {
            service.authorizationError = expectedError
        }

        do {
            try await service.requestAuthorization()
            #expect(Bool(false), "Expected error to be thrown")
        } catch {
            #expect((error as NSError).code == 42)
            #expect((error as NSError).domain == "TestError")
        }
    }

    @Test func requestAuthorizationDoesNotChangeStatusWhenErrorConfigured() async {
        let service = MockHealthKitService()
        await MainActor.run {
            service.authorizationError = NSError(domain: "Test", code: 1)
        }

        do {
            try await service.requestAuthorization()
        } catch {
            // Expected
        }

        let status = await service.authorizationStatus
        #expect(status == .notDetermined)
    }

    // MARK: - Fetch Metrics Tests

    @Test func fetchMetricsReturnsSampleDataByDefault() async throws {
        let service = MockHealthKitService()
        let range = dayRange(for: Date())

        let metrics = try await service.fetchMetrics(from: range.start, to: range.end)

        #expect(metrics.date == range.start)
        #expect(metrics.hasAnyData)
        #expect(metrics.restingHeartRate != nil)
        #expect(metrics.hrv != nil)
        #expect(metrics.sleepDuration != nil)
        #expect(metrics.steps != nil)
        #expect(metrics.activeCalories != nil)
    }

    @Test func fetchMetricsReturnsConfiguredMockData() async throws {
        let service = MockHealthKitService()
        let range = dayRange(for: Date())
        let customMetrics = HealthMetrics(
            date: range.start,
            restingHeartRate: 62,
            hrv: 45,
            sleepDuration: 7 * 3600,
            steps: 8000,
            activeCalories: 350
        )
        await MainActor.run {
            service.mockMetrics = customMetrics
        }

        let metrics = try await service.fetchMetrics(from: range.start, to: range.end)

        #expect(metrics.restingHeartRate == 62)
        #expect(metrics.hrv == 45)
		#expect(metrics.sleepDuration == 7.0 * 3600)
        #expect(metrics.steps == 8000)
        #expect(metrics.activeCalories == 350)
    }

    @Test func fetchMetricsTracksCalledRanges() async throws {
        let service = MockHealthKitService()
        let range1 = dayRange(for: Date())
        let range2 = dayRange(for: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)

        _ = try await service.fetchMetrics(from: range1.start, to: range1.end)
        _ = try await service.fetchMetrics(from: range2.start, to: range2.end)

        let ranges = service.fetchMetricsRanges
        #expect(ranges.count == 2)
    }

    @Test func fetchMetricsUsesCorrectDateInReturnedMetrics() async throws {
        let service = MockHealthKitService()
        let range = dayRange(for: Calendar.current.date(byAdding: .day, value: -1, to: Date())!)

        let metrics = try await service.fetchMetrics(from: range.start, to: range.end)

        #expect(metrics.date == range.start)
    }

    @Test func fetchMetricsReturnsEmptyMetricsWhenConfigured() async throws {
        let service = MockHealthKitService()
        let range = dayRange(for: Date())
        let emptyMetrics = HealthMetrics(
            date: range.start,
            restingHeartRate: nil,
            hrv: nil,
            sleepDuration: nil,
            steps: nil,
            activeCalories: nil
        )
        await MainActor.run {
            service.mockMetrics = emptyMetrics
        }

        let metrics = try await service.fetchMetrics(from: range.start, to: range.end)

        #expect(metrics.hasAnyData == false)
    }

    // MARK: - Simulated Delay Tests

    @Test func fetchMetricsRespectsSimulatedDelay() async throws {
        let service = MockHealthKitService()
        await MainActor.run {
		    service.simulatedDelay = 0.1 // 100ms
        }

        let startTime = Date()
        let range = dayRange(for: Date())
        _ = try await service.fetchMetrics(from: range.start, to: range.end)
        let elapsed = Date().timeIntervalSince(startTime)

        #expect(elapsed >= 0.1)
    }
}
