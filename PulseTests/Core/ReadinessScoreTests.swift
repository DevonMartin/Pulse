//
//  ReadinessScoreTests.swift
//  PulseTests
//
//  Created by Devon Martin on 12/4/2025.
//

import Testing
@testable import Pulse
import Foundation

/// Tests for the ReadinessScore domain model.
@MainActor
struct ReadinessScoreTests {

    // MARK: - Initialization Tests

    @Test func initializationClampsScoreToValidRange() {
        let breakdown = ReadinessBreakdown(
            hrvScore: 50,
            restingHeartRateScore: 50,
            sleepScore: 50,
            energyScore: 50
        )

        let scoreTooHigh = ReadinessScore(
            score: 150,
            breakdown: breakdown,
            confidence: .full
        )
        #expect(scoreTooHigh.score == 100)

        let scoreTooLow = ReadinessScore(
            score: -50,
            breakdown: breakdown,
            confidence: .full
        )
        #expect(scoreTooLow.score == 0)
    }

    @Test func initializationGeneratesUniqueID() {
        let breakdown = ReadinessBreakdown(
            hrvScore: 50,
            restingHeartRateScore: nil,
            sleepScore: nil,
            energyScore: nil
        )

        let score1 = ReadinessScore(score: 50, breakdown: breakdown, confidence: .limited)
        let score2 = ReadinessScore(score: 50, breakdown: breakdown, confidence: .limited)

        #expect(score1.id != score2.id)
    }

    @Test func initializationPreservesAllProperties() {
        let date = Date()
        let id = UUID()
        let metrics = HealthMetrics(date: date, hrv: 50)
        let breakdown = ReadinessBreakdown(
            hrvScore: 60,
            restingHeartRateScore: 70,
            sleepScore: 80,
            energyScore: 90
        )

        let score = ReadinessScore(
            id: id,
            date: date,
            score: 75,
            breakdown: breakdown,
            confidence: .full,
            healthMetrics: metrics,
            userEnergyLevel: 4
        )

        #expect(score.id == id)
        #expect(score.date == date)
        #expect(score.score == 75)
        #expect(score.confidence == .full)
        #expect(score.healthMetrics == metrics)
        #expect(score.userEnergyLevel == 4)
    }

    // MARK: - Score Description Tests

    @Test func scoreDescriptionPoor() {
        let breakdown = ReadinessBreakdown(hrvScore: 20, restingHeartRateScore: nil, sleepScore: nil, energyScore: nil)

        let scores = [0, 20, 40]
        for value in scores {
            let score = ReadinessScore(score: value, breakdown: breakdown, confidence: .limited)
            #expect(score.scoreDescription == "Poor", "Score \(value) should be Poor")
        }
    }

    @Test func scoreDescriptionModerate() {
        let breakdown = ReadinessBreakdown(hrvScore: 50, restingHeartRateScore: nil, sleepScore: nil, energyScore: nil)

        let scores = [41, 50, 60]
        for value in scores {
            let score = ReadinessScore(score: value, breakdown: breakdown, confidence: .limited)
            #expect(score.scoreDescription == "Moderate", "Score \(value) should be Moderate")
        }
    }

    @Test func scoreDescriptionGood() {
        let breakdown = ReadinessBreakdown(hrvScore: 70, restingHeartRateScore: nil, sleepScore: nil, energyScore: nil)

        let scores = [61, 70, 80]
        for value in scores {
            let score = ReadinessScore(score: value, breakdown: breakdown, confidence: .limited)
            #expect(score.scoreDescription == "Good", "Score \(value) should be Good")
        }
    }

    @Test func scoreDescriptionExcellent() {
        let breakdown = ReadinessBreakdown(hrvScore: 90, restingHeartRateScore: nil, sleepScore: nil, energyScore: nil)

        let scores = [81, 90, 100]
        for value in scores {
            let score = ReadinessScore(score: value, breakdown: breakdown, confidence: .limited)
            #expect(score.scoreDescription == "Excellent", "Score \(value) should be Excellent")
        }
    }

    // MARK: - Recommendation Tests

    @Test func recommendationForPoorScore() {
        let breakdown = ReadinessBreakdown(hrvScore: 20, restingHeartRateScore: nil, sleepScore: nil, energyScore: nil)
        let score = ReadinessScore(score: 30, breakdown: breakdown, confidence: .limited)

        #expect(score.recommendation.contains("rest") || score.recommendation.contains("recovery"))
    }

    @Test func recommendationForExcellentScore() {
        let breakdown = ReadinessBreakdown(hrvScore: 95, restingHeartRateScore: nil, sleepScore: nil, energyScore: nil)
        let score = ReadinessScore(score: 90, breakdown: breakdown, confidence: .limited)

        #expect(score.recommendation.contains("best today"))
    }

    // MARK: - isToday Tests

    @Test func isTodayReturnsTrueForToday() {
        let breakdown = ReadinessBreakdown(hrvScore: 50, restingHeartRateScore: nil, sleepScore: nil, energyScore: nil)
        let score = ReadinessScore(date: Date(), score: 50, breakdown: breakdown, confidence: .limited)

        #expect(score.isToday == true)
    }

    @Test func isTodayReturnsFalseForYesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let breakdown = ReadinessBreakdown(hrvScore: 50, restingHeartRateScore: nil, sleepScore: nil, energyScore: nil)
        let score = ReadinessScore(date: yesterday, score: 50, breakdown: breakdown, confidence: .limited)

