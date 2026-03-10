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

    // MARK: - Initialization

    init(dayRepository: DayRepositoryProtocol, healthKitService: HealthKitServiceProtocol) {
        self.dayRepository = dayRepository
        self.healthKitService = healthKitService
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
            // Fetch full-day metrics from HealthKit for this day's date range
            let dayStart = day.startDate
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                continue
            }

            let finalMetrics: HealthMetrics
            do {
                finalMetrics = try await healthKitService.fetchMetrics(from: dayStart, to: dayEnd)
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
}
