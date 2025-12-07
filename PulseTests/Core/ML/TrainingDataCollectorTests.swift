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
/// 1. Collection of training data from complete Days
/// 2. Label calculation (blended energy)
/// 3. Filtering of incomplete days
/// 4. Date sorting
@MainActor
struct TrainingDataCollectorTests {

    // MARK: - Helper

    /// Creates a health metrics with enough features to pass the minimum threshold
    private func makeMetrics(for date: Date) -> HealthMetrics {
        HealthMetrics(
            date: date,
            restingHeartRate: 60,
            hrv: 50,
            sleepDuration: 7 * 3600
        )
    }

    /// Creates a complete Day with both check-ins
    private func makeCompleteDay(
        date: Date,
        firstEnergy: Int = 3,
        secondEnergy: Int = 4,
        metrics: HealthMetrics? = nil
    ) -> Day {
        Day(
            startDate: date,
            firstCheckIn: CheckInSlot(energyLevel: firstEnergy),
            secondCheckIn: CheckInSlot(energyLevel: secondEnergy),
            healthMetrics: metrics ?? makeMetrics(for: date)
        )
    }

    /// Creates an incomplete Day with only first check-in
    private func makeIncompleteDay(
        date: Date,
        firstEnergy: Int = 3,
        metrics: HealthMetrics? = nil
    ) -> Day {
        Day(
            startDate: date,
            firstCheckIn: CheckInSlot(energyLevel: firstEnergy),
            secondCheckIn: nil,
            healthMetrics: metrics ?? makeMetrics(for: date)
        )
    }

    // MARK: - Collection Tests

    @Test func collectsOnlyCompleteDays() async {
        let collector = TrainingDataCollector()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let days = [
            makeCompleteDay(date: yesterday),  // Complete
            makeIncompleteDay(date: today)     // Incomplete
        ]

        let examples = await collector.collectTrainingData(from: days)

        #expect(examples.count == 1) // Only yesterday is complete
    }

    @Test func collectsMultipleCompleteDays() async {
        let collector = TrainingDataCollector()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var days: [Day] = []
        for dayOffset in 1...5 {
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            days.append(makeCompleteDay(date: date))
        }

        let examples = await collector.collectTrainingData(from: days)

        #expect(examples.count == 5)
    }

    // MARK: - Label Calculation Tests

    @Test func labelIsBlendedEnergy() async {
        let collector = TrainingDataCollector()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // First energy: 3, Second energy: 5
        // Blended: (3 * 0.4) + (5 * 0.6) = 1.2 + 3.0 = 4.2
        // Scaled: 4.2 * 20 = 84
        let days = [
            makeCompleteDay(date: yesterday, firstEnergy: 3, secondEnergy: 5)
        ]

        let examples = await collector.collectTrainingData(from: days)

        #expect(examples.count == 1)
        #expect(examples[0].label == 84.0)
    }

    @Test func labelRangeIsCorrect() async {
        let collector = TrainingDataCollector()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let day1 = calendar.date(byAdding: .day, value: -1, to: today)!
        let day2 = calendar.date(byAdding: .day, value: -2, to: today)!

        let days = [
            // Minimum: (1 * 0.4) + (1 * 0.6) = 1.0 * 20 = 20
            makeCompleteDay(date: day1, firstEnergy: 1, secondEnergy: 1),
            // Maximum: (5 * 0.4) + (5 * 0.6) = 5.0 * 20 = 100
            makeCompleteDay(date: day2, firstEnergy: 5, secondEnergy: 5)
        ]

        let examples = await collector.collectTrainingData(from: days)

        let labels = examples.map { $0.label }.sorted()
        #expect(labels.contains(20.0)) // Minimum
        #expect(labels.contains(100.0)) // Maximum
    }

    // MARK: - Sorting Tests

    @Test func examplesAreSortedByDate() async {
        let collector = TrainingDataCollector()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Add days in random order
        var days: [Day] = []
        for dayOffset in [3, 1, 5, 2, 4] { // Random order
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today)!
            days.append(makeCompleteDay(date: date))
        }

        let examples = await collector.collectTrainingData(from: days)

        // Verify sorted (oldest first)
        for i in 1..<examples.count {
            #expect(examples[i].date >= examples[i-1].date)
        }
    }

    // MARK: - Feature Extraction Tests

    @Test func usesHealthMetricsFromDay() async {
        let collector = TrainingDataCollector()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let metrics = HealthMetrics(
            date: yesterday,
            restingHeartRate: 55,
            hrv: 70,
            sleepDuration: 8 * 3600
        )

        let days = [
            makeCompleteDay(date: yesterday, metrics: metrics)
        ]

        let examples = await collector.collectTrainingData(from: days)

        #expect(examples.count == 1)
        // Verify features were extracted from the metrics
        #expect(examples[0].features.hrvNormalized != nil)
        #expect(examples[0].features.rhrNormalized != nil)
        #expect(examples[0].features.sleepNormalized != nil)
    }

    @Test func filtersExamplesWithInsufficientFeatures() async {
        let collector = TrainingDataCollector()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // Metrics with no features (only date)
        let emptyMetrics = HealthMetrics(
            date: yesterday,
            restingHeartRate: nil,
            hrv: nil,
            sleepDuration: nil
        )

        let days = [
            makeCompleteDay(date: yesterday, metrics: emptyMetrics)
        ]

        let examples = await collector.collectTrainingData(from: days)

        // Should be filtered out due to insufficient features (only dayOfWeek = 1 feature)
        #expect(examples.count == 0)
    }

    // MARK: - Empty Input Tests

    @Test func emptyDaysReturnsEmptyExamples() async {
        let collector = TrainingDataCollector()

        let examples = await collector.collectTrainingData(from: [])

        #expect(examples.isEmpty)
    }

    @Test func onlyIncompleteDaysReturnsEmpty() async {
        let collector = TrainingDataCollector()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let days = [
            makeIncompleteDay(date: today),
            makeIncompleteDay(date: calendar.date(byAdding: .day, value: -1, to: today)!)
        ]

        let examples = await collector.collectTrainingData(from: days)

        #expect(examples.isEmpty)
    }
}
