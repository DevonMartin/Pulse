//
//  PredictionRepository.swift
//  Pulse
//
//  Created by Devon Martin on 12/4/2025.
//

import Foundation
import SwiftData

// MARK: - Protocol

/// Defines the interface for prediction data operations.
///
/// The app layer interacts with this protocol, never with SwiftData directly.
/// This allows us to:
/// 1. Test without a real database
/// 2. Swap storage implementations without changing app code
/// 3. Keep persistence concerns isolated from business logic
protocol PredictionRepositoryProtocol: Sendable {
    /// Saves a new prediction
    func save(_ prediction: Prediction) async throws

    /// Updates an existing prediction (e.g., to add the actual score)
    func update(_ prediction: Prediction) async throws

    /// Retrieves the prediction for a specific target date, if it exists
    func getPrediction(for targetDate: Date) async throws -> Prediction?

    /// Retrieves all predictions within a date range (by target date)
    func getPredictions(from startDate: Date, to endDate: Date) async throws -> [Prediction]

    /// Retrieves only resolved predictions (those with actual scores) for accuracy analysis
    func getResolvedPredictions(limit: Int) async throws -> [Prediction]

    /// Retrieves unresolved predictions that need actual scores filled in
    func getUnresolvedPredictions() async throws -> [Prediction]

    /// Calculates overall prediction accuracy stats
    func getAccuracyStats() async throws -> PredictionAccuracyStats
}

/// Statistics about prediction accuracy over time
struct PredictionAccuracyStats: Sendable {
    /// Total number of resolved predictions
    let totalPredictions: Int

    /// Average absolute error (points)
    let averageError: Double

    /// Average accuracy percentage (0-100)
    let averageAccuracy: Double

    /// Predictions within 5 points
    let excellentCount: Int

    /// Predictions within 10 points
    let goodCount: Int

    /// Predictions within 15 points
    let fairCount: Int

    /// Predictions off by more than 15 points
    let poorCount: Int

    /// The trend in accuracy (positive = improving)
    let recentTrend: Double?

    /// Percentage of predictions that were excellent or good
    var successRate: Double {
        guard totalPredictions > 0 else { return 0 }
        return Double(excellentCount + goodCount) / Double(totalPredictions) * 100
    }
}

// MARK: - Implementation

/// SwiftData-backed implementation of PredictionRepository.
@ModelActor
actor PredictionRepository: PredictionRepositoryProtocol {

    func save(_ prediction: Prediction) async throws {
        let entity = PredictionEntity(from: prediction)
        modelContext.insert(entity)
        try modelContext.save()
    }

    func update(_ prediction: Prediction) async throws {
        let predictionId = prediction.id
        let predicate = #Predicate<PredictionEntity> { entity in
            entity.id == predictionId
        }

        let descriptor = FetchDescriptor<PredictionEntity>(predicate: predicate)
        let results = try modelContext.fetch(descriptor)

        if let entity = results.first {
            // Update the actual score fields
            entity.actualScore = prediction.actualScore
            entity.actualScoreRecordedAt = prediction.actualScoreRecordedAt
            try modelContext.save()
        }
    }

    func getPrediction(for targetDate: Date) async throws -> Prediction? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: targetDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = #Predicate<PredictionEntity> { entity in
            entity.targetDate >= startOfDay && entity.targetDate < endOfDay
        }

        var descriptor = FetchDescriptor<PredictionEntity>(predicate: predicate)
        descriptor.fetchLimit = 1

        let results = try modelContext.fetch(descriptor)
        return results.first?.toPrediction()
    }

    func getPredictions(from startDate: Date, to endDate: Date) async throws -> [Prediction] {
        let predicate = #Predicate<PredictionEntity> { entity in
            entity.targetDate >= startDate && entity.targetDate <= endDate
        }

        let descriptor = FetchDescriptor<PredictionEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.targetDate, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)
        return results.map { $0.toPrediction() }
    }

    func getResolvedPredictions(limit: Int) async throws -> [Prediction] {
        let predicate = #Predicate<PredictionEntity> { entity in
            entity.actualScore != nil
        }

        var descriptor = FetchDescriptor<PredictionEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.targetDate, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        let results = try modelContext.fetch(descriptor)
        return results.map { $0.toPrediction() }
    }

    func getUnresolvedPredictions() async throws -> [Prediction] {
        let now = Date()
        let predicate = #Predicate<PredictionEntity> { entity in
            entity.actualScore == nil && entity.targetDate < now
        }

        let descriptor = FetchDescriptor<PredictionEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.targetDate, order: .forward)]
        )

        let results = try modelContext.fetch(descriptor)
        return results.map { $0.toPrediction() }
    }

    func getAccuracyStats() async throws -> PredictionAccuracyStats {
        let predicate = #Predicate<PredictionEntity> { entity in
            entity.actualScore != nil
        }

        let descriptor = FetchDescriptor<PredictionEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.targetDate, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)
        let predictions = results.map { $0.toPrediction() }

        guard !predictions.isEmpty else {
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

        for prediction in predictions {
            guard let error = prediction.absoluteError else { continue }
            totalError += error

            switch error {
            case 0...5: excellentCount += 1
            case 6...10: goodCount += 1
            case 11...15: fairCount += 1
            default: poorCount += 1
            }
        }

        let averageError = Double(totalError) / Double(predictions.count)
        let averageAccuracy = max(0, 100 - averageError)

        // Calculate trend from recent vs older predictions
        let recentTrend: Double?
        if predictions.count >= 10 {
            let recentErrors = predictions.prefix(5).compactMap { $0.absoluteError }
            let olderErrors = predictions.dropFirst(5).prefix(5).compactMap { $0.absoluteError }

            if !recentErrors.isEmpty && !olderErrors.isEmpty {
                let recentAvg = Double(recentErrors.reduce(0, +)) / Double(recentErrors.count)
                let olderAvg = Double(olderErrors.reduce(0, +)) / Double(olderErrors.count)
                recentTrend = olderAvg - recentAvg // Positive = improving (lower error)
            } else {
                recentTrend = nil
            }
        } else {
            recentTrend = nil
        }

        return PredictionAccuracyStats(
            totalPredictions: predictions.count,
            averageError: averageError,
            averageAccuracy: averageAccuracy,
            excellentCount: excellentCount,
            goodCount: goodCount,
            fairCount: fairCount,
            poorCount: poorCount,
            recentTrend: recentTrend
        )
    }
}

