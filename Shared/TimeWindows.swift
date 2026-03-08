//
//  TimeWindows.swift
//  Pulse
//
//  Created by Devon Martin on 12/6/2025.
//

import Foundation

/// Centralized time window logic for check-ins.
/// Used by the main app, widget, and deep link handling.
///
/// Check-in times are user-configurable via App Group UserDefaults,
/// allowing both the app and widget to read the same values.
///
/// Each check-in has a 3-hour buffer window before the scheduled reminder,
/// so the user can check in early. The morning and evening windows can overlap
/// during the buffer zone — UI consumers resolve priority (morning first if
/// the first check-in isn't done).
///
/// Note: All members are nonisolated to allow use from any actor context.
/// These are pure functions based on Date calculations with no mutable state.
enum TimeWindows: Sendable {

    // MARK: - App Group UserDefaults

    /// App Group suite name shared between app and widget.
    nonisolated static let appGroupID = "group.net.devonmartin.Pulse"

    /// Keys for check-in schedule stored in App Group UserDefaults.
    enum Keys {
        nonisolated static let morningCheckInHour = "morningCheckInHour"
        nonisolated static let morningCheckInMinute = "morningCheckInMinute"
        nonisolated static let eveningCheckInHour = "eveningCheckInHour"
        nonisolated static let eveningCheckInMinute = "eveningCheckInMinute"
    }

    /// Shared UserDefaults for the App Group (falls back to .standard if unavailable).
    nonisolated private static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    // MARK: - User-Configured Check-In Times

    /// The hour for the morning (first) check-in. Default: 8 AM.
    nonisolated static var morningCheckInHour: Int {
        let stored = sharedDefaults.object(forKey: Keys.morningCheckInHour) as? Int
        return stored ?? 8
    }

    /// The minute for the morning (first) check-in. Default: 0.
    nonisolated static var morningCheckInMinute: Int {
        let stored = sharedDefaults.object(forKey: Keys.morningCheckInMinute) as? Int
        return stored ?? 0
    }

    /// The hour for the evening (second) check-in. Default: 7 PM (19).
    nonisolated static var eveningCheckInHour: Int {
        let stored = sharedDefaults.object(forKey: Keys.eveningCheckInHour) as? Int
        return stored ?? 19
    }

    /// The minute for the evening (second) check-in. Default: 0.
    nonisolated static var eveningCheckInMinute: Int {
        let stored = sharedDefaults.object(forKey: Keys.eveningCheckInMinute) as? Int
        return stored ?? 0
    }

    /// Saves check-in times to the shared App Group UserDefaults.
    nonisolated static func saveCheckInTimes(
        morningHour: Int, morningMinute: Int,
        eveningHour: Int, eveningMinute: Int
    ) {
        sharedDefaults.set(morningHour, forKey: Keys.morningCheckInHour)
        sharedDefaults.set(morningMinute, forKey: Keys.morningCheckInMinute)
        sharedDefaults.set(eveningHour, forKey: Keys.eveningCheckInHour)
        sharedDefaults.set(eveningMinute, forKey: Keys.eveningCheckInMinute)
    }

    // MARK: - Window Buffer

    /// Hours before the scheduled reminder that the check-in window opens.
    nonisolated static let windowBufferHours = 3

    /// The hour when the morning check-in window opens (3 hours before morning reminder).
    /// Clamped at midnight for AM morning times to avoid wrapping into PM.
    nonisolated static var morningWindowOpensHour: Int {
        max(0, morningCheckInHour - windowBufferHours)
    }

    /// The hour when the evening check-in window opens (3 hours before evening reminder).
    /// Wraps past midnight (e.g., evening at 1 AM → window opens at 10 PM).
    nonisolated static var eveningWindowOpensHour: Int {
        (eveningCheckInHour - windowBufferHours + 24) % 24
    }

    // MARK: - Cross-Day Detection

    /// True when the schedule represents a night-shift pattern where the morning
    /// check-in is in the PM. A morning=11am, evening=12:30am schedule is NOT
    /// cross-day — it's a normal day with a late evening. Only PM morning times
    /// (>= 12) qualify as true cross-day schedules.
    nonisolated static var isCrossDaySchedule: Bool {
        #if DEBUG
        if testingOverrideCrossDaySchedule {
            return true
        }
        #endif
        return morningCheckInHour >= 12 && morningCheckInHour >= eveningCheckInHour
    }

    // MARK: - Testing Overrides (DEBUG only)

    #if DEBUG
    /// Override for UI testing - forces morning window state
    nonisolated static var testingOverrideMorningWindow: Bool? {
        if CommandLine.arguments.contains("--morning-window") {
            return true
        } else if CommandLine.arguments.contains("--evening-window") {
            return false
        }
        return nil
    }

