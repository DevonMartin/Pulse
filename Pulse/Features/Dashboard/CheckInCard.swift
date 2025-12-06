//
//  CheckInCard.swift
//  Pulse
//
//  Created by Devon Martin on 12/6/2025.
//

import SwiftUI

/// A single contextual check-in card that shows the appropriate state based on:
/// - Time of day (morning vs evening window)
/// - Check-in completion status (morning done, evening done, both done)
///
/// States:
/// - `morningPending`: Morning window, no check-in yet
/// - `waitingForEvening`: Morning done, waiting for evening window
/// - `eveningPending`: Evening window, can check in
/// - `allComplete`: Both check-ins done
/// - `morningMissed`: Past morning window, no morning check-in
struct CheckInCard: View {
    let morningCheckIn: CheckIn?
    let eveningCheckIn: CheckIn?
    let isLoading: Bool
    let isMorningWindow: Bool
    let isEveningWindow: Bool
    let onMorningCheckInTapped: () -> Void
    let onEveningCheckInTapped: () -> Void

    /// Determines what state to show
    private var cardState: CardState {
        if isLoading { return .loading }

        let hasMorning = morningCheckIn != nil
        let hasEvening = eveningCheckIn != nil

        // Evening done - show completion (regardless of morning status)
        if hasEvening {
            return .allComplete
        }

        // Evening window, evening not done
        if isEveningWindow {
            return .eveningPending
        }

        // Morning window
        if isMorningWindow {
            if !hasMorning {
                return .morningPending
            } else {
                return .waitingForEvening
            }
        }

        // Between windows (4-5 PM gap)
        if hasMorning {
            return .waitingForEvening
        }

        // Fallback: morning not done, not in morning window, not evening yet
        return .morningMissed
    }

    private enum CardState {
        case loading
        case morningPending      // Morning window, no check-in yet
        case waitingForEvening   // Morning done, waiting for evening window
        case eveningPending      // Evening window, can check in
        case allComplete         // Both check-ins done
        case morningMissed       // Past morning window, no morning check-in
    }

    var body: some View {
        VStack(spacing: 16) {
            switch cardState {
            case .loading:
                loadingView

            case .morningPending:
                morningPromptView

            case .waitingForEvening:
                waitingForEveningView

            case .eveningPending:
                eveningPromptView

            case .allComplete:
                allCompleteView

            case .morningMissed:
                morningMissedView
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(backgroundGradient)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .animation(.easeInOut(duration: 0.3), value: cardState)
    }

    // MARK: - Card States

    private var loadingView: some View {
        HStack {
            ProgressView()
            Text("Checking status...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var morningPromptView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sun.horizon.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text("Good Morning!")
                .font(.headline)

            Text("Start your day with a quick check-in")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Check In Now") {
                onMorningCheckInTapped()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding(.vertical, 8)
    }

    private var waitingForEveningView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Label("Morning Check-In", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)

                Text("Come back this evening for your next check-in")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let checkIn = morningCheckIn {
                EnergyBadge(level: checkIn.energyLevel)
            }
        }
    }

    private var eveningPromptView: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.stars.fill")
                .font(.largeTitle)
                .foregroundStyle(.purple)

            Text("Good Evening!")
                .font(.headline)

            Text("Wrap up your day and see tomorrow's prediction")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Evening Check-In") {
                onEveningCheckInTapped()
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .controlSize(.regular)
        }
        .padding(.vertical, 8)
    }

    private var allCompleteView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("All Done for Today", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)

            Text("Check back tomorrow morning!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var morningMissedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text("Morning check-in window passed")
                .font(.headline)

            if isEveningWindow {
                Text("You can still do your evening check-in")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Evening Check-In") {
                    onEveningCheckInTapped()
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .controlSize(.regular)
            } else {
                Text("Evening check-in available after 5 PM")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Styling

    private var backgroundGradient: some View {
        Group {
            switch cardState {
            case .eveningPending, .allComplete:
                LinearGradient(
                    colors: [Color.purple.opacity(0.1), Color.purple.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            default:
                Color.clear
            }
        }
    }
}

// MARK: - Energy Badge

/// A colored badge showing the energy level.
private struct EnergyBadge: View {
    let level: Int

    var body: some View {
        Text("\(level)")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(Circle().fill(energyColor))
    }

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

#Preview("Morning Pending") {
    CheckInCard(
        morningCheckIn: nil,
        eveningCheckIn: nil,
        isLoading: false,
        isMorningWindow: true,
        isEveningWindow: false,
        onMorningCheckInTapped: {},
        onEveningCheckInTapped: {}
    )
    .padding()
}

#Preview("Waiting for Evening") {
    CheckInCard(
        morningCheckIn: CheckIn(type: .morning, energyLevel: 4, healthSnapshot: nil),
        eveningCheckIn: nil,
        isLoading: false,
        isMorningWindow: false,
        isEveningWindow: false,
        onMorningCheckInTapped: {},
        onEveningCheckInTapped: {}
    )
    .padding()
}

#Preview("Evening Pending") {
    CheckInCard(
        morningCheckIn: CheckIn(type: .morning, energyLevel: 4, healthSnapshot: nil),
        eveningCheckIn: nil,
        isLoading: false,
        isMorningWindow: false,
        isEveningWindow: true,
        onMorningCheckInTapped: {},
        onEveningCheckInTapped: {}
    )
    .padding()
}

#Preview("All Complete") {
    CheckInCard(
        morningCheckIn: CheckIn(type: .morning, energyLevel: 4, healthSnapshot: nil),
        eveningCheckIn: CheckIn(type: .evening, energyLevel: 3, healthSnapshot: nil),
        isLoading: false,
        isMorningWindow: false,
        isEveningWindow: true,
        onMorningCheckInTapped: {},
        onEveningCheckInTapped: {}
    )
    .padding()
}
