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
/// - Today's readiness score (includes HRV, RHR, sleep breakdown)
/// - Contextual check-in card
/// - Today's activity (steps and calories, updated throughout the day)
struct DashboardView: View {
    @Environment(AppContainer.self) private var container

    @State private var currentDay: Day?
    @State private var todayMetrics: HealthMetrics?
    @State private var isLoading = false
    @State private var showingMorningCheckIn = false
    @State private var showingEveningCheckIn = false
    @State private var errorMessage: String?

    // ML status
    @State private var mlExampleCount: Int = 0
    @State private var mlWeight: Double = 0
    @AccessibilityFocusState private var isTitleFocused: Bool

    // Tracks check-in schedule changes from Settings (triggers re-render via @AppStorage)
    @AppStorage(TimeWindows.Keys.morningCheckInHour, store: UserDefaults(suiteName: TimeWindows.appGroupID))
    private var morningHour: Int = 8
    @AppStorage(TimeWindows.Keys.eveningCheckInHour, store: UserDefaults(suiteName: TimeWindows.appGroupID))
    private var eveningHour: Int = 19

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Text("Dashboard")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($isTitleFocused)

                    // Readiness score card
					// (always shown - uses current day or placeholder)
                    ReadinessScoreCard(day: currentDay ?? Day(startDate: Date()))

                    // Single contextual check-in card
                    CheckInCard(
                        day: currentDay,
                        isLoading: isLoading,
                        isMorningWindow: TimeWindows.isMorningWindow,
                        isEveningWindow: TimeWindows.isEveningWindow,
						morningWindowOpensHour: max(0, morningHour - TimeWindows.windowBufferHours),
						eveningWindowOpensHour: (eveningHour - TimeWindows.windowBufferHours + 24) % 24,
                        onMorningCheckInTapped: { showingMorningCheckIn = true },
                        onEveningCheckInTapped: { showingEveningCheckIn = true }
                    )

                    // Personalization status
                    PersonalizationStatus(
                        exampleCount: mlExampleCount,
                        mlWeight: mlWeight
                    )

                    // Today's activity card (steps and calories - updates throughout the day)
                    TodaysActivityCard(metrics: currentDay?.healthMetrics ?? todayMetrics)

                    // Error display
                    if let error = errorMessage {
                        Text(error)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .padding()
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                            .accessibilityLabel("Settings")
                    }
                }
            }
            .refreshable {
                await loadData()
            }
            .sheet(isPresented: $showingMorningCheckIn) {
                CheckInView {
                    Task {
                        await loadData()
                        await container.notificationService.clearDeliveredNotifications()
                    }
                }
            }
            .sheet(isPresented: $showingEveningCheckIn) {
                EveningCheckInView {
                    Task {
                        await loadData()
                        await container.notificationService.clearDeliveredNotifications()
                    }
                }
            }
            .task {
                await initializeAndLoadData()
            }
            .onAppear {
                Task {
                    try? await Task.sleep(for: .milliseconds(300))
                    isTitleFocused = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .checkInCompleted)) { _ in
                Task { await loadData() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .onboardingCompleted)) { _ in
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    isTitleFocused = true
                }
            }
        }
    }

    // MARK: - Data Loading

    private func initializeAndLoadData() async {
        // Ensure sample data is populated before loading (for fresh installs)
        await container.populateSampleDataIfNeeded()

        // Load saved ML model and trigger retraining with historical data
        await container.readinessService.loadSavedModel()
        await retrainMLModel()

        await loadData()
    }

    private func loadData() async {
        errorMessage = nil

        // Use DayService to load and update today's data
        do {
            let result = try await container.dayService.loadAndUpdateToday()
            currentDay = result.day
            todayMetrics = result.freshMetrics
        } catch {
            // TODO: Surface error to the user
            // print("Failed to load today's data: \(error)")
        }

        // Update ML status
        await loadMLStatus()

        // Update widget with latest data
        updateWidgetData()

        isLoading = false
    }

    private func retrainMLModel() async {
        // Fetch all days (not just completed) so the training data collector can
        // look up the true previous calendar day's activity metrics for lagging
        // indicators. Only complete days produce training examples.
        do {
            let allDays = try await container.dayRepository.getRecentDays(limit: 365)
            await container.readinessService.retrain(with: allDays)
        } catch {
            // Silent failure — ML retraining is non-critical
        }
    }

    private func loadMLStatus() async {
        // Use completeDaysCount for progress display (counts days even before training starts)
        mlExampleCount = await container.readinessService.completeDaysCount
        mlWeight = await container.readinessService.mlWeight
    }

    private func updateWidgetData() {
        let data = WidgetData(
            score: currentDay?.readinessScore?.score,
            scoreDescription: currentDay?.readinessScore?.scoreDescription,
            morningCheckInComplete: currentDay?.hasFirstCheckIn ?? false,
            eveningCheckInComplete: currentDay?.hasSecondCheckIn ?? false,
            personalizationDays: mlExampleCount,
            personalizationTarget: 30,
            lastUpdated: Date()
        )
        WidgetDataProvider.save(data)
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
        .environment(AppContainer(healthKitService: MockHealthKitService()))
}