    /// Override for UI testing - forces evening window state
    nonisolated static var testingOverrideEveningWindow: Bool? {
        if CommandLine.arguments.contains("--evening-window") {
            return true
        } else if CommandLine.arguments.contains("--morning-window") {
            return false
        }
        return nil
    }

    /// Override for UI testing - simulates cross-day schedule (e.g., 6 PM - 6 AM)
    /// Use --cross-day-schedule to test scenarios where user day starts at 6 PM
    nonisolated static var testingOverrideCrossDaySchedule: Bool {
        CommandLine.arguments.contains("--cross-day-schedule")
    }
    #endif

    // MARK: - Circular Interval Helper

    /// Checks if `now` falls within the interval [start, end) on a circular 24-hour clock.
    /// Handles intervals that wrap past midnight (e.g., [22, 6) = 10 PM to 6 AM).
    nonisolated private static func isInWindow(now: Int, from start: Int, to end: Int) -> Bool {
        if start <= end {
            return now >= start && now < end
        } else {
            // Wraps past midnight
            return now >= start || now < end
        }
    }

    // MARK: - Current State

    nonisolated static var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }

    /// True when the current time is in the first (morning) check-in window.
    ///
    /// The morning window opens 3 hours before the morning reminder and runs
    /// until the evening check-in hour. This window can overlap with the evening
    /// window during the 3-hour buffer before the evening reminder.
    ///
    /// Examples (morning reminder → evening reminder):
    /// - 8 AM → 7 PM: morning window is 5 AM – 7 PM
    /// - 11 AM → 12:30 AM: morning window is 8 AM – 12 AM (wraps to evening hour)
    /// - 6 PM → 6 AM: morning window is 3 PM – 6 AM (wraps past midnight)
    nonisolated static var isMorningWindow: Bool {
        #if DEBUG
        if let override = testingOverrideMorningWindow {
            return override
        }
        #endif

        return isInWindow(now: currentHour, from: morningWindowOpensHour, to: eveningCheckInHour)
    }

    /// True when the current time is in the second (evening) check-in window.
    ///
    /// The evening window opens 3 hours before the evening reminder and runs
    /// until the morning window opens next day. This window can overlap with the
    /// morning window during the 3-hour buffer before the evening reminder.
    ///
    /// Examples (morning reminder → evening reminder):
    /// - 8 AM → 7 PM: evening window is 4 PM – 5 AM (wraps past midnight)
    /// - 11 AM → 12:30 AM: evening window is 9 PM – 8 AM (wraps past midnight)
    /// - 6 PM → 6 AM: evening window is 3 AM – 3 PM
    nonisolated static var isEveningWindow: Bool {
        #if DEBUG
        if let override = testingOverrideEveningWindow {
            return override
        }
        #endif

        return isInWindow(now: currentHour, from: eveningWindowOpensHour, to: morningWindowOpensHour)
    }

    // MARK: - User Day Boundaries

    /// The hour when a new "user day" begins.
    ///
    /// Aligned with when the morning window opens so that day boundaries and
    /// window boundaries are consistent. For standard schedules where the evening
    /// doesn't wrap past midnight, this is 0 (midnight) to preserve backward
    /// compatibility with existing Day records.
    nonisolated static var userDayStartHour: Int {
        // When the evening check-in hour falls before the morning window opens,
        // the schedule wraps past midnight and needs a non-midnight day boundary
        if eveningCheckInHour < morningWindowOpensHour {
            return morningWindowOpensHour
        }
        return 0
    }

    /// Returns the start of the current "user day".
    /// This accounts for user-defined day boundaries that may span calendar days.
    nonisolated static var currentUserDayStart: Date {
        startOfUserDay(for: Date())
    }

    /// Returns the start of the "user day" that contains the given date.
    ///
    /// For example, if userDayStartHour is 8 (morning=11 AM, evening=12:30 AM):
    /// - 10 AM Monday → user day started Monday 8 AM
    /// - 1 AM Tuesday → user day started Monday 8 AM (evening check-in same day)
    /// - 9 AM Tuesday → user day started Tuesday 8 AM
    nonisolated static func startOfUserDay(for date: Date) -> Date {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)

        // Get the calendar day start
        let calendarDayStart = calendar.startOfDay(for: date)

        if hour >= userDayStartHour {
            // We're past the user day start hour today, so user day started today
            return calendar.date(bySettingHour: userDayStartHour, minute: 0, second: 0, of: calendarDayStart)!
        } else {
            // We're before the user day start hour, so user day started yesterday
            let yesterday = calendar.date(byAdding: .day, value: -1, to: calendarDayStart)!
            return calendar.date(bySettingHour: userDayStartHour, minute: 0, second: 0, of: yesterday)!
        }
    }

    /// Checks if a given date falls within the current "user day".
    nonisolated static func isDateInCurrentUserDay(_ date: Date) -> Bool {
        let dateUserDay = startOfUserDay(for: date)
        let currentUserDay = currentUserDayStart
        return dateUserDay == currentUserDay
    }
}
