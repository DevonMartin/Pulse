//
//  ReadinessScoreRepository.swift
//  Pulse
//
//  Created by Devon Martin on 12/4/2025.
//

import Foundation
import SwiftData

// MARK: - Protocol

/// Defines the interface for readiness score data operations.
///
/// The app layer interacts with this protocol, never with SwiftData directly.
/// This allows us to:
/// 1. Test without a real database
/// 2. Swap storage implementations without changing app code
/// 3. Keep persistence concerns isolated from business logic
protocol ReadinessScoreRepositoryProtocol: Sendable {
    /// Saves a readiness score, replacing any existing score for that day
    func save(_ score: ReadinessScore) async throws

    /// Retrieves the score for a specific date, if it exists
    func getScore(for date: Date) async throws -> ReadinessScore?

    /// Retrieves all scores within a date range, sorted by date descending
    func getScores(from startDate: Date, to endDate: Date) async throws -> [ReadinessScore]

    /// Retrieves the most recent scores (for trends display)
    func getRecentScores(limit: Int) async throws -> [ReadinessScore]

    /// Checks if a score exists for today
    func hasTodaysScore() async throws -> Bool
}

// MARK: - Implementation

/// SwiftData-backed implementation of ReadinessScoreRepository.
///
/// This class manages all database operations for readiness scores.
/// It's marked as @ModelActor which provides:
/// - A dedicated actor context for thread-safe database access
/// - Automatic ModelContext management
@ModelActor
actor ReadinessScoreRepository: ReadinessScoreRepositoryProtocol {

    // MARK: - ReadinessScoreRepositoryProtocol

    func save(_ score: ReadinessScore) async throws {
        // First, delete any existing score for the same day
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: score.date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = #Predicate<ReadinessScoreEntity> { entity in
            entity.date >= startOfDay && entity.date < endOfDay
        }

        let descriptor = FetchDescriptor<ReadinessScoreEntity>(predicate: predicate)
        let existing = try modelContext.fetch(descriptor)

        for entity in existing {
            modelContext.delete(entity)
        }

        // Insert the new score
        let entity = ReadinessScoreEntity(from: score)
        modelContext.insert(entity)

        try modelContext.save()
    }

    func getScore(for date: Date) async throws -> ReadinessScore? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = #Predicate<ReadinessScoreEntity> { entity in
            entity.date >= startOfDay && entity.date < endOfDay
        }

        var descriptor = FetchDescriptor<ReadinessScoreEntity>(predicate: predicate)
        descriptor.fetchLimit = 1

        let results = try modelContext.fetch(descriptor)
        return results.first?.toReadinessScore()
    }

    func getScores(from startDate: Date, to endDate: Date) async throws -> [ReadinessScore] {
        let predicate = #Predicate<ReadinessScoreEntity> { entity in
            entity.date >= startDate && entity.date <= endDate
        }

        let descriptor = FetchDescriptor<ReadinessScoreEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)
        return results.map { $0.toReadinessScore() }
    }

    func getRecentScores(limit: Int) async throws -> [ReadinessScore] {
        var descriptor = FetchDescriptor<ReadinessScoreEntity>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        let results = try modelContext.fetch(descriptor)
        return results.map { $0.toReadinessScore() }
    }

    func hasTodaysScore() async throws -> Bool {
        let score = try await getScore(for: Date())
        return score != nil
    }
}

// MARK: - Mock Implementation

/// A mock implementation for testing and SwiftUI previews.
actor MockReadinessScoreRepository: ReadinessScoreRepositoryProtocol {
    var scores: [ReadinessScore] = []
    var saveCallCount = 0
    var shouldThrowError: Error?

    /// Creates a mock repository, optionally pre-populated with sample data
    init(withSampleData: Bool = false) {
        if withSampleData {
            scores = Self.generateSampleScores()
        }
    }

    /// Generates sample historical scores for the past 14 days
    private static func generateSampleScores() -> [ReadinessScore] {
        let calendar = Calendar.current
        let today = Date()

        return (1..<14).compactMap { daysAgo -> ReadinessScore? in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else {
                return nil
            }

            // Create varied but realistic scores
            let baseScore = 65 + Int.random(in: -15...20)
            let score = max(30, min(95, baseScore))

            let hrvScore = score + Int.random(in: -10...10)
            let rhrScore = score + Int.random(in: -10...10)
            let sleepScore = score + Int.random(in: -15...15)
            let energyScore = score + Int.random(in: -10...10)

            let confidence: ReadinessConfidence = {
                let roll = Int.random(in: 1...10)
                if roll <= 6 { return .full }
                if roll <= 9 { return .partial }
                return .limited
            }()

            return ReadinessScore(
                date: date,
                score: score,
                breakdown: ReadinessBreakdown(
                    hrvScore: max(10, min(100, hrvScore)),
                    restingHeartRateScore: max(10, min(100, rhrScore)),
                    sleepScore: max(10, min(100, sleepScore)),
                    energyScore: max(20, min(100, energyScore))
                ),
                confidence: confidence
            )
        }
    }

    func save(_ score: ReadinessScore) async throws {
        saveCallCount += 1
        if let error = shouldThrowError {
            throw error
        }

        // Remove any existing score for the same day
        let calendar = Calendar.current
        scores.removeAll { calendar.isDate($0.date, inSameDayAs: score.date) }
        scores.append(score)
    }

    func getScore(for date: Date) async throws -> ReadinessScore? {
        if let error = shouldThrowError {
            throw error
        }
        let calendar = Calendar.current
        return scores.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func getScores(from startDate: Date, to endDate: Date) async throws -> [ReadinessScore] {
        if let error = shouldThrowError {
            throw error
        }
        return scores
            .filter { $0.date >= startDate && $0.date <= endDate }
            .sorted { $0.date > $1.date }
    }

    func getRecentScores(limit: Int) async throws -> [ReadinessScore] {
        if let error = shouldThrowError {
            throw error
        }
        return Array(scores.sorted { $0.date > $1.date }.prefix(limit))
    }

    func hasTodaysScore() async throws -> Bool {
        if let error = shouldThrowError {
            throw error
        }
        let calendar = Calendar.current
        return scores.contains { calendar.isDateInToday($0.date) }
    }

    // MARK: - Test Helpers

    func reset() {
        scores = []
        saveCallCount = 0
        shouldThrowError = nil
    }
}
