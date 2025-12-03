//
//  CheckInEntity.swift
//  Pulse
//
//  Created by Devon Martin on 12/1/2025.
//

import Foundation
import SwiftData

/// The type of check-in (morning or evening).
/// Stored as raw string in SwiftData for CloudKit compatibility.
enum CheckInType: String, Codable, Sendable {
    case morning
    case evening
}

/// SwiftData entity for storing user check-ins.
///
/// Each check-in captures the user's subjective energy level (1-5) at a specific time.
/// Morning check-ins capture how the user feels upon waking.
/// Evening check-ins will capture end-of-day state (future feature).
///
/// Note: All properties have default values as required by CloudKit sync.
@Model
final class CheckInEntity {
    /// Unique identifier for this check-in
    var id: UUID = UUID()

    /// When the check-in was recorded
    var timestamp: Date = Date()

    /// The type of check-in (morning/evening), stored as raw string
    var typeRawValue: String = CheckInType.morning.rawValue

    /// User's subjective energy level (1-5)
    /// 1 = Very low energy, 5 = Very high energy
    var energyLevel: Int = 3

    /// Reference to the health snapshot captured at check-in time
    /// Optional because snapshot might fail to capture
    @Relationship(deleteRule: .cascade)
    var healthSnapshot: HealthSnapshotEntity?

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        type: CheckInType = .morning,
        energyLevel: Int = 3,
        healthSnapshot: HealthSnapshotEntity? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.typeRawValue = type.rawValue
        self.energyLevel = energyLevel
        self.healthSnapshot = healthSnapshot
    }

    // MARK: - Computed Properties

    /// Typed accessor for check-in type
    var type: CheckInType {
        get { CheckInType(rawValue: typeRawValue) ?? .morning }
        set { typeRawValue = newValue.rawValue }
    }
}
