//
//  FeatureExtractorTests.swift
//  PulseTests
//
//  Created by Devon Martin on 12/6/2025.
//

import Testing
@testable import Pulse
import Foundation

/// Tests for the FeatureExtractor.
///
/// Verifies:
/// 1. HRV normalization (20-100ms → 0-1)
/// 2. RHR normalization with inversion (40-90bpm → 1-0)
/// 3. Sleep normalization (two-phase: opinionated vs linear)
/// 4. Missing data handling
struct FeatureExtractorTests {

    // MARK: - HRV Normalization

    @Test func hrvNormalizationAtMinimum() {
        let extractor = FeatureExtractor(trainingExampleCount: 0)
        let metrics = HealthMetrics(date: Date(), hrv: 20)

        let features = extractor.extractFeatures(from: metrics)

        #expect(features.hrvNormalized == 0.0)
    }

    @Test func hrvNormalizationAtMaximum() {
        let extractor = FeatureExtractor(trainingExampleCount: 0)
        let metrics = HealthMetrics(date: Date(), hrv: 100)

        let features = extractor.extractFeatures(from: metrics)

        #expect(features.hrvNormalized == 1.0)
    }

    @Test func hrvNormalizationAtMidpoint() {
        let extractor = FeatureExtractor(trainingExampleCount: 0)
        let metrics = HealthMetrics(date: Date(), hrv: 60) // Midpoint of 20-100

        let features = extractor.extractFeatures(from: metrics)

        #expect(features.hrvNormalized == 0.5)
    }

    @Test func hrvNormalizationClampsBelowMinimum() {
        let extractor = FeatureExtractor(trainingExampleCount: 0)
        let metrics = HealthMetrics(date: Date(), hrv: 10) // Below minimum

        let features = extractor.extractFeatures(from: metrics)

        #expect(features.hrvNormalized == 0.0)
    }

    @Test func hrvNormalizationClampsAboveMaximum() {
        let extractor = FeatureExtractor(trainingExampleCount: 0)
        let metrics = HealthMetrics(date: Date(), hrv: 150) // Above maximum

        let features = extractor.extractFeatures(from: metrics)

        #expect(features.hrvNormalized == 1.0)
    }

    // MARK: - RHR Normalization (Inverted)

    @Test func rhrNormalizationAtMinimumGivesHighScore() {
        let extractor = FeatureExtractor(trainingExampleCount: 0)
        let metrics = HealthMetrics(date: Date(), restingHeartRate: 40) // Low RHR is good

        let features = extractor.extractFeatures(from: metrics)

        #expect(features.rhrNormalized == 1.0)
    }

    @Test func rhrNormalizationAtMaximumGivesLowScore() {
        let extractor = FeatureExtractor(trainingExampleCount: 0)
        let metrics = HealthMetrics(date: Date(), restingHeartRate: 90) // High RHR is bad

        let features = extractor.extractFeatures(from: metrics)

        #expect(features.rhrNormalized == 0.0)
    }

    @Test func rhrNormalizationAtMidpoint() {
        let extractor = FeatureExtractor(trainingExampleCount: 0)
        let metrics = HealthMetrics(date: Date(), restingHeartRate: 65) // Midpoint of 40-90

        let features = extractor.extractFeatures(from: metrics)

        #expect(features.rhrNormalized == 0.5)
    }

    // MARK: - Sleep Normalization (Opinionated - Early Phase)

    @Test func sleepOpinionatedOptimalRangeScoresHigh() {
        let extractor = FeatureExtractor(trainingExampleCount: 0) // Early phase

        // 8 hours is optimal center
        let metrics = HealthMetrics(date: Date(), sleepDuration: 8 * 3600)
        let features = extractor.extractFeatures(from: metrics)

        #expect(features.sleepNormalized! >= 0.9)
        #expect(features.sleepNormalized! <= 1.0)
    }

    @Test func sleepOpinionatedBelowOptimalScoresLower() {
        let extractor = FeatureExtractor(trainingExampleCount: 0) // Early phase

        // 5 hours is below optimal
        let metrics = HealthMetrics(date: Date(), sleepDuration: 5 * 3600)
        let features = extractor.extractFeatures(from: metrics)

        #expect(features.sleepNormalized! >= 0.2)
        #expect(features.sleepNormalized! < 0.8)
    }

