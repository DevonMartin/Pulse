//
//  CheckInTests.swift
//  PulseTests
//
//  Created by Devon Martin on 12/1/2025.
//

import Testing
@testable import Pulse
import Foundation

struct CheckInTests {

    // MARK: - Initialization

    @Test func defaultInitializationUsesCurrentDate() {
        let beforeCreation = Date()
        let checkIn = CheckIn(type: .morning, energyLevel: 3)
        let afterCreation = Date()

        #expect(checkIn.timestamp >= beforeCreation)
        #expect(checkIn.timestamp <= afterCreation)
    }

    @Test func defaultInitializationGeneratesUniqueId() {
        let checkIn1 = CheckIn(type: .morning, energyLevel: 3)
        let checkIn2 = CheckIn(type: .morning, energyLevel: 3)

        #expect(checkIn1.id != checkIn2.id)
    }

    @Test func initializationPreservesAllProperties() {
        let id = UUID()
        let timestamp = Date()
        let snapshot = HealthMetrics(
            date: timestamp,
            restingHeartRate: 62,
            hrv: 45,
            sleepDuration: 7 * 3600,
            steps: 8000,
            activeCalories: 350
        )

        let checkIn = CheckIn(
            id: id,
            timestamp: timestamp,
            type: .evening,
            energyLevel: 4,
            healthSnapshot: snapshot
        )

        #expect(checkIn.id == id)
        #expect(checkIn.timestamp == timestamp)
        #expect(checkIn.type == .evening)
        #expect(checkIn.energyLevel == 4)
        #expect(checkIn.healthSnapshot == snapshot)
    }

    // MARK: - isToday

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

    @Test func checkInIsNotTodayWhenTimestampIsTomorrow() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let checkIn = CheckIn(
            timestamp: tomorrow,
            type: .morning,
            energyLevel: 3
        )

        #expect(checkIn.isToday == false)
    }

    @Test func checkInIsTodayAtStartOfDay() {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let checkIn = CheckIn(
            timestamp: startOfToday,
            type: .morning,
            energyLevel: 3
        )

        #expect(checkIn.isToday == true)
    }

    // MARK: - date

    @Test func dateReturnsStartOfDay() {
        let now = Date()
        let checkIn = CheckIn(timestamp: now, type: .morning, energyLevel: 3)
        let expectedDate = Calendar.current.startOfDay(for: now)

        #expect(checkIn.date == expectedDate)
    }

    // MARK: - energyDescription

    @Test func energyDescriptionMapsCorrectly() {
        let levels = [1, 2, 3, 4, 5]
        let expected = ["Very Low", "Low", "Moderate", "High", "Very High"]

        for (level, description) in zip(levels, expected) {
            let checkIn = CheckIn(type: .morning, energyLevel: level)
            #expect(checkIn.energyDescription == description)
        }
    }

    @Test func energyDescriptionReturnsUnknownForInvalidLevel() {
        let checkInTooLow = CheckIn(type: .morning, energyLevel: 0)
        let checkInTooHigh = CheckIn(type: .morning, energyLevel: 6)
        let checkInNegative = CheckIn(type: .morning, energyLevel: -1)

        #expect(checkInTooLow.energyDescription == "Unknown")
        #expect(checkInTooHigh.energyDescription == "Unknown")
        #expect(checkInNegative.energyDescription == "Unknown")
    }

    // MARK: - Identifiable

    @Test func checkInIsIdentifiableById() {
        let id = UUID()
        let checkIn = CheckIn(id: id, type: .morning, energyLevel: 3)

        #expect(checkIn.id == id)
    }

    // MARK: - Equatable

    @Test func checkInsAreEqualWhenAllPropertiesMatch() {
        let id = UUID()
        let timestamp = Date()
        let checkIn1 = CheckIn(id: id, timestamp: timestamp, type: .morning, energyLevel: 3)
        let checkIn2 = CheckIn(id: id, timestamp: timestamp, type: .morning, energyLevel: 3)

        #expect(checkIn1 == checkIn2)
    }

    @Test func checkInsAreNotEqualWhenIdsDiffer() {
        let timestamp = Date()
        let checkIn1 = CheckIn(id: UUID(), timestamp: timestamp, type: .morning, energyLevel: 3)
        let checkIn2 = CheckIn(id: UUID(), timestamp: timestamp, type: .morning, energyLevel: 3)

        #expect(checkIn1 != checkIn2)
    }
}

// MARK: - CheckInType Tests

struct CheckInTypeTests {

    @Test func morningRawValueIsCorrect() {
        #expect(CheckInType.morning.rawValue == "morning")
    }

    @Test func eveningRawValueIsCorrect() {
        #expect(CheckInType.evening.rawValue == "evening")
    }

    @Test func initFromRawValueWorks() {
        #expect(CheckInType(rawValue: "morning") == .morning)
        #expect(CheckInType(rawValue: "evening") == .evening)
        #expect(CheckInType(rawValue: "invalid") == nil)
    }

    @Test func checkInTypesAreCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let morning = CheckInType.morning
        let encoded = try encoder.encode(morning)
        let decoded = try decoder.decode(CheckInType.self, from: encoded)

        #expect(decoded == morning)
    }
}
