//
//  PredictionService.swift
//  Pulse
//
//  Created by Devon Martin on 12/4/2025.
//

import Foundation

// MARK: - Protocol

/// Coordinates prediction creation, storage, and accuracy tracking.
///
/// This service orchestrates the prediction lifecycle:
/// 1. Generate prediction for tomorrow (via PredictionEngine)
/// 2. Store it in the repository
/// 3. When tomorrow arrives and user checks in, resolve the prediction
/// 4. Track accuracy over time
protocol PredictionServiceProtocol: Sendable {
    /// Creates and saves a new prediction for tomorrow.
    ///
    /// - Parameters:
    ///   - metrics: Today's health metrics
    ///   - energyLevel: Today's energy level (1-5)
    ///   - todayScore: Today's readiness score
    /// - Returns: The created prediction, or nil if insufficient data
    func createPrediction(
        metrics: HealthMetrics?,
        energyLevel: Int?,
        todayScore: Int?
    ) async throws -> Prediction?

    /// Gets today's prediction (made yesterday).
    func getTodaysPrediction() async throws -> Prediction?

    /// Resolves today's prediction with the actual readiness score.
    ///
    /// Called when the user completes their morning check-in,
    /// comparing the prediction to reality.
    func resolveTodaysPrediction(actualScore: Int) async throws

    /// Resolves any past predictions that have check-in data but weren't resolved.
    /// Useful for catching up after missed resolution windows.
    func resolveUnresolvedPredictions(using scores: [ReadinessScore]) async throws

    /// Gets prediction accuracy statistics.
    func getAccuracyStats() async throws -> PredictionAccuracyStats

    /// Gets recent predictions for display (both resolved and unresolved).
    func getRecentPredictions(days: Int) async throws -> [Prediction]
}

// MARK: - Implementation

/// Concrete implementation of PredictionService using repository and engine.
actor PredictionService: PredictionServiceProtocol {

    // MARK: - Dependencies

    private let engine: PredictionEngineProtocol
    private let repository: PredictionRepositoryProtocol

    // MARK: - Initialization

    init(engine: PredictionEngineProtocol, repository: PredictionRepositoryProtocol) {
        self.engine = engine
        self.repository = repository
    }

    // MARK: - Prediction Creation

    func createPrediction(
        metrics: HealthMetrics?,
        energyLevel: Int?,
        todayScore: Int?
    ) async throws -> Prediction? {
        // Generate prediction using the engine
        guard let prediction = engine.predictTomorrow(
            todayMetrics: metrics,
            todayEnergyLevel: energyLevel,
            todayScore: todayScore
        ) else {
            return nil
        }

        // Check if we already have a prediction for tomorrow
        let existing = try await repository.getPrediction(for: prediction.targetDate)
        if existing != nil {
            // Don't create duplicate predictions
            return existing
        }

        // Save to repository
        try await repository.save(prediction)

        return prediction
    }

    // MARK: - Prediction Retrieval

    func getTodaysPrediction() async throws -> Prediction? {
        return try await repository.getPrediction(for: Date())
    }

    func getRecentPredictions(days: Int) async throws -> [Prediction] {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days, to: Date())!
        return try await repository.getPredictions(from: startDate, to: Date())
    }

    // MARK: - Accuracy Tracking

    func resolveTodaysPrediction(actualScore: Int) async throws {
        // Get today's prediction
        guard let prediction = try await repository.getPrediction(for: Date()),
              !prediction.isResolved else {
            return // No prediction to resolve or already resolved
        }

        // Create resolved version
        let resolved = prediction.resolved(with: actualScore)

        // Update in repository
        try await repository.update(resolved)
    }

    func resolveUnresolvedPredictions(using scores: [ReadinessScore]) async throws {
        // Get all unresolved predictions
        let unresolved = try await repository.getUnresolvedPredictions()

        // Create a date -> score lookup
        let calendar = Calendar.current
        var scoresByDate: [Date: Int] = [:]
        for score in scores {
            let dateKey = calendar.startOfDay(for: score.date)
            scoresByDate[dateKey] = score.score
        }

        // Resolve each prediction that has a matching score
        for prediction in unresolved {
            let targetKey = calendar.startOfDay(for: prediction.targetDate)
            if let actualScore = scoresByDate[targetKey] {
                let resolved = prediction.resolved(with: actualScore)
                try await repository.update(resolved)
            }
        }
    }

    // MARK: - Statistics

    func getAccuracyStats() async throws -> PredictionAccuracyStats {
        return try await repository.getAccuracyStats()
    }
}

