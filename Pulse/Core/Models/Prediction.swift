//
//  Prediction.swift
//  Pulse
//
//  Created by Devon Martin on 12/4/2025.
//

import Foundation

/// The source/method used to generate a prediction.
enum PredictionSource: String, Codable, Sendable {
    /// Pure rules-based prediction (early stage, no ML)
    case rules
    /// Blended rules + ML prediction (transitional)
    case blended
    /// Pure ML prediction (sufficient training data)
    case ml
}

/// A prediction of tomorrow's readiness score based on today's data.
///
/// Predictions are made in the evening based on the day's health metrics
/// and the user's reported energy level. The next morning, when the user
/// checks in with their actual energy level, we can compare the prediction
/// to reality and track accuracy over time.
///
/// This creates labeled training data for the personalized ML model:
/// - Input: today's metrics (sleep, HRV, RHR, steps, energy)
/// - Output: tomorrow's actual readiness (from next-day check-in)
struct Prediction: Identifiable, Equatable, Sendable {
    let id: UUID

    /// The date the prediction was made (typically evening)
    let createdAt: Date

    /// The date this prediction is FOR (typically tomorrow)
    let targetDate: Date

    /// The predicted readiness score (0-100)
    let predictedScore: Int

    /// Confidence in this prediction (based on data quality)
    let confidence: ReadinessConfidence

    /// How this prediction was generated
    let source: PredictionSource

    // MARK: - Input Features (what the prediction was based on)

    /// The health metrics from the day the prediction was made
    let inputMetrics: HealthMetrics?

    /// The user's energy level on the day the prediction was made
    let inputEnergyLevel: Int?

    // MARK: - Accuracy Tracking

    /// The actual readiness score from the target date (filled in later)
    let actualScore: Int?

    /// When the actual score was recorded
    let actualScoreRecordedAt: Date?

    nonisolated init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        targetDate: Date,
        predictedScore: Int,
        confidence: ReadinessConfidence,
        source: PredictionSource = .rules,
        inputMetrics: HealthMetrics? = nil,
        inputEnergyLevel: Int? = nil,
        actualScore: Int? = nil,
        actualScoreRecordedAt: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.targetDate = targetDate
        self.predictedScore = max(0, min(100, predictedScore))
        self.confidence = confidence
        self.source = source
        self.inputMetrics = inputMetrics
        self.inputEnergyLevel = inputEnergyLevel
        self.actualScore = actualScore
        self.actualScoreRecordedAt = actualScoreRecordedAt
    }
}

// MARK: - Accuracy Calculation

extension Prediction {
    /// Whether this prediction has been resolved with an actual score
    nonisolated var isResolved: Bool {
        actualScore != nil
    }

    /// The absolute error between predicted and actual (nil if not resolved)
    nonisolated var absoluteError: Int? {
        guard let actual = actualScore else { return nil }
        return abs(predictedScore - actual)
    }

    /// The signed error (positive = overpredicted, negative = underpredicted)
    nonisolated var signedError: Int? {
        guard let actual = actualScore else { return nil }
        return predictedScore - actual
    }

    /// Accuracy as a percentage (100 = perfect, 0 = off by 100 points)
    nonisolated var accuracyPercentage: Double? {
        guard let error = absoluteError else { return nil }
        return max(0, 100.0 - Double(error))
    }

    /// Human-readable accuracy description
    nonisolated var accuracyDescription: String? {
        guard let error = absoluteError else { return nil }
        switch error {
        case 0...5: return "Excellent"
        case 6...10: return "Good"
        case 11...15: return "Fair"
        case 16...25: return "Poor"
        default: return "Very Poor"
        }
    }

    /// Returns a new prediction with the actual score filled in
    nonisolated func resolved(with actualScore: Int) -> Prediction {
        Prediction(
            id: id,
            createdAt: createdAt,
            targetDate: targetDate,
            predictedScore: predictedScore,
            confidence: confidence,
            source: source,
            inputMetrics: inputMetrics,
            inputEnergyLevel: inputEnergyLevel,
            actualScore: actualScore,
            actualScoreRecordedAt: Date()
        )
    }
}

// MARK: - Convenience

extension Prediction {
    /// Whether the target date is today
    nonisolated var isForToday: Bool {
        Calendar.current.isDateInToday(targetDate)
    }

    /// Whether the target date is tomorrow
    nonisolated var isForTomorrow: Bool {
        Calendar.current.isDateInTomorrow(targetDate)
    }

    /// Human-readable description of the predicted score
    nonisolated var scoreDescription: String {
        switch predictedScore {
        case 0...40: return "Poor"
        case 41...60: return "Moderate"
        case 61...80: return "Good"
        case 81...100: return "Excellent"
        default: return "Unknown"
        }
    }
}
