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

// MARK: - CheckIn Model Tests

struct CheckInTests {

    @Test func checkInIsTodayWhenTimestampIsToday() {
        let checkIn = CheckIn(
            timestamp: Date(),
            type: .morning,
            energyLevel: 3
        )

        #expect(checkIn.isToday == true)
    }

    @Test func checkInIsNotTodayWhenTimestampIsYesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let checkIn = CheckIn(
            timestamp: yesterday,
            type: .morning,
            energyLevel: 3
        )

        #expect(checkIn.isToday == false)
    }

    @Test func energyDescriptionMapsCorrectly() {
        let levels = [1, 2, 3, 4, 5]
        let expected = ["Very Low", "Low", "Moderate", "High", "Very High"]

        for (level, description) in zip(levels, expected) {
            let checkIn = CheckIn(type: .morning, energyLevel: level)
            #expect(checkIn.energyDescription == description)
        }
    }
}

// MARK: - MockCheckInRepository Tests

struct MockCheckInRepositoryTests {

    @Test func saveAddsCheckInToList() async throws {
        let repository = MockCheckInRepository()
        let checkIn = CheckIn(type: .morning, energyLevel: 4)

        try await repository.save(checkIn)

        let checkIns = await repository.checkIns
        #expect(checkIns.count == 1)
        #expect(checkIns.first?.energyLevel == 4)
    }

    @Test func getTodaysCheckInReturnsMorningCheckIn() async throws {
        let repository = MockCheckInRepository()
        let checkIn = CheckIn(type: .morning, energyLevel: 5)
        try await repository.save(checkIn)

        let result = try await repository.getTodaysCheckIn(type: .morning)

        #expect(result != nil)
        #expect(result?.energyLevel == 5)
    }

    @Test func getTodaysCheckInReturnsNilForDifferentType() async throws {
        let repository = MockCheckInRepository()
        let checkIn = CheckIn(type: .morning, energyLevel: 5)
        try await repository.save(checkIn)

        let result = try await repository.getTodaysCheckIn(type: .evening)

        #expect(result == nil)
    }

    @Test func deleteRemovesCheckIn() async throws {
        let repository = MockCheckInRepository()
        let checkIn = CheckIn(type: .morning, energyLevel: 3)
        try await repository.save(checkIn)

        try await repository.delete(id: checkIn.id)

        let checkIns = await repository.checkIns
        #expect(checkIns.isEmpty)
    }

    @Test func getRecentCheckInsRespectsLimit() async throws {
        let repository = MockCheckInRepository()

        // Add 5 check-ins
        for i in 1...5 {
            let date = Calendar.current.date(byAdding: .hour, value: -i, to: Date())!
            let checkIn = CheckIn(timestamp: date, type: .morning, energyLevel: i)
            try await repository.save(checkIn)
        }

        let recent = try await repository.getRecentCheckIns(limit: 3)

        #expect(recent.count == 3)
    }
}

// MARK: - HealthSnapshotEntity Tests

struct HealthSnapshotEntityTests {

    @Test func initFromHealthMetricsPreservesValues() {
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: 62,
            hrv: 45,
            sleepDuration: 7 * 3600,
            steps: 8000,
            activeCalories: 350
        )

        let entity = HealthSnapshotEntity(from: metrics)

        #expect(entity.restingHeartRateValue == 62)
        #expect(entity.hrvValue == 45)
        #expect(entity.sleepDurationValue == 7 * 3600)
        #expect(entity.stepsValue == 8000)
        #expect(entity.activeCaloriesValue == 350)
    }

    @Test func nilMetricsResultInNilOptionalAccessors() {
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: nil,
            hrv: nil,
            sleepDuration: nil,
            steps: nil,
            activeCalories: nil
        )

        let entity = HealthSnapshotEntity(from: metrics)

        #expect(entity.restingHeartRateValue == nil)
        #expect(entity.hrvValue == nil)
        #expect(entity.sleepDurationValue == nil)
        #expect(entity.stepsValue == nil)
        #expect(entity.activeCaloriesValue == nil)
    }

    @Test func toHealthMetricsRoundTripsCorrectly() {
        let original = HealthMetrics(
            date: Date(),
            restingHeartRate: 65,
            hrv: 50,
            sleepDuration: 8 * 3600,
            steps: 10000,
            activeCalories: 500
        )

        let entity = HealthSnapshotEntity(from: original)
        let converted = entity.toHealthMetrics()

        #expect(converted.restingHeartRate == original.restingHeartRate)
        #expect(converted.hrv == original.hrv)
        #expect(converted.sleepDuration == original.sleepDuration)
        #expect(converted.steps == original.steps)
        #expect(converted.activeCalories == original.activeCalories)
    }
}
