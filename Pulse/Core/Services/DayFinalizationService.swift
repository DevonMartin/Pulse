//
//  DayFinalizationService.swift
//  Pulse
//
//  Created by Devon Martin on 3/10/2026.
//

import Foundation

/// Finalizes past days by fetching their complete activity metrics from HealthKit.
///
/// ## Problem
/// Steps and active calories are only fetched while the app is foregrounded. If a user
/// does their evening check-in at 7 PM then walks 5,000 more steps without reopening
/// the app, those steps are never recorded for that day.
///
/// ## Solution
/// On each app foreground, this service checks for past days that haven't been finalized
/// and fetches their full-day step/calorie totals from HealthKit retroactively. Recovery
/// metrics (RHR, HRV, sleep) are preserved — only activity metrics are updated.
///
/// ## Trigger
/// Called from `RootView.onChange(of: scenePhase)` when the app becomes active.
actor DayFinalizationService {

    // MARK: - Dependencies

    private let dayRepository: DayRepositoryProtocol
    private let healthKitService: HealthKitServiceProtocol
    private let readinessService: ReadinessServiceProtocol

    // MARK: - Initialization

    init(
        dayRepository: DayRepositoryProtocol,
        healthKitService: HealthKitServiceProtocol,
        readinessService: ReadinessServiceProtocol
    ) {
        self.dayRepository = dayRepository
        self.healthKitService = healthKitService
        self.readinessService = readinessService
    }

    // MARK: - Finalization

    /// Checks for unfinalized past days and fetches their final activity metrics.
    ///
    /// For each unfinalized day:
    /// 1. Fetches the full-day step/calorie totals from HealthKit
    /// 2. Merges activity metrics (preserving existing recovery metrics)
    /// 3. Marks the day as finalized
    ///
    /// Days are marked finalized even if HealthKit returns empty data,
    /// preventing infinite retry loops for days where no data exists.
    /// If the HealthKit fetch fails (transient error), the day is skipped
    /// and retried on the next foreground.
    ///
    /// - Returns: The number of days that were finalized.
    @discardableResult
    func finalizePastDays() async -> Int {
        guard let unfinalizedDays = try? await dayRepository.getUnfinalizedPastDays(),
              !unfinalizedDays.isEmpty else {
            return 0
        }

        let calendar = Calendar.current
        var finalizedCount = 0

        for var day in unfinalizedDays {
            // Fetch full-day metrics from HealthKit using schedule-aware windows
            let dayStart = day.startDate
            let windows = DayService.metricsWindows(for: dayStart, calendar: calendar)

            let finalMetrics: HealthMetrics
            do {
                finalMetrics = try await healthKitService.fetchMetrics(windows: windows)
            } catch {
                // Transient HealthKit failure — skip this day and retry next foreground
                continue
            }

            if finalMetrics.hasAnyData {
                if let existing = day.healthMetrics {
                    // Merge activity only — preserve recovery metrics (RHR, HRV, sleep)
                    let (merged, _) = existing.mergingActivityOnly(with: finalMetrics)
                    day.healthMetrics = merged
                } else {
                    // No existing metrics — store just the activity data
                    day.healthMetrics = HealthMetrics(
                        date: dayStart,
                        steps: finalMetrics.steps,
                        activeCalories: finalMetrics.activeCalories
                    )
                }
            }

            day.isActivityFinalized = true
            try? await dayRepository.save(day)
            finalizedCount += 1
        }

        return finalizedCount
    }

    // MARK: - One-Time Recalculation

    /// Re-fetches all metrics for every past day using corrected query windows.
    ///
    /// This is a one-time migration that fully replaces health metrics (not a merge)
    /// because the previous query windows were incorrect, producing bad data
    /// (e.g., sleep queried during daytime instead of overnight).
    ///
    /// For days with a morning check-in, readiness scores are also recalculated
    /// since they depend on the corrected health data.
    ///
    /// - Returns: The number of days that were recalculated.
    @discardableResult
    func recalculateAllMetrics() async -> Int {
        guard let allDays = try? await dayRepository.getAllPastDays(),
              !allDays.isEmpty else {
            return 0
        }

        let calendar = Calendar.current
        var recalculatedCount = 0
        var previousDayMetrics: HealthMetrics?

        for var day in allDays {
            let dayStart = day.startDate
            let windows = DayService.metricsWindows(for: dayStart, calendar: calendar)

            let freshMetrics: HealthMetrics
            do {
                freshMetrics = try await healthKitService.fetchMetrics(windows: windows)
            } catch {
                // Transient HealthKit failure — skip this day
                previousDayMetrics = day.healthMetrics
                continue
            }

            if freshMetrics.hasAnyData {
                // Full replacement — old data was captured with wrong query windows
                day.healthMetrics = HealthMetrics(
                    date: dayStart,
                    restingHeartRate: freshMetrics.restingHeartRate,
                    hrv: freshMetrics.hrv,
                    sleepDuration: freshMetrics.sleepDuration,
                    steps: freshMetrics.steps,
                    activeCalories: freshMetrics.activeCalories
                )

                // Recalculate readiness score if this day had a morning check-in
                if let energyLevel = day.firstCheckIn?.energyLevel {
                    if let newScore = await readinessService.calculate(
                        from: day.healthMetrics,
                        energyLevel: energyLevel,
                        previousDayMetrics: previousDayMetrics
                    ) {
                        day.readinessScore = newScore
                    }
                }
            }

            day.isActivityFinalized = true
            try? await dayRepository.save(day)
            previousDayMetrics = day.healthMetrics
            recalculatedCount += 1
        }

        return recalculatedCount
    }
}
