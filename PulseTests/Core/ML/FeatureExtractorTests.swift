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
/// 4. Day of week encoding
/// 5. Missing data handling
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

    // MARK: - Day of Week Encoding

    @Test func dayOfWeekEncodesCorrectly() {
        let extractor = FeatureExtractor(trainingExampleCount: 0)

        // Create dates for specific days
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2025
        components.month = 12

        // Sunday (weekday = 1)
        components.day = 7 // Dec 7, 2025 is a Sunday
        let sunday = calendar.date(from: components)!
        let sundayMetrics = HealthMetrics(date: sunday, hrv: 50)
        let sundayFeatures = extractor.extractFeatures(from: sundayMetrics)

        // Saturday (weekday = 7)
        components.day = 6 // Dec 6, 2025 is a Saturday
        let saturday = calendar.date(from: components)!
        let saturdayMetrics = HealthMetrics(date: saturday, hrv: 50)
        let saturdayFeatures = extractor.extractFeatures(from: saturdayMetrics)

        #expect(sundayFeatures.dayOfWeek == 0.0) // Sunday = 0
        #expect(saturdayFeatures.dayOfWeek == 1.0) // Saturday = 1
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

    @Test func nilMetricsReturnsAllNilExceptDayOfWeek() {
        let extractor = FeatureExtractor(trainingExampleCount: 0)

        let features = extractor.extractFeatures(from: nil)

        #expect(features.hrvNormalized == nil)
        #expect(features.rhrNormalized == nil)
        #expect(features.sleepNormalized == nil)
        #expect(features.dayOfWeek >= 0)
        #expect(features.dayOfWeek <= 1)
    }

    // MARK: - Feature Vector Tests

    @Test func featureVectorToArrayUsesDefaultForMissing() {
        let features = FeatureVector(
            hrvNormalized: 0.5,
            rhrNormalized: nil,
            sleepNormalized: 0.8,
            dayOfWeek: 0.5
        )

        let array = features.toArray(defaultValue: 0.5)

        #expect(array[0] == 0.5) // HRV
        #expect(array[1] == 0.5) // RHR (default)
        #expect(array[2] == 0.8) // Sleep
        #expect(array[3] == 0.5) // Day of week
    }

    @Test func availableFeatureCountIsCorrect() {
        let allAvailable = FeatureVector(
            hrvNormalized: 0.5,
            rhrNormalized: 0.5,
            sleepNormalized: 0.5,
            dayOfWeek: 0.5
        )
        #expect(allAvailable.availableFeatureCount == 4)

        let twoMissing = FeatureVector(
            hrvNormalized: 0.5,
            rhrNormalized: nil,
            sleepNormalized: nil,
            dayOfWeek: 0.5
        )
        #expect(twoMissing.availableFeatureCount == 2)

        let allMissing = FeatureVector(
            hrvNormalized: nil,
            rhrNormalized: nil,
            sleepNormalized: nil,
            dayOfWeek: 0.5
        )
        #expect(allMissing.availableFeatureCount == 1) // Only dayOfWeek
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
}
