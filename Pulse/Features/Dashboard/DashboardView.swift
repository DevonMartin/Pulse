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
/// - Tomorrow's prediction (if available)
/// - Contextual check-in card
/// - Today's health metrics summary
struct DashboardView: View {
    @Environment(AppContainer.self) private var container

    @State private var morningCheckIn: CheckIn?
    @State private var eveningCheckIn: CheckIn?
    @State private var todaysMetrics: HealthMetrics?
    @State private var readinessScore: ReadinessScore?
    @State private var tomorrowsPrediction: Prediction?
    @State private var isLoading = true
    @State private var showingMorningCheckIn = false
    @State private var showingEveningCheckIn = false
    @State private var errorMessage: String?

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

                    // Tomorrow's prediction card (shown after evening check-in or if we have one)
                    if let prediction = tomorrowsPrediction {
                        TomorrowPredictionCard(prediction: prediction)
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
        async let predictionTask: () = loadTomorrowsPrediction()

        await morningTask
        await eveningTask
        await metricsTask
        await predictionTask

        // Calculate readiness score from loaded data and save it
        await calculateAndSaveReadinessScore()

        isLoading = false
    }

    private func calculateAndSaveReadinessScore() async {
        guard let score = container.readinessCalculator.calculate(
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

    private func loadTomorrowsPrediction() async {
        do {
            // First try to get existing prediction for tomorrow
            let calendar = Calendar.current
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
            tomorrowsPrediction = try await container.predictionRepository.getPrediction(for: tomorrow)
        } catch {
            print("Failed to load prediction: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
        .environment(AppContainer(healthKitService: MockHealthKitService()))
}
