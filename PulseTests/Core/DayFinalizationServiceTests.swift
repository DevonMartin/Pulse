//
//  DayFinalizationServiceTests.swift
//  PulseTests
//
//  Created by Devon Martin on 3/10/2026.
//

import Testing
@testable import Pulse
import Foundation

/// Tests for the DayFinalizationService.
///
/// Verifies:
/// 1. Past days get their final activity metrics from HealthKit
/// 2. Recovery metrics (RHR, HRV, sleep) are not overwritten
/// 3. Days are marked finalized even when HealthKit has no data
/// 4. The current day is never finalized
/// 5. Transient HealthKit failures skip the day (retried next foreground)
@MainActor
struct DayFinalizationServiceTests {

    // MARK: - Helpers

    private let calendar = Calendar.current

    private func makeService(
        repository: MockDayRepository,
        healthKit: MockHealthKitService? = nil
    ) -> DayFinalizationService {
        DayFinalizationService(dayRepository: repository, healthKitService: healthKit ?? MockHealthKitService())
    }

    private func yesterday() -> Date {
        calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!
    }

    // MARK: - Tests

    @Test func noUnfinalizedDaysReturnsZero() async {
        let repo = MockDayRepository(currentUserDayStart: calendar.startOfDay(for: Date()))
        let service = makeService(repository: repo)

        let count = await service.finalizePastDays()

        #expect(count == 0)
    }

    @Test func finalizesUnfinalizedPastDay() async {
        let today = calendar.startOfDay(for: Date())
        let yesterdayDate = yesterday()

        let day = Day(
            startDate: yesterdayDate,
            firstCheckIn: CheckInSlot(energyLevel: 3),
            healthMetrics: HealthMetrics(
                date: yesterdayDate,
                restingHeartRate: 60,
                hrv: 50,
                sleepDuration: 7 * 3600,
                steps: 5_000,
                activeCalories: 200
            )
        )

        let repo = MockDayRepository(currentUserDayStart: today, initialDays: [day])

        let healthKit = MockHealthKitService()
        healthKit.mockMetrics = HealthMetrics(
            date: yesterdayDate,
            restingHeartRate: 62,
            hrv: 48,
            sleepDuration: 7.5 * 3600,
            steps: 12_000,
            activeCalories: 500
        )

        let service = makeService(repository: repo, healthKit: healthKit)
        let count = await service.finalizePastDays()

        #expect(count == 1)

        let savedDay = await repo.days.first!
        #expect(savedDay.isActivityFinalized == true)
        // Activity should be updated (takes max)
        #expect(savedDay.healthMetrics?.steps == 12_000)
        #expect(savedDay.healthMetrics?.activeCalories == 500)
    }

    @Test func preservesRecoveryMetrics() async {
        let today = calendar.startOfDay(for: Date())
        let yesterdayDate = yesterday()

        let day = Day(
            startDate: yesterdayDate,
            firstCheckIn: CheckInSlot(energyLevel: 3),
            healthMetrics: HealthMetrics(
                date: yesterdayDate,
                restingHeartRate: 58,
                hrv: 65,
                sleepDuration: 8 * 3600,
                steps: 3_000,
                activeCalories: 100
            )
        )

        let repo = MockDayRepository(currentUserDayStart: today, initialDays: [day])

        let healthKit = MockHealthKitService()
        // HealthKit returns different recovery metrics — these should be ignored
        healthKit.mockMetrics = HealthMetrics(
            date: yesterdayDate,
            restingHeartRate: 72,
            hrv: 30,
            sleepDuration: 5 * 3600,
            steps: 10_000,
            activeCalories: 400
        )

        let service = makeService(repository: repo, healthKit: healthKit)
        await service.finalizePastDays()

        let savedDay = await repo.days.first!
        // Recovery metrics should be preserved from the original
        #expect(savedDay.healthMetrics?.restingHeartRate == 58)
        #expect(savedDay.healthMetrics?.hrv == 65)
        #expect(savedDay.healthMetrics?.sleepDuration == 8.0 * 3600)
        // Activity metrics should be updated
        #expect(savedDay.healthMetrics?.steps == 10_000)
        #expect(savedDay.healthMetrics?.activeCalories == 400)
    }

    @Test func markedFinalizedEvenWhenHealthKitReturnsNoData() async {
        let today = calendar.startOfDay(for: Date())
        let yesterdayDate = yesterday()

        let day = Day(
            startDate: yesterdayDate,
            firstCheckIn: CheckInSlot(energyLevel: 3),
            healthMetrics: HealthMetrics(date: yesterdayDate, steps: 2_000)
        )

        let repo = MockDayRepository(currentUserDayStart: today, initialDays: [day])

        let healthKit = MockHealthKitService()
        healthKit.mockMetrics = HealthMetrics(date: yesterdayDate) // No meaningful data

        let service = makeService(repository: repo, healthKit: healthKit)
        let count = await service.finalizePastDays()

        #expect(count == 1)
        let savedDay = await repo.days.first!
        #expect(savedDay.isActivityFinalized == true)
        // Original metrics should be preserved
        #expect(savedDay.healthMetrics?.steps == 2_000)
    }

    @Test func doesNotFinalizeCurrentDay() async {
        let today = calendar.startOfDay(for: Date())

        // Create a day for today — should not be finalized
        let day = Day(
            startDate: today,
            firstCheckIn: CheckInSlot(energyLevel: 3),
            healthMetrics: HealthMetrics(date: today, steps: 1_000)
        )

        let repo = MockDayRepository(currentUserDayStart: today, initialDays: [day])
        let service = makeService(repository: repo)

        let count = await service.finalizePastDays()

        #expect(count == 0)
        let savedDay = await repo.days.first!
        #expect(savedDay.isActivityFinalized == false)
    }

    @Test func skipsAlreadyFinalizedDays() async {
        let today = calendar.startOfDay(for: Date())
        let yesterdayDate = yesterday()

        let day = Day(
            startDate: yesterdayDate,
            firstCheckIn: CheckInSlot(energyLevel: 3),
            healthMetrics: HealthMetrics(date: yesterdayDate, steps: 10_000),
            isActivityFinalized: true
        )

        let repo = MockDayRepository(currentUserDayStart: today, initialDays: [day])
        let service = makeService(repository: repo)

        let count = await service.finalizePastDays()

        #expect(count == 0) // Already finalized, nothing to do
    }

    @Test func skipsDayWhenHealthKitFetchFails() async {
        let today = calendar.startOfDay(for: Date())
        let yesterdayDate = yesterday()

        let day = Day(
            startDate: yesterdayDate,
            firstCheckIn: CheckInSlot(energyLevel: 3),
            healthMetrics: HealthMetrics(date: yesterdayDate, steps: 3_000)
        )

        let repo = MockDayRepository(currentUserDayStart: today, initialDays: [day])

        let healthKit = MockHealthKitService()
        healthKit.fetchMetricsError = NSError(domain: "HKError", code: -1)

        let service = makeService(repository: repo, healthKit: healthKit)
        let count = await service.finalizePastDays()

        #expect(count == 0) // Skipped due to error
        let savedDay = await repo.days.first!
        #expect(savedDay.isActivityFinalized == false) // Not marked finalized
        #expect(savedDay.healthMetrics?.steps == 3_000) // Original preserved
    }
}
