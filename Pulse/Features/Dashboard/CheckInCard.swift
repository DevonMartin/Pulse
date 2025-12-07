//
//  CheckInCard.swift
//  Pulse
//
//  Created by Devon Martin on 12/6/2025.
//

import SwiftUI

/// A single contextual check-in card that shows the appropriate state based on:
/// - Check-in window (first vs second)
/// - Check-in completion status (first done, second done, both done)
///
/// Uses time-agnostic language to support any schedule (standard day, night shift, etc.)
///
/// States:
/// - `morningPending`: First check-in window, no check-in yet
/// - `waitingForEvening`: First check-in done, waiting for second window
/// - `eveningPending`: Second check-in window, can check in
/// - `allComplete`: Both check-ins done
/// - `morningMissed`: Past first check-in window, no first check-in
struct CheckInCard: View {
    let day: Day?
    let isLoading: Bool
    let isMorningWindow: Bool
    let isEveningWindow: Bool
    let onMorningCheckInTapped: () -> Void
    let onEveningCheckInTapped: () -> Void

    /// Determines what state to show
    private var cardState: CardState {
        if isLoading { return .loading }

        let hasMorning = day?.hasFirstCheckIn ?? false
        let hasEvening = day?.hasSecondCheckIn ?? false

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
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text("Ready to Start?")
                .font(.headline)

            Text("Begin your day with a quick check-in")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("First Check-In") {
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
                Label("First Check-In", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)

                Text("Come back later for your second check-in")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let energyLevel = day?.firstCheckIn?.energyLevel {
                EnergyBadge(level: energyLevel)
            }
        }
    }

    private var eveningPromptView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.badge.questionmark")
                .font(.largeTitle)
                .foregroundStyle(.purple)

            Text("Time for Check-In #2")
                .font(.headline)

            Text("Wrap up your day with your second check-in")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Second Check-In") {
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

            Text("See you next time!")
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

            Text("First check-in window passed")
                .font(.headline)

            if isEveningWindow {
                Text("You can still do your second check-in")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Second Check-In") {
                    onEveningCheckInTapped()
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .controlSize(.regular)
            } else {
                Text("Second check-in window opens later")
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
        day: nil,
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
        day: Day(
            startDate: Date(),
            firstCheckIn: CheckInSlot(energyLevel: 4)
        ),
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
        day: Day(
            startDate: Date(),
            firstCheckIn: CheckInSlot(energyLevel: 4)
        ),
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
        day: Day(
            startDate: Date(),
            firstCheckIn: CheckInSlot(energyLevel: 4),
            secondCheckIn: CheckInSlot(energyLevel: 3)
        ),
        isLoading: false,
        isMorningWindow: false,
        isEveningWindow: true,
        onMorningCheckInTapped: {},
        onEveningCheckInTapped: {}
    )
    .padding()
}
