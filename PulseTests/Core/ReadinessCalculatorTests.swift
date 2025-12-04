//
//  ReadinessCalculatorTests.swift
//  PulseTests
//
//  Created by Devon Martin on 12/4/2025.
//

import Testing
@testable import Pulse
import Foundation

/// Tests for the ReadinessCalculator service.
///
/// These tests verify:
/// 1. Individual component scoring (HRV, RHR, Sleep, Energy)
/// 2. Weighted score calculation
/// 3. Confidence determination
/// 4. Edge cases and missing data handling
@MainActor
struct ReadinessCalculatorTests {
    let calculator = ReadinessCalculator()

    // MARK: - Full Data Tests

    @Test func calculateWithAllMetricsReturnsFullConfidence() {
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: 65,
            hrv: 50,
            sleepDuration: 7.5 * 3600, // 7.5 hours
            steps: 8000,
            activeCalories: 400
        )

        let score = calculator.calculate(from: metrics, energyLevel: 4)

        #expect(score != nil)
        #expect(score?.confidence == .full)
    }

    @Test func calculateReturnsScoreInValidRange() {
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: 65,
            hrv: 50,
            sleepDuration: 7.5 * 3600,
            steps: 8000,
            activeCalories: 400
        )

        let score = calculator.calculate(from: metrics, energyLevel: 4)

        #expect(score != nil)
        #expect(score!.score >= 0)
        #expect(score!.score <= 100)
    }

    // MARK: - Partial Data Tests

    @Test func calculateWithTwoMetricsReturnsPartialConfidence() {
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: nil,
            hrv: 50,
            sleepDuration: 7 * 3600,
            steps: nil,
            activeCalories: nil
        )

        let score = calculator.calculate(from: metrics, energyLevel: nil)

        #expect(score != nil)
        #expect(score?.confidence == .partial)
        #expect(score?.breakdown.componentCount == 2)
    }

    @Test func calculateWithThreeMetricsReturnsPartialConfidence() {
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: 60,
            hrv: 55,
            sleepDuration: 8 * 3600,
            steps: nil,
            activeCalories: nil
        )

        let score = calculator.calculate(from: metrics, energyLevel: nil)

        #expect(score != nil)
        #expect(score?.confidence == .partial)
        #expect(score?.breakdown.componentCount == 3)
    }

    @Test func calculateWithOneMetricReturnsLimitedConfidence() {
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: nil,
            hrv: nil,
            sleepDuration: 7 * 3600,
            steps: nil,
            activeCalories: nil
        )

        let score = calculator.calculate(from: metrics, energyLevel: nil)

        #expect(score != nil)
        #expect(score?.confidence == .limited)
        #expect(score?.breakdown.componentCount == 1)
    }

    // MARK: - No Data Tests

    @Test func calculateWithNoDataReturnsNil() {
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: nil,
            hrv: nil,
            sleepDuration: nil,
            steps: nil,
            activeCalories: nil
        )

        let score = calculator.calculate(from: metrics, energyLevel: nil)

        #expect(score == nil)
    }

    @Test func calculateWithNilMetricsAndNoEnergyReturnsNil() {
        let score = calculator.calculate(from: nil, energyLevel: nil)
        #expect(score == nil)
    }

    @Test func calculateWithOnlyEnergyLevelReturnsScore() {
        let score = calculator.calculate(from: nil, energyLevel: 4)

        #expect(score != nil)
        #expect(score?.confidence == .limited)
        #expect(score?.breakdown.energyScore == 80) // Level 4 → 80
    }

    // MARK: - HRV Scoring Tests

    @Test func hrvScoreVeryLow() {
        let metrics = HealthMetrics(date: Date(), hrv: 15)
        let score = calculator.calculate(from: metrics, energyLevel: nil)

        #expect(score?.breakdown.hrvScore != nil)
        #expect(score!.breakdown.hrvScore! < 30) // Very low HRV = poor score
    }

    @Test func hrvScoreAverage() {
        let metrics = HealthMetrics(date: Date(), hrv: 50)
        let score = calculator.calculate(from: metrics, energyLevel: nil)

        #expect(score?.breakdown.hrvScore != nil)
        #expect(score!.breakdown.hrvScore! >= 50)
        #expect(score!.breakdown.hrvScore! <= 70)
    }

    @Test func hrvScoreExcellent() {
        let metrics = HealthMetrics(date: Date(), hrv: 80)
        let score = calculator.calculate(from: metrics, energyLevel: nil)

        #expect(score?.breakdown.hrvScore != nil)
        #expect(score!.breakdown.hrvScore! >= 75)
    }

    // MARK: - Resting Heart Rate Scoring Tests

    @Test func rhrScoreHigh() {
        let metrics = HealthMetrics(date: Date(), restingHeartRate: 95)
        let score = calculator.calculate(from: metrics, energyLevel: nil)

        #expect(score?.breakdown.restingHeartRateScore != nil)
        #expect(score!.breakdown.restingHeartRateScore! < 30) // High RHR = poor score
    }

    @Test func rhrScoreAverage() {
        let metrics = HealthMetrics(date: Date(), restingHeartRate: 72)
        let score = calculator.calculate(from: metrics, energyLevel: nil)

        #expect(score?.breakdown.restingHeartRateScore != nil)
        #expect(score!.breakdown.restingHeartRateScore! >= 50)
        #expect(score!.breakdown.restingHeartRateScore! <= 70)
    }

    @Test func rhrScoreExcellent() {
        let metrics = HealthMetrics(date: Date(), restingHeartRate: 55)
        let score = calculator.calculate(from: metrics, energyLevel: nil)

        #expect(score?.breakdown.restingHeartRateScore != nil)
        #expect(score!.breakdown.restingHeartRateScore! >= 80)
    }

    @Test func rhrScoreVeryLowCappedForSafety() {
        // Very low RHR (<40) might indicate issues, cap the score
        let metrics = HealthMetrics(date: Date(), restingHeartRate: 35)
        let score = calculator.calculate(from: metrics, energyLevel: nil)

        #expect(score?.breakdown.restingHeartRateScore != nil)
        #expect(score!.breakdown.restingHeartRateScore! <= 90) // Should be capped
    }

    // MARK: - Sleep Scoring Tests

    @Test func sleepScoreTooLittle() {
        let metrics = HealthMetrics(date: Date(), sleepDuration: 4 * 3600) // 4 hours
        let score = calculator.calculate(from: metrics, energyLevel: nil)

        #expect(score?.breakdown.sleepScore != nil)
        #expect(score!.breakdown.sleepScore! < 40)
    }

    @Test func sleepScoreOptimal() {
        let metrics = HealthMetrics(date: Date(), sleepDuration: 8 * 3600) // 8 hours
        let score = calculator.calculate(from: metrics, energyLevel: nil)

        #expect(score?.breakdown.sleepScore != nil)
        #expect(score!.breakdown.sleepScore! >= 95)
    }

    @Test func sleepScoreTooMuch() {
        let metrics = HealthMetrics(date: Date(), sleepDuration: 11 * 3600) // 11 hours
        let score = calculator.calculate(from: metrics, energyLevel: nil)

        #expect(score?.breakdown.sleepScore != nil)
        #expect(score!.breakdown.sleepScore! < 90) // Oversleeping penalized slightly
        #expect(score!.breakdown.sleepScore! >= 70) // But not too harshly
    }

    // MARK: - Energy Level Scoring Tests

    @Test func energyScoreMapsCorrectly() {
        // Test all energy levels map to expected scores
        let expectedScores = [
            (1, 20),
            (2, 40),
            (3, 60),
            (4, 80),
            (5, 100)
        ]

        for (level, expectedScore) in expectedScores {
            let score = calculator.calculate(from: nil, energyLevel: level)
            #expect(score?.breakdown.energyScore == expectedScore,
                   "Energy level \(level) should map to \(expectedScore)")
        }
    }

    @Test func energyScoreClampsInvalidValues() {
        // Test that out-of-range values are clamped
        let scoreLow = calculator.calculate(from: nil, energyLevel: 0)
        #expect(scoreLow?.breakdown.energyScore == 20) // Clamped to 1 → 20

        let scoreHigh = calculator.calculate(from: nil, energyLevel: 10)
        #expect(scoreHigh?.breakdown.energyScore == 100) // Clamped to 5 → 100
    }

    // MARK: - Weight Redistribution Tests

    @Test func weightsRedistributeWithMissingData() {
        // With only HRV and Sleep (each 30% and 25% normally)
        // The score should be based only on those two, normalized
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: nil,
            hrv: 50, // ~60 score
            sleepDuration: 8 * 3600, // ~95 score
            steps: nil,
            activeCalories: nil
        )

        let score = calculator.calculate(from: metrics, energyLevel: nil)

        #expect(score != nil)
        // Weighted average of ~60 (30%) and ~95 (25%) normalized
        // = (60*0.30 + 95*0.25) / (0.30 + 0.25) = (18 + 23.75) / 0.55 = 75.9
        #expect(score!.score >= 70)
        #expect(score!.score <= 85)
    }

    // MARK: - Breakdown Population Tests

    @Test func breakdownContainsOnlyAvailableComponents() {
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: 65,
            hrv: nil,
            sleepDuration: 7 * 3600,
            steps: nil,
            activeCalories: nil
        )

        let score = calculator.calculate(from: metrics, energyLevel: 3)

        #expect(score?.breakdown.hrvScore == nil)
        #expect(score?.breakdown.restingHeartRateScore != nil)
        #expect(score?.breakdown.sleepScore != nil)
        #expect(score?.breakdown.energyScore != nil)
        #expect(score?.breakdown.componentCount == 3)
    }

    // MARK: - Input Preservation Tests

    @Test func scorePreservesHealthMetrics() {
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: 65,
            hrv: 50,
            sleepDuration: 7 * 3600,
            steps: 10000,
            activeCalories: 500
        )

        let score = calculator.calculate(from: metrics, energyLevel: 4)

        #expect(score?.healthMetrics == metrics)
    }

    @Test func scorePreservesEnergyLevel() {
        let score = calculator.calculate(from: nil, energyLevel: 3)

        #expect(score?.userEnergyLevel == 3)
    }

    @Test func scoreUsesMetricsDate() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let metrics = HealthMetrics(date: yesterday, hrv: 50)

        let score = calculator.calculate(from: metrics, energyLevel: nil)

        #expect(score?.date == yesterday)
    }
}