// MARK: - Mock Implementation

/// A mock implementation for testing and SwiftUI previews.
actor MockPredictionRepository: PredictionRepositoryProtocol {
    var predictions: [Prediction] = []
    var saveCallCount = 0
    var shouldThrowError: Error?

    init(withSampleData: Bool = false) {
        if withSampleData {
            predictions = Self.generateSamplePredictions()
        }
    }

    private static func generateSamplePredictions() -> [Prediction] {
        let calendar = Calendar.current
        let today = Date()

        return (1..<14).compactMap { daysAgo -> Prediction? in
            guard let targetDate = calendar.date(byAdding: .day, value: -daysAgo, to: today),
                  let createdAt = calendar.date(byAdding: .day, value: -daysAgo - 1, to: today) else {
                return nil
            }

            let predicted = Int.random(in: 50...85)
            let actual = predicted + Int.random(in: -12...12)

            return Prediction(
                createdAt: createdAt,
                targetDate: targetDate,
                predictedScore: predicted,
                confidence: [.full, .partial].randomElement()!,
                source: .rules,
                inputMetrics: HealthMetrics(
                    date: createdAt,
                    restingHeartRate: Double.random(in: 52...72),
                    hrv: Double.random(in: 25...75),
                    sleepDuration: TimeInterval.random(in: 5*3600...9*3600),
                    steps: Int.random(in: 3000...15000)
                ),
                inputEnergyLevel: Int.random(in: 2...5),
                actualScore: max(0, min(100, actual)),
                actualScoreRecordedAt: targetDate
            )
        }
    }

    func save(_ prediction: Prediction) async throws {
        saveCallCount += 1
        if let error = shouldThrowError { throw error }
        predictions.append(prediction)
    }

    func update(_ prediction: Prediction) async throws {
        if let error = shouldThrowError { throw error }
        if let index = predictions.firstIndex(where: { $0.id == prediction.id }) {
            predictions[index] = prediction
        }
    }

    func getPrediction(for targetDate: Date) async throws -> Prediction? {
        if let error = shouldThrowError { throw error }
        let calendar = Calendar.current
        return predictions.first { calendar.isDate($0.targetDate, inSameDayAs: targetDate) }
    }

    func getPredictions(from startDate: Date, to endDate: Date) async throws -> [Prediction] {
        if let error = shouldThrowError { throw error }
        return predictions
            .filter { $0.targetDate >= startDate && $0.targetDate <= endDate }
            .sorted { $0.targetDate > $1.targetDate }
    }

    func getResolvedPredictions(limit: Int) async throws -> [Prediction] {
        if let error = shouldThrowError { throw error }
        return Array(predictions
            .filter { $0.isResolved }
            .sorted { $0.targetDate > $1.targetDate }
            .prefix(limit))
    }

    func getUnresolvedPredictions() async throws -> [Prediction] {
        if let error = shouldThrowError { throw error }
        return predictions
            .filter { !$0.isResolved && $0.targetDate < Date() }
            .sorted { $0.targetDate < $1.targetDate }
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

    // MARK: - Test Helpers

    func reset() {
        predictions = []
        saveCallCount = 0
        shouldThrowError = nil
    }
}
