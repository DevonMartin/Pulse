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
///
/// When no score is available, shows a placeholder state with contextual messaging.
struct ReadinessScoreCard: View {
    let day: Day

    private var score: ReadinessScore? { day.readinessScore }

    var body: some View {
        VStack(spacing: 16) {
            // Header with confidence badge
            HStack {
                Text("Today's Readiness")
                    .font(.headline)

                Spacer()

                if let score = score {
                    ConfidenceBadge(confidence: score.confidence)
                }
            }

            if let score = score {
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
            } else {
                // Placeholder state
                HStack(alignment: .center, spacing: 24) {
                    // Empty score circle
                    ZStack {
                        Circle()
                            .stroke(Color(.tertiarySystemFill), lineWidth: 12)

                        VStack(spacing: 2) {
                            Text("--")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)

                            Text(placeholderLabel)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(width: 120, height: 120)

                    // Placeholder breakdown
                    VStack(alignment: .leading, spacing: 8) {
                        BreakdownRow(label: "Resting HR", score: nil, color: .red)
                        BreakdownRow(label: "HRV", score: nil, color: .pink)
                        BreakdownRow(label: "Sleep", score: nil, color: .indigo)
                        BreakdownRow(label: "Energy", score: nil, color: .orange)
                    }
                }

                Text(placeholderMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var scoreColor: Color {
        if let score = score {
            return ReadinessStyles.color(for: score.score)
        }
        return .gray
    }

    /// Returns a short contextual label for the score circle
    private var placeholderLabel: String {
        let hasMorning = day.hasFirstCheckIn
        let isMorningWindow = TimeWindows.isMorningWindow

        if !hasMorning && isMorningWindow {
            return "Pending"
        } else if !hasMorning && !isMorningWindow {
            return "Missed"
        } else {
            return "Loading"
        }
    }

    /// Returns a contextual message based on time window and check-in status
    private var placeholderMessage: String {
        let hasMorning = day.hasFirstCheckIn
        let isMorningWindow = TimeWindows.isMorningWindow

        if !hasMorning && isMorningWindow {
            // Morning window, no morning check-in yet
            return "Complete your morning check-in to see your readiness score"
        } else if !hasMorning && !isMorningWindow {
            // Past morning window, missed morning check-in
            return "Morning check-in window has passed. Check in tomorrow morning for your score."
        } else {
            // Has morning check-in but no score (shouldn't normally happen)
            return "Calculating your readiness score..."
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

#Preview("With Score") {
    ReadinessScoreCard(
        day: Day(
            startDate: Date(),
            firstCheckIn: CheckInSlot(energyLevel: 4),
            readinessScore: ReadinessScore(
                date: Date(),
                score: 75,
                breakdown: ReadinessBreakdown(
                    hrvScore: 70,
                    restingHeartRateScore: 80,
                    sleepScore: 85,
                    energyScore: 65
                ),
                confidence: .full
            )
        )
    )
    .padding()
}

#Preview("No Score - Morning") {
    ReadinessScoreCard(
        day: Day(startDate: Date())
    )
    .padding()
}

#Preview("No Score - Evening Only") {
    ReadinessScoreCard(
        day: Day(
            startDate: Date(),
            secondCheckIn: CheckInSlot(energyLevel: 3)
        )
    )
    .padding()
}
