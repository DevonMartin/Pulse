//
//  HistoryView.swift
//  Pulse
//
//  Created by Devon Martin on 12/4/2025.
//

import SwiftUI

/// Time range options for viewing historical data.
enum TimeRange: String, CaseIterable, Identifiable {
    case week = "7 Days"
    case month = "30 Days"
    case all = "All Time"

    var id: String { rawValue }

    /// Returns the start date for this time range
    var startDate: Date {
        let calendar = Calendar.current
        switch self {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: Date())!
        case .month:
            return calendar.date(byAdding: .day, value: -30, to: Date())!
        case .all:
            return Date.distantPast
        }
    }
}

/// The section currently being viewed in history.
enum HistorySection: String, CaseIterable, Identifiable {
    case trends = "Trends"
    case predictions = "Predictions"
    case checkIns = "Check-ins"

    var id: String { rawValue }
}

/// Shows historical readiness trends and check-in history.
struct HistoryView: View {
    @Environment(AppContainer.self) private var container

    @State private var selectedTimeRange: TimeRange = .week
    @State private var selectedSection: HistorySection = .trends
    @State private var scores: [ReadinessScore] = []
    @State private var checkIns: [CheckIn] = []
    @State private var predictions: [Prediction] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Time range picker
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                // Section picker
                Picker("Section", selection: $selectedSection) {
                    ForEach(HistorySection.allCases) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 12)

                // Content
                if isLoading {
                    Spacer()
                    ProgressView("Loading history...")
                    Spacer()
                } else {
                    switch selectedSection {
                    case .trends:
                        if scores.isEmpty {
                            emptyState(
                                icon: "chart.line.uptrend.xyaxis",
                                title: "No Trends Yet",
                                message: "Complete daily check-ins to see your readiness trends over time."
                            )
                        } else {
                            TrendsChartView(scores: scores, timeRange: selectedTimeRange)
                        }

                    case .predictions:
                        if predictions.isEmpty {
                            emptyState(
                                icon: "sparkles",
                                title: "No Predictions Yet",
                                message: "Complete check-ins to start building predictions and tracking accuracy."
                            )
                        } else {
                            PredictionAccuracyView(
                                predictions: predictions,
                                timeRange: selectedTimeRange
                            )
                        }

                    case .checkIns:
                        if checkIns.isEmpty {
                            emptyState(
                                icon: "checkmark.circle",
                                title: "No Check-ins Yet",
                                message: "Your morning check-ins will appear here."
                            )
                        } else {
                            CheckInHistoryList(checkIns: checkIns)
                        }
                    }
                }
            }
            .navigationTitle("History")
            .task {
                await loadData()
            }
            .onChange(of: selectedTimeRange) {
                Task {
                    await loadDataAnimated()
                }
            }
            .refreshable {
                await loadData()
            }
        }
    }

    // MARK: - Empty State

    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        // Only show loading indicator on first load (when data is empty)
        let showLoading = scores.isEmpty && checkIns.isEmpty && predictions.isEmpty
        if showLoading {
            isLoading = true
        }

        async let scoresTask: () = loadScores()
        async let checkInsTask: () = loadCheckIns()
        async let predictionsTask: () = loadPredictions()

        await scoresTask
        await checkInsTask
        await predictionsTask

        isLoading = false
    }

    /// Loads data with animation for smoother transitions when changing time range
    private func loadDataAnimated() async {
        // Fetch the new data
        let newScores: [ReadinessScore]
        let newCheckIns: [CheckIn]
        let newPredictions: [Prediction]

        do {
            async let scoresResult = container.readinessScoreRepository.getScores(
                from: selectedTimeRange.startDate,
                to: Date()
            )
            async let checkInsResult = container.checkInRepository.getCheckIns(
                from: selectedTimeRange.startDate,
                to: Date()
            )
            async let predictionsResult = container.predictionService.getRecentPredictions(
                days: selectedTimeRange == .week ? 7 : (selectedTimeRange == .month ? 30 : 365)
            )

            newScores = try await scoresResult
            newCheckIns = try await checkInsResult
            newPredictions = try await predictionsResult
        } catch {
            print("Failed to load data: \(error)")
            return
        }

        // Animate the state changes
        withAnimation(.easeInOut(duration: 0.3)) {
            scores = newScores
            checkIns = newCheckIns
            predictions = newPredictions
        }
    }

    private func loadScores() async {
        do {
            scores = try await container.readinessScoreRepository.getScores(
                from: selectedTimeRange.startDate,
                to: Date()
            )
        } catch {
            print("Failed to load scores: \(error)")
            scores = []
        }
    }

    private func loadCheckIns() async {
        do {
            checkIns = try await container.checkInRepository.getCheckIns(
                from: selectedTimeRange.startDate,
                to: Date()
            )
        } catch {
            print("Failed to load check-ins: \(error)")
            checkIns = []
        }
    }

    private func loadPredictions() async {
        do {
            let days = selectedTimeRange == .week ? 7 : (selectedTimeRange == .month ? 30 : 365)
            predictions = try await container.predictionService.getRecentPredictions(days: days)
        } catch {
            print("Failed to load predictions: \(error)")
            predictions = []
        }
    }
}

// MARK: - Preview

#Preview {
    HistoryView()
        .environment(AppContainer(healthKitService: MockHealthKitService()))
}
