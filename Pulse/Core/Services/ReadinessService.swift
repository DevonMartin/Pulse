//
//  ReadinessService.swift
//  Pulse
//
//  Created by Devon Martin on 12/6/2025.
//

import Foundation

// MARK: - Protocol

/// Defines the interface for the readiness calculation service.
///
/// This service blends rules-based and ML-based scoring to provide
/// personalized readiness scores that improve over time.
protocol ReadinessServiceProtocol: Sendable {
    /// Calculates a readiness score, blending rules and ML.
    ///
    /// - Parameters:
    ///   - metrics: Health data from HealthKit
    ///   - energyLevel: User's subjective energy rating (1-5)
    /// - Returns: A ReadinessScore with breakdown and confidence
    func calculate(from metrics: HealthMetrics?, energyLevel: Int?) async -> ReadinessScore?

    /// Triggers model retraining with the latest data.
    ///
    /// - Parameter checkIns: All historical check-ins
    /// - Parameter healthKitService: Service to fetch metrics
    func retrain(with checkIns: [CheckIn], healthKitService: HealthKitServiceProtocol) async

    /// Returns the current ML blend weight (0-1).
    var mlWeight: Double { get async }

    /// Returns how many training examples the model has.
    var trainingExampleCount: Int { get async }
}

// MARK: - Implementation

/// Service that blends rules-based and ML-based readiness scoring.
///
/// ## Blending Strategy
/// The final score is a weighted blend:
/// ```
/// score = (rulesScore * (1 - mlWeight)) + (mlScore * mlWeight)
/// ```
///
/// Where `mlWeight` increases linearly over `transitionDays` (default 30) based on
/// completed training examples:
/// - 0 examples (Day 1): 0% ML, 100% rules
/// - 50% of transitionDays: 50% ML, 50% rules
/// - transitionDays+ examples: 100% ML
///
/// ## Fallback Behavior
/// If the ML model fails or returns nil:
/// - Falls back to 100% rules-based scoring
/// - This ensures the user always gets a score
///
/// ## Training
/// The model is automatically retrained when:
/// - New check-in data becomes available
/// - Called explicitly via `retrain(with:healthKitService:)`
actor ReadinessService: ReadinessServiceProtocol {

    // MARK: - Dependencies

    /// Rules-based calculator (always available as fallback)
    private let rulesCalculator: ReadinessCalculatorProtocol

    /// ML model for personalized scoring
    private let mlModel: PersonalizedReadinessModel

    /// Training data collector
    private let trainingDataCollector: TrainingDataCollector

    // MARK: - State

    /// Number of days of data the user has (for blend calculation)
    private var daysOfData: Int = 0

    /// Days over which to transition from rules to ML
    private let transitionDays: Int

    // MARK: - Initialization

    init(
        rulesCalculator: ReadinessCalculatorProtocol = ReadinessCalculator(),
        mlModel: PersonalizedReadinessModel = PersonalizedReadinessModel(),
        trainingDataCollector: TrainingDataCollector = TrainingDataCollector(),
        transitionDays: Int = 30
    ) {
        self.rulesCalculator = rulesCalculator
        self.mlModel = mlModel
        self.trainingDataCollector = trainingDataCollector
        self.transitionDays = transitionDays
    }

    /// Loads any saved ML model from disk.
    func loadSavedModel() async {
        await mlModel.loadSavedModel()
    }

    // MARK: - ReadinessServiceProtocol

    func calculate(from metrics: HealthMetrics?, energyLevel: Int?) async -> ReadinessScore? {
        // Always calculate rules-based score as baseline/fallback
        guard let rulesScore = rulesCalculator.calculate(from: metrics, energyLevel: energyLevel) else {
            return nil
        }

        // Try to get ML prediction
        let mlPrediction = await mlModel.predict(from: metrics)

        // Calculate blend weight based on days of data
        let weight = mlWeight

        // Blend the scores
        let finalScore: Int
        switch mlPrediction {
        case .success(let mlScore):
            // Blend rules and ML
            let blended = Double(rulesScore.score) * (1 - weight) + Double(mlScore) * weight
            finalScore = Int(round(blended))
        case .modelNotTrained, .insufficientData, .error:
            // Fall back to rules
            finalScore = rulesScore.score
        }

        // Return score with updated value but same breakdown
        return ReadinessScore(
            date: rulesScore.date,
            score: finalScore,
            breakdown: rulesScore.breakdown,
            confidence: rulesScore.confidence,
            healthMetrics: metrics,
            userEnergyLevel: energyLevel
        )
    }

    func retrain(with checkIns: [CheckIn], healthKitService: HealthKitServiceProtocol) async {
        // Get current example count to determine normalization strategy
        let currentCount = await mlModel.trainingExampleCount

        // Collect training data with appropriate normalization
        let examples = await trainingDataCollector.collectTrainingData(
            from: checkIns,
            healthKitService: healthKitService,
            currentExampleCount: currentCount
        )

        // Update days of data count
        daysOfData = examples.count

        // Train the model
        await mlModel.train(on: examples)
    }

    var mlWeight: Double {
        // Linear transition from 0 to 1 over transitionDays
        // 0 examples: 0% ML, 30+ examples: 100% ML
        // This correctly gives 0% on day 1 (no completed training examples yet)
        let weight = Double(min(daysOfData, transitionDays)) / Double(transitionDays)
        return weight
    }

    var trainingExampleCount: Int {
        get async {
            await mlModel.trainingExampleCount
        }
    }

    /// Returns how many complete days of data we have (for UI progress display).
    ///
    /// This differs from `trainingExampleCount` in that it counts days even before
    /// the minimum threshold for training is reached. Useful for showing progress
    /// like "2/30 days" to users.
    var completeDaysCount: Int {
        daysOfData
    }

    /// Updates the count of days with data (for testing or manual override).
    func setDaysOfData(_ days: Int) {
        daysOfData = days
    }
}

// MARK: - Mock Implementation

/// Mock service for testing and previews.
actor MockReadinessService: ReadinessServiceProtocol {
    var mockScore: ReadinessScore?
    var mockMLWeight: Double = 0.0
    var mockExampleCount: Int = 0

    func calculate(from metrics: HealthMetrics?, energyLevel: Int?) async -> ReadinessScore? {
        if let mock = mockScore {
            return mock
        }

        // Return a default score
        return ReadinessScore(
            score: 75,
            breakdown: ReadinessBreakdown(
                hrvScore: 70,
                restingHeartRateScore: 75,
                sleepScore: 80,
                energyScore: 80
            ),
            confidence: .full
        )
    }

    func retrain(with checkIns: [CheckIn], healthKitService: HealthKitServiceProtocol) async {
        mockExampleCount = checkIns.count / 2  // Assume half have both AM/PM
    }

    var mlWeight: Double {
        mockMLWeight
    }

    var trainingExampleCount: Int {
        mockExampleCount
    }
}
