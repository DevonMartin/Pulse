//
//  HealthMetrics.swift
//  Pulse
//
//  Created by Devon Martin on 12/1/2025.
//

import Foundation

/// A snapshot of health metrics for a specific date.
/// This is a domain model - pure Swift struct with no framework dependencies.
struct HealthMetrics: Equatable, Sendable {
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
}
