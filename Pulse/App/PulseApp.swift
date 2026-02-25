//
//  PulseApp.swift
//  Pulse
//
//  Created by Devon Martin on 12/1/2025.
//

import SwiftUI
import SwiftData
import UIKit

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
}

// MARK: - Notifications

extension Notification.Name {
    /// Posted when a check-in completes (from deep link or widget).
    /// DashboardView observes this to refresh its data.
    static let checkInCompleted = Notification.Name("checkInCompleted")
}

// MARK: - App

@main
struct PulseApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// SwiftData model container for persistence.
    private let sharedModelContainer: ModelContainer

    /// The app's dependency container, created once at launch.
    @State private var container: AppContainer

    // MARK: - Initialization

    init() {
        let schema = Schema([
            DayEntity.self,
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
            RootView()
                .environment(container)
        }
        .modelContainer(sharedModelContainer)
    }
}
