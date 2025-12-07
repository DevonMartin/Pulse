//
//  DayRepository.swift
//  Pulse
//
//  Created by Devon Martin on 12/6/2025.
//

import Foundation
import SwiftData

// MARK: - Protocol

/// Defines the interface for Day data operations.
///
/// The app layer interacts with this protocol, never with SwiftData directly.
/// This allows us to:
/// 1. Test without a real database
/// 2. Swap storage implementations without changing app code
/// 3. Keep persistence concerns isolated from business logic
protocol DayRepositoryProtocol: Sendable {
    /// Gets or creates the Day for the current user day.
    /// If no Day exists for the current user day, creates a new one.
    func getCurrentDay() async throws -> Day

    /// Gets the Day for the current user day, if it exists.
    func getCurrentDayIfExists() async throws -> Day?

    /// Saves/updates a Day.
    func save(_ day: Day) async throws

    /// Gets all Days within a date range (by startDate).
    func getDays(from startDate: Date, to endDate: Date) async throws -> [Day]

    /// Gets the most recent Days (for history display).
    func getRecentDays(limit: Int) async throws -> [Day]

    /// Gets all completed Days (both check-ins done) for training data.
    func getCompletedDays() async throws -> [Day]

    /// Deletes a Day by ID.
    func delete(id: UUID) async throws

    /// Gets the count of completed days (for personalization progress).
    func getCompletedDaysCount() async throws -> Int
}

// MARK: - Implementation

/// SwiftData-backed implementation of DayRepository.
@ModelActor
actor DayRepository: DayRepositoryProtocol {

    // MARK: - DayRepositoryProtocol

    func getCurrentDay() async throws -> Day {
        // Check if we already have a Day for the current user day
        if let existing = try await getCurrentDayIfExists() {
            return existing
        }

        // Create a new Day for the current user day
        let newDay = Day(startDate: TimeWindows.currentUserDayStart)
        let entity = DayEntity(from: newDay)
        modelContext.insert(entity)
        try modelContext.save()

        return newDay
    }

    func getCurrentDayIfExists() async throws -> Day? {
        let currentUserDayStart = TimeWindows.currentUserDayStart

        let predicate = #Predicate<DayEntity> { entity in
            entity.startDate == currentUserDayStart
        }

        var descriptor = FetchDescriptor<DayEntity>(predicate: predicate)
        descriptor.fetchLimit = 1

        let results = try modelContext.fetch(descriptor)
        return results.first?.toDay()
    }

    func save(_ day: Day) async throws {
        // Check if this Day already exists
        let dayId = day.id
        let predicate = #Predicate<DayEntity> { entity in
            entity.id == dayId
        }

        var descriptor = FetchDescriptor<DayEntity>(predicate: predicate)
        descriptor.fetchLimit = 1

        let results = try modelContext.fetch(descriptor)

        if let existing = results.first {
            // Update existing entity
            existing.update(from: day)
        } else {
            // Create new entity
            let entity = DayEntity(from: day)
            modelContext.insert(entity)
        }

        try modelContext.save()
    }

    func getDays(from startDate: Date, to endDate: Date) async throws -> [Day] {
        let predicate = #Predicate<DayEntity> { entity in
            entity.startDate >= startDate && entity.startDate <= endDate
        }

        let descriptor = FetchDescriptor<DayEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)
        return results.map { $0.toDay() }
    }

    func getRecentDays(limit: Int) async throws -> [Day] {
        var descriptor = FetchDescriptor<DayEntity>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        let results = try modelContext.fetch(descriptor)
        return results.map { $0.toDay() }
    }

    func getCompletedDays() async throws -> [Day] {
        // Fetch days where both check-ins are complete
        // We check for energy >= 1 since -1 is the sentinel for "no check-in"
        let predicate = #Predicate<DayEntity> { entity in
            entity.firstCheckInEnergy >= 1 && entity.secondCheckInEnergy >= 1
        }

        let descriptor = FetchDescriptor<DayEntity>(
            predicate: predicate,
			sortBy: [SortDescriptor(\.startDate, order: .forward)]
        )

        let results = try modelContext.fetch(descriptor)
        return results.map { $0.toDay() }
    }

    func delete(id: UUID) async throws {
        let predicate = #Predicate<DayEntity> { entity in
            entity.id == id
        }

        let descriptor = FetchDescriptor<DayEntity>(predicate: predicate)
        let results = try modelContext.fetch(descriptor)

        for entity in results {
            modelContext.delete(entity)
        }

        try modelContext.save()
    }

    func getCompletedDaysCount() async throws -> Int {
        let predicate = #Predicate<DayEntity> { entity in
            entity.firstCheckInEnergy >= 1 && entity.secondCheckInEnergy >= 1
        }

        let descriptor = FetchDescriptor<DayEntity>(predicate: predicate)
        let results = try modelContext.fetch(descriptor)
        return results.count
    }
}

