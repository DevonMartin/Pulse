//
//  HealthMetricsTests.swift
//  PulseTests
//
//  Created by Devon Martin on 12/1/2025.
//

import Testing
@testable import Pulse
import Foundation

@MainActor
struct HealthMetricsTests {

    // MARK: - Formatted Sleep Duration

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

    @Test func formattedSleepDurationHandlesExactHours() {
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: nil,
            hrv: nil,
            sleepDuration: 8 * 3600, // Exactly 8 hours
            steps: nil,
            activeCalories: nil
        )

        #expect(metrics.formattedSleepDuration == "8h 0m")
    }

    @Test func formattedSleepDurationHandlesZeroMinutes() {
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: nil,
            hrv: nil,
            sleepDuration: 0,
            steps: nil,
            activeCalories: nil
        )

        #expect(metrics.formattedSleepDuration == "0m")
    }

    // MARK: - Has Any Data

    @Test func hasAnyDataReturnsTrueWhenRestingHeartRatePresent() {
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: 65,
            hrv: nil,
            sleepDuration: nil,
            steps: nil,
            activeCalories: nil
        )

        #expect(metrics.hasAnyData == true)
    }

    @Test func hasAnyDataReturnsTrueWhenHRVPresent() {
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: nil,
            hrv: 45,
            sleepDuration: nil,
            steps: nil,
            activeCalories: nil
        )

        #expect(metrics.hasAnyData == true)
    }

    @Test func hasAnyDataReturnsTrueWhenSleepPresent() {
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: nil,
            hrv: nil,
            sleepDuration: 7 * 3600,
            steps: nil,
            activeCalories: nil
        )

        #expect(metrics.hasAnyData == true)
    }

    @Test func hasAnyDataReturnsTrueWhenStepsPresent() {
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: nil,
            hrv: nil,
            sleepDuration: nil,
            steps: 5000,
            activeCalories: nil
        )

        #expect(metrics.hasAnyData == true)
    }

    @Test func hasAnyDataReturnsTrueWhenCaloriesPresent() {
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: nil,
            hrv: nil,
            sleepDuration: nil,
            steps: nil,
            activeCalories: 350
        )

        #expect(metrics.hasAnyData == true)
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

    @Test func hasAnyDataReturnsTrueWhenAllPresent() {
        let fullMetrics = HealthMetrics(
            date: Date(),
            restingHeartRate: 62,
            hrv: 45,
            sleepDuration: 7 * 3600,
            steps: 8000,
            activeCalories: 350
        )

        #expect(fullMetrics.hasAnyData == true)
    }

    // MARK: - Equatable

    @Test func metricsAreEqualWhenAllPropertiesMatch() {
        let date = Date()
        let metrics1 = HealthMetrics(
            date: date,
            restingHeartRate: 62,
            hrv: 45,
            sleepDuration: 7 * 3600,
            steps: 8000,
            activeCalories: 350
        )
        let metrics2 = HealthMetrics(
            date: date,
            restingHeartRate: 62,
            hrv: 45,
            sleepDuration: 7 * 3600,
            steps: 8000,
            activeCalories: 350
        )

        #expect(metrics1 == metrics2)
    }

    @Test func metricsAreNotEqualWhenDifferentValues() {
        let date = Date()
        let metrics1 = HealthMetrics(
            date: date,
            restingHeartRate: 62,
            hrv: 45,
            sleepDuration: 7 * 3600,
            steps: 8000,
            activeCalories: 350
        )
        let metrics2 = HealthMetrics(
            date: date,
            restingHeartRate: 65, // Different
            hrv: 45,
            sleepDuration: 7 * 3600,
            steps: 8000,
            activeCalories: 350
        )

        #expect(metrics1 != metrics2)
    }

    // MARK: - Merging

    @Test func mergingFillsNilFieldsFromNewer() {
        let date = Date()
        let existing = HealthMetrics(
            date: date,
            restingHeartRate: 62,
            hrv: nil,
            sleepDuration: nil,
            steps: 5000,
            activeCalories: nil
        )
        let newer = HealthMetrics(
            date: date,
            restingHeartRate: 65,
            hrv: 45,
            sleepDuration: 7 * 3600,
            steps: 8000,
            activeCalories: 350
        )

        let (merged, didChange) = existing.merging(with: newer)

        #expect(didChange == true)
        #expect(merged.restingHeartRate == 62) // Kept existing
        #expect(merged.hrv == 45) // Filled from newer
		#expect(merged.sleepDuration == 7.0 * 3600) // Filled from newer
        #expect(merged.steps == 5000) // Kept existing
        #expect(merged.activeCalories == 350) // Filled from newer
    }

    @Test func mergingDoesNotOverwriteExistingValues() {
        let date = Date()
        let existing = HealthMetrics(
            date: date,
            restingHeartRate: 62,
            hrv: 50,
            sleepDuration: 8 * 3600,
            steps: 10000,
            activeCalories: 400
        )
        let newer = HealthMetrics(
            date: date,
            restingHeartRate: 70,
            hrv: 30,
            sleepDuration: 6 * 3600,
            steps: 5000,
            activeCalories: 200
        )

        let (merged, didChange) = existing.merging(with: newer)

        #expect(didChange == false)
        #expect(merged.restingHeartRate == 62)
        #expect(merged.hrv == 50)
		#expect(merged.sleepDuration == 8.0 * 3600)
        #expect(merged.steps == 10000)
        #expect(merged.activeCalories == 400)
    }

    @Test func mergingReturnsDidChangeFalseWhenNoNewData() {
        let date = Date()
        let existing = HealthMetrics(
            date: date,
            restingHeartRate: 62,
            hrv: nil,
            sleepDuration: nil,
            steps: nil,
            activeCalories: nil
        )
        let newer = HealthMetrics(
            date: date,
            restingHeartRate: nil,
            hrv: nil,
            sleepDuration: nil,
            steps: nil,
            activeCalories: nil
        )

        let (merged, didChange) = existing.merging(with: newer)

        #expect(didChange == false)
        #expect(merged.restingHeartRate == 62)
    }

    @Test func mergingPreservesOriginalDate() {
        let originalDate = Date()
        let newerDate = Date().addingTimeInterval(3600)
        let existing = HealthMetrics(
            date: originalDate,
            restingHeartRate: nil,
            hrv: nil,
            sleepDuration: nil,
            steps: nil,
            activeCalories: nil
        )
        let newer = HealthMetrics(
            date: newerDate,
            restingHeartRate: 65,
            hrv: 45,
            sleepDuration: nil,
            steps: nil,
            activeCalories: nil
        )

        let (merged, _) = existing.merging(with: newer)

        #expect(merged.date == originalDate)
    }

    @Test func mergingHandlesPartialNewData() {
        let date = Date()
        let existing = HealthMetrics(
            date: date,
            restingHeartRate: nil,
            hrv: nil,
            sleepDuration: nil,
            steps: nil,
            activeCalories: nil
        )
        let newer = HealthMetrics(
            date: date,
            restingHeartRate: 62,
            hrv: nil,
            sleepDuration: 7 * 3600,
            steps: nil,
            activeCalories: nil
        )

        let (merged, didChange) = existing.merging(with: newer)

        #expect(didChange == true)
        #expect(merged.restingHeartRate == 62)
        #expect(merged.hrv == nil)
		#expect(merged.sleepDuration == 7.0 * 3600)
        #expect(merged.steps == nil)
        #expect(merged.activeCalories == nil)
    }
}
