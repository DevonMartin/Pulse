//
//  PulseApp.swift
//  Pulse
//
//  Created by Devon Martin on 12/1/2025.
//

import SwiftUI
import SwiftData

@main
struct PulseApp: App {

    // MARK: - Dependencies

    /// SwiftData model container for persistence.
    private let sharedModelContainer: ModelContainer

    /// The app's dependency container, created once at launch.
    @State private var container: AppContainer

    /// Deep link state for showing check-in sheets
    @State private var showingMorningCheckIn = false
    @State private var showingEveningCheckIn = false

    // MARK: - Initialization

    init() {
        // Create the SwiftData schema with our entities
        let schema = Schema([
            DayEntity.self,
            ReadinessScoreEntity.self,
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none  // Temporarily disabled until schema is stable
        )

        do {
            let modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            self.sharedModelContainer = modelContainer
            self._container = State(initialValue: AppContainer(modelContainer: modelContainer))
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
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
            .environment(container)
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .sheet(isPresented: $showingMorningCheckIn) {
                CheckInView {}
                    .environment(container)
            }
            .sheet(isPresented: $showingEveningCheckIn) {
                EveningCheckInView {}
                    .environment(container)
            }
        }
        .modelContainer(sharedModelContainer)
    }

    // MARK: - Deep Linking

    private func handleDeepLink(_ url: URL) {
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
