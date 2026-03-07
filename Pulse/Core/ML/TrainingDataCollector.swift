//
//  TrainingDataCollector.swift
//  Pulse
//
//  Created by Devon Martin on 12/6/2025.
//

import Foundation

/// Collects and prepares training data from completed Days.
///
/// This actor converts completed Days (both check-ins done) into
/// training examples for the ML model.
///
/// ## Label Calculation
/// The training label is a blended energy score from the Day:
/// ```
/// label = (firstEnergy * 0.4 + secondEnergy * 0.6) * 20
/// ```
///
/// This produces a 20-100 scale where:
/// - Second check-in energy is weighted more heavily (60%) since it reflects
///   how the day actually went
/// - First check-in energy (40%) captures initial state/prediction accuracy
actor TrainingDataCollector {

    init() {}

    /// Collects training examples from completed Days.
    ///
    /// The normalization strategy depends on the current example count:
    /// - < 30 examples: Uses opinionated normalization (7-9 hours sleep is optimal)
    /// - 30+ examples: Uses linear normalization (model learns optimal)
    ///
    /// Days are sorted by date internally so each day can look back at the previous
    /// day's activity metrics (steps/calories) as lagging indicators.
    ///
    /// - Parameters:
    ///   - days: Completed Days (both check-ins done)
    ///   - currentExampleCount: Current number of training examples (for normalization strategy)
    /// - Returns: Array of training examples with features and labels
    func collectTrainingData(
        from days: [Day],
        currentExampleCount: Int = 0
    ) async -> [TrainingExample] {
        // Create feature extractor with appropriate normalization strategy
        let featureExtractor = FeatureExtractor(trainingExampleCount: currentExampleCount)

        // Sort days by date first so we can look back for previous-day metrics
        let sortedDays = days.sorted { $0.startDate < $1.startDate }

        var examples: [TrainingExample] = []

        for (index, day) in sortedDays.enumerated() {
            // Skip incomplete days
            guard let blendedScore = day.blendedEnergyScore else {
                continue
            }

            // Look back to find the previous day's metrics for lagging indicators
            let previousDayMetrics: HealthMetrics? = index > 0 ? sortedDays[index - 1].healthMetrics : nil

            // Extract features from health metrics, morning energy, and previous day
            let features = featureExtractor.extractFeatures(
                from: day.healthMetrics,
                morningEnergy: day.firstCheckIn?.energyLevel,
                previousDayMetrics: previousDayMetrics
            )

            // Only include if we have enough feature data
            guard features.availableFeatureCount >= 2 else {
                continue
            }

            examples.append(TrainingExample(
                features: features,
                label: blendedScore,
                date: day.startDate
            ))
        }

        return examples
    }
}
