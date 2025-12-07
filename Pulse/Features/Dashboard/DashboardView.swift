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
/// - Today's readiness score
/// - Contextual check-in card
/// - Today's health metrics summary
struct DashboardView: View {
    @Environment(AppContainer.self) private var container

    @State private var currentDay: Day?
    @State private var todayMetrics: HealthMetrics?
    @State private var isLoading = true
    @State private var showingMorningCheckIn = false
    @State private var showingEveningCheckIn = false
    @State private var errorMessage: String?

    // ML status
    @State private var mlExampleCount: Int = 0
    @State private var mlWeight: Double = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Readiness score card
					// (always shown - uses current day or placeholder)
                    ReadinessScoreCard(day: currentDay ?? Day(startDate: Date()))

                    // Single contextual check-in card
                    CheckInCard(
                        day: currentDay,
                        isLoading: isLoading,
                        isMorningWindow: TimeWindows.isMorningWindow,
                        isEveningWindow: TimeWindows.isEveningWindow,
                        onMorningCheckInTapped: { showingMorningCheckIn = true },
                        onEveningCheckInTapped: { showingEveningCheckIn = true }
                    )

                    // Personalization status
                    PersonalizationStatus(
                        exampleCount: mlExampleCount,
                        mlWeight: mlWeight
                    )

                    // Today's metrics card
					// (prefer Day's metrics if available, otherwise fetch from HealthKit)
                    TodaysMetricsCard(metrics: currentDay?.healthMetrics ?? todayMetrics)

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
            .refreshable {
                await loadData()
            }
            .sheet(isPresented: $showingMorningCheckIn) {
                CheckInView {
                    Task { await loadData() }
                }
            }
            .sheet(isPresented: $showingEveningCheckIn) {
                EveningCheckInView {
                    Task { await loadData() }
                }
            }
            .task {
                await requestAuthorizationAndLoadData()
            }
            .onReceive(NotificationCenter.default.publisher(for: .checkInCompleted)) { _ in
                Task { await loadData() }
            }
        }
    }

    // MARK: - Data Loading

    private func requestAuthorizationAndLoadData() async {
        do {
            try await container.healthKitService.requestAuthorization()

            // Ensure sample data is populated before loading (for fresh installs)
            await container.populateSampleDataIfNeeded()

            // Load saved ML model and trigger retraining with historical data
            await container.readinessService.loadSavedModel()
            await retrainMLModel()

            await loadData()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func loadData() async {
        errorMessage = nil

        // Use DayService to load and update today's data
        do {
            let result = try await container.dayService.loadAndUpdateToday()
            currentDay = result.day
            todayMetrics = result.freshMetrics
        } catch {
            print("Failed to load today's data: \(error)")
        }

        // Update ML status
        await loadMLStatus()

        // Update widget with latest data
        updateWidgetData()

        isLoading = false
    }

    private func retrainMLModel() async {
        // Fetch all completed days for training
        do {
            let completedDays = try await container.dayRepository.getCompletedDays()
            await container.readinessService.retrain(with: completedDays)
        } catch {
            print("Failed to retrain ML model: \(error)")
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
