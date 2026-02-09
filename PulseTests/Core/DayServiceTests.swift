//
//  DayServiceTests.swift
//  PulseTests
//
//  Created by Devon Martin on 12/7/2025.
//

import Testing
@testable import Pulse
import Foundation

// MARK: - Mock Time Window Provider

/// Mock time window provider for testing different time scenarios.
struct MockTimeWindowProvider: TimeWindowProvider, Sendable {
    nonisolated var isMorningWindow: Bool
    nonisolated var currentUserDayStart: Date

    init(isMorningWindow: Bool = true, currentUserDayStart: Date = Date()) {
        self.isMorningWindow = isMorningWindow
        self.currentUserDayStart = Calendar.current.startOfDay(for: currentUserDayStart)
    }
}

// MARK: - Day Service Tests

@MainActor
struct DayServiceTests {

    // MARK: - Test Helpers

    /// Standard date used for all tests - ensures consistency between components
    private var testDate: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private func makeService(
        dayRepository: MockDayRepository? = nil,
        healthKitService: MockHealthKitService? = nil,
        isMorningWindow: Bool = true
    ) -> (service: DayService, repository: MockDayRepository, healthKit: MockHealthKitService, testDate: Date) {
        let currentDate = testDate
        let repo = dayRepository ?? MockDayRepository(currentUserDayStart: currentDate)
        let health = healthKitService ?? MockHealthKitService()
        let readinessService = ReadinessService(rulesCalculator: ReadinessCalculator())
        let timeProvider = MockTimeWindowProvider(isMorningWindow: isMorningWindow, currentUserDayStart: currentDate)

        let service = DayService(
            dayRepository: repo,
            healthKitService: health,
            readinessService: readinessService,
            timeWindowProvider: timeProvider
        )

        return (service, repo, health, currentDate)
    }

    private func makeMetrics(
        restingHeartRate: Double? = 60,
        hrv: Double? = 45,
        sleepDuration: TimeInterval? = 7 * 3600,
        steps: Int? = 8000,
        activeCalories: Double? = 350
    ) -> HealthMetrics {
        HealthMetrics(
            date: Date(),
            restingHeartRate: restingHeartRate,
            hrv: hrv,
            sleepDuration: sleepDuration,
            steps: steps,
            activeCalories: activeCalories
        )
    }

    // MARK: - Load and Update Today Tests

    @Test func loadAndUpdateTodayCreatesDayDuringMorningWindow() async throws {
        let mockHealth = MockHealthKitService()
        mockHealth.mockMetrics = makeMetrics()

        let (service, _, _, _) = makeService(
            healthKitService: mockHealth,
            isMorningWindow: true
        )

        let result = try await service.loadAndUpdateToday()

        #expect(result.day != nil)
        #expect(result.freshMetrics != nil)
        #expect(result.metricsWereUpdated == true)
    }

    @Test func loadAndUpdateTodayUpdatesOnlyActivityMetricsAfterMorningWindow() async throws {
        let mockHealth = MockHealthKitService()
        mockHealth.mockMetrics = makeMetrics(steps: 8000, activeCalories: 350)

        let (service, _, _, _) = makeService(
            healthKitService: mockHealth,
            isMorningWindow: false
        )

        let result = try await service.loadAndUpdateToday()

        // After morning window, we still create/update a Day for activity metrics
        #expect(result.day != nil)
        #expect(result.freshMetrics != nil)
        #expect(result.metricsWereUpdated == true)

        // But only activity metrics should be stored (not recovery metrics)
        #expect(result.day?.healthMetrics?.steps == 8000)
        #expect(result.day?.healthMetrics?.activeCalories == 350)
        #expect(result.day?.healthMetrics?.restingHeartRate == nil)
        #expect(result.day?.healthMetrics?.hrv == nil)
        #expect(result.day?.healthMetrics?.sleepDuration == nil)
    }

    @Test func loadAndUpdateTodayMergesMetricsDuringMorningWindow() async throws {
        let currentDate = testDate
        let mockRepo = MockDayRepository(currentUserDayStart: currentDate)
        let mockHealth = MockHealthKitService()

        // Existing day with partial metrics - use the same date as mock repo
        let existingDay = Day(
            startDate: currentDate,
            healthMetrics: makeMetrics(restingHeartRate: 62, hrv: nil, sleepDuration: nil)
        )
        try await mockRepo.save(existingDay)

        // Fresh metrics have HRV and sleep
        mockHealth.mockMetrics = makeMetrics(restingHeartRate: 70, hrv: 50, sleepDuration: 8 * 3600)

        let (service, _, _, _) = makeService(
            dayRepository: mockRepo,
            healthKitService: mockHealth,
            isMorningWindow: true
        )

        let result = try await service.loadAndUpdateToday()

        #expect(result.day != nil)
        #expect(result.metricsWereUpdated == true)
        // Should keep original RHR (62), fill in HRV (50) and sleep (8h)
        #expect(result.day?.healthMetrics?.restingHeartRate == 62)
        #expect(result.day?.healthMetrics?.hrv == 50)
        #expect(result.day?.healthMetrics?.sleepDuration == 8.0 * 3600)
    }

