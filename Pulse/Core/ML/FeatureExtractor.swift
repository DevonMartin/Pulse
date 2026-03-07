//
//  FeatureExtractor.swift
//  Pulse
//
//  Created by Devon Martin on 12/6/2025.
//

import Foundation

/// Extracts and normalizes features from health data for ML input.
///
/// This prepares health metrics for the personalized readiness model by:
/// 1. Normalizing values to 0-1 range for consistent ML input
/// 2. Using population-based ranges for normalization
/// 3. Handling missing values with nil (model handles sparse features)
///
/// ## Feature Set
/// The model uses these normalized features:
/// - `hrvNormalized`: HRV in ms, normalized using 20-100ms range
/// - `rhrNormalized`: Resting HR in bpm, inverted (lower is better)
/// - `sleepNormalized`: Sleep duration normalized to 0-1
/// - `morningEnergyNormalized`: User's morning energy rating (1-5 → 0-1)
/// - `previousDayStepsNormalized`: Previous day's step count (0-20k → 0-1)
/// - `previousDayCaloriesNormalized`: Previous day's active calories (0-1000 → 0-1)
/// - `sleepNormalizedSquared`: Squared sleep (enables learning optimal sleep duration)
/// - `previousDayStepsNormalizedSquared`: Squared steps (enables learning optimal step count)
/// - `previousDayCaloriesNormalizedSquared`: Squared calories (enables learning optimal activity level)
///
/// ## Normalization Strategy
/// Two phases based on training data count:
///
/// **Early phase (< 30 examples)**: Opinionated normalization
/// - Sleep uses optimal range scoring (7-9 hours scores highest)
/// - Helps model learn quickly with limited data
///
/// **Mature phase (30+ examples)**: Linear normalization
/// - Sleep uses simple linear scaling (more hours = higher value)
/// - Lets the model discover personal patterns without assumptions
nonisolated struct FeatureExtractor: Sendable {

    // MARK: - Configuration

    /// Number of training examples before switching to linear normalization
    private let matureThreshold: Int = 30

    /// Whether to use linear (true) or opinionated (false) normalization
    private let useLinearNormalization: Bool

    // MARK: - Feature Ranges

    /// HRV range for normalization (ms)
    /// 20ms is low/stressed, 100ms is excellent recovery
    private let hrvMin: Double = 20
    private let hrvMax: Double = 100

    /// Resting heart rate range for normalization (bpm)
    /// Note: Lower is better, so we invert during normalization
    private let rhrMin: Double = 40  // Athlete/excellent
    private let rhrMax: Double = 90  // High/poor

    /// Sleep duration range for normalization (hours)
    private let sleepMinimum: Double = 4.0
    private let sleepMaximum: Double = 12.0

    /// Sleep optimal range (only used in early phase)
    private let sleepOptimalMin: Double = 7.0
    private let sleepOptimalMax: Double = 9.0

    /// Steps range for normalization
    private let stepsMin: Double = 0
    private let stepsMax: Double = 20_000

    /// Active calories range for normalization (kcal)
    private let caloriesMin: Double = 0
    private let caloriesMax: Double = 1_000

    // MARK: - Initialization

    /// Creates a feature extractor with the appropriate normalization strategy.
    ///
    /// - Parameter trainingExampleCount: Number of training examples the model has.
    ///   With fewer than 30 examples, uses opinionated normalization.
    ///   With 30+ examples, switches to linear normalization.
    init(trainingExampleCount: Int = 0) {
        self.useLinearNormalization = trainingExampleCount >= matureThreshold
    }

    // MARK: - Feature Extraction

    /// Extracts normalized features from health metrics.
    ///
    /// - Parameters:
    ///   - metrics: The health metrics to extract features from
    ///   - morningEnergy: User's morning energy rating (1-5), if available
    ///   - previousDayMetrics: Previous day's health metrics (for lagging activity indicators)
    /// - Returns: A feature vector with normalized values (some may be nil if data missing)
    func extractFeatures(
        from metrics: HealthMetrics?,
        morningEnergy: Int? = nil,
        previousDayMetrics: HealthMetrics? = nil
    ) -> FeatureVector {
        let sleepNorm = metrics?.sleepDuration.map { normalizeSleep($0) }
        let prevStepsNorm = previousDayMetrics?.steps.map { normalizeSteps(Double($0)) }
        let prevCaloriesNorm = previousDayMetrics?.activeCalories.map { normalizeCalories($0) }

        return FeatureVector(
            hrvNormalized: metrics?.hrv.map { normalizeHRV($0) } ?? nil,
            rhrNormalized: metrics?.restingHeartRate.map { normalizeRHR($0) } ?? nil,
            sleepNormalized: sleepNorm,
            morningEnergyNormalized: morningEnergy.map { normalizeMorningEnergy($0) },
            previousDayStepsNormalized: prevStepsNorm,
            previousDayCaloriesNormalized: prevCaloriesNorm,
            sleepNormalizedSquared: sleepNorm.map { $0 * $0 },
            previousDayStepsNormalizedSquared: prevStepsNorm.map { $0 * $0 },
            previousDayCaloriesNormalizedSquared: prevCaloriesNorm.map { $0 * $0 }
        )
    }

    // MARK: - Normalization Functions

    /// Normalizes HRV to 0-1 range (higher is better)
    private func normalizeHRV(_ hrv: Double) -> Double {
        let clamped = max(hrvMin, min(hrvMax, hrv))
        return (clamped - hrvMin) / (hrvMax - hrvMin)
    }

    /// Normalizes resting heart rate to 0-1 range (inverted: lower RHR = higher score)
    private func normalizeRHR(_ rhr: Double) -> Double {
        let clamped = max(rhrMin, min(rhrMax, rhr))
        // Invert so lower RHR gives higher normalized value
        return 1.0 - ((clamped - rhrMin) / (rhrMax - rhrMin))
    }

    /// Normalizes sleep duration to 0-1 range.
    ///
    /// Uses different strategies based on data maturity:
    /// - Early phase: Opinionated (7-9 hours scores highest)
    /// - Mature phase: Linear (more sleep = higher value, model learns optimal)
    private func normalizeSleep(_ duration: TimeInterval) -> Double {
        let hours = duration / 3600

        if useLinearNormalization {
            // Mature phase: Simple linear normalization
            // Let the model learn what sleep duration works best for this user
            let clamped = max(sleepMinimum, min(sleepMaximum, hours))
            return (clamped - sleepMinimum) / (sleepMaximum - sleepMinimum)
        }

        // Early phase: Opinionated normalization with optimal range

        // Optimal range (7-9 hours) scores 0.8-1.0
        if hours >= sleepOptimalMin && hours <= sleepOptimalMax {
            let optimalRange = sleepOptimalMax - sleepOptimalMin
            let position = (hours - sleepOptimalMin) / optimalRange
            // Peak at 8 hours (middle of optimal range)
            let distanceFromMiddle = abs(position - 0.5) * 2  // 0 at middle, 1 at edges
            return 1.0 - (distanceFromMiddle * 0.2)  // 0.8-1.0 range
        }

        // Below optimal (4-7 hours) scores 0.2-0.8
        if hours < sleepOptimalMin {
            let range = sleepOptimalMin - sleepMinimum
            let position = max(0, hours - sleepMinimum) / range
            return 0.2 + (position * 0.6)
        }

        // Above optimal (9-12 hours) scores 0.5-0.8
        let range = sleepMaximum - sleepOptimalMax
        let position = min(hours - sleepOptimalMax, range) / range
        return 0.8 - (position * 0.3)
    }

    /// Normalizes morning energy (1-5) to 0-1 range
    private func normalizeMorningEnergy(_ energy: Int) -> Double {
        let clamped = max(1, min(5, energy))
        return Double(clamped - 1) / 4.0
    }

    /// Normalizes step count to 0-1 range
    private func normalizeSteps(_ steps: Double) -> Double {
        let clamped = max(stepsMin, min(stepsMax, steps))
        return (clamped - stepsMin) / (stepsMax - stepsMin)
    }

    /// Normalizes active calories to 0-1 range
    private func normalizeCalories(_ calories: Double) -> Double {
        let clamped = max(caloriesMin, min(caloriesMax, calories))
        return (clamped - caloriesMin) / (caloriesMax - caloriesMin)
    }

}

