//
//  DayEntity.swift
//  Pulse
//
//  Created by Devon Martin on 12/6/2025.
//

import Foundation
import SwiftData

/// SwiftData entity for persisting a user's "day" with check-in slots.
///
/// A DayEntity represents a single user day with:
/// - Two check-in slots (first and second)
/// - A single health metrics snapshot
/// - A reference to the readiness score
///
/// Note: All properties have default values as required by CloudKit sync.
/// Sentinel values (-1) indicate "no data" for numeric fields.
@Model
final class DayEntity {

    // MARK: - Core Properties

    /// Unique identifier for this day
    var id: UUID = UUID()

    /// When this "user day" began (based on user's day boundary settings)
    var startDate: Date = Date()

    // MARK: - First Check-In Slot

    /// Timestamp of first check-in. Sentinel Date.distantPast means no check-in.
    var firstCheckInTimestamp: Date = Date.distantPast

    /// Energy level from first check-in (1-5). -1 means no check-in.
    var firstCheckInEnergy: Int = -1

    // MARK: - Second Check-In Slot

    /// Timestamp of second check-in. Sentinel Date.distantPast means no check-in.
    var secondCheckInTimestamp: Date = Date.distantPast

    /// Energy level from second check-in (1-5). -1 means no check-in.
    var secondCheckInEnergy: Int = -1

    // MARK: - Health Metrics (embedded, not a relationship)
    // Using embedded values for simplicity and to avoid relationship complexity

    /// The date the health metrics are for
    var healthMetricsDate: Date = Date.distantPast

    /// Resting heart rate in BPM. -1 indicates no data.
    var healthRestingHeartRate: Double = -1

    /// Heart rate variability (SDNN) in milliseconds. -1 indicates no data.
    var healthHRV: Double = -1

    /// Sleep duration in seconds. -1 indicates no data.
    var healthSleepDuration: Double = -1

    /// Step count. -1 indicates no data.
    var healthSteps: Int = -1

    /// Active calories burned. -1 indicates no data.
    var healthActiveCalories: Double = -1

    // MARK: - Readiness Score (embedded)

    /// The calculated readiness score (0-100). -1 means not yet calculated.
    var readinessScore: Int = -1

    /// Readiness score ID for reference. Nil means not calculated.
    var readinessScoreId: UUID?

    /// Confidence level raw value
    var readinessConfidenceRawValue: String = ""

    // MARK: - Breakdown Scores

    var breakdownHRVScore: Int = -1
    var breakdownRestingHeartRateScore: Int = -1
    var breakdownSleepScore: Int = -1
    var breakdownEnergyScore: Int = -1

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        startDate: Date = Date()
    ) {
        self.id = id
        self.startDate = startDate
    }

    /// Creates an entity from a domain Day
    convenience init(from day: Day) {
        self.init(id: day.id, startDate: day.startDate)

        // First check-in
        if let first = day.firstCheckIn {
            self.firstCheckInTimestamp = first.timestamp
            self.firstCheckInEnergy = first.energyLevel
        }

        // Second check-in
        if let second = day.secondCheckIn {
            self.secondCheckInTimestamp = second.timestamp
            self.secondCheckInEnergy = second.energyLevel
        }

        // Health metrics
        if let metrics = day.healthMetrics {
            self.healthMetricsDate = metrics.date
            self.healthRestingHeartRate = metrics.restingHeartRate ?? -1
            self.healthHRV = metrics.hrv ?? -1
            self.healthSleepDuration = metrics.sleepDuration ?? -1
            self.healthSteps = metrics.steps ?? -1
            self.healthActiveCalories = metrics.activeCalories ?? -1
        }

        // Readiness score
        if let score = day.readinessScore {
            self.readinessScoreId = score.id
            self.readinessScore = score.score
            self.readinessConfidenceRawValue = score.confidence.rawValue
            self.breakdownHRVScore = score.breakdown.hrvScore ?? -1
            self.breakdownRestingHeartRateScore = score.breakdown.restingHeartRateScore ?? -1
            self.breakdownSleepScore = score.breakdown.sleepScore ?? -1
            self.breakdownEnergyScore = score.breakdown.energyScore ?? -1
        }
    }
}

// MARK: - Computed Properties

