//
//  TodaysMetricsCard.swift
//  Pulse
//
//  Created by Devon Martin on 12/6/2025.
//

import SwiftUI

/// Displays a summary of today's health metrics in a grid layout.
///
/// Shows:
/// - Resting heart rate
/// - HRV
/// - Sleep duration
/// - Step count
struct TodaysMetricsCard: View {
    let metrics: HealthMetrics?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Metrics")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                MetricTile(
                    title: "Resting HR",
                    value: metrics?.restingHeartRate.map { "\(Int($0))" },
                    unit: "bpm",
                    icon: "heart.fill",
                    color: .red
                )

                MetricTile(
                    title: "HRV",
                    value: metrics?.hrv.map { "\(Int($0))" },
                    unit: "ms",
                    icon: "waveform.path.ecg",
                    color: .pink
                )

                MetricTile(
                    title: "Sleep",
                    value: metrics?.formattedSleepDuration,
                    unit: nil,
                    icon: "bed.double.fill",
                    color: .indigo
                )

                MetricTile(
                    title: "Steps",
                    value: metrics?.steps.map { $0.formatted() },
                    unit: nil,
                    icon: "figure.walk",
                    color: .green
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Metric Tile

/// A single metric tile in the grid.
private struct MetricTile: View {
    let title: String
    let value: String?
    let unit: String?
    let icon: String
    let color: Color

    /// Display value for animation tracking
    private var displayValue: String {
        value ?? "--"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(displayValue)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(value != nil ? .primary : .tertiary)
                    .contentTransition(.numericText())

                if let unit = unit, value != nil {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.3), value: displayValue)
    }
}

// MARK: - Preview

#Preview("With Data") {
    TodaysMetricsCard(
        metrics: HealthMetrics(
            date: Date(),
            restingHeartRate: 58,
            hrv: 45,
            sleepDuration: 7.5 * 3600,
            steps: 8432
        )
    )
    .padding()
}

#Preview("No Data") {
    TodaysMetricsCard(metrics: nil)
        .padding()
}
