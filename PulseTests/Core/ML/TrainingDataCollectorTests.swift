//
//  TrainingDataCollectorTests.swift
//  PulseTests
//
//  Created by Devon Martin on 12/6/2025.
//

import Testing
@testable import Pulse
import Foundation

/// Tests for the TrainingDataCollector.
///
/// Verifies:
/// 1. Pairing of morning and evening check-ins
/// 2. Label calculation (blended energy)
/// 3. Filtering of incomplete days
/// 4. Date sorting
@MainActor
struct TrainingDataCollectorTests {

    // MARK: - Helper

    /// Creates a health snapshot with enough features to pass the minimum threshold
    private func makeSnapshot(for date: Date) -> HealthMetrics {
        HealthMetrics(
            date: date,
            restingHeartRate: 60,
            hrv: 50,
            sleepDuration: 7 * 3600
        )
    }

    // MARK: - Pairing Tests

    @Test func collectsOnlyCompleteDays() async {
        let collector = TrainingDataCollector()
        let healthKitService = MockHealthKitService()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let checkIns = [
            // Complete day (yesterday)
            CheckIn(timestamp: yesterday, type: .morning, energyLevel: 4, healthSnapshot: makeSnapshot(for: yesterday)),
            CheckIn(timestamp: yesterday.addingTimeInterval(12 * 3600), type: .evening, energyLevel: 3, healthSnapshot: nil),
            // Incomplete day (today - only morning)
            CheckIn(timestamp: today, type: .morning, energyLevel: 5, healthSnapshot: makeSnapshot(for: today))
        ]

        let examples = await collector.collectTrainingData(
            from: checkIns,
            healthKitService: healthKitService
        )

        #expect(examples.count == 1) // Only yesterday is complete
    }

    @Test func collectsMultipleCompleteDays() async {
        let collector = TrainingDataCollector()
        let healthKitService = MockHealthKitService()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var checkIns: [CheckIn] = []
        for dayOffset in 1...5 {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            checkIns.append(CheckIn(timestamp: date, type: .morning, energyLevel: 3, healthSnapshot: makeSnapshot(for: date)))
            checkIns.append(CheckIn(timestamp: date.addingTimeInterval(12 * 3600), type: .evening, energyLevel: 4, healthSnapshot: nil))
        }

        let examples = await collector.collectTrainingData(
            from: checkIns,
            healthKitService: healthKitService
        )

        #expect(examples.count == 5)
    }

    // MARK: - Label Calculation Tests

    @Test func labelIsBlendedEnergy() async {
        let collector = TrainingDataCollector()
        let healthKitService = MockHealthKitService()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // Morning energy: 3, Evening energy: 5
        // Blended: (3 * 0.4) + (5 * 0.6) = 1.2 + 3.0 = 4.2
        // Scaled: 4.2 * 20 = 84
        let checkIns = [
            CheckIn(timestamp: yesterday, type: .morning, energyLevel: 3, healthSnapshot: makeSnapshot(for: yesterday)),
            CheckIn(timestamp: yesterday.addingTimeInterval(12 * 3600), type: .evening, energyLevel: 5, healthSnapshot: nil)
        ]

        let examples = await collector.collectTrainingData(
            from: checkIns,
            healthKitService: healthKitService
        )

        #expect(examples.count == 1)
        #expect(examples[0].label == 84.0)
    }

    @Test func labelRangeIsCorrect() async {
        let collector = TrainingDataCollector()
        let healthKitService = MockHealthKitService()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Test minimum (1, 1) and maximum (5, 5)
        let day1 = calendar.date(byAdding: .day, value: -1, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -2, to: today)!

        let checkIns = [
            // Minimum: (1 * 0.4) + (1 * 0.6) = 1.0 * 20 = 20
            CheckIn(timestamp: day1, type: .morning, energyLevel: 1, healthSnapshot: makeSnapshot(for: day1)),
            CheckIn(timestamp: day1.addingTimeInterval(12 * 3600), type: .evening, energyLevel: 1, healthSnapshot: nil),
            // Maximum: (5 * 0.4) + (5 * 0.6) = 5.0 * 20 = 100
            CheckIn(timestamp: day2, type: .morning, energyLevel: 5, healthSnapshot: makeSnapshot(for: day2)),
            CheckIn(timestamp: day2.addingTimeInterval(12 * 3600), type: .evening, energyLevel: 5, healthSnapshot: nil)
        ]

        let examples = await collector.collectTrainingData(
            from: checkIns,
            healthKitService: healthKitService
        )

        let labels = examples.map { $0.label }.sorted()
        #expect(labels.contains(20.0)) // Minimum
        #expect(labels.contains(100.0)) // Maximum
    }

