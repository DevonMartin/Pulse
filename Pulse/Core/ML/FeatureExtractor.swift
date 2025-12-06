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
/// - `dayOfWeek`: Day encoded as 0-1 (Sunday=0, Saturday=1)
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
    /// - Parameter metrics: The health metrics to extract features from
    /// - Returns: A feature vector with normalized values (some may be nil if data missing)
    func extractFeatures(from metrics: HealthMetrics?) -> FeatureVector {
        guard let metrics = metrics else {
            return FeatureVector(
                hrvNormalized: nil,
                rhrNormalized: nil,
                sleepNormalized: nil,
                dayOfWeek: extractDayOfWeek(from: Date())
            )
        }

        return FeatureVector(
            hrvNormalized: metrics.hrv.map { normalizeHRV($0) },
            rhrNormalized: metrics.restingHeartRate.map { normalizeRHR($0) },
            sleepNormalized: metrics.sleepDuration.map { normalizeSleep($0) },
            dayOfWeek: extractDayOfWeek(from: metrics.date)
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

    /// Extracts day of week as 0-1 value
    private func extractDayOfWeek(from date: Date) -> Double {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        // Sunday = 1, Saturday = 7 -> normalize to 0-1
        return Double(weekday - 1) / 6.0
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

    /// Day of week (0 = Sunday, 1 = Saturday)
    let dayOfWeek: Double

    /// Converts to array format for ML input, using 0.5 as default for missing values
    func toArray(defaultValue: Double = 0.5) -> [Double] {
        [
            hrvNormalized ?? defaultValue,
            rhrNormalized ?? defaultValue,
            sleepNormalized ?? defaultValue,
            dayOfWeek
        ]
    }

    /// Number of features with actual data (not using defaults)
    var availableFeatureCount: Int {
        [hrvNormalized, rhrNormalized, sleepNormalized].compactMap { $0 }.count + 1  // +1 for dayOfWeek
    }
}
