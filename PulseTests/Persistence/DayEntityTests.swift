//
//  DayEntityTests.swift
//  PulseTests
//
//  Created by Devon Martin on 12/6/2025.
//

import Testing
@testable import Pulse
import Foundation

/// Tests for DayEntity SwiftData persistence.
///
/// Verifies:
/// 1. Conversion from Day domain model to entity
/// 2. Conversion from entity back to Day domain model
/// 3. Sentinel value handling for optional fields
/// 4. Update functionality
@MainActor
struct DayEntityTests {

    // MARK: - Initialization

    @Test func initializationWithDefaults() {
        let entity = DayEntity()

        #expect(entity.firstCheckInEnergy == -1)
        #expect(entity.secondCheckInEnergy == -1)
        #expect(entity.healthRestingHeartRate == -1)
        #expect(entity.readinessScore == -1)
    }

    @Test func initializationFromEmptyDay() {
        let day = Day(startDate: Date())
        let entity = DayEntity(from: day)

        #expect(entity.id == day.id)
        #expect(entity.startDate == day.startDate)
        #expect(entity.hasFirstCheckIn == false)
        #expect(entity.hasSecondCheckIn == false)
        #expect(entity.hasHealthMetrics == false)
        #expect(entity.hasReadinessScore == false)
    }

    // MARK: - Check-In Conversion

    @Test func convertsFirstCheckInFromDay() {
        let timestamp = Date()
        let day = Day(
            startDate: Date(),
            firstCheckIn: CheckInSlot(timestamp: timestamp, energyLevel: 4)
        )

        let entity = DayEntity(from: day)

        #expect(entity.hasFirstCheckIn == true)
        #expect(entity.firstCheckInTimestamp == timestamp)
        #expect(entity.firstCheckInEnergy == 4)
        #expect(entity.hasSecondCheckIn == false)
    }

    @Test func convertsSecondCheckInFromDay() {
        let timestamp = Date()
        let day = Day(
            startDate: Date(),
            secondCheckIn: CheckInSlot(timestamp: timestamp, energyLevel: 3)
        )

        let entity = DayEntity(from: day)

        #expect(entity.hasFirstCheckIn == false)
        #expect(entity.hasSecondCheckIn == true)
        #expect(entity.secondCheckInTimestamp == timestamp)
        #expect(entity.secondCheckInEnergy == 3)
    }

    @Test func convertsBothCheckInsFromDay() {
        let firstTimestamp = Date()
        let secondTimestamp = Date().addingTimeInterval(3600)
        let day = Day(
            startDate: Date(),
            firstCheckIn: CheckInSlot(timestamp: firstTimestamp, energyLevel: 4),
            secondCheckIn: CheckInSlot(timestamp: secondTimestamp, energyLevel: 3)
        )

        let entity = DayEntity(from: day)

        #expect(entity.hasFirstCheckIn == true)
        #expect(entity.hasSecondCheckIn == true)
        #expect(entity.firstCheckInEnergy == 4)
        #expect(entity.secondCheckInEnergy == 3)
    }

    // MARK: - Health Metrics Conversion

    @Test func convertsHealthMetricsFromDay() {
        let metricsDate = Date()
        let metrics = HealthMetrics(
            date: metricsDate,
            restingHeartRate: 60,
            hrv: 50,
            sleepDuration: 7 * 3600,
            steps: 8000,
            activeCalories: 350
        )

        let day = Day(startDate: Date(), healthMetrics: metrics)
        let entity = DayEntity(from: day)

        #expect(entity.hasHealthMetrics == true)
        #expect(entity.healthMetricsDate == metricsDate)
        #expect(entity.healthRestingHeartRate == 60)
        #expect(entity.healthHRV == 50)
        #expect(entity.healthSleepDuration == 7 * 3600)
        #expect(entity.healthSteps == 8000)
        #expect(entity.healthActiveCalories == 350)
    }

    @Test func convertsPartialHealthMetrics() {
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: 60,
            hrv: nil,  // Missing
            sleepDuration: 7 * 3600,
            steps: nil,  // Missing
            activeCalories: nil  // Missing
        )

        let day = Day(startDate: Date(), healthMetrics: metrics)
        let entity = DayEntity(from: day)

