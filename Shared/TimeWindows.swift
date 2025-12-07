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
/// TODO: Make these user-configurable by storing in App Group
/// and reading values here instead of using hardcoded defaults.
///
/// Note: All members are nonisolated to allow use from any actor context.
/// These are pure functions based on Date calculations with no mutable state.
enum TimeWindows: Sendable {
    // MARK: - Configuration
    // These will eventually be read from UserDefaults in the App Group

    /// Hour when morning check-in window ends (default: 4 PM)
    nonisolated static var morningWindowEndHour: Int { 16 }

    /// Hour when evening check-in window starts (default: 5 PM)
    nonisolated static var eveningWindowStartHour: Int { 17 }

    // MARK: - Current State

    nonisolated static var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }

    nonisolated static var isMorningWindow: Bool {
        currentHour < morningWindowEndHour
    }

    nonisolated static var isEveningWindow: Bool {
        currentHour >= eveningWindowStartHour
    }

    // MARK: - User Day Boundaries

    /// The hour when a new "user day" begins.
    /// For default settings (midnight), this is 0.
    /// If user's first check-in window starts at 6 PM, this would be 18.
    nonisolated static var userDayStartHour: Int { 0 }

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
