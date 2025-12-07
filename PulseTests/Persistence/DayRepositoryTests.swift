//
//  DayRepositoryTests.swift
//  PulseTests
//
//  Created by Devon Martin on 12/6/2025.
//

import Testing
@testable import Pulse
import Foundation

/// Tests for the MockDayRepository.
///
/// These tests verify the mock implementation works correctly for testing
/// and SwiftUI previews. The real repository tests would require a SwiftData
/// container setup.
@MainActor
struct DayRepositoryTests {

    // MARK: - Test Helpers

    private func makeDay(
        startDate: Date = Date(),
        firstEnergy: Int? = nil,
        secondEnergy: Int? = nil,
        withMetrics: Bool = false
    ) -> Day {
        Day(
            startDate: startDate,
            firstCheckIn: firstEnergy.map { CheckInSlot(energyLevel: $0) },
            secondCheckIn: secondEnergy.map { CheckInSlot(energyLevel: $0) },
            healthMetrics: withMetrics ? HealthMetrics(
                date: startDate,
                restingHeartRate: 60,
                hrv: 50,
                sleepDuration: 7 * 3600
            ) : nil
        )
    }

    private func makeCompleteDay(startDate: Date = Date()) -> Day {
        makeDay(startDate: startDate, firstEnergy: 4, secondEnergy: 3, withMetrics: true)
    }

    // MARK: - getCurrentDay Tests

    @Test func getCurrentDayCreatesNewDayWhenNoneExists() async throws {
        let repository = MockDayRepository()

        let day = try await repository.getCurrentDay()

        #expect(day.hasFirstCheckIn == false)
        #expect(day.hasSecondCheckIn == false)
    }

    @Test func getCurrentDayReturnsExistingDay() async throws {
        let repository = MockDayRepository()

        // Create and save a day for "today"
        let existingDay = makeDay(
            startDate: TimeWindows.currentUserDayStart,
            firstEnergy: 4
        )
        try await repository.save(existingDay)

        // Getting current day should return the existing one
        let retrievedDay = try await repository.getCurrentDay()

        #expect(retrievedDay.id == existingDay.id)
        #expect(retrievedDay.hasFirstCheckIn == true)
        #expect(retrievedDay.firstCheckIn?.energyLevel == 4)
    }

    @Test func getCurrentDayThrowsWhenConfigured() async throws {
        let repository = MockDayRepository()
        await repository.setError(TestError.mockError)

        do {
            _ = try await repository.getCurrentDay()
            Issue.record("Expected error to be thrown")
        } catch {
            #expect(error is TestError)
        }
    }

    // MARK: - getCurrentDayIfExists Tests

    @Test func getCurrentDayIfExistsReturnsNilWhenNoneExists() async throws {
        let repository = MockDayRepository()

        let day = try await repository.getCurrentDayIfExists()

        #expect(day == nil)
    }

    @Test func getCurrentDayIfExistsReturnsExistingDay() async throws {
        let repository = MockDayRepository()

        let existingDay = makeDay(
            startDate: TimeWindows.currentUserDayStart,
            firstEnergy: 4
        )
        try await repository.save(existingDay)

        let retrievedDay = try await repository.getCurrentDayIfExists()

        #expect(retrievedDay != nil)
        #expect(retrievedDay?.id == existingDay.id)
    }

    // MARK: - Save Tests

    @Test func saveStoresNewDay() async throws {
        let repository = MockDayRepository()
        let day = makeDay(firstEnergy: 4)

        try await repository.save(day)

        let days = await repository.days
        #expect(days.count == 1)
        #expect(days.first?.id == day.id)
    }

    @Test func saveUpdatesExistingDay() async throws {
        let repository = MockDayRepository()

        // Save initial day
        var day = makeDay(firstEnergy: 4)
        try await repository.save(day)

        // Update with second check-in
        day.secondCheckIn = CheckInSlot(energyLevel: 3)
        try await repository.save(day)

        let days = await repository.days
        #expect(days.count == 1)
        #expect(days.first?.hasSecondCheckIn == true)
        #expect(days.first?.secondCheckIn?.energyLevel == 3)
    }

    @Test func saveThrowsWhenConfigured() async throws {
        let repository = MockDayRepository()
        await repository.setError(TestError.mockError)

        do {
            try await repository.save(makeDay())
            Issue.record("Expected error to be thrown")
        } catch {
            #expect(error is TestError)
        }
    }

    // MARK: - getDays Tests

    @Test func getDaysReturnsEmptyWhenNoData() async throws {
        let repository = MockDayRepository()
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!

        let days = try await repository.getDays(from: weekAgo, to: Date())

        #expect(days.isEmpty)
    }

    @Test func getDaysFiltersToDateRange() async throws {
        let repository = MockDayRepository()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Add days for the past 10 days
        for daysAgo in 0..<10 {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            try await repository.save(makeCompleteDay(startDate: date))
        }

        // Query for last 5 days
        let fiveDaysAgo = calendar.date(byAdding: .day, value: -4, to: today)!
        let days = try await repository.getDays(from: fiveDaysAgo, to: today)

        #expect(days.count == 5)
    }

    @Test func getDaysReturnsSortedByDateDescending() async throws {
        let repository = MockDayRepository()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Add days out of order
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        try await repository.save(makeCompleteDay(startDate: twoDaysAgo))
        try await repository.save(makeCompleteDay(startDate: today))
        try await repository.save(makeCompleteDay(startDate: yesterday))

        let days = try await repository.getDays(from: twoDaysAgo, to: today)

        #expect(days.count == 3)
        #expect(days[0].startDate == today)
        #expect(days[1].startDate == yesterday)
        #expect(days[2].startDate == twoDaysAgo)
    }