        #expect(entity.hasHealthMetrics == true)
        #expect(entity.healthRestingHeartRate == 60)
        #expect(entity.healthHRV == -1)  // Sentinel value
        #expect(entity.healthSleepDuration == 7 * 3600)
        #expect(entity.healthSteps == -1)  // Sentinel value
        #expect(entity.healthActiveCalories == -1)  // Sentinel value
    }

    // MARK: - Readiness Score Conversion

    @Test func convertsReadinessScoreFromDay() {
        let scoreId = UUID()
        let score = ReadinessScore(
            id: scoreId,
            date: Date(),
            score: 75,
            breakdown: ReadinessBreakdown(
                hrvScore: 70,
                restingHeartRateScore: 75,
                sleepScore: 80,
                energyScore: 80
            ),
            confidence: .full
        )

        let day = Day(startDate: Date(), readinessScore: score)
        let entity = DayEntity(from: day)

        #expect(entity.hasReadinessScore == true)
        #expect(entity.readinessScore == 75)
        #expect(entity.readinessScoreId == scoreId)
        #expect(entity.readinessConfidenceRawValue == "full")
        #expect(entity.breakdownHRVScore == 70)
        #expect(entity.breakdownRestingHeartRateScore == 75)
        #expect(entity.breakdownSleepScore == 80)
        #expect(entity.breakdownEnergyScore == 80)
    }

    // MARK: - Round-Trip Conversion (Day → Entity → Day)

    @Test func roundTripPreservesEmptyDay() {
        let original = Day(startDate: Date())
        let entity = DayEntity(from: original)
        let restored = entity.toDay()

        #expect(restored.id == original.id)
        #expect(restored.startDate == original.startDate)
        #expect(restored.firstCheckIn == nil)
        #expect(restored.secondCheckIn == nil)
        #expect(restored.healthMetrics == nil)
        #expect(restored.readinessScore == nil)
    }

    @Test func roundTripPreservesCheckIns() {
        let firstTimestamp = Date()
        let secondTimestamp = Date().addingTimeInterval(3600)

        let original = Day(
            startDate: Date(),
            firstCheckIn: CheckInSlot(timestamp: firstTimestamp, energyLevel: 4),
            secondCheckIn: CheckInSlot(timestamp: secondTimestamp, energyLevel: 3)
        )

        let entity = DayEntity(from: original)
        let restored = entity.toDay()

        #expect(restored.firstCheckIn?.timestamp == firstTimestamp)
        #expect(restored.firstCheckIn?.energyLevel == 4)
        #expect(restored.secondCheckIn?.timestamp == secondTimestamp)
        #expect(restored.secondCheckIn?.energyLevel == 3)
    }

    @Test func roundTripPreservesHealthMetrics() {
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: 60,
            hrv: 50,
            sleepDuration: 7 * 3600,
            steps: 8000,
            activeCalories: 350
        )

        let original = Day(startDate: Date(), healthMetrics: metrics)
        let entity = DayEntity(from: original)
        let restored = entity.toDay()

        #expect(restored.healthMetrics?.restingHeartRate == 60)
        #expect(restored.healthMetrics?.hrv == 50)
		#expect(restored.healthMetrics?.sleepDuration == 7.0 * 3600)
        #expect(restored.healthMetrics?.steps == 8000)
        #expect(restored.healthMetrics?.activeCalories == 350)
    }

    @Test func roundTripPreservesPartialHealthMetrics() {
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: 60,
            hrv: nil,
            sleepDuration: nil,
            steps: 8000,
            activeCalories: nil
        )

        let original = Day(startDate: Date(), healthMetrics: metrics)
        let entity = DayEntity(from: original)
        let restored = entity.toDay()

        #expect(restored.healthMetrics?.restingHeartRate == 60)
        #expect(restored.healthMetrics?.hrv == nil)
        #expect(restored.healthMetrics?.sleepDuration == nil)
        #expect(restored.healthMetrics?.steps == 8000)
        #expect(restored.healthMetrics?.activeCalories == nil)
    }

    @Test func roundTripPreservesReadinessScore() {
        let scoreId = UUID()
        let score = ReadinessScore(
            id: scoreId,
            date: Date(),
            score: 75,
            breakdown: ReadinessBreakdown(
                hrvScore: 70,
                restingHeartRateScore: 75,
                sleepScore: 80,
                energyScore: 80
            ),
            confidence: .full
        )

        let original = Day(startDate: Date(), readinessScore: score)
        let entity = DayEntity(from: original)
        let restored = entity.toDay()

        #expect(restored.readinessScore?.id == scoreId)
        #expect(restored.readinessScore?.score == 75)
        #expect(restored.readinessScore?.confidence == .full)
        #expect(restored.readinessScore?.breakdown.hrvScore == 70)
    }

    @Test func roundTripPreservesCompleteDay() {
        let id = UUID()
        let startDate = Date()
        let firstTimestamp = startDate
        let secondTimestamp = startDate.addingTimeInterval(12 * 3600)

        let metrics = HealthMetrics(
            date: startDate,
            restingHeartRate: 58,
            hrv: 65,
            sleepDuration: 7.5 * 3600,
            steps: 10000,
            activeCalories: 450
        )

        let score = ReadinessScore(
            date: startDate,
            score: 82,
            breakdown: ReadinessBreakdown(
                hrvScore: 85,
                restingHeartRateScore: 80,
                sleepScore: 78,
                energyScore: 80
            ),
            confidence: .full,
            healthMetrics: metrics,
            userEnergyLevel: 4
        )

        let original = Day(
            id: id,
            startDate: startDate,
            firstCheckIn: CheckInSlot(timestamp: firstTimestamp, energyLevel: 4),
            secondCheckIn: CheckInSlot(timestamp: secondTimestamp, energyLevel: 4),
            healthMetrics: metrics,
            readinessScore: score
        )

        let entity = DayEntity(from: original)
        let restored = entity.toDay()

        #expect(restored.id == id)
        #expect(restored.startDate == startDate)
        #expect(restored.isComplete == true)
        #expect(restored.healthMetrics?.restingHeartRate == 58)
        #expect(restored.readinessScore?.score == 82)
    }

    // MARK: - Update Tests

    @Test func updateAddsFirstCheckIn() {
        let entity = DayEntity(id: UUID(), startDate: Date())
        #expect(entity.hasFirstCheckIn == false)

        let updatedDay = Day(
            id: entity.id,
            startDate: entity.startDate,
            firstCheckIn: CheckInSlot(energyLevel: 4)
        )

        entity.update(from: updatedDay)

        #expect(entity.hasFirstCheckIn == true)
        #expect(entity.firstCheckInEnergy == 4)
    }

    @Test func updateAddsSecondCheckIn() {
        var day = Day(
            startDate: Date(),
            firstCheckIn: CheckInSlot(energyLevel: 4)
        )
        let entity = DayEntity(from: day)

        #expect(entity.hasSecondCheckIn == false)

        day.secondCheckIn = CheckInSlot(energyLevel: 3)
        entity.update(from: day)

        #expect(entity.hasSecondCheckIn == true)
        #expect(entity.secondCheckInEnergy == 3)
    }

    @Test func updateAddsHealthMetrics() {
        let entity = DayEntity(id: UUID(), startDate: Date())
        #expect(entity.hasHealthMetrics == false)

        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: 60,
            hrv: 50,
            sleepDuration: 7 * 3600
        )

        let updatedDay = Day(
            id: entity.id,
            startDate: entity.startDate,
            healthMetrics: metrics
        )

        entity.update(from: updatedDay)

        #expect(entity.hasHealthMetrics == true)
        #expect(entity.healthRestingHeartRate == 60)
    }

    @Test func updateAddsReadinessScore() {
        let entity = DayEntity(id: UUID(), startDate: Date())
        #expect(entity.hasReadinessScore == false)

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

        let updatedDay = Day(
            id: entity.id,
            startDate: entity.startDate,
            readinessScore: score
        )

        entity.update(from: updatedDay)

        #expect(entity.hasReadinessScore == true)
        #expect(entity.readinessScore == 75)
    }

    // MARK: - Sentinel Value Detection

    @Test func detectsSentinelValues() {
        let entity = DayEntity()

        // All should be using sentinel values initially
        #expect(entity.firstCheckInEnergy == -1)
        #expect(entity.secondCheckInEnergy == -1)
        #expect(entity.healthRestingHeartRate == -1)
        #expect(entity.healthHRV == -1)
        #expect(entity.healthSleepDuration == -1)
        #expect(entity.healthSteps == -1)
        #expect(entity.healthActiveCalories == -1)
        #expect(entity.readinessScore == -1)

        // Helper properties should detect no data
        #expect(entity.hasFirstCheckIn == false)
        #expect(entity.hasSecondCheckIn == false)
        #expect(entity.hasHealthMetrics == false)
        #expect(entity.hasReadinessScore == false)
    }

    @Test func toDayConvertsNilForSentinelValues() {
        let entity = DayEntity(id: UUID(), startDate: Date())
        // Set some values, leave others as sentinels
        entity.healthMetricsDate = Date()
        entity.healthRestingHeartRate = 60
        // Leave hrv, sleep, steps, calories as -1

        let day = entity.toDay()

        #expect(day.healthMetrics?.restingHeartRate == 60)
        #expect(day.healthMetrics?.hrv == nil)
        #expect(day.healthMetrics?.sleepDuration == nil)
        #expect(day.healthMetrics?.steps == nil)
        #expect(day.healthMetrics?.activeCalories == nil)
    }
}
