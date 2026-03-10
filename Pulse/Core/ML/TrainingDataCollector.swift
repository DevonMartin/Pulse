//
//  TrainingDataCollector.swift
//  Pulse
//
//  Created by Devon Martin on 12/6/2025.
//

import Foundation

/// Collects and prepares training data from Days.
///
/// This actor converts completed Days (both check-ins done) into
/// training examples for the ML model. Incomplete days in the input
/// array provide context for previous-day activity lookback but do
/// not generate training examples.
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
///
/// ## Previous-Day Activity Lookback
/// Steps and calories from the previous calendar day are used as lagging
/// indicators. The collector resolves previous-day metrics in this order:
/// 1. From an existing Day record for the previous calendar day
/// 2. From HealthKit (fetches retroactively if no Day record exists)
/// 3. Nil (if neither source has data)
actor TrainingDataCollector {

    // MARK: - Dependencies

    private let healthKitService: HealthKitServiceProtocol

    // MARK: - Initialization

    init(healthKitService: HealthKitServiceProtocol) {
        self.healthKitService = healthKitService
    }

    /// Collects training examples from Days.
    ///
    /// The normalization strategy depends on the current example count:
    /// - < 30 examples: Uses opinionated normalization (7-9 hours sleep is optimal)
    /// - 30+ examples: Uses linear normalization (model learns optimal)
    ///
    /// Days are sorted by date internally. Only complete days (both check-ins done)
    /// produce training examples, but all days contribute to the previous-day lookback.
    /// When the previous calendar day has no Day record, activity metrics are fetched
    /// directly from HealthKit.
    ///
    /// - Parameters:
    ///   - days: All Days (complete and incomplete) for lookback context
    ///   - currentExampleCount: Current number of training examples (for normalization strategy)
    /// - Returns: Array of training examples with features and labels
    func collectTrainingData(
        from days: [Day],
        currentExampleCount: Int = 0
    ) async -> [TrainingExample] {
        // Create feature extractor with appropriate normalization strategy
        let featureExtractor = FeatureExtractor(trainingExampleCount: currentExampleCount)

        let calendar = Calendar.current

        // Sort all days by date for lookback
        let sortedDays = days.sorted { $0.startDate < $1.startDate }

        var examples: [TrainingExample] = []

        for (index, day) in sortedDays.enumerated() {
            // Only generate training examples from complete days
            guard let blendedScore = day.blendedEnergyScore else {
                continue
            }

            // Find the previous calendar day's metrics for lagging indicators
            let previousDayMetrics = await resolvePreviousDayMetrics(
                for: day,
                at: index,
                in: sortedDays,
                calendar: calendar
            )

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

    // MARK: - Previous-Day Resolution

    /// Resolves the previous calendar day's health metrics for use as lagging indicators.
    ///
    /// Checks for an existing Day record first (fast path), then falls back to
    /// fetching from HealthKit if no record exists for the previous calendar day.
    private func resolvePreviousDayMetrics(
        for day: Day,
        at index: Int,
        in sortedDays: [Day],
        calendar: Calendar
    ) async -> HealthMetrics? {
        guard let previousCalendarDay = calendar.date(byAdding: .day, value: -1, to: day.startDate) else {
            return nil
        }

        // Fast path: check if the previous entry in the array is the previous calendar day
        if index > 0 {
            let previousEntry = sortedDays[index - 1]
            if calendar.isDate(previousEntry.startDate, inSameDayAs: previousCalendarDay) {
                return previousEntry.healthMetrics
            }
        }

        // No Day record for previous calendar day — fetch from HealthKit
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: previousCalendarDay) else {
            return nil
        }

        return try? await healthKitService.fetchMetrics(from: previousCalendarDay, to: dayEnd)
    }
}
