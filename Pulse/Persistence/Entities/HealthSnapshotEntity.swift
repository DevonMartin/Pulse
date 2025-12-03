//
//  HealthSnapshotEntity.swift
//  Pulse
//
//  Created by Devon Martin on 12/1/2025.
//

import Foundation
import SwiftData

/// SwiftData entity for storing a snapshot of health metrics at check-in time.
///
/// This captures the user's HealthKit data at the moment of check-in, providing
/// the objective data that pairs with their subjective energy rating.
/// These snapshots become training data for the ML model.
///
/// Note: All properties have default values as required by CloudKit sync.
/// Optional metrics use sentinel values (-1) to indicate "no data" since
/// SwiftData/CloudKit doesn't support optional primitives well.
@Model
final class HealthSnapshotEntity {
    /// Unique identifier for this snapshot
    var id: UUID = UUID()

    /// The date this snapshot represents (typically "yesterday" for morning check-ins)
    var date: Date = Date()

    /// Resting heart rate in BPM. -1 indicates no data available.
    var restingHeartRate: Double = -1

    /// Heart rate variability (SDNN) in milliseconds. -1 indicates no data available.
    var hrv: Double = -1

    /// Sleep duration in seconds. -1 indicates no data available.
    var sleepDuration: Double = -1

    /// Step count. -1 indicates no data available.
    var steps: Int = -1

    /// Active calories burned. -1 indicates no data available.
    var activeCalories: Double = -1

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        restingHeartRate: Double? = nil,
        hrv: Double? = nil,
        sleepDuration: TimeInterval? = nil,
        steps: Int? = nil,
        activeCalories: Double? = nil
    ) {
        self.id = id
        self.date = date
        self.restingHeartRate = restingHeartRate ?? -1
        self.hrv = hrv ?? -1
        self.sleepDuration = sleepDuration ?? -1
        self.steps = steps ?? -1
        self.activeCalories = activeCalories ?? -1
    }

    // MARK: - Convenience

    /// Creates a snapshot from a HealthMetrics domain object
    convenience init(from metrics: HealthMetrics, id: UUID = UUID()) {
        self.init(
            id: id,
            date: metrics.date,
            restingHeartRate: metrics.restingHeartRate,
            hrv: metrics.hrv,
            sleepDuration: metrics.sleepDuration,
            steps: metrics.steps,
            activeCalories: metrics.activeCalories
        )
    }

    // MARK: - Computed Properties (Optional accessors)

    /// Resting heart rate as optional (nil if no data)
    var restingHeartRateValue: Double? {
        restingHeartRate >= 0 ? restingHeartRate : nil
    }

    /// HRV as optional (nil if no data)
    var hrvValue: Double? {
        hrv >= 0 ? hrv : nil
    }

    /// Sleep duration as optional (nil if no data)
    var sleepDurationValue: TimeInterval? {
        sleepDuration >= 0 ? sleepDuration : nil
    }

    /// Steps as optional (nil if no data)
    var stepsValue: Int? {
        steps >= 0 ? steps : nil
    }

    /// Active calories as optional (nil if no data)
    var activeCaloriesValue: Double? {
        activeCalories >= 0 ? activeCalories : nil
    }

    /// Converts this entity back to a domain HealthMetrics object
    func toHealthMetrics() -> HealthMetrics {
        HealthMetrics(
            date: date,
            restingHeartRate: restingHeartRateValue,
            hrv: hrvValue,
            sleepDuration: sleepDurationValue,
            steps: stepsValue,
            activeCalories: activeCaloriesValue
        )
    }
}
