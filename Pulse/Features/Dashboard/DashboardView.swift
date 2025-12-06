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

    @State private var morningCheckIn: CheckIn?
    @State private var eveningCheckIn: CheckIn?
    @State private var todaysMetrics: HealthMetrics?
    @State private var readinessScore: ReadinessScore?
    @State private var isLoading = true
    @State private var showingMorningCheckIn = false
    @State private var showingEveningCheckIn = false
    @State private var errorMessage: String?

    // ML status
    @State private var mlExampleCount: Int = 0
    @State private var mlWeight: Double = 0

    // MARK: - Time Windows (can be user-configurable later)

    /// Hour when morning check-in window ends (default: 4 PM / 16:00)
    private let morningWindowEndHour: Int = 16

    /// Hour when evening check-in window starts (default: 5 PM / 17:00)
    private let eveningWindowStartHour: Int = 17

    /// Current hour for time-based UI decisions
    private var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }

    /// Whether we're in the morning check-in window
    private var isMorningWindow: Bool {
        currentHour < morningWindowEndHour
    }

    /// Whether we're in the evening check-in window
    private var isEveningWindow: Bool {
        currentHour >= eveningWindowStartHour
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Readiness score card (shown when we have a score)
                    if let score = readinessScore {
                        ReadinessScoreCard(score: score)
                    }

                    // Single contextual check-in card
                    CheckInCard(
                        morningCheckIn: morningCheckIn,
                        eveningCheckIn: eveningCheckIn,
                        isLoading: isLoading,
                        isMorningWindow: isMorningWindow,
                        isEveningWindow: isEveningWindow,
                        onMorningCheckInTapped: { showingMorningCheckIn = true },
                        onEveningCheckInTapped: { showingEveningCheckIn = true }
                    )

                    // Personalization status
                    PersonalizationStatus(
                        exampleCount: mlExampleCount,
                        mlWeight: mlWeight
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

        // Load check-ins and metrics concurrently
        async let morningTask: () = loadMorningCheckIn()
        async let eveningTask: () = loadEveningCheckIn()
        async let metricsTask: () = loadTodaysMetrics()

        await morningTask
        await eveningTask
        await metricsTask

        // Calculate readiness score using blended rules + ML
        await calculateAndSaveReadinessScore()

        // Update ML status
        await loadMLStatus()

        isLoading = false
    }

    private func retrainMLModel() async {
        // Fetch all historical check-ins for training
        do {
            let allCheckIns = try await container.checkInRepository.getCheckIns(
                from: Date.distantPast,
                to: Date()
            )
            await container.readinessService.retrain(
                with: allCheckIns,
                healthKitService: container.healthKitService
            )
        } catch {
            print("Failed to retrain ML model: \(error)")
        }
    }

    private func calculateAndSaveReadinessScore() async {
        // Use the blended readiness service (rules + ML)
        guard let score = await container.readinessService.calculate(
            from: todaysMetrics,
            energyLevel: morningCheckIn?.energyLevel
        ) else {
            readinessScore = nil
            return
        }

        readinessScore = score

        // Save the score for historical tracking
        do {
            try await container.readinessScoreRepository.save(score)
        } catch {
            print("Failed to save readiness score: \(error)")
        }
    }

    private func loadMorningCheckIn() async {
        do {
            morningCheckIn = try await container.checkInRepository.getTodaysCheckIn(type: .morning)
        } catch {
            print("Failed to load morning check-in: \(error)")
        }
    }

    private func loadEveningCheckIn() async {
        do {
            eveningCheckIn = try await container.checkInRepository.getTodaysCheckIn(type: .evening)
        } catch {
            print("Failed to load evening check-in: \(error)")
        }
    }

    private func loadTodaysMetrics() async {
        do {
            todaysMetrics = try await container.healthKitService.fetchMetrics(for: Date())
        } catch {
            print("Failed to load today's metrics: \(error)")
        }
    }

    private func loadMLStatus() async {
        mlExampleCount = await container.readinessService.trainingExampleCount
        mlWeight = await container.readinessService.mlWeight
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
        .environment(AppContainer(healthKitService: MockHealthKitService()))
}
