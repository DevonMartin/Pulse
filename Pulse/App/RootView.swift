//
//  RootView.swift
//  Pulse
//
//  Created by Devon Martin on 2/24/2026.
//

import SwiftUI

struct RootView: View {

	@Environment(AppContainer.self) private var container

	/// Whether the user has completed the onboarding flow (persisted).
	@AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
	@State private var showOnboarding: Bool

	/// Deep link state for showing check-in sheets
	@State private var showingMorningCheckIn = false
	@State private var showingEveningCheckIn = false

	// MARK: - Initialization

	init() {
		let completed = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
		_showOnboarding = State(initialValue: !completed)
	}

	// MARK: - Body

	var body: some View {
		ZStack {
			mainTabView
			if showOnboarding {
				OnboardingView {
//					hasCompletedOnboarding = true
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
		TabView {
			DashboardView()
				.tabItem {
					Label("Dashboard", systemImage: "heart.text.square")
				}

			HistoryView()
				.tabItem {
					Label("History", systemImage: "chart.line.uptrend.xyaxis")
				}
		}
		.onOpenURL { url in
			handleDeepLink(url)
		}
		.sheet(isPresented: $showingMorningCheckIn) {
			CheckInView {
				NotificationCenter.default.post(name: .checkInCompleted, object: nil)
			}
		}
		.sheet(isPresented: $showingEveningCheckIn) {
			EveningCheckInView {
				NotificationCenter.default.post(name: .checkInCompleted, object: nil)
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

		// Check time window and completion status
		if TimeWindows.isMorningWindow {
			// Morning window: show first check-in if not already done
			if currentDay?.hasFirstCheckIn != true {
				showingMorningCheckIn = true
			}
		} else if TimeWindows.isEveningWindow {
			// Evening window: show second check-in if not already done
			if currentDay?.hasSecondCheckIn != true {
				showingEveningCheckIn = true
			}
		}
		// Outside both windows or already checked in: just open the app
	}
}

#Preview {
    RootView()
        .environment(AppContainer(healthKitService: MockHealthKitService()))
}
