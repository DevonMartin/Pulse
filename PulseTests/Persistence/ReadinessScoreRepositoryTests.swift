//
//  ReadinessScoreRepositoryTests.swift
//  PulseTests
//
//  Created by Devon Martin on 12/4/2025.
//

import Testing
@testable import Pulse
import Foundation

/// Tests for the MockReadinessScoreRepository.
///
/// These tests verify the mock implementation works correctly for testing
/// and SwiftUI previews. The real repository tests would require a SwiftData
/// container setup.
@MainActor
struct ReadinessScoreRepositoryTests {

    // MARK: - Test Helpers

    private func makeScore(
        date: Date = Date(),
        score: Int = 75,
        confidence: ReadinessConfidence = .full
    ) -> ReadinessScore {
        ReadinessScore(
            date: date,
            score: score,
            breakdown: ReadinessBreakdown(
                hrvScore: 70,
                restingHeartRateScore: 75,
                sleepScore: 80,
                energyScore: 75
            ),
            confidence: confidence
        )
    }

    // MARK: - Save Tests

    @Test func saveStoresScore() async throws {
        let repository = MockReadinessScoreRepository()
        let score = makeScore()

        try await repository.save(score)

        let retrieved = try await repository.getScore(for: score.date)
        #expect(retrieved != nil)
        #expect(retrieved?.score == score.score)
    }

    @Test func saveReplacesExistingScoreForSameDay() async throws {
        let repository = MockReadinessScoreRepository()
        let today = Date()

        let firstScore = makeScore(date: today, score: 60)
        try await repository.save(firstScore)

        let secondScore = makeScore(date: today, score: 80)
        try await repository.save(secondScore)

        let scores = await repository.scores
        #expect(scores.count == 1)
        #expect(scores.first?.score == 80)
    }

    @Test func saveIncrementsSaveCallCount() async throws {
        let repository = MockReadinessScoreRepository()

        try await repository.save(makeScore())
        try await repository.save(makeScore())

        let count = await repository.saveCallCount
        #expect(count == 2)
    }

    @Test func saveThrowsWhenConfigured() async throws {
        let repository = MockReadinessScoreRepository()
        await repository.setShouldThrowError(TestError.mockError)

        do {
            try await repository.save(makeScore())
            Issue.record("Expected error to be thrown")
        } catch {
            #expect(error is TestError)
        }
    }

    // MARK: - Get Score Tests

    @Test func getScoreReturnsNilWhenEmpty() async throws {
        let repository = MockReadinessScoreRepository()

        let score = try await repository.getScore(for: Date())

        #expect(score == nil)
    }

    @Test func getScoreFindsCorrectDate() async throws {
        let repository = MockReadinessScoreRepository()
        let calendar = Calendar.current

        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        try await repository.save(makeScore(date: today, score: 80))
        try await repository.save(makeScore(date: yesterday, score: 60))

        let todayScore = try await repository.getScore(for: today)
        let yesterdayScore = try await repository.getScore(for: yesterday)

        #expect(todayScore?.score == 80)
        #expect(yesterdayScore?.score == 60)
    }

    // MARK: - Get Scores Range Tests

    @Test func getScoresReturnsEmptyWhenNoData() async throws {
        let repository = MockReadinessScoreRepository()
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!

        let scores = try await repository.getScores(from: weekAgo, to: Date())

        #expect(scores.isEmpty)
    }

    @Test func getScoresFiltersToDateRange() async throws {
        let repository = MockReadinessScoreRepository()
        let calendar = Calendar.current
        let today = Date()

        // Add scores for different days
        for daysAgo in 0..<10 {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            try await repository.save(makeScore(date: date, score: 70 + daysAgo))
        }

        // Query for last 5 days
        let fiveDaysAgo = calendar.date(byAdding: .day, value: -4, to: today)!
        let scores = try await repository.getScores(from: fiveDaysAgo, to: today)

        #expect(scores.count == 5)
    }

    @Test func getScoresReturnsSortedByDateDescending() async throws {
        let repository = MockReadinessScoreRepository()
        let calendar = Calendar.current
        let today = Date()

        // Add scores out of order
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        try await repository.save(makeScore(date: twoDaysAgo, score: 60))
        try await repository.save(makeScore(date: today, score: 80))
        try await repository.save(makeScore(date: yesterday, score: 70))

        let scores = try await repository.getScores(from: twoDaysAgo, to: today)

        #expect(scores.count == 3)
        #expect(scores[0].score == 80) // Today
        #expect(scores[1].score == 70) // Yesterday
        #expect(scores[2].score == 60) // Two days ago
    }

    // MARK: - Get Recent Scores Tests

    @Test func getRecentScoresRespectsLimit() async throws {
        let repository = MockReadinessScoreRepository()
        let calendar = Calendar.current
        let today = Date()

        // Add 10 scores
        for daysAgo in 0..<10 {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            try await repository.save(makeScore(date: date, score: 70 + daysAgo))
        }

        let scores = try await repository.getRecentScores(limit: 5)

        #expect(scores.count == 5)
    }

    @Test func getRecentScoresReturnsSortedByDateDescending() async throws {
        let repository = MockReadinessScoreRepository()
        let calendar = Calendar.current
        let today = Date()

        // Add scores
        for daysAgo in 0..<5 {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            try await repository.save(makeScore(date: date, score: 100 - daysAgo * 10))
        }

        let scores = try await repository.getRecentScores(limit: 5)

        #expect(scores[0].score == 100) // Most recent (today)
        #expect(scores[4].score == 60)  // Oldest
    }

    // MARK: - Has Today's Score Tests

    @Test func hasTodaysScoreReturnsFalseWhenEmpty() async throws {
        let repository = MockReadinessScoreRepository()

        let hasScore = try await repository.hasTodaysScore()

        #expect(hasScore == false)
    }

    @Test func hasTodaysScoreReturnsTrueWhenExists() async throws {
        let repository = MockReadinessScoreRepository()
        try await repository.save(makeScore(date: Date()))

        let hasScore = try await repository.hasTodaysScore()

        #expect(hasScore == true)
    }

    @Test func hasTodaysScoreReturnsFalseForYesterdayOnly() async throws {
        let repository = MockReadinessScoreRepository()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        try await repository.save(makeScore(date: yesterday))

        let hasScore = try await repository.hasTodaysScore()

        #expect(hasScore == false)
    }

    // MARK: - Reset Tests

    @Test func resetClearsAllData() async throws {
        let repository = MockReadinessScoreRepository()

        try await repository.save(makeScore())
        try await repository.save(makeScore())

        await repository.reset()

        let scores = await repository.scores
        let count = await repository.saveCallCount

        #expect(scores.isEmpty)
        #expect(count == 0)
    }
}

// MARK: - Test Error

private enum TestError: Error {
    case mockError
}

// MARK: - Mock Helper Extensions

extension MockReadinessScoreRepository {
    func setShouldThrowError(_ error: Error?) async {
        shouldThrowError = error
    }
}
