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
enum TimeWindows {
    // MARK: - Configuration
    // These will eventually be read from UserDefaults in the App Group

    /// Hour when morning check-in window ends (default: 4 PM)
    static var morningWindowEndHour: Int { 16 }

    /// Hour when evening check-in window starts (default: 5 PM)
    static var eveningWindowStartHour: Int { 17 }

    // MARK: - Current State

    static var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }

    static var isMorningWindow: Bool {
        currentHour < morningWindowEndHour
    }

    static var isEveningWindow: Bool {
        currentHour >= eveningWindowStartHour
    }
}
