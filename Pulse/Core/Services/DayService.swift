//
//  DayService.swift
//  Pulse
//
//  Created by Devon Martin on 12/7/2025.
//

import Foundation

/// Protocol for time window checking, allowing injection for testing.
protocol TimeWindowProvider: Sendable {
    nonisolated var isMorningWindow: Bool { get }
    nonisolated var currentUserDayStart: Date { get }
}

/// Default implementation using TimeWindows.
struct DefaultTimeWindowProvider: TimeWindowProvider, Sendable {
    nonisolated init() {}
    nonisolated var isMorningWindow: Bool { TimeWindows.isMorningWindow }
    nonisolated var currentUserDayStart: Date { TimeWindows.currentUserDayStart }
}

/// Service responsible for managing Day records and their metrics.
/// Handles creating, updating, and merging health metrics into Days.
actor DayService {
    private let dayRepository: DayRepositoryProtocol
    private let healthKitService: HealthKitServiceProtocol
    private let readinessService: ReadinessService
    private let timeWindowProvider: TimeWindowProvider

    init(
        dayRepository: DayRepositoryProtocol,
        healthKitService: HealthKitServiceProtocol,
        readinessService: ReadinessService,
        timeWindowProvider: TimeWindowProvider = DefaultTimeWindowProvider()
    ) {
        self.dayRepository = dayRepository
        self.healthKitService = healthKitService
        self.readinessService = readinessService
        self.timeWindowProvider = timeWindowProvider
    }

    /// Result of loading and updating today's data.
    struct LoadResult: Sendable {
        let day: Day?
        let freshMetrics: HealthMetrics?
        let metricsWereUpdated: Bool
        let scoreWasRecalculated: Bool
    }

    /// Loads today's Day and metrics, always updating activity metrics (steps/calories).
    /// Recovery metrics (RHR, HRV, sleep) and score recalculation only happen in morning window.
    /// - Returns: The current Day (possibly updated) and fresh metrics from HealthKit.
    func loadAndUpdateToday() async throws -> LoadResult {
        // Load existing day if any
        var currentDay = try await dayRepository.getCurrentDayIfExists()

        // Fetch fresh metrics from HealthKit
        let freshMetrics = try await healthKitService.fetchMetrics(for: Date())

        var metricsWereUpdated = false
        var scoreWasRecalculated = false

        // Always update activity metrics (steps/calories accumulate throughout the day)
        // Only update recovery metrics (RHR, HRV, sleep) and recalculate score during morning window
        let result = try await updateDayWithMetrics(
            currentDay: currentDay,
            freshMetrics: freshMetrics,
            updateRecoveryMetrics: timeWindowProvider.isMorningWindow
        )
        currentDay = result.day
        metricsWereUpdated = result.metricsChanged
        scoreWasRecalculated = result.scoreRecalculated

        return LoadResult(
            day: currentDay,
            freshMetrics: freshMetrics,
            metricsWereUpdated: metricsWereUpdated,
            scoreWasRecalculated: scoreWasRecalculated
        )
    }

    /// Updates or creates a Day with fresh metrics.
    /// - Parameters:
    ///   - currentDay: The existing Day record, if any
    ///   - freshMetrics: Fresh metrics from HealthKit
    ///   - updateRecoveryMetrics: If true, updates RHR/HRV/sleep and recalculates score.
    ///                            If false, only updates activity metrics (steps/calories).
    func updateDayWithMetrics(
        currentDay: Day?,
        freshMetrics: HealthMetrics,
        updateRecoveryMetrics: Bool = true
    ) async throws -> (day: Day?, metricsChanged: Bool, scoreRecalculated: Bool) {
        var day = currentDay ?? Day(startDate: timeWindowProvider.currentUserDayStart)
        var metricsChanged = false
        var scoreRecalculated = false

        if let existingMetrics = day.healthMetrics {
            if updateRecoveryMetrics {
                // Full merge: recovery metrics fill nil fields, activity metrics take max
                let (merged, didChange) = existingMetrics.merging(with: freshMetrics)
                if didChange {
                    day.healthMetrics = merged
                    metricsChanged = true
                }
            } else {
                // Activity-only merge: only update steps and calories
                let (merged, didChange) = existingMetrics.mergingActivityOnly(with: freshMetrics)
                if didChange {
                    day.healthMetrics = merged
                    metricsChanged = true
                }
            }
        } else {
            // No existing metrics
            if updateRecoveryMetrics {
                // Use all fresh metrics
                day.healthMetrics = freshMetrics
                metricsChanged = true
            } else {
                // Only use activity metrics from fresh data
                day.healthMetrics = HealthMetrics(
                    date: freshMetrics.date,
                    steps: freshMetrics.steps,
                    activeCalories: freshMetrics.activeCalories
                )
                metricsChanged = freshMetrics.steps != nil || freshMetrics.activeCalories != nil
            }
        }

        // Recalculate score only if updating recovery metrics and metrics changed
        if updateRecoveryMetrics && metricsChanged && day.hasFirstCheckIn {
            if let energyLevel = day.firstCheckIn?.energyLevel,
               let metrics = day.healthMetrics {
                if let newScore = await readinessService.calculate(
                    from: metrics,
                    energyLevel: energyLevel
                ) {
                    day.readinessScore = newScore
                    scoreRecalculated = true
                }
            }
        }

        // Save if anything changed or this is a new day
        if metricsChanged || currentDay == nil {
            try await dayRepository.save(day)
        }

        return (day, metricsChanged, scoreRecalculated)
    }
}
