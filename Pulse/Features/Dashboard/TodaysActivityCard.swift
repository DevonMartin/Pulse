//
//  TodaysActivityCard.swift
//  Pulse
//
//  Created by Devon Martin on 12/6/2025.
//

import SwiftUI

/// Displays today's activity metrics (steps and calories burned).
///
/// These metrics update throughout the day, unlike recovery metrics
/// (HRV, RHR, sleep) which are captured in the morning.
struct TodaysActivityCard: View {
    let metrics: HealthMetrics?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Activity")
                .font(.headline)

            HStack(spacing: 12) {
                ActivityTile(
                    title: "Steps",
                    value: metrics?.steps.map { $0.formatted() },
                    icon: "figure.walk",
                    color: .green
                )

                ActivityTile(
                    title: "Active Cal",
                    value: metrics?.activeCalories.map { "\(Int($0))" },
                    icon: "flame.fill",
                    color: .orange
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Activity Tile

/// A single activity metric tile.
private struct ActivityTile: View {
    let title: String
    let value: String?
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

            Text(displayValue)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(value != nil ? .primary : .tertiary)
                .contentTransition(.numericText())
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
    TodaysActivityCard(
        metrics: HealthMetrics(
            date: Date(),
            steps: 8432,
            activeCalories: 342
        )
    )
    .padding()
}

#Preview("No Data") {
    TodaysActivityCard(metrics: nil)
        .padding()
}
