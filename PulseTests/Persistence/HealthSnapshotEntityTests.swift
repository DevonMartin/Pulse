//
//  HealthSnapshotEntityTests.swift
//  PulseTests
//
//  Created by Devon Martin on 12/1/2025.
//

import Testing
@testable import Pulse
import Foundation

struct HealthSnapshotEntityTests {

    // MARK: - Initialization from HealthMetrics

    @Test func initFromHealthMetricsPreservesAllValues() {
        let date = Date()
        let metrics = HealthMetrics(
            date: date,
            restingHeartRate: 62,
            hrv: 45,
            sleepDuration: 7 * 3600,
            steps: 8000,
            activeCalories: 350
        )

        let entity = HealthSnapshotEntity(from: metrics)

        #expect(entity.date == date)
        #expect(entity.restingHeartRateValue == 62)
        #expect(entity.hrvValue == 45)
		#expect(entity.sleepDurationValue == 7.0 * 3600)
        #expect(entity.stepsValue == 8000)
        #expect(entity.activeCaloriesValue == 350)
    }

    @Test func initFromHealthMetricsHandlesNilValues() {
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

    @Test func initFromHealthMetricsHandlesPartialData() {
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: 65,
            hrv: nil,
            sleepDuration: 6 * 3600,
            steps: nil,
            activeCalories: 200
        )

        let entity = HealthSnapshotEntity(from: metrics)

        #expect(entity.restingHeartRateValue == 65)
        #expect(entity.hrvValue == nil)
		#expect(entity.sleepDurationValue == 6.0 * 3600)
        #expect(entity.stepsValue == nil)
        #expect(entity.activeCaloriesValue == 200)
    }

    // MARK: - Conversion to HealthMetrics

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

    @Test func toHealthMetricsPreservesNilValues() {
        let original = HealthMetrics(
            date: Date(),
            restingHeartRate: nil,
            hrv: nil,
            sleepDuration: nil,
            steps: nil,
            activeCalories: nil
        )

        let entity = HealthSnapshotEntity(from: original)
        let converted = entity.toHealthMetrics()

        #expect(converted.restingHeartRate == nil)
        #expect(converted.hrv == nil)
        #expect(converted.sleepDuration == nil)
        #expect(converted.steps == nil)
        #expect(converted.activeCalories == nil)
    }

    @Test func toHealthMetricsPreservesDate() {
        let specificDate = Calendar.current.date(from: DateComponents(year: 2024, month: 6, day: 15))!
        let metrics = HealthMetrics(
            date: specificDate,
            restingHeartRate: 60,
            hrv: 40,
            sleepDuration: 7 * 3600,
            steps: 5000,
            activeCalories: 250
        )

        let entity = HealthSnapshotEntity(from: metrics)
        let converted = entity.toHealthMetrics()

        #expect(converted.date == specificDate)
    }

    // MARK: - Default Values (CloudKit Compatibility)

    @Test func defaultInitializationHasValidDefaults() {
        let entity = HealthSnapshotEntity()

        // Should have sentinel values for CloudKit compatibility
        #expect(entity.id != UUID())
        #expect(entity.date <= Date())
    }

    // MARK: - Edge Cases

    @Test func handlesZeroValues() {
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: 0,
            hrv: 0,
            sleepDuration: 0,
            steps: 0,
            activeCalories: 0
        )

        let entity = HealthSnapshotEntity(from: metrics)

        // Zero should be preserved, not treated as nil
        #expect(entity.restingHeartRateValue == 0)
        #expect(entity.hrvValue == 0)
        #expect(entity.sleepDurationValue == 0)
        #expect(entity.stepsValue == 0)
        #expect(entity.activeCaloriesValue == 0)
    }

    @Test func handlesLargeValues() {
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: 200,
            hrv: 150,
            sleepDuration: 24 * 3600, // 24 hours
            steps: 100000,
            activeCalories: 10000
        )

        let entity = HealthSnapshotEntity(from: metrics)
        let converted = entity.toHealthMetrics()

        #expect(converted.restingHeartRate == 200)
        #expect(converted.hrv == 150)
		#expect(converted.sleepDuration == 24.0 * 3600)
        #expect(converted.steps == 100000)
        #expect(converted.activeCalories == 10000)
    }

    @Test func handlesDecimalValues() {
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: 62.5,
            hrv: 45.7,
            sleepDuration: 7.5 * 3600,
            steps: 8000,
            activeCalories: 350.25
        )

        let entity = HealthSnapshotEntity(from: metrics)
        let converted = entity.toHealthMetrics()

        #expect(converted.restingHeartRate == 62.5)
        #expect(converted.hrv == 45.7)
        #expect(converted.sleepDuration == 7.5 * 3600)
        #expect(converted.activeCalories == 350.25)
    }
}