    @Test func loadAndUpdateTodayDoesNotOverwriteExistingMetrics() async throws {
        let currentDate = testDate
        let mockRepo = MockDayRepository(currentUserDayStart: currentDate)
        let mockHealth = MockHealthKitService()

        // Existing day with full metrics
        let existingDay = Day(
            startDate: currentDate,
            healthMetrics: makeMetrics(restingHeartRate: 62, hrv: 50, sleepDuration: 7 * 3600)
        )
        try await mockRepo.save(existingDay)

        // Fresh metrics have different values
        mockHealth.mockMetrics = makeMetrics(restingHeartRate: 70, hrv: 30, sleepDuration: 6 * 3600)

        let (service, _, _, _) = makeService(
            dayRepository: mockRepo,
            healthKitService: mockHealth,
            isMorningWindow: true
        )

        let result = try await service.loadAndUpdateToday()

        #expect(result.metricsWereUpdated == false)
        // Should keep all original values
        #expect(result.day?.healthMetrics?.restingHeartRate == 62)
        #expect(result.day?.healthMetrics?.hrv == 50)
		#expect(result.day?.healthMetrics?.sleepDuration == 7.0 * 3600)
    }

    @Test func loadAndUpdateTodayRecalculatesScoreWhenMetricsChangeAndHasMorningCheckIn() async throws {
        let currentDate = testDate
        let mockRepo = MockDayRepository(currentUserDayStart: currentDate)
        let mockHealth = MockHealthKitService()

        // Existing day with morning check-in but missing HRV
        var existingDay = Day(
            startDate: currentDate,
            firstCheckIn: CheckInSlot(energyLevel: 4),
            healthMetrics: makeMetrics(restingHeartRate: 62, hrv: nil, sleepDuration: 7 * 3600)
        )
        existingDay.readinessScore = ReadinessScore(
            date: currentDate,
            score: 70,
            breakdown: ReadinessBreakdown(hrvScore: nil, restingHeartRateScore: 75, sleepScore: 80, energyScore: 80),
            confidence: .partial
        )
        try await mockRepo.save(existingDay)

        // Fresh metrics now have HRV
        mockHealth.mockMetrics = makeMetrics(restingHeartRate: 70, hrv: 50, sleepDuration: 8 * 3600)

        let (service, _, _, _) = makeService(
            dayRepository: mockRepo,
            healthKitService: mockHealth,
            isMorningWindow: true
        )

        let result = try await service.loadAndUpdateToday()

        #expect(result.metricsWereUpdated == true)
        #expect(result.scoreWasRecalculated == true)
        #expect(result.day?.readinessScore != nil)
    }

    @Test func loadAndUpdateTodayDoesNotRecalculateScoreWithoutMorningCheckIn() async throws {
        let currentDate = testDate
        let mockRepo = MockDayRepository(currentUserDayStart: currentDate)
        let mockHealth = MockHealthKitService()

        // Existing day WITHOUT morning check-in
        let existingDay = Day(
            startDate: currentDate,
            healthMetrics: makeMetrics(restingHeartRate: 62, hrv: nil, sleepDuration: nil)
        )
        try await mockRepo.save(existingDay)

        // Fresh metrics have HRV
        mockHealth.mockMetrics = makeMetrics(restingHeartRate: 70, hrv: 50, sleepDuration: 8 * 3600)

        let (service, _, _, _) = makeService(
            dayRepository: mockRepo,
            healthKitService: mockHealth,
            isMorningWindow: true
        )

        let result = try await service.loadAndUpdateToday()

        #expect(result.metricsWereUpdated == true)
        #expect(result.scoreWasRecalculated == false)
        #expect(result.day?.readinessScore == nil)
    }

    // MARK: - Update Day With Metrics Tests

    @Test func updateDayWithMetricsCreatesNewDayWhenNoneExists() async throws {
        let freshMetrics = makeMetrics()

        let (service, _, _, _) = makeService(isMorningWindow: true)

        let result = try await service.updateDayWithMetrics(
            currentDay: nil,
            freshMetrics: freshMetrics
        )

        #expect(result.day != nil)
        #expect(result.metricsChanged == true)
        #expect(result.day?.healthMetrics?.restingHeartRate == freshMetrics.restingHeartRate)
    }

    @Test func updateDayWithMetricsOnlyFillsNilFields() async throws {
        let currentDate = testDate
        let existingDay = Day(
            startDate: currentDate,
            healthMetrics: makeMetrics(restingHeartRate: 55, hrv: nil, sleepDuration: 6 * 3600, steps: nil, activeCalories: nil)
        )

        let freshMetrics = makeMetrics(restingHeartRate: 70, hrv: 60, sleepDuration: 8 * 3600, steps: 10000, activeCalories: 500)

        let (service, _, _, _) = makeService(isMorningWindow: true)

        let result = try await service.updateDayWithMetrics(
            currentDay: existingDay,
            freshMetrics: freshMetrics
        )

        #expect(result.metricsChanged == true)
        #expect(result.day?.healthMetrics?.restingHeartRate == 55) // Kept original
        #expect(result.day?.healthMetrics?.hrv == 60) // Filled from fresh
		#expect(result.day?.healthMetrics?.sleepDuration == 6.0 * 3600) // Kept original
        #expect(result.day?.healthMetrics?.steps == 10000) // Filled from fresh
        #expect(result.day?.healthMetrics?.activeCalories == 500) // Filled from fresh
    }

    @Test func updateDayWithMetricsReturnsNoChangeWhenNothingNew() async throws {
        let currentDate = testDate
        // Existing day with full metrics
        let existingDay = Day(
            startDate: currentDate,
            healthMetrics: makeMetrics()
        )

        // Fresh metrics are the same or have values for already-filled fields
        let freshMetrics = makeMetrics()

        let (service, _, _, _) = makeService(isMorningWindow: true)

        let result = try await service.updateDayWithMetrics(
            currentDay: existingDay,
            freshMetrics: freshMetrics
        )

        #expect(result.metricsChanged == false)
    }
}
