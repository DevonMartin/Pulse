//
//  SettingsView.swift
//  Pulse
//
//  Created by Devon Martin on 3/6/2026.
//

import SwiftUI
import UserNotifications

/// App settings for check-in schedule and notification preferences.
///
/// Accessible via the gear icon on the Dashboard navigation bar.
/// Changes to check-in times are saved to App Group UserDefaults
/// (shared with the widget) and trigger notification rescheduling.
struct SettingsView: View {
    @Environment(AppContainer.self) private var container

    // MARK: - Check-In Times

    @State private var morningTime: Date
    @State private var eveningTime: Date

    // MARK: - Notifications

    @State private var notificationsEnabled: Bool
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - Initialization

    init() {
        let calendar = Calendar.current
        let now = Date()

        // Build Date values from stored hour/minute for DatePicker binding
        let morningDate = calendar.date(
            bySettingHour: TimeWindows.morningCheckInHour,
            minute: TimeWindows.morningCheckInMinute,
            second: 0,
            of: now
        ) ?? now
        let eveningDate = calendar.date(
            bySettingHour: TimeWindows.eveningCheckInHour,
            minute: TimeWindows.eveningCheckInMinute,
            second: 0,
            of: now
        ) ?? now

        _morningTime = State(initialValue: morningDate)
        _eveningTime = State(initialValue: eveningDate)

        let defaults = UserDefaults(suiteName: TimeWindows.appGroupID) ?? .standard
        let enabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? true
        _notificationsEnabled = State(initialValue: enabled)
    }

    // MARK: - Body

    var body: some View {
        Form {
            checkInScheduleSection
            notificationsSection
            aboutSection
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshFromDefaults()
        }
        .task {
            notificationStatus = await container.notificationService.authorizationStatus()
        }
    }

    // MARK: - Check-In Schedule

    private var checkInScheduleSection: some View {
        Section {
            DatePicker(
                "Morning Check-In",
                selection: $morningTime,
                displayedComponents: .hourAndMinute
            )
            .onChange(of: morningTime) {
                saveTimesAndReschedule()
            }

            DatePicker(
                "Evening Check-In",
                selection: $eveningTime,
                displayedComponents: .hourAndMinute
            )
            .onChange(of: eveningTime) {
                saveTimesAndReschedule()
            }
        } header: {
            Text("Check-In Schedule")
        } footer: {
            Text("These times control when you're reminded to check in and when the morning and evening windows switch over.")
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section {
            Toggle("Reminders", isOn: $notificationsEnabled)
                .onChange(of: notificationsEnabled) { _, enabled in
                    handleNotificationToggle(enabled)
                }

            if notificationStatus == .denied {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Notifications are disabled in system settings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        } header: {
            Text("Notifications")
        } footer: {
            if notificationStatus != .denied {
                Text("Get reminded at your scheduled check-in times.")
            }
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    /// Refreshes state from UserDefaults so the view always reflects
    /// the latest values (e.g., times set during onboarding).
    private func refreshFromDefaults() {
        let calendar = Calendar.current
        let now = Date()

        morningTime = calendar.date(
            bySettingHour: TimeWindows.morningCheckInHour,
            minute: TimeWindows.morningCheckInMinute,
            second: 0,
            of: now
        ) ?? now
        eveningTime = calendar.date(
            bySettingHour: TimeWindows.eveningCheckInHour,
            minute: TimeWindows.eveningCheckInMinute,
            second: 0,
            of: now
        ) ?? now

        let defaults = UserDefaults(suiteName: TimeWindows.appGroupID) ?? .standard
        notificationsEnabled = defaults.object(forKey: "notificationsEnabled") as? Bool ?? true
    }

    private func saveTimesAndReschedule() {
        let calendar = Calendar.current
        let mh = calendar.component(.hour, from: morningTime)
        let mm = calendar.component(.minute, from: morningTime)
        let eh = calendar.component(.hour, from: eveningTime)
        let em = calendar.component(.minute, from: eveningTime)

        // TODO: Switching between normal and cross-day schedules (e.g., 8 AM → 6 PM)
        // changes userDayStartHour, which shifts the day boundary. Any check-ins
        // already recorded for the current day would be orphaned because
        // currentUserDayStart no longer matches the existing Day's startDate.
        // Consider migrating the current Day record or warning the user.
        TimeWindows.saveCheckInTimes(
            morningHour: mh, morningMinute: mm,
            eveningHour: eh, eveningMinute: em
        )

        Task {
            await container.notificationService.scheduleCheckInReminders()
        }
    }

    private func handleNotificationToggle(_ enabled: Bool) {
        let defaults = UserDefaults(suiteName: TimeWindows.appGroupID) ?? .standard
        defaults.set(enabled, forKey: "notificationsEnabled")

        Task {
            if enabled {
                // Request permission if needed, then schedule
                if notificationStatus == .notDetermined {
                    let granted = await container.notificationService.requestAuthorization()
                    notificationStatus = granted ? .authorized : .denied
                }
                await container.notificationService.scheduleCheckInReminders()
            } else {
                await container.notificationService.cancelAllReminders()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AppContainer(healthKitService: MockHealthKitService()))
}
