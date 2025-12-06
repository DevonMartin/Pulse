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
/// When submitted, it also captures a health snapshot from HealthKit
/// and calculates today's readiness score.
struct CheckInView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    @State private var selectedEnergy: Int = 3
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    /// Called when check-in is successfully saved
    var onComplete: (() -> Void)?

    var body: some View {
        NavigationStack {
            energyInputView
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

            // Calculate today's readiness score using blended rules + ML
            if let score = await container.readinessService.calculate(
                from: todayMetrics,
                energyLevel: selectedEnergy
            ) {
                // Save the score
                try await container.readinessScoreRepository.save(score)
            }

            onComplete?()
            dismiss()
        } catch {
            errorMessage = "Failed to save check-in: \(error.localizedDescription)"
        }

        isSubmitting = false
    }
}

// MARK: - Preview

#Preview {
    CheckInView()
        .environment(AppContainer(healthKitService: MockHealthKitService()))
}
