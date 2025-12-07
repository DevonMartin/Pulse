//
//  DayTests.swift
//  PulseTests
//
//  Created by Devon Martin on 12/6/2025.
//

import Testing
@testable import Pulse
import Foundation

/// Tests for the Day domain model.
///
/// Verifies:
/// 1. Check-in slot properties
/// 2. Completion status
/// 3. Blended energy score calculation
/// 4. Equatable conformance
@MainActor
struct DayTests {

    // MARK: - Check-In Slot Properties

    @Test func hasFirstCheckInReturnsTrueWhenPresent() {
        let day = Day(
            startDate: Date(),
            firstCheckIn: CheckInSlot(energyLevel: 4)
        )

        #expect(day.hasFirstCheckIn == true)
        #expect(day.hasSecondCheckIn == false)
    }

    @Test func hasSecondCheckInReturnsTrueWhenPresent() {
        let day = Day(
            startDate: Date(),
            secondCheckIn: CheckInSlot(energyLevel: 3)
        )

        #expect(day.hasFirstCheckIn == false)
        #expect(day.hasSecondCheckIn == true)
    }

    @Test func bothCheckInsReturnTrueWhenBothPresent() {
        let day = Day(
            startDate: Date(),
            firstCheckIn: CheckInSlot(energyLevel: 4),
            secondCheckIn: CheckInSlot(energyLevel: 3)
        )

        #expect(day.hasFirstCheckIn == true)
        #expect(day.hasSecondCheckIn == true)
    }

    @Test func noCheckInsReturnFalseForBoth() {
        let day = Day(startDate: Date())

        #expect(day.hasFirstCheckIn == false)
        #expect(day.hasSecondCheckIn == false)
    }

    // MARK: - Completion Status

    @Test func isCompleteReturnsTrueWhenBothCheckInsPresent() {
        let day = Day(
            startDate: Date(),
            firstCheckIn: CheckInSlot(energyLevel: 4),
            secondCheckIn: CheckInSlot(energyLevel: 3)
        )

        #expect(day.isComplete == true)
    }

    @Test func isCompleteReturnsFalseWhenOnlyFirstCheckIn() {
        let day = Day(
            startDate: Date(),
            firstCheckIn: CheckInSlot(energyLevel: 4)
        )

        #expect(day.isComplete == false)
    }

    @Test func isCompleteReturnsFalseWhenOnlySecondCheckIn() {
        let day = Day(
            startDate: Date(),
            secondCheckIn: CheckInSlot(energyLevel: 3)
        )

        #expect(day.isComplete == false)
    }

    @Test func isCompleteReturnsFalseWhenNoCheckIns() {
        let day = Day(startDate: Date())

        #expect(day.isComplete == false)
    }

    // MARK: - Blended Energy Score

    @Test func blendedEnergyScoreCalculatesCorrectly() {
        // First energy: 3, Second energy: 5
        // Blended: (3 * 0.4) + (5 * 0.6) = 1.2 + 3.0 = 4.2
        // Scaled: 4.2 * 20 = 84
        let day = Day(
            startDate: Date(),
            firstCheckIn: CheckInSlot(energyLevel: 3),
            secondCheckIn: CheckInSlot(energyLevel: 5)
        )

        #expect(day.blendedEnergyScore == 84.0)
    }

    @Test func blendedEnergyScoreMinimum() {
        // First energy: 1, Second energy: 1
        // Blended: (1 * 0.4) + (1 * 0.6) = 0.4 + 0.6 = 1.0
        // Scaled: 1.0 * 20 = 20
        let day = Day(
            startDate: Date(),
            firstCheckIn: CheckInSlot(energyLevel: 1),
            secondCheckIn: CheckInSlot(energyLevel: 1)
        )

        #expect(day.blendedEnergyScore == 20.0)
    }

    @Test func blendedEnergyScoreMaximum() {
        // First energy: 5, Second energy: 5
        // Blended: (5 * 0.4) + (5 * 0.6) = 2.0 + 3.0 = 5.0
        // Scaled: 5.0 * 20 = 100
        let day = Day(
            startDate: Date(),
            firstCheckIn: CheckInSlot(energyLevel: 5),
            secondCheckIn: CheckInSlot(energyLevel: 5)
        )

        #expect(day.blendedEnergyScore == 100.0)
    }

    @Test func blendedEnergyScoreWeightsSecondCheckInHigher() {
        // First: 1, Second: 5 → (1 * 0.4) + (5 * 0.6) = 0.4 + 3.0 = 3.4 * 20 = 68
        let dayLowThenHigh = Day(
            startDate: Date(),
            firstCheckIn: CheckInSlot(energyLevel: 1),
            secondCheckIn: CheckInSlot(energyLevel: 5)
        )

        // First: 5, Second: 1 → (5 * 0.4) + (1 * 0.6) = 2.0 + 0.6 = 2.6 * 20 = 52
        let dayHighThenLow = Day(
            startDate: Date(),
            firstCheckIn: CheckInSlot(energyLevel: 5),
            secondCheckIn: CheckInSlot(energyLevel: 1)
        )

        #expect(dayLowThenHigh.blendedEnergyScore == 68.0)
        #expect(dayHighThenLow.blendedEnergyScore == 52.0)
        // Low-then-high should score higher because second is weighted 60%
        #expect(dayLowThenHigh.blendedEnergyScore! > dayHighThenLow.blendedEnergyScore!)
    }

