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

    // MARK: - Initialization

    init() {
        // Create the SwiftData schema with our entities
        let schema = Schema([
            CheckInEntity.self,
            HealthSnapshotEntity.self,
            ReadinessScoreEntity.self,
            PredictionEntity.self,
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
            .task {
                await container.populateSampleDataIfNeeded()
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
