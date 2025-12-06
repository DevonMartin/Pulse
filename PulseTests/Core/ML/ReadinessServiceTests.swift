//
//  ReadinessServiceTests.swift
//  PulseTests
//
//  Created by Devon Martin on 12/6/2025.
//

import Testing
@testable import Pulse
import Foundation

/// Tests for the ReadinessService.
///
/// Verifies:
/// 1. Score blending between rules and ML
/// 2. ML weight progression over days
/// 3. Fallback to rules when ML fails
/// 4. Retraining behavior
@MainActor
struct ReadinessServiceTests {

    // MARK: - ML Weight Tests

    @Test func mlWeightIsZeroWithNoData() async {
        let service = ReadinessService()

        let weight = await service.mlWeight

        #expect(weight == 0.0)
    }

    @Test func mlWeightIncreasesWithData() async {
        let service = ReadinessService()

        await service.setDaysOfData(15)
        let weight = await service.mlWeight

        #expect(weight == 0.5) // 15/30 = 50%
    }

    @Test func mlWeightCapsAtOne() async {
        let service = ReadinessService()

        await service.setDaysOfData(50) // More than 30
        let weight = await service.mlWeight

        #expect(weight == 1.0)
    }

    @Test func mlWeightAt30DaysIsOne() async {
        let service = ReadinessService()

        await service.setDaysOfData(30)
        let weight = await service.mlWeight

        #expect(weight == 1.0)
    }

    // MARK: - Calculate Tests

    @Test func calculateReturnsScoreWithMetrics() async {
        let service = ReadinessService()
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: 60,
            hrv: 50,
            sleepDuration: 8 * 3600
        )

        let score = await service.calculate(from: metrics, energyLevel: 4)

        #expect(score != nil)
        #expect(score!.score >= 0)
        #expect(score!.score <= 100)
    }

    @Test func calculateReturnsNilWithNoData() async {
        let service = ReadinessService()

        let score = await service.calculate(from: nil, energyLevel: nil)

        #expect(score == nil)
    }

    @Test func calculateFallsBackToRulesWhenMLNotTrained() async {
        let service = ReadinessService()
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: 60,
            hrv: 50,
            sleepDuration: 8 * 3600
        )

        // Without training, ML can't contribute
        await service.setDaysOfData(30) // Even at 100% ML weight

        let score = await service.calculate(from: metrics, energyLevel: 4)

        // Should still get a score (from rules fallback)
        #expect(score != nil)
    }

    // MARK: - Blending Tests

    @Test func calculateUsesRulesOnlyOnDayZero() async {
        let rulesCalc = ReadinessCalculator()
        let service = ReadinessService(rulesCalculator: rulesCalc)

        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: 60,
            hrv: 50,
            sleepDuration: 8 * 3600
        )

        // Day 0 - ML weight is 0
        await service.setDaysOfData(0)

        let serviceScore = await service.calculate(from: metrics, energyLevel: 4)
        let rulesScore = rulesCalc.calculate(from: metrics, energyLevel: 4)

        // Scores should be identical since ML weight is 0
        #expect(serviceScore?.score == rulesScore?.score)
    }

    // MARK: - Training Example Count

    @Test func trainingExampleCountStartsAtZero() async {
        let service = ReadinessService()

        let count = await service.trainingExampleCount

        #expect(count == 0)
    }
}

// MARK: - Mock Readiness Service Tests

@MainActor
struct MockReadinessServiceTests {

    @Test func mockReturnsDefaultScore() async {
        let mock = MockReadinessService()

        let score = await mock.calculate(from: nil, energyLevel: nil)

        #expect(score != nil)
        #expect(score?.score == 75)
    }

    @Test func mockReturnsMockScore() async {
        let mock = MockReadinessService()
        let customScore = ReadinessScore(
            score: 90,
            breakdown: ReadinessBreakdown(
                hrvScore: 90,
                restingHeartRateScore: 90,
                sleepScore: 90,
                energyScore: 90
            ),
            confidence: .full
        )
        await mock.setMockScore(customScore)

        let score = await mock.calculate(from: nil, energyLevel: nil)

        #expect(score?.score == 90)
    }

    @Test func mockMLWeightIsConfigurable() async {
        let mock = MockReadinessService()

        await mock.setMockMLWeight(0.75)
        let weight = await mock.mlWeight

        #expect(weight == 0.75)
    }
}

// Helper extension for MockReadinessService
extension MockReadinessService {
    func setMockScore(_ score: ReadinessScore) async {
        mockScore = score
    }

    func setMockMLWeight(_ weight: Double) async {
        mockMLWeight = weight
    }
}
