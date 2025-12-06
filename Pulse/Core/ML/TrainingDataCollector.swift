//
//  TrainingDataCollector.swift
//  Pulse
//
//  Created by Devon Martin on 12/6/2025.
//

import Foundation

/// Collects and prepares training data from historical check-ins.
///
/// This actor gathers paired morning/evening check-ins and their associated
/// health metrics to create labeled training examples for the ML model.
///
/// ## Label Calculation
/// The training label is a blended energy score:
/// ```
/// label = (morningEnergy * 0.4 + eveningEnergy * 0.6) * 20
/// ```
///
/// This produces a 20-100 scale where:
/// - Evening energy is weighted more heavily (60%) since it reflects
///   how the day actually went
/// - Morning energy (40%) captures initial state/prediction accuracy
actor TrainingDataCollector {

    init() {}

    /// Collects training examples from historical check-ins.
    ///
    /// The normalization strategy depends on the current example count:
    /// - < 30 examples: Uses opinionated normalization (7-9 hours sleep is optimal)
    /// - 30+ examples: Uses linear normalization (model learns optimal)
    ///
    /// - Parameters:
    ///   - checkIns: All historical check-ins
    ///   - healthKitService: Service to fetch health metrics for each day
    ///   - currentExampleCount: Current number of training examples (for normalization strategy)
    /// - Returns: Array of training examples with features and labels
    func collectTrainingData(
        from checkIns: [CheckIn],
        healthKitService: HealthKitServiceProtocol,
        currentExampleCount: Int = 0
    ) async -> [TrainingExample] {
        // Create feature extractor with appropriate normalization strategy
        let featureExtractor = FeatureExtractor(trainingExampleCount: currentExampleCount)

        // Group check-ins by date
        let calendar = Calendar.current
        var checkInsByDate: [Date: (morning: CheckIn?, evening: CheckIn?)] = [:]

        for checkIn in checkIns {
            let dayStart = calendar.startOfDay(for: checkIn.timestamp)

            var existing = checkInsByDate[dayStart] ?? (morning: nil, evening: nil)
            switch checkIn.type {
            case .morning:
                existing.morning = checkIn
            case .evening:
                existing.evening = checkIn
            }
            checkInsByDate[dayStart] = existing
        }

        // Create training examples for days with both check-ins
        var examples: [TrainingExample] = []

        for (date, pair) in checkInsByDate {
            guard let morning = pair.morning,
                  let evening = pair.evening else {
                continue
            }

            // Calculate blended label
            let label = Double(morning.energyLevel) * 0.4 + Double(evening.energyLevel) * 0.6
            let scaledLabel = label * 20  // Scale 1-5 to 20-100

            // Get health metrics for this day (prefer morning snapshot)
            let metrics = morning.healthSnapshot ?? evening.healthSnapshot

            // Extract features
            let features = featureExtractor.extractFeatures(from: metrics)

            // Only include if we have enough feature data
            guard features.availableFeatureCount >= 2 else {
                continue
            }

            examples.append(TrainingExample(
                features: features,
                label: scaledLabel,
                date: date
            ))
        }

        // Sort by date (oldest first) for consistent training
        return examples.sorted { $0.date < $1.date }
    }
}