// MARK: - Mock Implementation

/// Mock prediction service for testing and previews.
actor MockPredictionService: PredictionServiceProtocol {
    var predictions: [Prediction] = []
    var createCallCount = 0
    var resolveCallCount = 0
    var shouldThrowError: Error?

    init(withSamplePredictions: Bool = false) {
        if withSamplePredictions {
            self.predictions = Self.generateSamplePredictions()
        }
    }

    func createPrediction(
        metrics: HealthMetrics?,
        energyLevel: Int?,
        todayScore: Int?
    ) async throws -> Prediction? {
        createCallCount += 1
        if let error = shouldThrowError { throw error }

        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!

        let prediction = Prediction(
            targetDate: tomorrow,
            predictedScore: todayScore ?? 70,
            confidence: .partial,
            source: .rules,
            inputMetrics: metrics,
            inputEnergyLevel: energyLevel
        )

        predictions.append(prediction)
        return prediction
    }

    func getTodaysPrediction() async throws -> Prediction? {
        if let error = shouldThrowError { throw error }
        let calendar = Calendar.current
        return predictions.first { calendar.isDateInToday($0.targetDate) }
    }

    func resolveTodaysPrediction(actualScore: Int) async throws {
        resolveCallCount += 1
        if let error = shouldThrowError { throw error }

        let calendar = Calendar.current
        if let index = predictions.firstIndex(where: { calendar.isDateInToday($0.targetDate) && !$0.isResolved }) {
            predictions[index] = predictions[index].resolved(with: actualScore)
        }
    }

    func resolveUnresolvedPredictions(using scores: [ReadinessScore]) async throws {
        if let error = shouldThrowError { throw error }
        // Simplified - just mark everything as resolved
    }

    func getAccuracyStats() async throws -> PredictionAccuracyStats {
        if let error = shouldThrowError { throw error }

        let resolved = predictions.filter { $0.isResolved }
        guard !resolved.isEmpty else {
            return PredictionAccuracyStats(
                totalPredictions: 0,
                averageError: 0,
                averageAccuracy: 0,
                excellentCount: 0,
                goodCount: 0,
                fairCount: 0,
                poorCount: 0,
                recentTrend: nil
            )
        }

        var totalError = 0
        var excellentCount = 0
        var goodCount = 0
        var fairCount = 0
        var poorCount = 0

        for prediction in resolved {
            guard let error = prediction.absoluteError else { continue }
            totalError += error

            switch error {
            case 0...5: excellentCount += 1
            case 6...10: goodCount += 1
            case 11...15: fairCount += 1
            default: poorCount += 1
            }
        }

        let averageError = Double(totalError) / Double(resolved.count)

        return PredictionAccuracyStats(
            totalPredictions: resolved.count,
            averageError: averageError,
            averageAccuracy: max(0, 100 - averageError),
            excellentCount: excellentCount,
            goodCount: goodCount,
            fairCount: fairCount,
            poorCount: poorCount,
            recentTrend: nil
        )
    }

    func getRecentPredictions(days: Int) async throws -> [Prediction] {
        if let error = shouldThrowError { throw error }
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days, to: Date())!
        return predictions
            .filter { $0.targetDate >= startDate }
            .sorted { $0.targetDate > $1.targetDate }
    }

    private static func generateSamplePredictions() -> [Prediction] {
        let calendar = Calendar.current
        let today = Date()

        return (1..<10).compactMap { daysAgo -> Prediction? in
            guard let targetDate = calendar.date(byAdding: .day, value: -daysAgo, to: today),
                  let createdAt = calendar.date(byAdding: .day, value: -daysAgo - 1, to: today) else {
                return nil
            }

            let predicted = Int.random(in: 55...85)
            let actual = predicted + Int.random(in: -12...12)

            return Prediction(
                createdAt: createdAt,
                targetDate: targetDate,
                predictedScore: predicted,
                confidence: [.full, .partial].randomElement()!,
                source: .rules,
                inputMetrics: HealthMetrics(
                    date: createdAt,
                    restingHeartRate: Double.random(in: 52...70),
                    hrv: Double.random(in: 30...70),
                    sleepDuration: TimeInterval.random(in: 5*3600...9*3600),
                    steps: Int.random(in: 4000...12000)
                ),
                inputEnergyLevel: Int.random(in: 2...5),
                actualScore: max(0, min(100, actual)),
                actualScoreRecordedAt: targetDate
            )
        }
    }
}