    @Test func sleepOpinionatedAboveOptimalScoresModerate() {
        let extractor = FeatureExtractor(trainingExampleCount: 0) // Early phase

        // 10 hours is above optimal
        let metrics = HealthMetrics(date: Date(), sleepDuration: 10 * 3600)
        let features = extractor.extractFeatures(from: metrics)

        #expect(features.sleepNormalized! >= 0.5)
        #expect(features.sleepNormalized! < 0.8)
    }

    // MARK: - Sleep Normalization (Linear - Mature Phase)

    @Test func sleepLinearIsSimpleScaling() {
        let extractor = FeatureExtractor(trainingExampleCount: 30) // Mature phase

        // With linear normalization, more sleep = higher value
        let metrics4h = HealthMetrics(date: Date(), sleepDuration: 4 * 3600)
        let metrics8h = HealthMetrics(date: Date(), sleepDuration: 8 * 3600)
        let metrics12h = HealthMetrics(date: Date(), sleepDuration: 12 * 3600)

        let features4h = extractor.extractFeatures(from: metrics4h)
        let features8h = extractor.extractFeatures(from: metrics8h)
        let features12h = extractor.extractFeatures(from: metrics12h)

        #expect(features4h.sleepNormalized == 0.0) // Minimum
        #expect(features12h.sleepNormalized == 1.0) // Maximum
        #expect(features8h.sleepNormalized == 0.5) // Midpoint
    }

    @Test func sleepLinearDiffersFromOpinionated() {
        let earlyExtractor = FeatureExtractor(trainingExampleCount: 0)
        let matureExtractor = FeatureExtractor(trainingExampleCount: 30)

        // At 10 hours, opinionated penalizes oversleeping, linear doesn't
        let metrics = HealthMetrics(date: Date(), sleepDuration: 10 * 3600)

        let earlyFeatures = earlyExtractor.extractFeatures(from: metrics)
        let matureFeatures = matureExtractor.extractFeatures(from: metrics)

        // Linear should score higher for 10 hours (0.75) than opinionated
        #expect(matureFeatures.sleepNormalized! > earlyFeatures.sleepNormalized!)
    }

    // MARK: - Missing Data Handling

    @Test func missingHrvReturnsNil() {
        let extractor = FeatureExtractor(trainingExampleCount: 0)
        let metrics = HealthMetrics(date: Date(), hrv: nil)

        let features = extractor.extractFeatures(from: metrics)

        #expect(features.hrvNormalized == nil)
    }

    @Test func missingRhrReturnsNil() {
        let extractor = FeatureExtractor(trainingExampleCount: 0)
        let metrics = HealthMetrics(date: Date(), restingHeartRate: nil)

        let features = extractor.extractFeatures(from: metrics)

        #expect(features.rhrNormalized == nil)
    }

    @Test func missingSleepReturnsNil() {
        let extractor = FeatureExtractor(trainingExampleCount: 0)
        let metrics = HealthMetrics(date: Date(), sleepDuration: nil)

        let features = extractor.extractFeatures(from: metrics)

        #expect(features.sleepNormalized == nil)
    }

    @Test func nilMetricsReturnsAllNil() {
        let extractor = FeatureExtractor(trainingExampleCount: 0)

        let features = extractor.extractFeatures(from: nil)

        #expect(features.hrvNormalized == nil)
        #expect(features.rhrNormalized == nil)
        #expect(features.sleepNormalized == nil)
        #expect(features.morningEnergyNormalized == nil)
        #expect(features.previousDayStepsNormalized == nil)
        #expect(features.previousDayCaloriesNormalized == nil)
    }

    // MARK: - Feature Vector Tests

