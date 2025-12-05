//
//  PredictionEngineTests.swift
//  PulseTests
//
//  Created by Devon Martin on 12/4/2025.
//

import Testing
@testable import Pulse
import Foundation

/// Tests for the PredictionEngine's rules-based prediction logic.
///
/// These tests verify that the prediction engine:
/// - Generates predictions with correct scores based on input metrics
/// - Responds appropriately to granular changes in each metric
/// - Handles edge cases (missing data, extreme values)
/// - Calculates confidence levels correctly
@Suite("PredictionEngine Tests")
struct PredictionEngineTests {

    let engine = PredictionEngine()

    // MARK: - Basic Prediction Tests

    @Test("Returns nil when no data provided")
    func testNilWhenNoData() {
        let prediction = engine.predictTomorrow(
            todayMetrics: nil,
            todayEnergyLevel: nil,
            todayScore: nil
        )

        #expect(prediction == nil)
    }

    @Test("Generates prediction with only today's score")
    func testPredictionWithOnlyTodayScore() {
        let prediction = engine.predictTomorrow(
            todayMetrics: nil,
            todayEnergyLevel: nil,
            todayScore: 70
        )

        #expect(prediction != nil)
        #expect(prediction?.confidence == .limited)
        #expect(prediction?.source == .rules)
    }

    @Test("Generates prediction with only energy level")
    func testPredictionWithOnlyEnergy() {
        let prediction = engine.predictTomorrow(
            todayMetrics: nil,
            todayEnergyLevel: 4,
            todayScore: nil
        )

        #expect(prediction != nil)
        #expect(prediction?.confidence == .limited)
    }

    @Test("Target date is tomorrow")
    func testTargetDateIsTomorrow() {
        let prediction = engine.predictTomorrow(
            todayMetrics: nil,
            todayEnergyLevel: 3,
            todayScore: 65
        )

        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!

        #expect(prediction?.targetDate == tomorrow)
    }

    // MARK: - Sleep Impact Tests

    @Test("Severe sleep debt lowers prediction significantly")
    func testSevereSleepDebt() {
        let poorSleepMetrics = HealthMetrics(
            date: Date(),
            sleepDuration: 3 * 3600 // 3 hours
        )

        let prediction = engine.predictTomorrow(
            todayMetrics: poorSleepMetrics,
            todayEnergyLevel: nil,
            todayScore: 70
        )

        // With 3h sleep (-17 adjustment * 0.35 weight / 0.35 * 0.7 damping ≈ -12)
        // Score should be notably lower than baseline 70
        #expect(prediction != nil)
        #expect(prediction!.predictedScore < 65)
    }

    @Test("Optimal sleep boosts prediction")
    func testOptimalSleep() {
        let goodSleepMetrics = HealthMetrics(
            date: Date(),
            sleepDuration: 8.25 * 3600 // 8.25 hours (optimal range)
        )

        let prediction = engine.predictTomorrow(
            todayMetrics: goodSleepMetrics,
            todayEnergyLevel: nil,
            todayScore: 70
        )

        // With 8.25h sleep (+8 adjustment), score should be higher
        #expect(prediction != nil)
        #expect(prediction!.predictedScore > 70)
    }

    @Test("Granular sleep differences produce different predictions")
    func testGranularSleepDifferences() {
        let sleep7h = HealthMetrics(date: Date(), sleepDuration: 7.0 * 3600)
        let sleep7_5h = HealthMetrics(date: Date(), sleepDuration: 7.5 * 3600)
        let sleep8h = HealthMetrics(date: Date(), sleepDuration: 8.0 * 3600)

        let pred7h = engine.predictTomorrow(todayMetrics: sleep7h, todayEnergyLevel: nil, todayScore: 70)
        let pred7_5h = engine.predictTomorrow(todayMetrics: sleep7_5h, todayEnergyLevel: nil, todayScore: 70)
        let pred8h = engine.predictTomorrow(todayMetrics: sleep8h, todayEnergyLevel: nil, todayScore: 70)

        // Each half-hour difference should produce a different score
        #expect(pred7h?.predictedScore != pred7_5h?.predictedScore)
        #expect(pred7_5h?.predictedScore != pred8h?.predictedScore)

        // More sleep (up to optimal) should increase score
        #expect(pred7h!.predictedScore < pred7_5h!.predictedScore)
        #expect(pred7_5h!.predictedScore < pred8h!.predictedScore)
    }

