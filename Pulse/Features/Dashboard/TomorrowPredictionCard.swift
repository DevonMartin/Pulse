//
//  TomorrowPredictionCard.swift
//  Pulse
//
//  Created by Devon Martin on 12/6/2025.
//

import SwiftUI

/// Displays tomorrow's predicted readiness score.
///
/// Shows:
/// - Predicted score with description
/// - Trend indicator and advice
/// - Prediction source (rules, blended, or ML)
/// - Confidence level
struct TomorrowPredictionCard: View {
    let prediction: Prediction

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Label("Tomorrow's Forecast", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.purple)

                Spacer()

                ConfidenceBadge(confidence: prediction.confidence)
            }

            // Prediction display
            HStack(spacing: 20) {
                // Predicted score
                VStack(spacing: 4) {
                    Text("\(prediction.predictedScore)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor)
                        .contentTransition(.numericText())

                    Text(prediction.scoreDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Visual indicator
                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: trendIcon)
                            .foregroundStyle(scoreColor)
                        Text(trendText)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    Text(sourceLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            // Explanation
            Text(explanationText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.1), Color.purple.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var scoreColor: Color {
        switch prediction.predictedScore {
        case 0...40: return .red
        case 41...60: return .orange
        case 61...80: return .green
        case 81...100: return .mint
        default: return .gray
        }
    }

    private var trendIcon: String {
        switch prediction.predictedScore {
        case 0...40: return "arrow.down.circle.fill"
        case 41...55: return "minus.circle.fill"
        case 56...75: return "equal.circle.fill"
        case 76...100: return "arrow.up.circle.fill"
        default: return "questionmark.circle.fill"
        }
    }

    private var trendText: String {
        switch prediction.predictedScore {
        case 0...40: return "Rest day ahead"
        case 41...55: return "Take it easy"
        case 56...75: return "Moderate day"
        case 76...100: return "Great day ahead"
        default: return "Unknown"
        }
    }

    private var sourceLabel: String {
        switch prediction.source {
        case .rules: return "Rules-based prediction"
        case .blended: return "Hybrid prediction"
        case .ml: return "Personalized ML"
        }
    }

    private var explanationText: String {
        "Based on today's sleep, HRV, activity, and energy levels"
    }
}

// MARK: - Preview

#Preview {
    TomorrowPredictionCard(
        prediction: Prediction(
            targetDate: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
            predictedScore: 72,
            confidence: .partial,
            source: .rules,
            inputMetrics: nil,
            inputEnergyLevel: 4
        )
    )
    .padding()
}
