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
            // Fetch yesterday's health data for the snapshot
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
            let healthMetrics = try await container.healthKitService.fetchMetrics(for: yesterday)

            // Create and save the check-in
            let checkIn = CheckIn(
                type: .morning,
                energyLevel: selectedEnergy,
                healthSnapshot: healthMetrics
            )

            try await container.checkInRepository.save(checkIn)

            // Success - dismiss and notify
            onComplete?()
            dismiss()
        } catch {
            errorMessage = "Failed to save check-in: \(error.localizedDescription)"
            isSubmitting = false
        }
    }
}

// MARK: - Energy Picker

/// A custom picker for selecting energy level 1-5.
/// Displays as a row of selectable circles with numbers.
private struct EnergyPicker: View {
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
    CheckInView()
        .environment(AppContainer(healthKitService: MockHealthKitService()))
}
