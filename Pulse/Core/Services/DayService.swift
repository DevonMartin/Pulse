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

    /// Loads today's Day and metrics, updating if in morning window.
    /// - Returns: The current Day (possibly updated) and fresh metrics from HealthKit.
    func loadAndUpdateToday() async throws -> LoadResult {
        // Load existing day if any
        var currentDay = try await dayRepository.getCurrentDayIfExists()

        // Fetch fresh metrics from HealthKit
        let freshMetrics = try await healthKitService.fetchMetrics(for: Date())

        var metricsWereUpdated = false
        var scoreWasRecalculated = false

        // Only update Day with metrics during morning window
        if timeWindowProvider.isMorningWindow {
            let result = try await updateDayWithMetrics(
                currentDay: currentDay,
                freshMetrics: freshMetrics
            )
            currentDay = result.day
            metricsWereUpdated = result.metricsChanged
            scoreWasRecalculated = result.scoreRecalculated
        }

        return LoadResult(
            day: currentDay,
            freshMetrics: freshMetrics,
            metricsWereUpdated: metricsWereUpdated,
            scoreWasRecalculated: scoreWasRecalculated
        )
    }

    /// Updates or creates a Day with fresh metrics.
    /// Only fills in nil fields in existing metrics.
    /// Recalculates score if metrics changed and morning check-in exists.
    func updateDayWithMetrics(
        currentDay: Day?,
        freshMetrics: HealthMetrics
    ) async throws -> (day: Day?, metricsChanged: Bool, scoreRecalculated: Bool) {
        var day = currentDay ?? Day(startDate: timeWindowProvider.currentUserDayStart)
        var metricsChanged = false
        var scoreRecalculated = false

        if let existingMetrics = day.healthMetrics {
            // Merge: only fill in nil fields
            let (merged, didChange) = existingMetrics.merging(with: freshMetrics)
            if didChange {
                day.healthMetrics = merged
                metricsChanged = true
            }
        } else {
            // No existing metrics, use fresh ones
            day.healthMetrics = freshMetrics
            metricsChanged = true
        }

        // Recalculate score if metrics changed and we have a morning check-in
        if metricsChanged && day.hasFirstCheckIn {
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
