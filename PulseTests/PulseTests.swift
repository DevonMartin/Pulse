//
//  PulseTests.swift
//  PulseTests
//
//  Created by Devon Martin on 12/1/2025.
//

import Testing
@testable import Pulse
import Foundation

// MARK: - MockHealthKitService Tests

struct MockHealthKitServiceTests {

    // MARK: - Authorization Tests

    @Test func initialStatusIsNotDetermined() async {
        let service = await MockHealthKitService()

        let status = await service.authorizationStatus

        #expect(status == .notDetermined)
    }

    @Test func requestAuthorizationUpdatesStatus() async throws {
        let service = await MockHealthKitService()

        try await service.requestAuthorization()

        let status = await service.authorizationStatus
        #expect(status == .authorized)
        #expect(await service.requestAuthorizationCallCount == 1)
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
        }
    }

    @Test func mockStatusCanBeConfigured() async {
        let service = await MockHealthKitService()
        await MainActor.run {
            service.mockAuthorizationStatus = .denied
        }

        let status = await service.authorizationStatus

        #expect(status == .denied)
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
        #expect(metrics.steps == 8000)
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
}

// MARK: - HealthMetrics Tests

struct HealthMetricsTests {

    @Test func formattedSleepDurationShowsHoursAndMinutes() {
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: nil,
            hrv: nil,
            sleepDuration: 7 * 3600 + 30 * 60, // 7h 30m
            steps: nil,
            activeCalories: nil
        )

        #expect(metrics.formattedSleepDuration == "7h 30m")
    }

    @Test func formattedSleepDurationShowsMinutesOnlyWhenUnderOneHour() {
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: nil,
            hrv: nil,
            sleepDuration: 45 * 60, // 45 minutes
            steps: nil,
            activeCalories: nil
        )

        #expect(metrics.formattedSleepDuration == "45m")
    }

    @Test func formattedSleepDurationIsNilWhenNoData() {
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: nil,
            hrv: nil,
            sleepDuration: nil,
            steps: nil,
            activeCalories: nil
        )

        #expect(metrics.formattedSleepDuration == nil)
    }

    @Test func hasAnyDataReturnsTrueWhenAnyMetricPresent() {
        let metricsWithSteps = HealthMetrics(
            date: Date(),
            restingHeartRate: nil,
            hrv: nil,
            sleepDuration: nil,
            steps: 5000,
            activeCalories: nil
        )

        #expect(metricsWithSteps.hasAnyData == true)
    }

    @Test func hasAnyDataReturnsFalseWhenAllNil() {
        let emptyMetrics = HealthMetrics(
            date: Date(),
            restingHeartRate: nil,
            hrv: nil,
            sleepDuration: nil,
            steps: nil,
            activeCalories: nil
        )

        #expect(emptyMetrics.hasAnyData == false)
    }
}