// MARK: - Mock Implementation

/// A mock implementation for testing and SwiftUI previews.
actor MockDayRepository: DayRepositoryProtocol {
    var days: [Day] = []
    var shouldThrowError: Error?

    /// Optional override for "current user day start" - if nil, uses TimeWindows
    private let currentUserDayStartOverride: Date?

    /// Creates a mock repository, optionally pre-populated with sample data
    init(withSampleData: Bool = false, currentUserDayStart: Date? = nil) {
        self.currentUserDayStartOverride = currentUserDayStart
        if withSampleData {
            days = Self.generateSampleDays()
        }
    }

    /// The date to use for "current day" lookups
    private var currentUserDayStart: Date {
        currentUserDayStartOverride ?? TimeWindows.currentUserDayStart
    }

    /// Generates sample historical days for the past 14 days
    private static func generateSampleDays() -> [Day] {
        let calendar = Calendar.current
        let today = Date()

        return (1..<14).compactMap { daysAgo -> Day? in
            guard let startDate = calendar.date(byAdding: .day, value: -daysAgo, to: today) else {
                return nil
            }

            let dayStart = calendar.startOfDay(for: startDate)
            let firstEnergy = Int.random(in: 2...5)
            let secondEnergy = Int.random(in: 2...5)

            // Create health metrics
            let healthMetrics = HealthMetrics(
                date: dayStart,
                restingHeartRate: Double.random(in: 52...72),
                hrv: Double.random(in: 25...75),
                sleepDuration: TimeInterval.random(in: 5*3600...9*3600),
                steps: Int.random(in: 3000...15000),
                activeCalories: Double.random(in: 150...650)
            )

            // Create timestamps for check-ins
            let firstTimestamp = calendar.date(bySettingHour: Int.random(in: 7...9), minute: Int.random(in: 0...59), second: 0, of: dayStart)!
            let secondTimestamp = calendar.date(bySettingHour: Int.random(in: 18...21), minute: Int.random(in: 0...59), second: 0, of: dayStart)!

            return Day(
                startDate: dayStart,
                firstCheckIn: CheckInSlot(timestamp: firstTimestamp, energyLevel: firstEnergy),
                secondCheckIn: CheckInSlot(timestamp: secondTimestamp, energyLevel: secondEnergy),
                healthMetrics: healthMetrics,
                readinessScore: nil  // Mock doesn't need scores for basic testing
            )
        }
    }

    func getCurrentDay() async throws -> Day {
        if let error = shouldThrowError { throw error }

        if let existing = try await getCurrentDayIfExists() {
            return existing
        }

        let newDay = Day(startDate: currentUserDayStart)
        days.append(newDay)
        return newDay
    }

    func getCurrentDayIfExists() async throws -> Day? {
        if let error = shouldThrowError { throw error }

        return days.first { $0.startDate == currentUserDayStart }
    }

    func save(_ day: Day) async throws {
        if let error = shouldThrowError { throw error }

        if let index = days.firstIndex(where: { $0.id == day.id }) {
            days[index] = day
        } else {
            days.append(day)
        }
    }

    func getDays(from startDate: Date, to endDate: Date) async throws -> [Day] {
        if let error = shouldThrowError { throw error }

        return days
            .filter { $0.startDate >= startDate && $0.startDate <= endDate }
            .sorted { $0.startDate > $1.startDate }
    }

    func getRecentDays(limit: Int) async throws -> [Day] {
        if let error = shouldThrowError { throw error }

        return Array(days.sorted { $0.startDate > $1.startDate }.prefix(limit))
    }

    func getCompletedDays() async throws -> [Day] {
        if let error = shouldThrowError { throw error }

        return days
            .filter { $0.isComplete }
            .sorted { $0.startDate < $1.startDate }
    }

    func delete(id: UUID) async throws {
        if let error = shouldThrowError { throw error }

        days.removeAll { $0.id == id }
    }

    func getCompletedDaysCount() async throws -> Int {
        if let error = shouldThrowError { throw error }

        return days.filter { $0.isComplete }.count
    }

    // MARK: - Test Helpers

    func reset() {
        days = []
        shouldThrowError = nil
    }

    func setError(_ error: Error?) {
        shouldThrowError = error
    }
}