extension DayEntity {
    /// Whether first check-in has been completed
    var hasFirstCheckIn: Bool {
        firstCheckInEnergy >= 1
    }

    /// Whether second check-in has been completed
    var hasSecondCheckIn: Bool {
        secondCheckInEnergy >= 1
    }

    /// Whether health metrics have been captured
    var hasHealthMetrics: Bool {
        healthMetricsDate != Date.distantPast
    }

    /// Whether a readiness score has been calculated
    var hasReadinessScore: Bool {
        readinessScore >= 0
    }
}

// MARK: - Domain Conversion

extension DayEntity {
    /// Converts this entity to a domain Day
    func toDay() -> Day {
        // First check-in slot
        let firstSlot: CheckInSlot? = hasFirstCheckIn
            ? CheckInSlot(timestamp: firstCheckInTimestamp, energyLevel: firstCheckInEnergy)
            : nil

        // Second check-in slot
        let secondSlot: CheckInSlot? = hasSecondCheckIn
            ? CheckInSlot(timestamp: secondCheckInTimestamp, energyLevel: secondCheckInEnergy)
            : nil

        // Health metrics
        let metrics: HealthMetrics? = hasHealthMetrics
            ? HealthMetrics(
                date: healthMetricsDate,
                restingHeartRate: healthRestingHeartRate >= 0 ? healthRestingHeartRate : nil,
                hrv: healthHRV >= 0 ? healthHRV : nil,
                sleepDuration: healthSleepDuration >= 0 ? healthSleepDuration : nil,
                steps: healthSteps >= 0 ? healthSteps : nil,
                activeCalories: healthActiveCalories >= 0 ? healthActiveCalories : nil
            )
            : nil

        // Readiness score
        let score: ReadinessScore? = hasReadinessScore
            ? ReadinessScore(
                id: readinessScoreId ?? UUID(),
                date: startDate,
                score: readinessScore,
                breakdown: ReadinessBreakdown(
                    hrvScore: breakdownHRVScore >= 0 ? breakdownHRVScore : nil,
                    restingHeartRateScore: breakdownRestingHeartRateScore >= 0 ? breakdownRestingHeartRateScore : nil,
                    sleepScore: breakdownSleepScore >= 0 ? breakdownSleepScore : nil,
                    energyScore: breakdownEnergyScore >= 0 ? breakdownEnergyScore : nil
                ),
                confidence: ReadinessConfidence(rawValue: readinessConfidenceRawValue) ?? .limited,
                healthMetrics: metrics,
                userEnergyLevel: hasFirstCheckIn ? firstCheckInEnergy : nil
            )
            : nil

        return Day(
            id: id,
            startDate: startDate,
            firstCheckIn: firstSlot,
            secondCheckIn: secondSlot,
            healthMetrics: metrics,
            readinessScore: score
        )
    }

    /// Updates this entity from a domain Day
    func update(from day: Day) {
        // First check-in
        if let first = day.firstCheckIn {
            self.firstCheckInTimestamp = first.timestamp
            self.firstCheckInEnergy = first.energyLevel
        }

        // Second check-in
        if let second = day.secondCheckIn {
            self.secondCheckInTimestamp = second.timestamp
            self.secondCheckInEnergy = second.energyLevel
        }

        // Health metrics
        if let metrics = day.healthMetrics {
            self.healthMetricsDate = metrics.date
            self.healthRestingHeartRate = metrics.restingHeartRate ?? -1
            self.healthHRV = metrics.hrv ?? -1
            self.healthSleepDuration = metrics.sleepDuration ?? -1
            self.healthSteps = metrics.steps ?? -1
            self.healthActiveCalories = metrics.activeCalories ?? -1
        }

        // Readiness score
        if let score = day.readinessScore {
            self.readinessScoreId = score.id
            self.readinessScore = score.score
            self.readinessConfidenceRawValue = score.confidence.rawValue
            self.breakdownHRVScore = score.breakdown.hrvScore ?? -1
            self.breakdownRestingHeartRateScore = score.breakdown.restingHeartRateScore ?? -1
            self.breakdownSleepScore = score.breakdown.sleepScore ?? -1
            self.breakdownEnergyScore = score.breakdown.energyScore ?? -1
        }
    }
}
