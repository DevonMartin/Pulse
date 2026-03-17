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

    // MARK: - Metrics Query Windows

    /// Computes HealthKit query windows for each metric category based on the user's schedule.
    ///
    /// Different metrics need different query windows:
    /// - **Recovery** (RHR, HRV, sleep): Recorded overnight. Window spans from 3h before
    ///   the previous evening check-in to 3h after the morning check-in.
    /// - **Activity** (steps, calories): Accumulated during waking hours. Window spans from
    ///   3h before the morning check-in to 3h after the evening check-in.
    ///
    /// Examples for default schedule (morning=8AM, evening=7PM):
    /// - Recovery: previous day 4PM → today 11AM
    /// - Activity: today 5AM → today 10PM
    ///
    /// Examples for late evening (morning=8AM, evening=1AM):
    /// - Recovery: previous day 10PM → today 11AM
    /// - Activity: today 5AM → tomorrow 4AM
    static func metricsWindows(for userDayStart: Date, calendar: Calendar) -> MetricsWindows {
        let calendarDayStart = calendar.startOfDay(for: userDayStart)

        // --- Recovery window (RHR, HRV, sleep) ---
        // Start: 3h before previous evening check-in
        let eveningBufferedHour = (TimeWindows.eveningCheckInHour - 3 + 24) % 24
        let recoveryStartDay: Date
        if eveningBufferedHour >= 12 {
            // Buffered hour is in the PM → place on previous calendar day
            recoveryStartDay = calendar.date(byAdding: .day, value: -1, to: calendarDayStart)!
        } else {
            // Buffered hour is in the AM → place on current calendar day
            recoveryStartDay = calendarDayStart
        }
        let recoveryStart = calendar.date(bySettingHour: eveningBufferedHour, minute: 0, second: 0, of: recoveryStartDay)!

        // End: 3h after morning check-in
        let morningBufferedHour = min(TimeWindows.morningCheckInHour + 3, 23)
        let recoveryEnd = calendar.date(bySettingHour: morningBufferedHour, minute: 0, second: 0, of: calendarDayStart)!

        // --- Activity window (steps, calories) ---
        // Start: 3h before morning check-in (capture early morning exercise)
        let activityStartHour = max(TimeWindows.morningCheckInHour - 3, 0)
        let activityStart = calendar.date(bySettingHour: activityStartHour, minute: 0, second: 0, of: calendarDayStart)!

        // End: 3h after evening check-in (capture late evening activity)
        let activityEndHour = (TimeWindows.eveningCheckInHour + 3) % 24
        let eveningIsNextDay = TimeWindows.eveningCheckInHour < TimeWindows.morningCheckInHour
        let activityEndDay: Date
        if eveningIsNextDay || TimeWindows.eveningCheckInHour + 3 >= 24 {
            // Evening check-in is past midnight or +3h wraps → place on next calendar day
            activityEndDay = calendar.date(byAdding: .day, value: 1, to: calendarDayStart)!
        } else {
            activityEndDay = calendarDayStart
        }
        let activityEnd = calendar.date(bySettingHour: activityEndHour, minute: 0, second: 0, of: activityEndDay)!

        return MetricsWindows(
            recovery: (start: recoveryStart, end: recoveryEnd),
            activity: (start: activityStart, end: activityEnd)
        )
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

        // Fetch fresh metrics from HealthKit using schedule-aware query windows.
        // Recovery metrics (RHR, HRV, sleep) use an overnight window; activity metrics
        // (steps, calories) use a full-day window with buffers before/after check-ins.
        let userDayStart = timeWindowProvider.currentUserDayStart
        let windows = Self.metricsWindows(for: userDayStart, calendar: Calendar.current)
        let freshMetrics = try? await healthKitService.fetchMetrics(windows: windows)

        var metricsWereUpdated = false
        var scoreWasRecalculated = false

        // Only merge if we got metrics with actual data from HealthKit
        // (denied permissions return a HealthMetrics with all-nil fields, not nil itself)
        if let freshMetrics, freshMetrics.hasAnyData {
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
        }

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
                // Use all fresh metrics (only if there's actual data)
                if freshMetrics.hasAnyData {
                    day.healthMetrics = freshMetrics
                    metricsChanged = true
                }
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
                // Fetch previous day's metrics for ML lagging indicators
                let recentDays = try await dayRepository.getRecentDays(limit: 2)
                let previousDayMetrics = recentDays.count >= 2 ? recentDays[1].healthMetrics : nil

                if let newScore = await readinessService.calculate(
                    from: metrics,
                    energyLevel: energyLevel,
                    previousDayMetrics: previousDayMetrics
                ) {
                    day.readinessScore = newScore
                    scoreRecalculated = true
                }
            }
        }

        // Save if metrics changed, or this is a new day that has meaningful content
        if metricsChanged || (currentDay == nil && (day.hasFirstCheckIn || day.healthMetrics?.hasAnyData == true)) {
            try await dayRepository.save(day)
        }

        return (day, metricsChanged, scoreRecalculated)
    }
}
