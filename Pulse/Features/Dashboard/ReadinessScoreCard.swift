//
//  ReadinessScoreCard.swift
//  Pulse
//
//  Created by Devon Martin on 12/6/2025.
//

import SwiftUI

/// Displays the calculated readiness score prominently.
///
/// Shows:
/// - Main score in a circular progress indicator
/// - Score description (e.g., "Good", "Excellent")
/// - Breakdown bars for each component (RHR, HRV, Sleep, Energy)
/// - Personalized recommendation
struct ReadinessScoreCard: View {
    let score: ReadinessScore

    var body: some View {
        VStack(spacing: 16) {
            // Header with confidence badge
            HStack {
                Text("Today's Readiness")
                    .font(.headline)

                Spacer()

                ConfidenceBadge(confidence: score.confidence)
            }

            // Main score display
            HStack(alignment: .center, spacing: 24) {
                // Score circle
                ZStack {
                    Circle()
                        .stroke(scoreColor.opacity(0.2), lineWidth: 12)

                    Circle()
                        .trim(from: 0, to: CGFloat(score.score) / 100)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text("\(score.score)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())

                        Text(score.scoreDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 120, height: 120)
                .animation(.easeInOut(duration: 0.5), value: score.score)

                // Breakdown
                VStack(alignment: .leading, spacing: 8) {
                    BreakdownRow(
                        label: "Resting HR",
                        score: score.breakdown.restingHeartRateScore,
                        color: .red
                    )
                    BreakdownRow(
                        label: "HRV",
                        score: score.breakdown.hrvScore,
                        color: .pink
                    )
                    BreakdownRow(
                        label: "Sleep",
                        score: score.breakdown.sleepScore,
                        color: .indigo
                    )
                    BreakdownRow(
                        label: "Energy",
                        score: score.breakdown.energyScore,
                        color: .orange
                    )
                }
            }

            // Recommendation
            Text(score.recommendation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var scoreColor: Color {
        switch score.score {
        case 0...40: return .red
        case 41...60: return .orange
        case 61...80: return .green
        case 81...100: return .mint
        default: return .gray
        }
    }
}

// MARK: - Breakdown Row

/// Shows a single breakdown row with label and score bar.
private struct BreakdownRow: View {
    let label: String
    let score: Int?
    let color: Color

    /// Computed property to track for animation
    private var animatableScore: Int {
        score ?? 0
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            if let score = score {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color.opacity(0.2))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: geometry.size.width * CGFloat(score) / 100)
                    }
                }
                .frame(height: 8)

                Text("\(score)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, alignment: .trailing)
                    .contentTransition(.numericText())
            } else {
                Text("--")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: animatableScore)
    }
}

// MARK: - Preview

#Preview {
    ReadinessScoreCard(
        score: ReadinessScore(
            date: Date(),
            score: 75,
			breakdown: ReadinessBreakdown(
				hrvScore: 70,
				restingHeartRateScore: 80,
				sleepScore: 85,
				energyScore: 65
			), confidence: .full
        )
    )
    .padding()
}
