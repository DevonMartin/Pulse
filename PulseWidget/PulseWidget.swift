//
//  PulseWidget.swift
//  PulseWidget
//
//  Created by Devon Martin on 12/1/2025.
//

import WidgetKit
import SwiftUI

// Shared types (ReadinessStyles, WidgetData) are in Shared/ folder
// and must be added to both Pulse and PulseWidgetExtension targets in Xcode

/// Reads widget data from the shared App Group container.
enum WidgetDataReader {
    private static let appGroupIdentifier = "group.net.devonmartin.Pulse"
    private static let fileName = "widget-data.json"

    static func load() -> WidgetData? {
        guard let url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)?
            .appendingPathComponent(fileName) else {
            return nil
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(WidgetData.self, from: data)
        } catch {
            return nil
        }
    }
}

// MARK: - Timeline Provider

struct Provider: TimelineProvider {

    // MARK: - Placeholder
    // Shown in widget gallery or as loading state. Must return instantly.
    func placeholder(in context: Context) -> PulseEntry {
        PulseEntry(
            date: Date(),
            score: 75,
            scoreDescription: "Good",  // 61-80 = Good
            morningCheckInComplete: false,
            eveningCheckInComplete: false,
            personalizationDays: 0,
            personalizationTarget: 30
        )
    }

    // MARK: - Snapshot
    // For previews when adding widget. Should be quick - use cached or sample data.
    func getSnapshot(in context: Context, completion: @escaping (PulseEntry) -> ()) {
        let entry = PulseEntry(
            date: Date(),
            score: 82,
            scoreDescription: "Excellent",  // 81-100 = Excellent
            morningCheckInComplete: true,
            eveningCheckInComplete: false,
            personalizationDays: 12,
            personalizationTarget: 30
        )
        completion(entry)
    }

    // MARK: - Timeline
    // The main method. Returns entries and tells iOS when to refresh.
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // Read real data from the shared App Group container
        let widgetData = WidgetDataReader.load()

        let entry = PulseEntry(
            date: Date(),
            score: widgetData?.score,
            scoreDescription: widgetData?.scoreDescription,
            morningCheckInComplete: widgetData?.morningCheckInComplete ?? false,
            eveningCheckInComplete: widgetData?.eveningCheckInComplete ?? false,
            personalizationDays: widgetData?.personalizationDays ?? 0,
            personalizationTarget: widgetData?.personalizationTarget ?? 30
        )

        // Reload policy: refresh at the start of the next hour as a fallback
        // The main app also triggers immediate refreshes via WidgetCenter
        let nextHour = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextHour))

        completion(timeline)
    }
}

/// The data model for one widget "snapshot"
/// Think of this as the props for your widget view - everything it needs to render
struct PulseEntry: TimelineEntry {
    let date: Date

    // Readiness data
    let score: Int?              // nil if no score calculated yet
    let scoreDescription: String? // "Good", "Fair", etc.

    // Check-in status for today
    let morningCheckInComplete: Bool
    let eveningCheckInComplete: Bool

    // Personalization progress (e.g., "Day 5 of 30")
    let personalizationDays: Int
    let personalizationTarget: Int
}

struct PulseWidgetEntryView: View {
    var entry: PulseEntry

    /// Whether a check-in prompt should trigger a deep link
    private var shouldDeepLink: Bool {
        (TimeWindows.isMorningWindow && !entry.morningCheckInComplete) ||
        (TimeWindows.isEveningWindow && !entry.eveningCheckInComplete)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Priority 1: Morning check-in prompt
            if TimeWindows.isMorningWindow && !entry.morningCheckInComplete {
                checkInPromptView(type: "morning", icon: "sun.max.fill", color: .orange)
            }
            // Priority 2: Evening check-in prompt
            else if TimeWindows.isEveningWindow && !entry.eveningCheckInComplete {
                checkInPromptView(type: "evening", icon: "moon.fill", color: .indigo)
            }
            // Priority 3: Show readiness score if we have one
            else if let score = entry.score, let description = entry.scoreDescription {
                scoreView(score: score, description: description)
            }
            // Priority 4: Day is complete (evening check-in done = day is over)
            else if entry.eveningCheckInComplete {
                dayCompleteView()
            }
            // Fallback: Waiting for data (e.g., first launch)
            else {
                welcomeView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(shouldDeepLink ? URL(string: "pulse://checkin") : nil)
    }

    // MARK: - Subviews

    @ViewBuilder
    private func scoreView(score: Int, description: String) -> some View {
        VStack(spacing: 4) {
            Text("Readiness")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(score)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(colorForScore(score))

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func checkInPromptView(type: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)

            Text("Check in")
                .font(.callout)
                .fontWeight(.medium)

            Text("Tap to log your \(type)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func dayCompleteView() -> some View {
        VStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title)
                .foregroundStyle(.green)

            Text("All done!")
                .font(.callout)
                .fontWeight(.medium)

            Text("Check-ins complete")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func welcomeView() -> some View {
        VStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .font(.title)
                .foregroundStyle(.pink)

            Text("Pulse")
                .font(.callout)
                .fontWeight(.medium)

            Text("Tap to get started")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func colorForScore(_ score: Int) -> Color {
        ReadinessStyles.color(for: score)
    }
}

struct PulseWidget: Widget {
    let kind: String = "PulseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                PulseWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                PulseWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Readiness")
        .description("See your daily readiness score and check-in status.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Previews

#Preview("Readiness Score", as: .systemSmall) {
    PulseWidget()
} timeline: {
    PulseEntry(
        date: .now,
        score: 82,
        scoreDescription: "Excellent",  // 81-100 = Excellent
        morningCheckInComplete: true,
        eveningCheckInComplete: false,
        personalizationDays: 12,
        personalizationTarget: 30
    )
}

#Preview("Morning Check-in", as: .systemSmall) {
    PulseWidget()
} timeline: {
    PulseEntry(
        date: .now,
        score: nil,
        scoreDescription: nil,
        morningCheckInComplete: false,
        eveningCheckInComplete: false,
        personalizationDays: 5,
        personalizationTarget: 30
    )
}

#Preview("Evening Check-in", as: .systemSmall) {
    PulseWidget()
} timeline: {
    // Simulates evening: morning done, have score, evening not done
    PulseEntry(
        date: .now,
        score: 78,
        scoreDescription: "Good",  // 61-80 = Good
        morningCheckInComplete: true,
        eveningCheckInComplete: false,
        personalizationDays: 10,
        personalizationTarget: 30
    )
}

#Preview("Day Complete", as: .systemSmall) {
    PulseWidget()
} timeline: {
    PulseEntry(
        date: .now,
        score: 85,
        scoreDescription: "Excellent",  // 81-100 = Excellent
        morningCheckInComplete: true,
        eveningCheckInComplete: true,
        personalizationDays: 15,
        personalizationTarget: 30
    )
}
