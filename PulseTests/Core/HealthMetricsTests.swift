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
}
