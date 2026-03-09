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
	@State private var showSplash: Bool
	@State private var showOnboardingIcon = false
	@State private var splashAnimationDone = false
	@State private var showDashboardSplash: Bool
	@State private var dashboardSplashExpanding = false
	@State private var skipDashboardSplashAnimation = false
	@Namespace private var heroAnimation

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
			_showSplash = State(initialValue: false)
			_showDashboardSplash = State(initialValue: false)
			return
		}
		#endif
		let completed = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
		_showOnboarding = State(initialValue: !completed)
		_showSplash = State(initialValue: !completed)
		_showDashboardSplash = State(initialValue: completed)
	}

	// MARK: - Body

	var body: some View {
		ZStack {
			mainTabView
				.accessibilityHidden(showOnboarding)

			if showOnboarding {
				// Solid base — always covers the dashboard during onboarding
				Color(.systemBackground)
					.ignoresSafeArea()
					.task {
						guard showSplash else { return }
						try? await Task.sleep(for: .milliseconds(800))
						withAnimation(.spring(duration: 0.7)) {
							showSplash = false
						}
						try? await Task.sleep(for: .milliseconds(800))
						showOnboardingIcon = true
						try? await Task.sleep(for: .milliseconds(50))
						splashAnimationDone = true
					}

				// Splash background — fades via direct opacity animation
				Color("LaunchBackground")
					.ignoresSafeArea()
					.opacity(showSplash ? 1 : 0)

				// OnboardingView is always present behind the splash
				OnboardingView(
					heroAnimation: heroAnimation,
					splashActive: showSplash,
					showIcon: showOnboardingIcon
				) {
					hasCompletedOnboarding = true
					withAnimation(.easeInOut) { showOnboarding = false }
				}

				// Floating icon — follows the onboarding anchor via matchedGeometry.
				// During splash (no source) it stays centered at intrinsic size;
				// once the onboarding anchor becomes the source it animates to
				// the page-1 position and scales down to 80×80.
				// GeometryReader + ignoresSafeArea centers on the full screen,
				// matching the system launch screen's centering.
				GeometryReader { proxy in
					Image("LaunchImage")
						.resizable()
						.scaledToFit()
						.frame(
							width: showSplash ? launchIconSize : 80,
							height: showSplash ? launchIconSize : 80
						)
						.matchedGeometryEffect(
							id: "appIcon",
							in: heroAnimation,
							properties: .position,
							isSource: false
						)
						.position(
							x: proxy.size.width / 2,
							y: proxy.size.height / 2
						)
				}
				.ignoresSafeArea()
				.opacity(splashAnimationDone ? 0 : 1)
				.allowsHitTesting(false)
			}

			// Dashboard splash — expanding icon transition when launching
			// straight to the dashboard (onboarding already completed).
			if showDashboardSplash {
				Color("LaunchBackground")
					.ignoresSafeArea()
					.opacity(dashboardSplashExpanding ? 0 : 1)
					.allowsHitTesting(false)
					.task {
						try? await Task.sleep(for: .milliseconds(400))
						guard !skipDashboardSplashAnimation else { return }
						withAnimation(.spring(duration: 0.5)) {
							dashboardSplashExpanding = true
						}
						try? await Task.sleep(for: .milliseconds(600))
						showDashboardSplash = false
					}

				GeometryReader { proxy in
					Image("LaunchImage")
						.resizable()
						.scaledToFit()
						.frame(
							width: dashboardSplashExpanding ? proxy.size.height * 3 : launchIconSize,
							height: dashboardSplashExpanding ? proxy.size.height * 3 : launchIconSize
						)
						.position(
							x: proxy.size.width / 2,
							y: proxy.size.height / 2
						)
				}
				.ignoresSafeArea()
				.allowsHitTesting(false)
			}
		}
	}

	/// Intrinsic size of the launch-screen PDF so the floating icon
	/// starts at the same dimensions the system launch screen used.
	private var launchIconSize: CGFloat {
		UIImage(named: "LaunchImage")?.size.width ?? 80
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

		// Immediately prevent the expanding animation from firing,
		// then remove the splash after a short delay so the sheet
		// has time to present and cover the dashboard.
		skipDashboardSplashAnimation = true
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
			showDashboardSplash = false
		}

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