    // MARK: - getRecentDays Tests

    @Test func getRecentDaysRespectsLimit() async throws {
        let repository = MockDayRepository()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Add 10 days
        for daysAgo in 0..<10 {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            try await repository.save(makeCompleteDay(startDate: date))
        }

        let days = try await repository.getRecentDays(limit: 5)

        #expect(days.count == 5)
    }

    @Test func getRecentDaysReturnsSortedByDateDescending() async throws {
        let repository = MockDayRepository()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for daysAgo in 0..<5 {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            try await repository.save(makeCompleteDay(startDate: date))
        }

        let days = try await repository.getRecentDays(limit: 5)

        #expect(days[0].startDate == today)
        let fourDaysAgo = calendar.date(byAdding: .day, value: -4, to: today)!
        #expect(days[4].startDate == fourDaysAgo)
    }

    // MARK: - getCompletedDays Tests

    @Test func getCompletedDaysReturnsOnlyCompleteDays() async throws {
        let repository = MockDayRepository()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Add complete days
        for daysAgo in [1, 3, 5] {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            try await repository.save(makeCompleteDay(startDate: date))
        }

        // Add incomplete days
        for daysAgo in [2, 4] {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            try await repository.save(makeDay(startDate: date, firstEnergy: 4))
        }

        let completedDays = try await repository.getCompletedDays()

        #expect(completedDays.count == 3)
        for day in completedDays {
            #expect(day.isComplete == true)
        }
    }

    @Test func getCompletedDaysReturnsSortedByDateAscending() async throws {
        let repository = MockDayRepository()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Add complete days out of order
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!
        let oneDayAgo = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        try await repository.save(makeCompleteDay(startDate: threeDaysAgo))
        try await repository.save(makeCompleteDay(startDate: oneDayAgo))
        try await repository.save(makeCompleteDay(startDate: twoDaysAgo))

        let days = try await repository.getCompletedDays()

        #expect(days.count == 3)
        // Should be sorted oldest first (for training data)
        #expect(days[0].startDate == threeDaysAgo)
        #expect(days[1].startDate == twoDaysAgo)
        #expect(days[2].startDate == oneDayAgo)
    }

    @Test func getCompletedDaysReturnsEmptyWhenNoCompleteDays() async throws {
        let repository = MockDayRepository()

        // Add only incomplete days
        try await repository.save(makeDay(firstEnergy: 4))
        try await repository.save(makeDay(firstEnergy: 3))

        let completedDays = try await repository.getCompletedDays()

        #expect(completedDays.isEmpty)
    }

    // MARK: - getCompletedDaysCount Tests

    @Test func getCompletedDaysCountReturnsCorrectCount() async throws {
        let repository = MockDayRepository()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Add 3 complete days
        for daysAgo in 1...3 {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            try await repository.save(makeCompleteDay(startDate: date))
        }

        // Add 2 incomplete days
        for daysAgo in 4...5 {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            try await repository.save(makeDay(startDate: date, firstEnergy: 4))
        }

        let count = try await repository.getCompletedDaysCount()

        #expect(count == 3)
    }

    @Test func getCompletedDaysCountReturnsZeroWhenEmpty() async throws {
        let repository = MockDayRepository()

        let count = try await repository.getCompletedDaysCount()

        #expect(count == 0)
    }

    // MARK: - Delete Tests

    @Test func deleteRemovesDay() async throws {
        let repository = MockDayRepository()
        let day = makeDay(firstEnergy: 4)

        try await repository.save(day)
        var days = await repository.days
        #expect(days.count == 1)

        try await repository.delete(id: day.id)
        days = await repository.days
        #expect(days.isEmpty)
    }

    @Test func deleteDoesNotAffectOtherDays() async throws {
        let repository = MockDayRepository()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let todayDay = makeDay(startDate: today, firstEnergy: 4)
        let yesterdayDay = makeDay(startDate: yesterday, firstEnergy: 3)

        try await repository.save(todayDay)
        try await repository.save(yesterdayDay)

        try await repository.delete(id: todayDay.id)

        let days = await repository.days
        #expect(days.count == 1)
        #expect(days.first?.id == yesterdayDay.id)
    }

    // MARK: - Reset Tests

    @Test func resetClearsAllData() async throws {
        let repository = MockDayRepository()

        try await repository.save(makeDay(firstEnergy: 4))
        try await repository.save(makeDay(firstEnergy: 3))

        await repository.reset()

        let days = await repository.days
        #expect(days.isEmpty)
    }

    @Test func resetClearsError() async throws {
        let repository = MockDayRepository()
        await repository.setError(TestError.mockError)

        await repository.reset()

        // Should no longer throw - getCurrentDay always returns a Day
        let day = try await repository.getCurrentDay()
        #expect(day.id != UUID()) // Just verify we got a valid day
    }

    // MARK: - Sample Data Tests

    @Test func initWithSampleDataPopulatesDays() async throws {
        let repository = MockDayRepository(withSampleData: true)

        let days = await repository.days

        #expect(days.count > 0)
        #expect(days.count < 20) // Reasonable upper bound
    }

    @Test func sampleDataHasCompleteDays() async throws {
        let repository = MockDayRepository(withSampleData: true)

        let completedDays = try await repository.getCompletedDays()

        #expect(completedDays.count > 0)
    }
}

// MARK: - Test Error

private enum TestError: Error {
    case mockError
}