// MARK: - Feature Vector

/// A normalized feature vector for ML input.
///
/// All values are in the 0-1 range where available.
/// Nil values indicate missing data that the model should handle gracefully.
nonisolated struct FeatureVector: Sendable, Equatable {
    /// Normalized HRV (0-1, higher is better)
    let hrvNormalized: Double?

    /// Normalized resting heart rate (0-1, higher means lower/better RHR)
    let rhrNormalized: Double?

    /// Normalized sleep duration (0-1, optimal sleep scores highest)
    let sleepNormalized: Double?

    /// Normalized morning energy rating (0-1, from 1-5 scale)
    let morningEnergyNormalized: Double?

    /// Normalized previous day's step count (0-1, 0-20k range)
    let previousDayStepsNormalized: Double?

    /// Normalized previous day's active calories (0-1, 0-1000 kcal range)
    let previousDayCaloriesNormalized: Double?

    /// Squared sleep normalization (polynomial feature for learning optimal sleep duration)
    let sleepNormalizedSquared: Double?

    /// Squared previous day's steps (polynomial feature for learning optimal step count)
    let previousDayStepsNormalizedSquared: Double?

    /// Squared previous day's calories (polynomial feature for learning optimal activity level)
    let previousDayCaloriesNormalizedSquared: Double?

    /// Converts to array format for ML input, using 0.5 as default for missing values.
    /// Squared features default to 0.25 (0.5²) when their base feature is missing.
    func toArray(defaultValue: Double = 0.5) -> [Double] {
        let sqDefault = defaultValue * defaultValue
        return [
            hrvNormalized ?? defaultValue,
            rhrNormalized ?? defaultValue,
            sleepNormalized ?? defaultValue,
            sleepNormalizedSquared ?? sqDefault,
            morningEnergyNormalized ?? defaultValue,
            previousDayStepsNormalized ?? defaultValue,
            previousDayStepsNormalizedSquared ?? sqDefault,
            previousDayCaloriesNormalized ?? defaultValue,
            previousDayCaloriesNormalizedSquared ?? sqDefault
        ]
    }

    /// Number of independent features with actual data (not using defaults).
    /// Squared features are not counted separately since they derive from the same source data.
    var availableFeatureCount: Int {
        [hrvNormalized, rhrNormalized, sleepNormalized,
         morningEnergyNormalized, previousDayStepsNormalized,
         previousDayCaloriesNormalized].compactMap { $0 }.count
    }
}
