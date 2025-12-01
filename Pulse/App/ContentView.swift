//
//  ContentView.swift
//  Pulse
//
//  Created by Devon Martin on 12/1/2025.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppContainer.self) private var container

    @State private var metrics: HealthMetrics?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading health data...")
                } else if let error = errorMessage {
                    ContentUnavailableView(
                        "Unable to Load Data",
                        systemImage: "heart.slash",
                        description: Text(error)
                    )
                } else if let metrics = metrics {
                    HealthMetricsView(metrics: metrics)
                } else {
                    ContentUnavailableView(
                        "No Health Data",
                        systemImage: "heart.text.square",
                        description: Text("No health data available for today.")
                    )
                }
            }
            .navigationTitle("Today's Metrics")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await loadMetrics() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
        }
        .task {
            await requestAuthorizationAndLoadMetrics()
        }
    }

    // MARK: - Data Loading

    private func requestAuthorizationAndLoadMetrics() async {
        do {
            try await container.healthKitService.requestAuthorization()
            await loadMetrics()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func loadMetrics() async {
        isLoading = true
        errorMessage = nil

        do {
            metrics = try await container.healthKitService.fetchMetrics(for: Date())
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Health Metrics View

/// Displays health metrics in a clean, readable format.
private struct HealthMetricsView: View {
    let metrics: HealthMetrics

    var body: some View {
        List {
            Section("Heart") {
                MetricRow(
                    title: "Resting Heart Rate",
                    value: metrics.restingHeartRate.map { "\(Int($0)) bpm" },
                    icon: "heart.fill",
                    color: .red
                )
                MetricRow(
                    title: "Heart Rate Variability",
                    value: metrics.hrv.map { "\(Int($0)) ms" },
                    icon: "waveform.path.ecg",
                    color: .pink
                )
            }

            Section("Sleep") {
                MetricRow(
                    title: "Sleep Duration",
                    value: metrics.formattedSleepDuration,
                    icon: "bed.double.fill",
                    color: .indigo
                )
            }

            Section("Activity") {
                MetricRow(
                    title: "Steps",
                    value: metrics.steps.map { "\($0.formatted())" },
                    icon: "figure.walk",
                    color: .green
                )
                MetricRow(
                    title: "Active Calories",
                    value: metrics.activeCalories.map { "\(Int($0)) kcal" },
                    icon: "flame.fill",
                    color: .orange
                )
            }
        }
    }
}

// MARK: - Metric Row

/// A single row displaying a health metric with an icon.
private struct MetricRow: View {
    let title: String
    let value: String?
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)

            Text(title)
                .foregroundStyle(.primary)

            Spacer()

            if let value = value {
                Text(value)
                    .foregroundStyle(.secondary)
                    .fontWeight(.medium)
            } else {
                Text("--")
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environment(AppContainer(healthKitService: MockHealthKitService()))
}
