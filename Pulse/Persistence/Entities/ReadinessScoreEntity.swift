//
//  ReadinessScoreEntity.swift
//  Pulse
//
//  Created by Devon Martin on 12/4/2025.
//

import Foundation
import SwiftData

/// SwiftData entity for persisting readiness scores.
///
/// Stores historical readiness scores so users can view trends over time.
/// Also stores the raw inputs (metrics + energy level) for potential
/// recalculation with improved algorithms in the future.
@Model
final class ReadinessScoreEntity {

    // MARK: - Core Properties

    /// Unique identifier for this score
    var id: UUID

    /// The date this score is for (typically start of day)
    var date: Date

    /// The calculated readiness score (0-100)
    var score: Int

    /// Confidence level raw value for Codable storage
    var confidenceRawValue: String

    // MARK: - Breakdown Scores (nil if metric wasn't available)

    var hrvScore: Int?
    var restingHeartRateScore: Int?
    var sleepScore: Int?
    var energyScore: Int?

    // MARK: - Raw Input Data (for future recalculation)

    /// The HRV value that was used (ms)
    var rawHRV: Double?

    /// The resting heart rate that was used (bpm)
    var rawRestingHeartRate: Double?

    /// The sleep duration that was used (seconds)
    var rawSleepDuration: Double?

    /// The user's energy level input (1-5)
    var rawEnergyLevel: Int?

    /// Steps recorded that day (informational, for future pattern analysis)
    var rawSteps: Int?

    /// Active calories recorded that day (informational, for future pattern analysis)
    var rawActiveCalories: Double?

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        score: Int = 0,
        confidenceRawValue: String = ReadinessConfidence.limited.rawValue,
        hrvScore: Int? = nil,
        restingHeartRateScore: Int? = nil,
        sleepScore: Int? = nil,
        energyScore: Int? = nil,
        rawHRV: Double? = nil,
        rawRestingHeartRate: Double? = nil,
        rawSleepDuration: Double? = nil,
        rawEnergyLevel: Int? = nil,
        rawSteps: Int? = nil,
        rawActiveCalories: Double? = nil
    ) {
        self.id = id
        self.date = date
        self.score = score
        self.confidenceRawValue = confidenceRawValue
        self.hrvScore = hrvScore
        self.restingHeartRateScore = restingHeartRateScore
        self.sleepScore = sleepScore
        self.energyScore = energyScore
        self.rawHRV = rawHRV
        self.rawRestingHeartRate = rawRestingHeartRate
        self.rawSleepDuration = rawSleepDuration
        self.rawEnergyLevel = rawEnergyLevel
        self.rawSteps = rawSteps
        self.rawActiveCalories = rawActiveCalories
    }

    /// Creates an entity from a domain ReadinessScore
    convenience init(from score: ReadinessScore) {
        self.init(
            id: score.id,
            date: score.date,
            score: score.score,
            confidenceRawValue: score.confidence.rawValue,
            hrvScore: score.breakdown.hrvScore,
            restingHeartRateScore: score.breakdown.restingHeartRateScore,
            sleepScore: score.breakdown.sleepScore,
            energyScore: score.breakdown.energyScore,
            rawHRV: score.healthMetrics?.hrv,
            rawRestingHeartRate: score.healthMetrics?.restingHeartRate,
            rawSleepDuration: score.healthMetrics?.sleepDuration,
            rawEnergyLevel: score.userEnergyLevel,
            rawSteps: score.healthMetrics?.steps,
            rawActiveCalories: score.healthMetrics?.activeCalories
        )
    }
}

// MARK: - Computed Properties

extension ReadinessScoreEntity {
    /// The confidence level as an enum
    var confidence: ReadinessConfidence {
        get {
            ReadinessConfidence(rawValue: confidenceRawValue) ?? .limited
        }
        set {
            confidenceRawValue = newValue.rawValue
        }
    }
}

// MARK: - Domain Conversion

extension ReadinessScoreEntity {
    /// Converts this entity to a domain ReadinessScore
    func toReadinessScore() -> ReadinessScore {
        let breakdown = ReadinessBreakdown(
            hrvScore: hrvScore,
            restingHeartRateScore: restingHeartRateScore,
            sleepScore: sleepScore,
            energyScore: energyScore
        )

        // Reconstruct health metrics if we have any raw data
        let healthMetrics: HealthMetrics?
        if rawHRV != nil || rawRestingHeartRate != nil || rawSleepDuration != nil ||
           rawSteps != nil || rawActiveCalories != nil {
            healthMetrics = HealthMetrics(
                date: date,
                restingHeartRate: rawRestingHeartRate,
                hrv: rawHRV,
                sleepDuration: rawSleepDuration,
                steps: rawSteps,
                activeCalories: rawActiveCalories
            )
        } else {
            healthMetrics = nil
        }

        return ReadinessScore(
            id: id,
            date: date,
            score: score,
            breakdown: breakdown,
            confidence: confidence,
            healthMetrics: healthMetrics,
            userEnergyLevel: rawEnergyLevel
        )
    }
}
