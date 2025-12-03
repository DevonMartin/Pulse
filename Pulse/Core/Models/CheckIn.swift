//
//  CheckIn.swift
//  Pulse
//
//  Created by Devon Martin on 12/1/2025.
//

import Foundation

/// A domain model representing a user check-in.
///
/// This is a pure Swift struct used throughout the app layer.
/// It's independent of SwiftData/persistence concerns.
/// The repository layer handles conversion to/from CheckInEntity.
struct CheckIn: Identifiable, Equatable, Sendable {
    let id: UUID
    let timestamp: Date
    let type: CheckInType
    let energyLevel: Int
    let healthSnapshot: HealthMetrics?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: CheckInType,
        energyLevel: Int,
        healthSnapshot: HealthMetrics? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.type = type
        self.energyLevel = energyLevel
        self.healthSnapshot = healthSnapshot
    }
}

// MARK: - Convenience

extension CheckIn {
    /// Returns true if this check-in is from today
    var isToday: Bool {
        Calendar.current.isDateInToday(timestamp)
    }

    /// The date component of the timestamp (without time)
    var date: Date {
        Calendar.current.startOfDay(for: timestamp)
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

// MARK: - Entity Conversion

extension CheckIn {
    /// Creates a domain CheckIn from a persistence entity
    init(from entity: CheckInEntity) {
        self.id = entity.id
        self.timestamp = entity.timestamp
        self.type = entity.type
        self.energyLevel = entity.energyLevel
        self.healthSnapshot = entity.healthSnapshot?.toHealthMetrics()
    }
}

extension CheckInEntity {
    /// Updates this entity from a domain CheckIn
    /// Note: Does not update healthSnapshot relationship - handle separately
    func update(from checkIn: CheckIn) {
        self.id = checkIn.id
        self.timestamp = checkIn.timestamp
        self.type = checkIn.type
        self.energyLevel = checkIn.energyLevel
    }
}
