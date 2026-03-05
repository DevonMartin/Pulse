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
/// Supports cross-day schedules (e.g., night shift: 6 PM → 6 AM).
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

    // MARK: - Cross-Day Detection

    /// True when the morning check-in hour is at or after the evening hour,
    /// indicating the user's "day" spans two calendar days (e.g., night shift).
    nonisolated static var isCrossDaySchedule: Bool {
        #if DEBUG
        if testingOverrideCrossDaySchedule {
            return true
        }
        #endif
        return morningCheckInHour >= eveningCheckInHour
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

    // MARK: - Current State

    nonisolated static var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }

    /// True when the current time is in the first (morning) check-in window.
    ///
    /// - **Normal schedule**: morning window is any hour before the evening check-in hour.
    /// - **Cross-day schedule**: morning window wraps around midnight
    ///   (e.g., morning=18, evening=6 → hours 18-23 and 0-5 are morning).
    nonisolated static var isMorningWindow: Bool {
        #if DEBUG
        if let override = testingOverrideMorningWindow {
            return override
        }
        #endif

        let hour = currentHour
        if isCrossDaySchedule {
            return hour >= morningCheckInHour || hour < eveningCheckInHour
        } else {
            return hour < eveningCheckInHour
        }
    }

    /// True when the current time is in the second (evening) check-in window.
    ///
    /// - **Normal schedule**: evening window is any hour at or after the evening check-in hour.
    /// - **Cross-day schedule**: evening window is between evening and morning hours
    ///   (e.g., morning=18, evening=6 → hours 6-17 are evening).
    nonisolated static var isEveningWindow: Bool {
        #if DEBUG
        if let override = testingOverrideEveningWindow {
            return override
        }
        #endif

        let hour = currentHour
        if isCrossDaySchedule {
            return hour >= eveningCheckInHour && hour < morningCheckInHour
        } else {
            return hour >= eveningCheckInHour
        }
    }

    // MARK: - User Day Boundaries

    /// The hour when a new "user day" begins.
    /// For normal schedules this is 0 (midnight).
    /// For cross-day schedules it matches the morning check-in hour
    /// (e.g., morning at 6 PM → user day starts at 18:00).
    nonisolated static var userDayStartHour: Int {
        if isCrossDaySchedule {
            return morningCheckInHour
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
    /// For example, if userDayStartHour is 18 (6 PM):
    /// - 10 PM Monday → user day started Monday 6 PM
    /// - 2 AM Tuesday → user day started Monday 6 PM
    /// - 7 PM Tuesday → user day started Tuesday 6 PM
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
