//
//  RootView.swift
//  Pulse
//
//  Created by Devon Martin on 2/24/2026.
//

import SwiftUI

struct RootView: View {

	@Environment(AppContainer.self) private var container
	@Environment(\.scenePhase) private var scenePhase

	/// Whether the user has completed the onboarding flow (persisted).
	@AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
	@State private var showOnboarding: Bool

	/// Tab selection tracking for VoiceOver focus management
	@State private var selectedTab = 0

	/// Deep link state for showing check-in sheets
	@State private var showingMorningCheckIn = false
	@State private var showingEveningCheckIn = false

	// MARK: - Initialization

	init() {
		#if DEBUG
		if CommandLine.arguments.contains("--uitesting") {
			_showOnboarding = State(initialValue: false)
			return
		}
		#endif
		let completed = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
		_showOnboarding = State(initialValue: !completed)
	}

	// MARK: - Body

	var body: some View {
		ZStack {
			mainTabView
				.accessibilityHidden(showOnboarding)
			if showOnboarding {
				OnboardingView {
					hasCompletedOnboarding = true
					withAnimation(.easeInOut) { showOnboarding = false }
				}
				.transition(.opacity)
				.id("onboarding")
				.zIndex(1)
			}
		}
	}

	@ViewBuilder
	private var mainTabView: some View {
		TabView(selection: $selectedTab) {
			DashboardView()
				.tabItem {
					Label("Dashboard", systemImage: "heart.text.square")
				}
				.tag(0)

			HistoryView()
				.tabItem {
					Label("History", systemImage: "chart.line.uptrend.xyaxis")
				}
				.tag(1)
		}
		.onOpenURL { url in
			handleDeepLink(url)
		}
		.onChange(of: scenePhase) { _, newPhase in
			if newPhase == .active && hasCompletedOnboarding {
				Task {
					// Re-schedule to keep notification times in sync with settings
					await container.notificationService.scheduleCheckInReminders()

					// Only clear delivered notifications and badge if the user
					// is caught up on check-ins for the current window
					let day = try? await container.dayRepository.getCurrentDayIfExists()
					let pendingCheckIn = (TimeWindows.isMorningWindow && day?.hasFirstCheckIn != true)
						|| (TimeWindows.isEveningWindow && day?.hasSecondCheckIn != true)

					if !pendingCheckIn {
						await container.notificationService.clearDeliveredNotifications()
					}
				}
			}
		}
		.sheet(isPresented: $showingMorningCheckIn) {
			CheckInView {
				NotificationCenter.default.post(name: .checkInCompleted, object: nil)
				Task { await container.notificationService.clearDeliveredNotifications() }
			}
		}
		.sheet(isPresented: $showingEveningCheckIn) {
			EveningCheckInView {
				NotificationCenter.default.post(name: .checkInCompleted, object: nil)
				Task { await container.notificationService.clearDeliveredNotifications() }
			}
		}
	}

	// MARK: - Deep Linking

	private func handleDeepLink(_ url: URL) {
		// Block deep links during onboarding
		guard hasCompletedOnboarding else { return }

		// Expected format: pulse://checkin
		guard url.scheme == "pulse",
			  url.host == "checkin" else {
			return
		}

		// Small delay to ensure the view hierarchy is ready
		// This prevents crashes when cold-launching via deep link
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
			Task {
				await showAppropriateCheckIn()
			}
		}
	}

	private func showAppropriateCheckIn() async {
		// Get current day's state
		let currentDay = try? await container.dayRepository.getCurrentDayIfExists()

		// Morning and evening windows can overlap during the evening buffer.
		// Morning takes priority when the first check-in isn't done.
		if TimeWindows.isMorningWindow && currentDay?.hasFirstCheckIn != true {
			showingMorningCheckIn = true
		} else if TimeWindows.isEveningWindow && currentDay?.hasSecondCheckIn != true {
			showingEveningCheckIn = true
		}
		// Outside both windows or already checked in: just open the app
	}
}

#Preview {
    RootView()
        .environment(AppContainer(healthKitService: MockHealthKitService()))
}