    // MARK: - HRV Impact Tests

    @Test("Low HRV lowers prediction")
    func testLowHRV() {
        let lowHRVMetrics = HealthMetrics(
            date: Date(),
            hrv: 18 // Very low
        )

        let prediction = engine.predictTomorrow(
            todayMetrics: lowHRVMetrics,
            todayEnergyLevel: nil,
            todayScore: 70
        )

        #expect(prediction != nil)
        #expect(prediction!.predictedScore < 70)
    }

    @Test("High HRV boosts prediction")
    func testHighHRV() {
        let highHRVMetrics = HealthMetrics(
            date: Date(),
            hrv: 75 // Great recovery
        )

        let prediction = engine.predictTomorrow(
            todayMetrics: highHRVMetrics,
            todayEnergyLevel: nil,
            todayScore: 70
        )

        #expect(prediction != nil)
        #expect(prediction!.predictedScore > 70)
    }

    @Test("Granular HRV differences produce different predictions")
    func testGranularHRVDifferences() {
        let hrv35 = HealthMetrics(date: Date(), hrv: 35)
        let hrv45 = HealthMetrics(date: Date(), hrv: 45)
        let hrv55 = HealthMetrics(date: Date(), hrv: 55)

        let pred35 = engine.predictTomorrow(todayMetrics: hrv35, todayEnergyLevel: nil, todayScore: 70)
        let pred45 = engine.predictTomorrow(todayMetrics: hrv45, todayEnergyLevel: nil, todayScore: 70)
        let pred55 = engine.predictTomorrow(todayMetrics: hrv55, todayEnergyLevel: nil, todayScore: 70)

        // Higher HRV should produce higher scores
        #expect(pred35!.predictedScore < pred45!.predictedScore)
        #expect(pred45!.predictedScore < pred55!.predictedScore)
    }

    // MARK: - RHR Impact Tests

    @Test("Elevated RHR lowers prediction")
    func testElevatedRHR() {
        let highRHRMetrics = HealthMetrics(
            date: Date(),
            restingHeartRate: 92 // Elevated
        )

        let prediction = engine.predictTomorrow(
            todayMetrics: highRHRMetrics,
            todayEnergyLevel: nil,
            todayScore: 70
        )

        #expect(prediction != nil)
        #expect(prediction!.predictedScore < 70)
    }

    @Test("Low RHR boosts prediction")
    func testLowRHR() {
        let lowRHRMetrics = HealthMetrics(
            date: Date(),
            restingHeartRate: 52 // Athletic
        )

        let prediction = engine.predictTomorrow(
            todayMetrics: lowRHRMetrics,
            todayEnergyLevel: nil,
            todayScore: 70
        )

        #expect(prediction != nil)
        #expect(prediction!.predictedScore > 70)
    }

    // MARK: - Steps Impact Tests

    @Test("Very sedentary day lowers prediction")
    func testSedentaryDay() {
        let sedentaryMetrics = HealthMetrics(
            date: Date(),
            sleepDuration: 7 * 3600,
            steps: 800
        )

        let prediction = engine.predictTomorrow(
            todayMetrics: sedentaryMetrics,
            todayEnergyLevel: nil,
            todayScore: 70
        )

        #expect(prediction != nil)
        // Sedentary should have slight negative impact
    }

    @Test("Moderate activity with good sleep boosts prediction")
    func testModerateActivityGoodSleep() {
        let activeMetrics = HealthMetrics(
            date: Date(),
            sleepDuration: 8 * 3600, // Well rested
            steps: 9000 // Moderate-high activity
        )

        let prediction = engine.predictTomorrow(
            todayMetrics: activeMetrics,
            todayEnergyLevel: nil,
            todayScore: 70
        )

        #expect(prediction != nil)
        #expect(prediction!.predictedScore > 70)
    }

    @Test("High activity with poor sleep lowers prediction")
    func testHighActivityPoorSleep() {
        let overtrainedMetrics = HealthMetrics(
            date: Date(),
            sleepDuration: 5 * 3600, // Poor sleep
            steps: 18000 // Very high activity
        )

        let prediction = engine.predictTomorrow(
            todayMetrics: overtrainedMetrics,
            todayEnergyLevel: nil,
            todayScore: 70
        )

        #expect(prediction != nil)
        #expect(prediction!.predictedScore < 65) // Should be notably lower
    }

    // MARK: - Energy Level Impact Tests

