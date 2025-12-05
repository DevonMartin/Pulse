//
//  EveningCheckInView.swift
//  Pulse
//
//  Created by Devon Martin on 12/4/2025.
//

import SwiftUI

/// The evening check-in flow where users:
/// 1. Rate how their day went (energy level)
/// 2. See tomorrow's prediction generated from today's data
///
/// This creates the prediction → resolution loop:
/// - Evening: Capture end-of-day state, generate prediction
/// - Morning: Compare prediction to actual, capture new state
struct EveningCheckInView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var selectedEnergy: Int = 3
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var generatedPrediction: Prediction?
    @State private var currentStep: Step = .energyInput

    /// Called when check-in is successfully saved
    var onComplete: (() -> Void)?

    private enum Step {
        case energyInput
        case predictionReveal
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                switch currentStep {
                case .energyInput:
                    energyInputView
                case .predictionReveal:
                    predictionRevealView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Energy Input Step

    private var energyInputView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Header
            VStack(spacing: 8) {
                Text("Good Evening")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("How did your day go?")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            // Energy picker
            EnergyPicker(selectedEnergy: $selectedEnergy)
                .padding(.vertical, 24)

            // Energy description
            Text(energyDescription)
                .font(.headline)
                .foregroundStyle(.secondary)
                .animation(.easeInOut, value: selectedEnergy)

            Spacer()

            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Submit button
            Button {
                Task { await submitEveningCheckIn() }
            } label: {
                if isSubmitting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isSubmitting)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    // MARK: - Prediction Reveal Step

    private var predictionRevealView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Header
            VStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 48))
                    .foregroundStyle(.purple)

                Text("Tomorrow's Forecast")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }

            if let prediction = generatedPrediction {
                // Prediction display
                VStack(spacing: 16) {
                    Text("\(prediction.predictedScore)")
                        .font(.system(size: 72, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor(prediction.predictedScore))

                    Text(prediction.scoreDescription)
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    // Trend message
                    HStack(spacing: 8) {
                        Image(systemName: trendIcon(prediction.predictedScore))
                            .foregroundStyle(scoreColor(prediction.predictedScore))
                        Text(trendMessage(prediction.predictedScore))
                            .font(.headline)
                    }
                    .padding()
                    .background(scoreColor(prediction.predictedScore).opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Confidence indicator
                    HStack(spacing: 4) {
                        Text("Confidence:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(confidenceLabel(prediction.confidence))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(confidenceColor(prediction.confidence))
                    }
                }
                .padding()
            } else {
                // No prediction generated
                VStack(spacing: 12) {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)

                    Text("Couldn't generate a prediction")
                        .font(.headline)

                    Text("We need more data to forecast tomorrow's readiness.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }

            Spacer()

            // Explanation
            Text("Check in tomorrow morning to see how accurate this prediction was!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Done button
            Button {
                onComplete?()
                dismiss()
            } label: {
                Text("Done")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    // MARK: - Computed Properties

    private var energyDescription: String {
        switch selectedEnergy {
        case 1: return "Very Low - Exhausted, drained"
        case 2: return "Low - Tired, sluggish day"
        case 3: return "Moderate - Average day"
        case 4: return "High - Productive, good energy"
        case 5: return "Very High - Excellent day"
        default: return ""
        }
    }

    // MARK: - Actions

    private func submitEveningCheckIn() async {
        isSubmitting = true
        errorMessage = nil

        do {
            // Evening check-in only captures energy level - no health snapshot needed
            // (Morning check-in captures sleep/HRV/RHR, prediction uses that data)
            let checkIn = CheckIn(
                type: .evening,
                energyLevel: selectedEnergy,
                healthSnapshot: nil
            )

            try await container.checkInRepository.save(checkIn)

            // Fetch today's metrics for prediction (uses morning's sleep/HRV + today's activity)
            let todayMetrics = try await container.healthKitService.fetchMetrics(for: Date())

            // Get today's readiness score for prediction input
            let todayScore = try? await container.readinessScoreRepository.getScore(for: Date())

            // Generate tomorrow's prediction using:
            // - Today's metrics (sleep from last night, current HRV/RHR, today's steps)
            // - Evening energy level (how the day went)
            // - Today's readiness score as baseline
            generatedPrediction = try await container.predictionService.createPrediction(
                metrics: todayMetrics,
                energyLevel: selectedEnergy,
                todayScore: todayScore?.score
            )

            // Transition to prediction reveal
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep = .predictionReveal
            }
        } catch {
            errorMessage = "Failed to save check-in: \(error.localizedDescription)"
        }

        isSubmitting = false
    }

    // MARK: - Helpers

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 0...40: return .red
        case 41...60: return .orange
        case 61...80: return .green
        case 81...100: return .mint
        default: return .gray
        }
    }

    private func trendIcon(_ score: Int) -> String {
        switch score {
        case 0...40: return "arrow.down.circle.fill"
        case 41...55: return "minus.circle.fill"
        case 56...75: return "equal.circle.fill"
        case 76...100: return "arrow.up.circle.fill"
        default: return "questionmark.circle.fill"
        }
    }

    private func trendMessage(_ score: Int) -> String {
        switch score {
        case 0...40: return "Take it easy tomorrow"
        case 41...55: return "Light activity recommended"
        case 56...75: return "Moderate day ahead"
        case 76...100: return "Great day tomorrow!"
        default: return "Unknown"
        }
    }

    private func confidenceLabel(_ confidence: ReadinessConfidence) -> String {
        switch confidence {
        case .full: return "High"
        case .partial: return "Medium"
        case .limited: return "Low"
        }
    }

    private func confidenceColor(_ confidence: ReadinessConfidence) -> Color {
        switch confidence {
        case .full: return .green
        case .partial: return .orange
        case .limited: return .red
        }
    }
}

// MARK: - Energy Picker (Shared)

/// A custom picker for selecting energy level 1-5.
/// Displays as a row of selectable circles with numbers.
struct EnergyPicker: View {
    @Binding var selectedEnergy: Int

    var body: some View {
        HStack(spacing: 16) {
            ForEach(1...5, id: \.self) { level in
                EnergyButton(
                    level: level,
                    isSelected: selectedEnergy == level
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedEnergy = level
                    }
                }
            }
        }
    }
}

/// A single energy level button.
private struct EnergyButton: View {
    let level: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(level)")
                .font(.title2)
                .fontWeight(.semibold)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(isSelected ? energyColor : Color(.systemGray5))
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.1 : 1.0)
    }

    /// Color gradient from red (1) to mint (5)
    private var energyColor: Color {
        switch level {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        case 5: return .mint
        default: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    EveningCheckInView()
        .environment(AppContainer(healthKitService: MockHealthKitService()))
}
