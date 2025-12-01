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

    /// The app's dependency container, created once at launch.
    @State private var container = AppContainer()

    /// SwiftData model container for persistence.
    private var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(container)
        }
        .modelContainer(sharedModelContainer)
    }
}
