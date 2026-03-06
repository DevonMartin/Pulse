//
//  NotificationService.swift
//  Pulse
//
//  Created by Devon Martin on 3/5/2026.
//

import UserNotifications

/// Protocol for notification scheduling, enabling mock injection in tests/previews.
protocol NotificationServiceProtocol: Sendable {
    /// Requests notification authorization from the user. Returns true if granted.
    func requestAuthorization() async -> Bool

    /// Schedules repeating daily check-in reminders at the user's configured times.
    /// Cancels any existing reminders before scheduling new ones.
    func scheduleCheckInReminders() async

    /// Cancels all pending check-in reminders (e.g., when the user disables notifications).
    func cancelAllReminders() async

    /// Removes delivered notifications from the notification center and clears the app badge.
    /// Call this on app launch or after a check-in so stale notifications don't linger.
    func clearDeliveredNotifications() async

    /// Returns the current notification authorization status.
    func authorizationStatus() async -> UNAuthorizationStatus
}

/// Manages local notification scheduling for check-in reminders.
///
/// Reads check-in times from the same App Group UserDefaults as ``TimeWindows``,
/// then schedules two daily repeating notifications via `UNCalendarNotificationTrigger`.
/// Notifications include a deep link URL (`pulse://checkin`) so tapping them
/// opens the appropriate check-in flow.
///
/// Repeating notifications fire every day regardless of check-in status.
/// If the user has already checked in, tapping the notification opens the app
/// to a contextual "already done" state. Delivered notifications are cleared
/// on app launch and after check-in completion.
final class NotificationService: NotificationServiceProtocol, @unchecked Sendable {

    private let center = UNUserNotificationCenter.current()

    // MARK: - Notification Identifiers

    private static let morningID = "morning-checkin"
    private static let eveningID = "evening-checkin"
    private static let categoryID = "checkin"

    // MARK: - Authorization

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: - Scheduling

    func scheduleCheckInReminders() async {
        // Only schedule if authorized
        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        // Check if user has notifications enabled
        let defaults = UserDefaults(suiteName: TimeWindows.appGroupID) ?? .standard
        let enabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? true
        guard enabled else {
            await cancelAllReminders()
            return
        }

        // Cancel existing before scheduling fresh
        await cancelAllReminders()

        // Morning reminder
        let morningContent = UNMutableNotificationContent()
        morningContent.title = "Time to Check In"
        morningContent.body = "How are you feeling? Start your day with a quick energy check-in."
        morningContent.sound = .default
        morningContent.badge = 1
        morningContent.categoryIdentifier = Self.categoryID
        morningContent.userInfo = ["deepLink": "pulse://checkin"]

        let morningTrigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(
                hour: TimeWindows.morningCheckInHour,
                minute: TimeWindows.morningCheckInMinute
            ),
            repeats: true
        )

        let morningRequest = UNNotificationRequest(
            identifier: Self.morningID,
            content: morningContent,
            trigger: morningTrigger
        )

        // Evening reminder
        let eveningContent = UNMutableNotificationContent()
        eveningContent.title = "Evening Check-In"
        eveningContent.body = "How did your day go? Reflect on your energy to help Pulse learn your patterns."
        eveningContent.sound = .default
        eveningContent.badge = 1
        eveningContent.categoryIdentifier = Self.categoryID
        eveningContent.userInfo = ["deepLink": "pulse://checkin"]

        let eveningTrigger = UNCalendarNotificationTrigger(
            dateMatching: DateComponents(
                hour: TimeWindows.eveningCheckInHour,
                minute: TimeWindows.eveningCheckInMinute
            ),
            repeats: true
        )

        let eveningRequest = UNNotificationRequest(
            identifier: Self.eveningID,
            content: eveningContent,
            trigger: eveningTrigger
        )

        try? await center.add(morningRequest)
        try? await center.add(eveningRequest)
    }

    // MARK: - Cancellation & Clearing

    func cancelAllReminders() async {
        center.removePendingNotificationRequests(
            withIdentifiers: [Self.morningID, Self.eveningID]
        )
    }

    func clearDeliveredNotifications() async {
        center.removeDeliveredNotifications(
            withIdentifiers: [Self.morningID, Self.eveningID]
        )
        try? await center.setBadgeCount(0)
    }
}

// MARK: - Mock for Previews/Tests

/// A no-op notification service for use in previews and tests.
final class MockNotificationService: NotificationServiceProtocol, @unchecked Sendable {
    var mockAuthorizationGranted = true
    var mockStatus: UNAuthorizationStatus = .authorized

    func requestAuthorization() async -> Bool { mockAuthorizationGranted }
    func scheduleCheckInReminders() async {}
    func cancelAllReminders() async {}
    func clearDeliveredNotifications() async {}
    func authorizationStatus() async -> UNAuthorizationStatus { mockStatus }
}