    // MARK: - Sorting Tests

    @Test func examplesAreSortedByDate() async {
        let collector = TrainingDataCollector()
        let healthKitService = MockHealthKitService()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Add check-ins in random order
        var checkIns: [CheckIn] = []
        for dayOffset in [3, 1, 5, 2, 4] { // Random order
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            checkIns.append(CheckIn(timestamp: date, type: .morning, energyLevel: 3, healthSnapshot: makeSnapshot(for: date)))
            checkIns.append(CheckIn(timestamp: date.addingTimeInterval(12 * 3600), type: .evening, energyLevel: 4, healthSnapshot: nil))
        }

        let examples = await collector.collectTrainingData(
            from: checkIns,
            healthKitService: healthKitService
        )

        // Verify sorted (oldest first)
        for i in 1..<examples.count {
            #expect(examples[i].date >= examples[i-1].date)
        }
    }

    // MARK: - Feature Extraction Tests

    @Test func usesHealthSnapshotFromMorningCheckIn() async {
        let collector = TrainingDataCollector()
        let healthKitService = MockHealthKitService()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let snapshot = HealthMetrics(
            date: yesterday,
            restingHeartRate: 55,
            hrv: 70,
            sleepDuration: 8 * 3600
        )

        let checkIns = [
            CheckIn(timestamp: yesterday, type: .morning, energyLevel: 4, healthSnapshot: snapshot),
            CheckIn(timestamp: yesterday.addingTimeInterval(12 * 3600), type: .evening, energyLevel: 4, healthSnapshot: nil)
        ]

        let examples = await collector.collectTrainingData(
            from: checkIns,
            healthKitService: healthKitService
        )

        #expect(examples.count == 1)
        // Verify features were extracted from the snapshot
        #expect(examples[0].features.hrvNormalized != nil)
        #expect(examples[0].features.rhrNormalized != nil)
        #expect(examples[0].features.sleepNormalized != nil)
    }

    @Test func filtersExamplesWithInsufficientFeatures() async {
        let collector = TrainingDataCollector()
        let healthKitService = MockHealthKitService()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // Snapshot with no features (only date)
        let emptySnapshot = HealthMetrics(
            date: yesterday,
            restingHeartRate: nil,
            hrv: nil,
            sleepDuration: nil
        )

        let checkIns = [
            CheckIn(timestamp: yesterday, type: .morning, energyLevel: 4, healthSnapshot: emptySnapshot),
            CheckIn(timestamp: yesterday.addingTimeInterval(12 * 3600), type: .evening, energyLevel: 4, healthSnapshot: nil)
        ]

        let examples = await collector.collectTrainingData(
            from: checkIns,
            healthKitService: healthKitService
        )

        // Should be filtered out due to insufficient features (only dayOfWeek = 1 feature)
        #expect(examples.count == 0)
    }

    // MARK: - Empty Input Tests

    @Test func emptyCheckInsReturnsEmptyExamples() async {
        let collector = TrainingDataCollector()
        let healthKitService = MockHealthKitService()

        let examples = await collector.collectTrainingData(
            from: [],
            healthKitService: healthKitService
        )

        #expect(examples.isEmpty)
    }

    @Test func onlyMorningCheckInsReturnsEmpty() async {
        let collector = TrainingDataCollector()
        let healthKitService = MockHealthKitService()

        let checkIns = [
            CheckIn(timestamp: Date(), type: .morning, energyLevel: 3, healthSnapshot: nil),
            CheckIn(timestamp: Date().addingTimeInterval(-86400), type: .morning, energyLevel: 4, healthSnapshot: nil)
        ]

        let examples = await collector.collectTrainingData(
            from: checkIns,
            healthKitService: healthKitService
        )

        #expect(examples.isEmpty)
    }

    @Test func onlyEveningCheckInsReturnsEmpty() async {
        let collector = TrainingDataCollector()
        let healthKitService = MockHealthKitService()

        let checkIns = [
            CheckIn(timestamp: Date(), type: .evening, energyLevel: 3, healthSnapshot: nil),
            CheckIn(timestamp: Date().addingTimeInterval(-86400), type: .evening, energyLevel: 4, healthSnapshot: nil)
        ]

        let examples = await collector.collectTrainingData(
            from: checkIns,
            healthKitService: healthKitService
        )

        #expect(examples.isEmpty)
    }
}