    @Test func featureVectorToArrayUsesDefaultForMissing() {
        let features = FeatureVector(
            hrvNormalized: 0.5,
            rhrNormalized: nil,
            sleepNormalized: 0.8,
            morningEnergyNormalized: 0.75,
            previousDayStepsNormalized: nil,
            previousDayCaloriesNormalized: nil,
            sleepNormalizedSquared: 0.64,
            previousDayStepsNormalizedSquared: nil,
            previousDayCaloriesNormalizedSquared: nil
        )

        let array = features.toArray(defaultValue: 0.5)

        #expect(array[0] == 0.5)    // HRV
        #expect(array[1] == 0.5)    // RHR (default)
        #expect(array[2] == 0.8)    // Sleep
        #expect(array[3] == 0.64)   // Sleep² (0.8²)
        #expect(array[4] == 0.75)   // Morning energy
        #expect(array[5] == 0.5)    // Prev steps (default)
        #expect(array[6] == 0.25)   // Prev steps² (default 0.5² = 0.25)
        #expect(array[7] == 0.5)    // Prev calories (default)
        #expect(array[8] == 0.25)   // Prev calories² (default 0.5² = 0.25)
    }

    @Test func availableFeatureCountIsCorrect() {
        let allAvailable = FeatureVector(
            hrvNormalized: 0.5,
            rhrNormalized: 0.5,
            sleepNormalized: 0.5,
            morningEnergyNormalized: 0.5,
            previousDayStepsNormalized: 0.5,
            previousDayCaloriesNormalized: 0.5,
            sleepNormalizedSquared: 0.25,
            previousDayStepsNormalizedSquared: 0.25,
            previousDayCaloriesNormalizedSquared: 0.25
        )
        #expect(allAvailable.availableFeatureCount == 6)

        let twoMissing = FeatureVector(
            hrvNormalized: 0.5,
            rhrNormalized: nil,
            sleepNormalized: nil,
            morningEnergyNormalized: 0.5,
            previousDayStepsNormalized: nil,
            previousDayCaloriesNormalized: nil,
            sleepNormalizedSquared: nil,
            previousDayStepsNormalizedSquared: nil,
            previousDayCaloriesNormalizedSquared: nil
        )
        #expect(twoMissing.availableFeatureCount == 2)

        let allMissing = FeatureVector(
            hrvNormalized: nil,
            rhrNormalized: nil,
            sleepNormalized: nil,
            morningEnergyNormalized: nil,
            previousDayStepsNormalized: nil,
            previousDayCaloriesNormalized: nil,
            sleepNormalizedSquared: nil,
            previousDayStepsNormalizedSquared: nil,
            previousDayCaloriesNormalizedSquared: nil
        )
        #expect(allMissing.availableFeatureCount == 0)
    }

    // MARK: - Normalization Strategy Threshold

    @Test func thresholdAt29UsesOpinionated() {
        let extractor = FeatureExtractor(trainingExampleCount: 29)
        let metrics = HealthMetrics(date: Date(), sleepDuration: 10 * 3600)

        let features = extractor.extractFeatures(from: metrics)

        // Opinionated penalizes oversleeping more than linear
        #expect(features.sleepNormalized! < 0.75)
    }

    @Test func thresholdAt30UsesLinear() {
        let extractor = FeatureExtractor(trainingExampleCount: 30)
        let metrics = HealthMetrics(date: Date(), sleepDuration: 10 * 3600)

        let features = extractor.extractFeatures(from: metrics)

        // Linear: (10-4)/(12-4) = 6/8 = 0.75
        #expect(features.sleepNormalized == 0.75)
    }

    // MARK: - Morning Energy Normalization

    @Test func morningEnergyNormalization() {
        let extractor = FeatureExtractor(trainingExampleCount: 0)
        let metrics = HealthMetrics(date: Date(), hrv: 50)

        let features1 = extractor.extractFeatures(from: metrics, morningEnergy: 1)
        let features3 = extractor.extractFeatures(from: metrics, morningEnergy: 3)
        let features5 = extractor.extractFeatures(from: metrics, morningEnergy: 5)

        #expect(features1.morningEnergyNormalized == 0.0)
        #expect(features3.morningEnergyNormalized == 0.5)
        #expect(features5.morningEnergyNormalized == 1.0)
    }

