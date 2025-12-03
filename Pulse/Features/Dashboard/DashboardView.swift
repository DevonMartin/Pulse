//
//  DashboardView.swift
//  Pulse
//
//  Created by Devon Martin on 12/1/2025.
//

import SwiftUI

/// The main dashboard showing today's status and prompting for check-in if needed.
///
/// This is the primary view users see when opening the app.
/// It shows:
/// - Whether they've completed their morning check-in
/// - Their energy level if checked in
/// - Today's health metrics summary
struct DashboardView: View {
    @Environment(AppContainer.self) private var container

    @State private var todaysCheckIn: CheckIn?
    @State private var todaysMetrics: HealthMetrics?
    @State private var isLoading = true
    @State private var showingCheckIn = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Check-in status card
                    CheckInStatusCard(
                        checkIn: todaysCheckIn,
                        isLoading: isLoading,
                        onCheckInTapped: { showingCheckIn = true }
                    )

                    // Today's metrics card
                    TodaysMetricsCard(metrics: todaysMetrics)

                    // Error display
                    if let error = errorMessage {
                        Text(error)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .padding()
                    }
                }
                .padding()
                .animation(.easeInOut(duration: 0.3), value: isLoading)
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await loadData() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .sheet(isPresented: $showingCheckIn) {
                CheckInView {
                    Task { await loadData() }
                }
            }
            .task {
                await requestAuthorizationAndLoadData()
            }
        }
    }

    // MARK: - Data Loading

    private func requestAuthorizationAndLoadData() async {
        do {
            try await container.healthKitService.requestAuthorization()
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        // Load check-in and metrics concurrently
		async let checkInTask: () = loadTodaysCheckIn()
		async let metricsTask: () = loadTodaysMetrics()

        await checkInTask
        await metricsTask

        isLoading = false
    }

    private func loadTodaysCheckIn() async {
        do {
            todaysCheckIn = try await container.checkInRepository.getTodaysCheckIn(type: .morning)
        } catch {
            print("Failed to load today's check-in: \(error)")
        }
    }

    private func loadTodaysMetrics() async {
        do {
            todaysMetrics = try await container.healthKitService.fetchMetrics(for: Date())
        } catch {
            print("Failed to load today's metrics: \(error)")
        }
    }
}

// MARK: - Check-In Status Card

/// Shows whether the user has completed their morning check-in.
private struct CheckInStatusCard: View {
    let checkIn: CheckIn?
    let isLoading: Bool
    let onCheckInTapped: () -> Void

    /// Computed state for animation tracking
    private var state: CardState {
        if isLoading { return .loading }
        if checkIn != nil { return .checkedIn }
        return .notCheckedIn
    }

    private enum CardState {
        case loading, checkedIn, notCheckedIn
    }

    /// Asymmetric transition: loading fades out faster than new content fades in
    private var loadingTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.animation(.easeIn(duration: 0.15)),
            removal: .opacity.animation(.easeOut(duration: 0.15))
        )
    }

    private var contentTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.animation(.easeIn(duration: 0.3).delay(0.1)),
            removal: .opacity.animation(.easeOut(duration: 0.15))
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            switch state {
            case .loading:
                // Loading state - show placeholder to prevent flash
                HStack {
                    ProgressView()
                    Text("Checking status...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .transition(loadingTransition)

            case .checkedIn:
                // Already checked in
                if let checkIn = checkIn {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Morning Check-In", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .foregroundStyle(.green)

                            Text("Completed at \(checkIn.timestamp.formatted(date: .omitted, time: .shortened))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Energy level badge
                        EnergyBadge(level: checkIn.energyLevel)
                    }
                    .transition(contentTransition)
                }

            case .notCheckedIn:
                // Not checked in yet
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
                        onCheckInTapped()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
                .padding(.vertical, 8)
                .transition(contentTransition)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .animation(.easeInOut(duration: 0.3), value: state)
    }
}

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
        case 4: return .mint
        case 5: return .green
        default: return .gray
        }
    }
}

// MARK: - Today's Metrics Card

/// Displays a summary of today's health metrics.
private struct TodaysMetricsCard: View {
    let metrics: HealthMetrics?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Metrics")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                MetricTile(
                    title: "Resting HR",
                    value: metrics?.restingHeartRate.map { "\(Int($0))" },
                    unit: "bpm",
                    icon: "heart.fill",
                    color: .red
                )

                MetricTile(
                    title: "HRV",
                    value: metrics?.hrv.map { "\(Int($0))" },
                    unit: "ms",
                    icon: "waveform.path.ecg",
                    color: .pink
                )

                MetricTile(
                    title: "Sleep",
                    value: metrics?.formattedSleepDuration,
                    unit: nil,
                    icon: "bed.double.fill",
                    color: .indigo
                )

                MetricTile(
                    title: "Steps",
                    value: metrics?.steps.map { $0.formatted() },
                    unit: nil,
                    icon: "figure.walk",
                    color: .green
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// A single metric tile in the grid.
private struct MetricTile: View {
    let title: String
    let value: String?
    let unit: String?
    let icon: String
    let color: Color

    /// Display value for animation tracking
    private var displayValue: String {
        value ?? "--"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(displayValue)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(value != nil ? .primary : .tertiary)
                    .contentTransition(.numericText())

                if let unit = unit, value != nil {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.3), value: displayValue)
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
        .environment(AppContainer(healthKitService: MockHealthKitService()))
}
