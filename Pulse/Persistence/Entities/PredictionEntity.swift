//
//  PredictionEntity.swift
//  Pulse
//
//  Created by Devon Martin on 12/4/2025.
//

import Foundation
import SwiftData

/// SwiftData entity for persisting predictions.
///
/// Stores predictions along with their input features and actual outcomes.
/// This data is essential for:
/// 1. Tracking prediction accuracy over time
/// 2. Training the personalized ML model
/// 3. Showing users how well the app learns their patterns
@Model
final class PredictionEntity {

    // MARK: - Core Properties

    /// Unique identifier for this prediction
    var id: UUID

    /// When the prediction was created
    var createdAt: Date

    /// The date this prediction is for
    var targetDate: Date

    /// The predicted readiness score (0-100)
    var predictedScore: Int

    /// Confidence level raw value for storage
    var confidenceRawValue: String

    /// Prediction source raw value (rules, blended, ml)
    var sourceRawValue: String

    // MARK: - Input Features

    /// HRV on the day the prediction was made (ms)
    var inputHRV: Double?

    /// Resting heart rate on prediction day (bpm)
    var inputRestingHeartRate: Double?

    /// Sleep duration the night before prediction (seconds)
    var inputSleepDuration: Double?

    /// Steps on prediction day
    var inputSteps: Int?

    /// Active calories on prediction day
    var inputActiveCalories: Double?

    /// User's energy level on prediction day (1-5)
    var inputEnergyLevel: Int?

    // MARK: - Outcome Tracking

    /// The actual readiness score on the target date (filled in later)
    var actualScore: Int?

    /// When the actual score was recorded
    var actualScoreRecordedAt: Date?

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        targetDate: Date,
        predictedScore: Int,
        confidenceRawValue: String = ReadinessConfidence.limited.rawValue,
        sourceRawValue: String = PredictionSource.rules.rawValue,
        inputHRV: Double? = nil,
        inputRestingHeartRate: Double? = nil,
        inputSleepDuration: Double? = nil,
        inputSteps: Int? = nil,
        inputActiveCalories: Double? = nil,
        inputEnergyLevel: Int? = nil,
        actualScore: Int? = nil,
        actualScoreRecordedAt: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.targetDate = targetDate
        self.predictedScore = predictedScore
        self.confidenceRawValue = confidenceRawValue
        self.sourceRawValue = sourceRawValue
        self.inputHRV = inputHRV
        self.inputRestingHeartRate = inputRestingHeartRate
        self.inputSleepDuration = inputSleepDuration
        self.inputSteps = inputSteps
        self.inputActiveCalories = inputActiveCalories
        self.inputEnergyLevel = inputEnergyLevel
        self.actualScore = actualScore
        self.actualScoreRecordedAt = actualScoreRecordedAt
    }

    /// Creates an entity from a domain Prediction
    convenience init(from prediction: Prediction) {
        self.init(
            id: prediction.id,
            createdAt: prediction.createdAt,
            targetDate: prediction.targetDate,
            predictedScore: prediction.predictedScore,
            confidenceRawValue: prediction.confidence.rawValue,
            sourceRawValue: prediction.source.rawValue,
            inputHRV: prediction.inputMetrics?.hrv,
            inputRestingHeartRate: prediction.inputMetrics?.restingHeartRate,
            inputSleepDuration: prediction.inputMetrics?.sleepDuration,
            inputSteps: prediction.inputMetrics?.steps,
            inputActiveCalories: prediction.inputMetrics?.activeCalories,
            inputEnergyLevel: prediction.inputEnergyLevel,
            actualScore: prediction.actualScore,
            actualScoreRecordedAt: prediction.actualScoreRecordedAt
        )
    }
}

// MARK: - Computed Properties

extension PredictionEntity {
    /// The confidence level as an enum
    var confidence: ReadinessConfidence {
        get {
            ReadinessConfidence(rawValue: confidenceRawValue) ?? .limited
        }
        set {
            confidenceRawValue = newValue.rawValue
        }
    }

    /// The prediction source as an enum
    var source: PredictionSource {
        get {
            PredictionSource(rawValue: sourceRawValue) ?? .rules
        }
        set {
            sourceRawValue = newValue.rawValue
        }
    }
}

// MARK: - Domain Conversion

extension PredictionEntity {
    /// Converts this entity to a domain Prediction
    func toPrediction() -> Prediction {
        // Reconstruct health metrics if we have any input data
        let inputMetrics: HealthMetrics?
        if inputHRV != nil || inputRestingHeartRate != nil || inputSleepDuration != nil ||
           inputSteps != nil || inputActiveCalories != nil {
            inputMetrics = HealthMetrics(
                date: createdAt,
                restingHeartRate: inputRestingHeartRate,
                hrv: inputHRV,
                sleepDuration: inputSleepDuration,
                steps: inputSteps,
                activeCalories: inputActiveCalories
            )
        } else {
            inputMetrics = nil
        }

        return Prediction(
            id: id,
            createdAt: createdAt,
            targetDate: targetDate,
            predictedScore: predictedScore,
            confidence: confidence,
            source: source,
            inputMetrics: inputMetrics,
            inputEnergyLevel: inputEnergyLevel,
            actualScore: actualScore,
            actualScoreRecordedAt: actualScoreRecordedAt
        )
    }
}