        #expect(score.isToday == false)
    }

    // MARK: - Equatable Tests

    @Test func scoresWithSameValuesAreEqual() {
        let date = Date()
        let id = UUID()
        let breakdown = ReadinessBreakdown(hrvScore: 50, restingHeartRateScore: 60, sleepScore: 70, energyScore: 80)

        let score1 = ReadinessScore(id: id, date: date, score: 65, breakdown: breakdown, confidence: .full)
        let score2 = ReadinessScore(id: id, date: date, score: 65, breakdown: breakdown, confidence: .full)

        #expect(score1 == score2)
    }

    @Test func scoresWithDifferentIDsAreNotEqual() {
        let date = Date()
        let breakdown = ReadinessBreakdown(hrvScore: 50, restingHeartRateScore: 60, sleepScore: 70, energyScore: 80)

        let score1 = ReadinessScore(id: UUID(), date: date, score: 65, breakdown: breakdown, confidence: .full)
        let score2 = ReadinessScore(id: UUID(), date: date, score: 65, breakdown: breakdown, confidence: .full)

        #expect(score1 != score2)
    }
}

// MARK: - ReadinessBreakdown Tests

@MainActor
struct ReadinessBreakdownTests {

    // MARK: - Component Count Tests

    @Test func componentCountWithAllComponents() {
        let breakdown = ReadinessBreakdown(
            hrvScore: 50,
            restingHeartRateScore: 60,
            sleepScore: 70,
            energyScore: 80
        )

        #expect(breakdown.componentCount == 4)
    }

    @Test func componentCountWithNoComponents() {
        let breakdown = ReadinessBreakdown(
            hrvScore: nil,
            restingHeartRateScore: nil,
            sleepScore: nil,
            energyScore: nil
        )

        #expect(breakdown.componentCount == 0)
    }

    @Test func componentCountWithSomeComponents() {
        let breakdown = ReadinessBreakdown(
            hrvScore: 50,
            restingHeartRateScore: nil,
            sleepScore: 70,
            energyScore: nil
        )

        #expect(breakdown.componentCount == 2)
    }

    // MARK: - Available Components Tests

    @Test func availableComponentsReturnsCorrectList() {
        let breakdown = ReadinessBreakdown(
            hrvScore: 50,
            restingHeartRateScore: nil,
            sleepScore: 70,
            energyScore: nil
        )

        let available = breakdown.availableComponents
        #expect(available.contains(.hrv))
        #expect(!available.contains(.restingHeartRate))
        #expect(available.contains(.sleep))
        #expect(!available.contains(.energy))
    }

    // MARK: - Component Scores Dictionary Tests

    @Test func componentScoresReturnsOnlyAvailableScores() {
        let breakdown = ReadinessBreakdown(
            hrvScore: 50,
            restingHeartRateScore: nil,
            sleepScore: 70,
            energyScore: 80
        )

        let scores = breakdown.componentScores

        #expect(scores[.hrv] == 50)
        #expect(scores[.restingHeartRate] == nil)
        #expect(scores[.sleep] == 70)
        #expect(scores[.energy] == 80)
        #expect(scores.count == 3)
    }

    // MARK: - Weights Tests

    @Test func weightsAreDefined() {
        let weights = ReadinessBreakdown.weights

        #expect(weights[.hrv] != nil)
        #expect(weights[.restingHeartRate] != nil)
        #expect(weights[.sleep] != nil)
        #expect(weights[.energy] != nil)
    }

    @Test func weightsSumToOne() {
        let weights = ReadinessBreakdown.weights
        let total = weights.values.reduce(0, +)

        #expect(total == 1.0)
    }

    // MARK: - Equatable Tests

    @Test func breakdownsWithSameValuesAreEqual() {
        let breakdown1 = ReadinessBreakdown(hrvScore: 50, restingHeartRateScore: 60, sleepScore: 70, energyScore: 80)
        let breakdown2 = ReadinessBreakdown(hrvScore: 50, restingHeartRateScore: 60, sleepScore: 70, energyScore: 80)

        #expect(breakdown1 == breakdown2)
    }

    @Test func breakdownsWithDifferentValuesAreNotEqual() {
        let breakdown1 = ReadinessBreakdown(hrvScore: 50, restingHeartRateScore: 60, sleepScore: 70, energyScore: 80)
        let breakdown2 = ReadinessBreakdown(hrvScore: 51, restingHeartRateScore: 60, sleepScore: 70, energyScore: 80)

        #expect(breakdown1 != breakdown2)
    }

    // MARK: - Description Tests

    @Test func descriptionIncludesAvailableComponents() {
        let breakdown = ReadinessBreakdown(
            hrvScore: 50,
            restingHeartRateScore: nil,
            sleepScore: 70,
            energyScore: nil
        )

        let description = breakdown.description

        #expect(description.contains("HRV: 50"))
        #expect(description.contains("Sleep: 70"))
        #expect(!description.contains("RHR"))
        #expect(!description.contains("Energy"))
    }
}

// MARK: - ReadinessConfidence Tests

@MainActor
struct ReadinessConfidenceTests {

    @Test func confidenceRawValues() {
        #expect(ReadinessConfidence.full.rawValue == "full")
        #expect(ReadinessConfidence.partial.rawValue == "partial")
        #expect(ReadinessConfidence.limited.rawValue == "limited")
    }

    @Test func confidenceIsCodable() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for confidence in [ReadinessConfidence.full, .partial, .limited] {
            let data = try encoder.encode(confidence)
            let decoded = try decoder.decode(ReadinessConfidence.self, from: data)
            #expect(decoded == confidence)
        }
    }
}
