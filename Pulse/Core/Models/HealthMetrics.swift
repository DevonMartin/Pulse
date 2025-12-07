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
    var formattedSleepDuration: String? {
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
    var hasAnyData: Bool {
        restingHeartRate != nil ||
        hrv != nil ||
        sleepDuration != nil ||
        steps != nil ||
        activeCalories != nil
    }

    /// Merges new metrics into this one, only filling in nil fields.
    /// Returns a new HealthMetrics with combined data and whether any fields were updated.
    nonisolated func merging(with newer: HealthMetrics) -> (merged: HealthMetrics, didChange: Bool) {
        let mergedRHR = restingHeartRate ?? newer.restingHeartRate
        let mergedHRV = hrv ?? newer.hrv
        let mergedSleep = sleepDuration ?? newer.sleepDuration
        let mergedSteps = steps ?? newer.steps
        let mergedCalories = activeCalories ?? newer.activeCalories

        let didChange = (restingHeartRate == nil && mergedRHR != nil) ||
                        (hrv == nil && mergedHRV != nil) ||
                        (sleepDuration == nil && mergedSleep != nil) ||
                        (steps == nil && mergedSteps != nil) ||
                        (activeCalories == nil && mergedCalories != nil)

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
}
