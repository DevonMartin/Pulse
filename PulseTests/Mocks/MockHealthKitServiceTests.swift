//
//  MockHealthKitServiceTests.swift
//  PulseTests
//
//  Created by Devon Martin on 12/1/2025.
//

import Testing
@testable import Pulse
import Foundation

struct MockHealthKitServiceTests {

    // MARK: - Authorization Status Tests

    @Test func initialStatusIsNotDetermined() async {
        let service = await MockHealthKitService()

        let status = await service.authorizationStatus

        #expect(status == .notDetermined)
    }

    @Test func mockStatusCanBeConfiguredToDenied() async {
        let service = await MockHealthKitService()
        await MainActor.run {
            service.mockAuthorizationStatus = .denied
        }

        let status = await service.authorizationStatus

        #expect(status == .denied)
    }

    @Test func mockStatusCanBeConfiguredToAuthorized() async {
        let service = await MockHealthKitService()
        await MainActor.run {
            service.mockAuthorizationStatus = .authorized
        }

        let status = await service.authorizationStatus

        #expect(status == .authorized)
    }

    @Test func mockStatusCanBeConfiguredToUnavailable() async {
        let service = await MockHealthKitService()
        await MainActor.run {
            service.mockAuthorizationStatus = .unavailable
        }

        let status = await service.authorizationStatus

        #expect(status == .unavailable)
    }

    // MARK: - Request Authorization Tests

    @Test func requestAuthorizationUpdatesStatusToAuthorized() async throws {
        let service = await MockHealthKitService()

        try await service.requestAuthorization()

        let status = await service.authorizationStatus
        #expect(status == .authorized)
    }

    @Test func requestAuthorizationIncrementsCallCount() async throws {
        let service = await MockHealthKitService()

        try await service.requestAuthorization()
        try await service.requestAuthorization()
        try await service.requestAuthorization()

        #expect(await service.requestAuthorizationCallCount == 3)
    }

    @Test func requestAuthorizationThrowsConfiguredError() async {
        let service = await MockHealthKitService()
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
        let service = await MockHealthKitService()
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
        let service = await MockHealthKitService()
        let today = Date()

        let metrics = try await service.fetchMetrics(for: today)

        #expect(metrics.date == today)
        #expect(metrics.hasAnyData)
        #expect(metrics.restingHeartRate != nil)
        #expect(metrics.hrv != nil)
        #expect(metrics.sleepDuration != nil)
        #expect(metrics.steps != nil)
        #expect(metrics.activeCalories != nil)
    }

    @Test func fetchMetricsReturnsConfiguredMockData() async throws {
        let service = await MockHealthKitService()
        let testDate = Date()
        let customMetrics = HealthMetrics(
            date: testDate,
            restingHeartRate: 62,
            hrv: 45,
            sleepDuration: 7 * 3600,
            steps: 8000,
            activeCalories: 350
        )
        await MainActor.run {
            service.mockMetrics = customMetrics
        }

        let metrics = try await service.fetchMetrics(for: testDate)

        #expect(metrics.restingHeartRate == 62)
        #expect(metrics.hrv == 45)
		#expect(metrics.sleepDuration == 7.0 * 3600)
        #expect(metrics.steps == 8000)
        #expect(metrics.activeCalories == 350)
    }

    @Test func fetchMetricsTracksCalledDates() async throws {
        let service = await MockHealthKitService()
        let date1 = Date()
        let date2 = Calendar.current.date(byAdding: .day, value: -1, to: date1)!

        _ = try await service.fetchMetrics(for: date1)
        _ = try await service.fetchMetrics(for: date2)

        let dates = await service.fetchMetricsDates
        #expect(dates.count == 2)
    }

    @Test func fetchMetricsUsesCorrectDateInReturnedMetrics() async throws {
        let service = await MockHealthKitService()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        let metrics = try await service.fetchMetrics(for: yesterday)

        #expect(metrics.date == yesterday)
    }

    @Test func fetchMetricsReturnsEmptyMetricsWhenConfigured() async throws {
        let service = await MockHealthKitService()
        let emptyMetrics = HealthMetrics(
            date: Date(),
            restingHeartRate: nil,
            hrv: nil,
            sleepDuration: nil,
            steps: nil,
            activeCalories: nil
        )
        await MainActor.run {
            service.mockMetrics = emptyMetrics
        }

        let metrics = try await service.fetchMetrics(for: Date())

        #expect(metrics.hasAnyData == false)
    }

    // MARK: - Simulated Delay Tests

    @Test func fetchMetricsRespectsSimulatedDelay() async throws {
        let service = await MockHealthKitService()
        await MainActor.run {
		    service.simulatedDelay = 0.1 // 100ms
        }

        let startTime = Date()
        _ = try await service.fetchMetrics(for: Date())
        let elapsed = Date().timeIntervalSince(startTime)

        #expect(elapsed >= 0.1)
    }
}