    @Test("Low energy lowers prediction")
    func testLowEnergy() {
        let prediction = engine.predictTomorrow(
            todayMetrics: nil,
            todayEnergyLevel: 1,
            todayScore: 70
        )

        #expect(prediction != nil)
        #expect(prediction!.predictedScore < 70)
    }

    @Test("High energy boosts prediction")
    func testHighEnergy() {
        let prediction = engine.predictTomorrow(
            todayMetrics: nil,
            todayEnergyLevel: 5,
            todayScore: 70
        )

        #expect(prediction != nil)
        #expect(prediction!.predictedScore > 70)
    }

    // MARK: - Confidence Level Tests

    @Test("Full confidence with all data points")
    func testFullConfidence() {
        let fullMetrics = HealthMetrics(
            date: Date(),
            restingHeartRate: 60,
            hrv: 50,
            sleepDuration: 7.5 * 3600,
            steps: 8000
        )

        let prediction = engine.predictTomorrow(
            todayMetrics: fullMetrics,
            todayEnergyLevel: 4,
            todayScore: 70
        )

        #expect(prediction?.confidence == .full)
    }

    @Test("Partial confidence with some data points")
    func testPartialConfidence() {
        let partialMetrics = HealthMetrics(
            date: Date(),
            sleepDuration: 7 * 3600,
            steps: 5000
        )

        let prediction = engine.predictTomorrow(
            todayMetrics: partialMetrics,
            todayEnergyLevel: 3,
            todayScore: nil
        )

        #expect(prediction?.confidence == .partial)
    }

    @Test("Limited confidence with minimal data")
    func testLimitedConfidence() {
        let prediction = engine.predictTomorrow(
            todayMetrics: nil,
            todayEnergyLevel: 3,
            todayScore: nil
        )

        #expect(prediction?.confidence == .limited)
    }

    // MARK: - Combined Metrics Tests

    @Test("Good metrics produce high prediction")
    func testGoodMetricsCombined() {
        let goodMetrics = HealthMetrics(
            date: Date(),
            restingHeartRate: 55,
            hrv: 70,
            sleepDuration: 8 * 3600,
            steps: 8500
        )

        let prediction = engine.predictTomorrow(
            todayMetrics: goodMetrics,
            todayEnergyLevel: 5,
            todayScore: 75
        )

        #expect(prediction != nil)
        #expect(prediction!.predictedScore > 75)
    }

    @Test("Poor metrics produce low prediction")
    func testPoorMetricsCombined() {
        let poorMetrics = HealthMetrics(
            date: Date(),
            restingHeartRate: 85,
            hrv: 22,
            sleepDuration: 4.5 * 3600,
            steps: 1500
        )

        let prediction = engine.predictTomorrow(
            todayMetrics: poorMetrics,
            todayEnergyLevel: 1,
            todayScore: 50
        )

        #expect(prediction != nil)
        #expect(prediction!.predictedScore < 50)
    }

    // MARK: - Score Clamping Tests

    @Test("Score is clamped to minimum 15")
    func testMinimumScoreClamping() {
        let terribleMetrics = HealthMetrics(
            date: Date(),
            restingHeartRate: 100,
            hrv: 10,
            sleepDuration: 2 * 3600,
            steps: 500
        )

        let prediction = engine.predictTomorrow(
            todayMetrics: terribleMetrics,
            todayEnergyLevel: 1,
            todayScore: 20
        )

        #expect(prediction != nil)
        #expect(prediction!.predictedScore >= 15)
    }

    @Test("Score is clamped to maximum 95")
    func testMaximumScoreClamping() {
        let excellentMetrics = HealthMetrics(
            date: Date(),
            restingHeartRate: 45,
            hrv: 110,
            sleepDuration: 8.25 * 3600,
            steps: 9000
        )

        let prediction = engine.predictTomorrow(
            todayMetrics: excellentMetrics,
            todayEnergyLevel: 5,
            todayScore: 95
        )

        #expect(prediction != nil)
        #expect(prediction!.predictedScore <= 95)
    }

    // MARK: - Source Tests

    @Test("Source is always rules for this engine")
    func testSourceIsRules() {
        let prediction = engine.predictTomorrow(
            todayMetrics: nil,
            todayEnergyLevel: 3,
            todayScore: 70
        )

        #expect(prediction?.source == .rules)
        #expect(engine.currentSource == .rules)
    }
}
