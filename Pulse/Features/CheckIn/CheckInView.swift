//
//  CheckInView.swift
//  Pulse
//
//  Created by Devon Martin on 12/1/2025.
//

import SwiftUI

/// The morning check-in view where users rate their energy level.
///
/// This captures the subjective component of our readiness data.
/// When submitted, it also captures a health snapshot from HealthKit.
///
/// If there's a prediction for today (made yesterday), we show the
/// prediction feedback after submitting the check-in.
struct CheckInView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var selectedEnergy: Int = 3
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var todaysPrediction: Prediction?
    @State private var actualScore: Int?
    @State private var currentStep: Step = .energyInput
    @State private var isLoadingPrediction = true

    /// Called when check-in is successfully saved
    var onComplete: (() -> Void)?

    private enum Step {
        case energyInput
        case predictionFeedback
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                switch currentStep {
                case .energyInput:
                    energyInputView
                case .predictionFeedback:
                    predictionFeedbackView
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
            .task {
                await loadTodaysPrediction()
            }
        }
    }

    // MARK: - Energy Input Step

    private var energyInputView: some View {
        VStack(spacing: 32) {
            Spacer()

            // Header
            VStack(spacing: 8) {
                Text("Good Morning")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("How's your energy level today?")
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
                Task { await submitCheckIn() }
            } label: {
                if isSubmitting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Check In")
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

    // MARK: - Prediction Feedback Step

    private var predictionFeedbackView: some View {
        VStack(spacing: 24) {
            Spacer()

            if let prediction = todaysPrediction, let actual = actualScore {
                let error = prediction.predictedScore - actual
                let absError = abs(error)

                // Header based on accuracy
                VStack(spacing: 8) {
                    Image(systemName: accuracyIcon(absError))
                        .font(.system(size: 48))
                        .foregroundStyle(accuracyColor(absError))

                    Text(accuracyTitle(absError))
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text(accuracySubtitle(absError))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                // Score comparison
                HStack(spacing: 32) {
                    // Predicted
                    VStack(spacing: 4) {
                        Text("Predicted")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("\(prediction.predictedScore)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(.purple)
                    }

                    // Arrow
                    Image(systemName: "arrow.right")
                        .font(.title)
                        .foregroundStyle(.secondary)

                    // Actual
                    VStack(spacing: 4) {
                        Text("Actual")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("\(actual)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(scoreColor(actual))
                    }
                }
                .padding(.vertical)

                // Error badge
                HStack(spacing: 8) {
                    Text(error >= 0 ? "+\(error)" : "\(error)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(accuracyColor(absError))

                    Text("points off")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(accuracyColor(absError).opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            } else {
                // No prediction to compare
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)

                    Text("Check-in Complete!")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Your readiness score has been calculated.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Tip for next time
            if todaysPrediction != nil {
                Text("Complete an evening check-in tonight for tomorrow's prediction!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

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
        case 1: return "Very Low - Exhausted, need rest"
        case 2: return "Low - Tired, low motivation"
        case 3: return "Moderate - Average, functional"
        case 4: return "High - Energized, ready to go"
        case 5: return "Very High - Peak energy, unstoppable"
        default: return ""
        }
    }

    // MARK: - Data Loading

    private func loadTodaysPrediction() async {
        do {
            todaysPrediction = try await container.predictionService.getTodaysPrediction()
        } catch {
            print("Failed to load today's prediction: \(error)")
        }
        isLoadingPrediction = false
    }

    // MARK: - Actions

    private func submitCheckIn() async {
        isSubmitting = true
        errorMessage = nil

        do {
            // Fetch today's health data for the snapshot
            let todayMetrics = try await container.healthKitService.fetchMetrics(for: Date())

            // Create and save the check-in
            let checkIn = CheckIn(
                type: .morning,
                energyLevel: selectedEnergy,
                healthSnapshot: todayMetrics
            )

            try await container.checkInRepository.save(checkIn)

            // Calculate today's readiness score
            if let score = container.readinessCalculator.calculate(
                from: todayMetrics,
                energyLevel: selectedEnergy
            ) {
                actualScore = score.score

                // Save the score
                try await container.readinessScoreRepository.save(score)

                // Resolve today's prediction with actual score
                if todaysPrediction != nil {
                    try await container.predictionService.resolveTodaysPrediction(actualScore: score.score)
                }
            }

            // If we have a prediction to show feedback for, transition to that step
            if todaysPrediction != nil && actualScore != nil {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentStep = .predictionFeedback
                }
            } else {
                // No prediction, just complete
                onComplete?()
                dismiss()
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

    private func accuracyIcon(_ error: Int) -> String {
        switch error {
        case 0...5: return "star.fill"
        case 6...10: return "hand.thumbsup.fill"
        case 11...15: return "face.smiling"
        default: return "arrow.triangle.2.circlepath"
        }
    }

    private func accuracyColor(_ error: Int) -> Color {
        switch error {
        case 0...5: return .mint
        case 6...10: return .green
        case 11...15: return .orange
        default: return .red
        }
    }

    private func accuracyTitle(_ error: Int) -> String {
        switch error {
        case 0...5: return "Excellent!"
        case 6...10: return "Nice!"
        case 11...15: return "Getting There"
        default: return "Learning..."
        }
    }

    private func accuracySubtitle(_ error: Int) -> String {
        switch error {
        case 0...5: return "Your prediction was spot on!"
        case 6...10: return "Pretty close prediction!"
        case 11...15: return "We're still learning your patterns"
        default: return "More data will improve predictions"
        }
    }
}

// MARK: - Preview

#Preview {
    CheckInView()
        .environment(AppContainer(healthKitService: MockHealthKitService()))
}
