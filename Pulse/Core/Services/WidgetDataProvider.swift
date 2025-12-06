//
//  WidgetDataProvider.swift
//  Pulse
//
//  Created by Devon Martin on 12/6/2025.
//

import Foundation
import WidgetKit

// WidgetData is defined in Shared/WidgetData.swift

/// Handles reading/writing widget data to the shared App Group container.
/// Used by the main app to write data, and by the widget to read it.
enum WidgetDataProvider {
    private static let appGroupIdentifier = "group.net.devonmartin.Pulse"
    private static let fileName = "widget-data.json"

    /// URL for the shared JSON file in the App Group container
    private static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(fileName)
    }

    // MARK: - Write (called by main app)

    /// Saves widget data to the shared container and triggers a widget refresh.
    static func save(_ data: WidgetData) {
        guard let url = fileURL else {
            print("WidgetDataProvider: Could not get App Group container URL")
            return
        }

        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: url)

            // Tell iOS to refresh the widget immediately
            WidgetCenter.shared.reloadTimelines(ofKind: "PulseWidget")
        } catch {
            print("WidgetDataProvider: Failed to save widget data: \(error)")
        }
    }

    // MARK: - Read (called by widget extension)

    /// Loads widget data from the shared container.
    /// Returns nil if no data exists or if reading fails.
    static func load() -> WidgetData? {
        guard let url = fileURL else {
            print("WidgetDataProvider: Could not get App Group container URL")
            return nil
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(WidgetData.self, from: data)
        } catch {
            print("WidgetDataProvider: Failed to load widget data: \(error)")
            return nil
        }
    }
}