    @Test func morningEnergyNilWhenNotProvided() {
        let extractor = FeatureExtractor(trainingExampleCount: 0)
        let metrics = HealthMetrics(date: Date(), hrv: 50)

        let features = extractor.extractFeatures(from: metrics)

        #expect(features.morningEnergyNormalized == nil)
    }

    // MARK: - Previous Day Steps/Calories Normalization

    @Test func previousDayStepsNormalization() {
        let extractor = FeatureExtractor(trainingExampleCount: 0)
        let metrics = HealthMetrics(date: Date(), hrv: 50)
        let prevMetrics = HealthMetrics(date: Date(), steps: 10_000, activeCalories: 500)

        let features = extractor.extractFeatures(from: metrics, previousDayMetrics: prevMetrics)

        #expect(features.previousDayStepsNormalized == 0.5) // 10000/20000
        #expect(features.previousDayCaloriesNormalized == 0.5) // 500/1000
    }

    @Test func previousDayMetricsNilWhenNotProvided() {
        let extractor = FeatureExtractor(trainingExampleCount: 0)
        let metrics = HealthMetrics(date: Date(), hrv: 50)

        let features = extractor.extractFeatures(from: metrics)

        #expect(features.previousDayStepsNormalized == nil)
        #expect(features.previousDayCaloriesNormalized == nil)
    }

    @Test func previousDayStepsClampsAtMax() {
        let extractor = FeatureExtractor(trainingExampleCount: 0)
        let metrics = HealthMetrics(date: Date(), hrv: 50)
        let prevMetrics = HealthMetrics(date: Date(), steps: 30_000)

        let features = extractor.extractFeatures(from: metrics, previousDayMetrics: prevMetrics)

        #expect(features.previousDayStepsNormalized == 1.0)
    }

    // MARK: - Polynomial (Squared) Feature Tests

    @Test func sleepSquaredIsComputedFromLinearValue() {
        let extractor = FeatureExtractor(trainingExampleCount: 30) // Mature phase for predictable values
        let metrics = HealthMetrics(date: Date(), sleepDuration: 8 * 3600)

        let features = extractor.extractFeatures(from: metrics)

        // Linear: (8-4)/(12-4) = 0.5, squared = 0.25
        #expect(features.sleepNormalized == 0.5)
        #expect(features.sleepNormalizedSquared == 0.25)
    }

    @Test func stepsSquaredIsComputedFromLinearValue() {
        let extractor = FeatureExtractor(trainingExampleCount: 0)
        let metrics = HealthMetrics(date: Date(), hrv: 50)
        let prevMetrics = HealthMetrics(date: Date(), steps: 10_000)

        let features = extractor.extractFeatures(from: metrics, previousDayMetrics: prevMetrics)

        // 10000/20000 = 0.5, squared = 0.25
        #expect(features.previousDayStepsNormalized == 0.5)
        #expect(features.previousDayStepsNormalizedSquared == 0.25)
    }

    @Test func caloriesSquaredIsComputedFromLinearValue() {
        let extractor = FeatureExtractor(trainingExampleCount: 0)
        let metrics = HealthMetrics(date: Date(), hrv: 50)
        let prevMetrics = HealthMetrics(date: Date(), activeCalories: 500)

        let features = extractor.extractFeatures(from: metrics, previousDayMetrics: prevMetrics)

        // 500/1000 = 0.5, squared = 0.25
        #expect(features.previousDayCaloriesNormalized == 0.5)
        #expect(features.previousDayCaloriesNormalizedSquared == 0.25)
    }

    @Test func squaredFeaturesAreNilWhenBaseIsNil() {
        let extractor = FeatureExtractor(trainingExampleCount: 0)
        let metrics = HealthMetrics(date: Date(), sleepDuration: nil)

        let features = extractor.extractFeatures(from: metrics)

        #expect(features.sleepNormalized == nil)
        #expect(features.sleepNormalizedSquared == nil)
        #expect(features.previousDayStepsNormalized == nil)
        #expect(features.previousDayStepsNormalizedSquared == nil)
        #expect(features.previousDayCaloriesNormalized == nil)
        #expect(features.previousDayCaloriesNormalizedSquared == nil)
    }
}