    @Test func blendedEnergyScoreIsNilWhenIncomplete() {
        let onlyFirst = Day(
            startDate: Date(),
            firstCheckIn: CheckInSlot(energyLevel: 4)
        )

        let onlySecond = Day(
            startDate: Date(),
            secondCheckIn: CheckInSlot(energyLevel: 3)
        )

        let neither = Day(startDate: Date())

        #expect(onlyFirst.blendedEnergyScore == nil)
        #expect(onlySecond.blendedEnergyScore == nil)
        #expect(neither.blendedEnergyScore == nil)
    }

    // MARK: - Equatable

    @Test func daysAreEqualWhenAllPropertiesMatch() {
        let id = UUID()
        let date = Date()
        let firstCheckIn = CheckInSlot(timestamp: date, energyLevel: 4)
        let secondCheckIn = CheckInSlot(timestamp: date.addingTimeInterval(3600), energyLevel: 3)
        let metrics = HealthMetrics(date: date, restingHeartRate: 60, hrv: 50, sleepDuration: 7 * 3600)

        let day1 = Day(
            id: id,
            startDate: date,
            firstCheckIn: firstCheckIn,
            secondCheckIn: secondCheckIn,
            healthMetrics: metrics
        )

        let day2 = Day(
            id: id,
            startDate: date,
            firstCheckIn: firstCheckIn,
            secondCheckIn: secondCheckIn,
            healthMetrics: metrics
        )

        #expect(day1 == day2)
    }

    @Test func daysAreNotEqualWhenIdsDiffer() {
        let date = Date()

        let day1 = Day(id: UUID(), startDate: date)
        let day2 = Day(id: UUID(), startDate: date)

        #expect(day1 != day2)
    }

    @Test func daysAreNotEqualWhenCheckInsDiffer() {
        let id = UUID()
        let date = Date()

        let day1 = Day(
            id: id,
            startDate: date,
            firstCheckIn: CheckInSlot(energyLevel: 4)
        )

        let day2 = Day(
            id: id,
            startDate: date,
            firstCheckIn: CheckInSlot(energyLevel: 5)
        )

        #expect(day1 != day2)
    }

    // MARK: - CheckInSlot

    @Test func checkInSlotEnergyDescription() {
        #expect(CheckInSlot(energyLevel: 1).energyDescription == "Very Low")
        #expect(CheckInSlot(energyLevel: 2).energyDescription == "Low")
        #expect(CheckInSlot(energyLevel: 3).energyDescription == "Moderate")
        #expect(CheckInSlot(energyLevel: 4).energyDescription == "High")
        #expect(CheckInSlot(energyLevel: 5).energyDescription == "Very High")
        #expect(CheckInSlot(energyLevel: 0).energyDescription == "Unknown")
        #expect(CheckInSlot(energyLevel: 6).energyDescription == "Unknown")
    }

    @Test func checkInSlotEquatable() {
        let timestamp = Date()

        let slot1 = CheckInSlot(timestamp: timestamp, energyLevel: 4)
        let slot2 = CheckInSlot(timestamp: timestamp, energyLevel: 4)
        let slot3 = CheckInSlot(timestamp: timestamp, energyLevel: 5)

        #expect(slot1 == slot2)
        #expect(slot1 != slot3)
    }

    // MARK: - Initialization

    @Test func initializationWithDefaults() {
        let day = Day()

        #expect(day.firstCheckIn == nil)
        #expect(day.secondCheckIn == nil)
        #expect(day.healthMetrics == nil)
        #expect(day.readinessScore == nil)
    }

    @Test func initializationWithAllParameters() {
        let id = UUID()
        let date = Date()
        let firstCheckIn = CheckInSlot(energyLevel: 4)
        let secondCheckIn = CheckInSlot(energyLevel: 3)
        let metrics = HealthMetrics(date: date, restingHeartRate: 60)
        let score = ReadinessScore(
            score: 75,
            breakdown: ReadinessBreakdown(
                hrvScore: 70,
                restingHeartRateScore: 75,
                sleepScore: 80,
                energyScore: 80
            ),
            confidence: .full
        )

        let day = Day(
            id: id,
            startDate: date,
            firstCheckIn: firstCheckIn,
            secondCheckIn: secondCheckIn,
            healthMetrics: metrics,
            readinessScore: score
        )

        #expect(day.id == id)
        #expect(day.startDate == date)
        #expect(day.firstCheckIn == firstCheckIn)
        #expect(day.secondCheckIn == secondCheckIn)
        #expect(day.healthMetrics == metrics)
        #expect(day.readinessScore?.id == score.id)
    }
}
