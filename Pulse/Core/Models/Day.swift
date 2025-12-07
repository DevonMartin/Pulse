//
//  Day.swift
//  Pulse
//
//  Created by Devon Martin on 12/6/2025.
//

import Foundation

/// A domain model representing a single "user day" with two check-in slots.
///
/// A Day encapsulates:
/// - A start date (based on user's configured day boundary, not calendar)
/// - Two check-in slots (first and second)
/// - A single health metrics snapshot for the day
/// - An optional computed readiness score
///
/// This design:
/// - Eliminates pairing logic for check-ins
/// - Handles user days that span calendar days (e.g., 6 PM to 6 AM)
/// - Provides a single source of truth for health metrics
/// - Maps 1:1 with training examples for ML
struct Day: Identifiable, Sendable {
    let id: UUID

    /// When this "user day" began.
    /// This is the timestamp when the Day was created (typically first check-in),
    /// used to determine which day this belongs to.
    let startDate: Date

    /// First check-in of the day (typically morning/start of day)
    var firstCheckIn: CheckInSlot?

    /// Second check-in of the day (typically evening/end of day)
    var secondCheckIn: CheckInSlot?

    /// Health metrics snapshot for this day.
    /// Captured once, typically at the first check-in.
    var healthMetrics: HealthMetrics?

    /// The calculated readiness score for this day.
    /// Computed after the first check-in using health metrics + energy level.
    var readinessScore: ReadinessScore?

    nonisolated init(
        id: UUID = UUID(),
        startDate: Date = Date(),
        firstCheckIn: CheckInSlot? = nil,
        secondCheckIn: CheckInSlot? = nil,
        healthMetrics: HealthMetrics? = nil,
        readinessScore: ReadinessScore? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.firstCheckIn = firstCheckIn
        self.secondCheckIn = secondCheckIn
        self.healthMetrics = healthMetrics
        self.readinessScore = readinessScore
    }
}

// MARK: - Check-In Slot

/// A single check-in within a Day.
/// Captures when the check-in occurred and the user's energy level.
struct CheckInSlot: Sendable, Equatable {
    let timestamp: Date
    let energyLevel: Int

    init(timestamp: Date = Date(), energyLevel: Int) {
        self.timestamp = timestamp
        self.energyLevel = energyLevel
    }

    /// Human-readable description of energy level
    var energyDescription: String {
        switch energyLevel {
        case 1: return "Very Low"
        case 2: return "Low"
        case 3: return "Moderate"
        case 4: return "High"
        case 5: return "Very High"
        default: return "Unknown"
        }
    }
}

// MARK: - Equatable

extension Day: Equatable {
    static func == (lhs: Day, rhs: Day) -> Bool {
        lhs.id == rhs.id &&
        lhs.startDate == rhs.startDate &&
        lhs.firstCheckIn == rhs.firstCheckIn &&
        lhs.secondCheckIn == rhs.secondCheckIn &&
        lhs.healthMetrics == rhs.healthMetrics &&
        lhs.readinessScore?.id == rhs.readinessScore?.id
    }
}

// MARK: - Convenience

extension Day {
    /// Whether the first check-in has been completed
    nonisolated var hasFirstCheckIn: Bool {
        firstCheckIn != nil
    }

    /// Whether the second check-in has been completed
    nonisolated var hasSecondCheckIn: Bool {
        secondCheckIn != nil
    }

    /// Whether both check-ins are complete (day is done)
    nonisolated var isComplete: Bool {
        hasFirstCheckIn && hasSecondCheckIn
    }

    /// Whether this Day belongs to the current user day.
    /// Uses TimeWindows to determine the boundary.
    nonisolated var isCurrentDay: Bool {
        TimeWindows.isDateInCurrentUserDay(startDate)
    }

    /// Blended energy score for ML training.
    /// Returns nil if both check-ins aren't complete.
    /// Formula: (firstEnergy * 0.4 + secondEnergy * 0.6) * 20
    nonisolated var blendedEnergyScore: Double? {
        guard let first = firstCheckIn, let second = secondCheckIn else {
            return nil
        }
        let blended = Double(first.energyLevel) * 0.4 + Double(second.energyLevel) * 0.6
        return blended * 20  // Scale 1-5 to 20-100
    }

    /// A display-friendly date string for this day
    nonisolated var displayDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: startDate)
    }
}
