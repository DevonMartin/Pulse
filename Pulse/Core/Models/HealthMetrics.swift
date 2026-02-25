//
//  HealthMetrics.swift
//  Pulse
//
//  Created by Devon Martin on 12/1/2025.
//

import Foundation

/// A snapshot of health metrics for a specific date.
/// This is a domain model - pure Swift struct with no framework dependencies.
struct HealthMetrics: Sendable {
    /// The date these metrics are for (typically "today" or "yesterday")
    let date: Date

    /// Resting heart rate in beats per minute.
    /// Nil if no data available for this date.
    let restingHeartRate: Double?

    /// Heart rate variability (SDNN) in milliseconds.
    /// Higher values generally indicate better recovery.
    /// Nil if no data available for this date.
    let hrv: Double?

    /// Total sleep duration in seconds.
    /// Nil if no sleep data available for this date.
    let sleepDuration: TimeInterval?

    /// Number of steps taken.
    /// Nil if no step data available for this date.
    let steps: Int?

    /// Active energy burned in kilocalories.
    /// Nil if no data available for this date.
    let activeCalories: Double?
	
	nonisolated init(
		date: Date,
		restingHeartRate: Double? = nil,
		hrv: Double? = nil,
		sleepDuration: TimeInterval? = nil,
		steps: Int? = nil,
		activeCalories: Double? = nil
	) {
		self.date = date
		self.restingHeartRate = restingHeartRate
		self.hrv = hrv
		self.sleepDuration = sleepDuration
		self.steps = steps
		self.activeCalories = activeCalories
	}
}

// MARK: - Equatable

extension HealthMetrics: Equatable {
    nonisolated static func == (lhs: HealthMetrics, rhs: HealthMetrics) -> Bool {
        lhs.date == rhs.date &&
        lhs.restingHeartRate == rhs.restingHeartRate &&
        lhs.hrv == rhs.hrv &&
        lhs.sleepDuration == rhs.sleepDuration &&
        lhs.steps == rhs.steps &&
        lhs.activeCalories == rhs.activeCalories
    }
}

// MARK: - Convenience

extension HealthMetrics {
    /// Returns sleep duration formatted as hours and minutes (e.g., "7h 30m")
    nonisolated var formattedSleepDuration: String? {
        guard let duration = sleepDuration else { return nil }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Returns true if we have at least some health data
    nonisolated var hasAnyData: Bool {
        restingHeartRate != nil ||
        hrv != nil ||
        sleepDuration != nil ||
        steps != nil ||
        activeCalories != nil
    }

    /// Merges new metrics into this one.
    /// - Recovery metrics (RHR, HRV, sleep): only fills in nil fields (these are "fixed" morning values)
    /// - Activity metrics (steps, calories): takes the maximum value (these accumulate throughout the day)
    /// Returns a new HealthMetrics with combined data and whether any fields were updated.
    nonisolated func merging(with newer: HealthMetrics) -> (merged: HealthMetrics, didChange: Bool) {
        // Recovery metrics: keep existing if available (these don't change after morning)
        let mergedRHR = restingHeartRate ?? newer.restingHeartRate
        let mergedHRV = hrv ?? newer.hrv
        let mergedSleep = sleepDuration ?? newer.sleepDuration

        // Activity metrics: take max value (these accumulate throughout the day)
        let mergedSteps = maxOptional(steps, newer.steps)
        let mergedCalories = maxOptional(activeCalories, newer.activeCalories)

        let didChange = (restingHeartRate == nil && mergedRHR != nil) ||
                        (hrv == nil && mergedHRV != nil) ||
                        (sleepDuration == nil && mergedSleep != nil) ||
                        (mergedSteps != steps) ||
                        (mergedCalories != activeCalories)

        let merged = HealthMetrics(
            date: date,
            restingHeartRate: mergedRHR,
            hrv: mergedHRV,
            sleepDuration: mergedSleep,
            steps: mergedSteps,
            activeCalories: mergedCalories
        )

        return (merged, didChange)
    }

    /// Merges only activity metrics (steps, calories) from newer metrics.
    /// Recovery metrics (RHR, HRV, sleep) are preserved from self.
    /// Returns a new HealthMetrics with combined data and whether any fields were updated.
    nonisolated func mergingActivityOnly(with newer: HealthMetrics) -> (merged: HealthMetrics, didChange: Bool) {
        // Activity metrics: take max value (these accumulate throughout the day)
        let mergedSteps = maxOptional(steps, newer.steps)
        let mergedCalories = maxOptional(activeCalories, newer.activeCalories)

        let didChange = (mergedSteps != steps) || (mergedCalories != activeCalories)

        let merged = HealthMetrics(
            date: date,
            restingHeartRate: restingHeartRate,  // Keep existing
            hrv: hrv,                            // Keep existing
            sleepDuration: sleepDuration,        // Keep existing
            steps: mergedSteps,
            activeCalories: mergedCalories
        )

        return (merged, didChange)
    }

    /// Returns the maximum of two optional values, preferring non-nil values.
    private nonisolated func maxOptional<T: Comparable>(_ a: T?, _ b: T?) -> T? {
        switch (a, b) {
        case let (a?, b?): return max(a, b)
        case let (a?, nil): return a
        case let (nil, b?): return b
        case (nil, nil): return nil
        }
    }
}
