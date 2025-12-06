//
//  PersonalizationStatus.swift
//  Pulse
//
//  Created by Devon Martin on 12/6/2025.
//

import SwiftUI

/// Displays the ML model's personalization progress.
///
/// Shows users how their readiness predictions are becoming more personalized
/// as the model learns from their data. This helps set expectations and
/// encourages continued check-ins.
///
/// ## States
/// - **Learning** (< 3 examples): Not enough data yet
/// - **Personalizing** (3-29 examples): Actively learning
/// - **Personalized** (30+ examples): Fully trained on user's patterns
struct PersonalizationStatus: View {
    /// Number of complete training examples (days with both AM/PM check-ins)
    let exampleCount: Int

    /// Current ML weight (0-1, how much the prediction relies on ML vs rules)
    let mlWeight: Double

    /// Threshold for full personalization (default 30, can be customized for debug)
    var targetExamples: Int = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)

                Text(statusTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if exampleCount >= 3 && exampleCount < targetExamples {
                    Text("\(exampleCount)/\(targetExamples) days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if exampleCount >= 3 && exampleCount < targetExamples {
                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(statusColor.opacity(0.2))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(statusColor)
                            .frame(width: geometry.size.width * progress)
                    }
                }
                .frame(height: 6)
            }

            Text(statusDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Computed Properties

    private var progress: CGFloat {
        CGFloat(min(exampleCount, targetExamples)) / CGFloat(targetExamples)
    }

    private var statusIcon: String {
        if exampleCount < 3 {
            return "brain"
        } else if exampleCount < targetExamples {
            return "brain.head.profile"
        } else {
            return "brain.fill"
        }
    }

    private var statusTitle: String {
        if exampleCount < 3 {
            return "Learning Your Patterns"
        } else if exampleCount < targetExamples {
            return "Personalizing"
        } else {
            return "Fully Personalized"
        }
    }

    private var statusDescription: String {
        if exampleCount < 3 {
            let remaining = 3 - exampleCount
            let dayWord = remaining == 1 ? "day" : "days"
            return "Complete \(remaining) more \(dayWord) of check-ins to start personalization."
        } else if exampleCount < targetExamples {
            let percentage = Int(mlWeight * 100)
            return "Your score is \(percentage)% personalized to your patterns."
        } else {
            return "Predictions are fully tailored to your personal patterns."
        }
    }

    private var statusColor: Color {
        if exampleCount < 3 {
            return .orange
        } else if exampleCount < targetExamples {
            return .blue
        } else {
            return .green
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        PersonalizationStatus(exampleCount: 0, mlWeight: 0)
        PersonalizationStatus(exampleCount: 2, mlWeight: 0)
        PersonalizationStatus(exampleCount: 15, mlWeight: 0.5)
        PersonalizationStatus(exampleCount: 30, mlWeight: 1.0)
    }
    .padding()
}
