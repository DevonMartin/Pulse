//
//  EveningCheckInView.swift
//  Pulse
//
//  Created by Devon Martin on 12/4/2025.
//

import SwiftUI

/// The second check-in flow where users rate their energy throughout the day.
///
/// This captures a retrospective assessment of how energetic the user felt
/// during the day (not how tired they are now). This data is used:
/// - As training labels for the personalized readiness model
/// - To validate how accurate the first check-in's readiness prediction was
struct EveningCheckInView: View {
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
                Text("Good Evening")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("How was your energy today?")
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
                Task { await submitSecondCheckIn() }
            } label: {
                if isSubmitting {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Save Check-In")
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
        case 1: return "Very Low - Struggled all day"
        case 2: return "Low - Sluggish, low motivation"
        case 3: return "Moderate - Typical day"
        case 4: return "High - Energetic, productive"
        case 5: return "Very High - Exceptional energy"
        default: return ""
        }
    }

    // MARK: - Actions

    private func submitSecondCheckIn() async {
        isSubmitting = true
        errorMessage = nil

        do {
            // Get the current Day (should already exist from first check-in)
            var day = try await container.dayRepository.getCurrentDay()

            // Set the second check-in
            day.secondCheckIn = CheckInSlot(energyLevel: selectedEnergy)

            // Save the updated Day
            try await container.dayRepository.save(day)

            onComplete?()
            dismiss()
        } catch {
            errorMessage = "Failed to save check-in: \(error.localizedDescription)"
        }

        isSubmitting = false
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
