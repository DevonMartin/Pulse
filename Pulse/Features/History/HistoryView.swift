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

/// Shows historical readiness trends and daily check-in history.
/// Combines summary stats, chart, and day cards in a single scrollable view.
struct HistoryView: View {
    @Environment(AppContainer.self) private var container

    @State private var selectedTimeRange: TimeRange = .week
    @State private var days: [Day] = []
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
                .padding(.bottom, 12)

                // Content
                if isLoading {
                    Spacer()
                    ProgressView("Loading history...")
                    Spacer()
                } else if days.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            // Summary stats and chart
                            TrendsChartView(days: days, timeRange: selectedTimeRange)

                            // Day cards list
                            DayHistoryList(days: days)
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
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

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "calendar")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No History Yet")
                .font(.headline)

            Text("Complete daily check-ins to see your readiness trends over time.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        let showLoading = days.isEmpty
        if showLoading {
            isLoading = true
        }

        do {
            days = try await container.dayRepository.getDays(
                from: selectedTimeRange.startDate,
                to: Date()
            )
        } catch {
            print("Failed to load days: \(error)")
            days = []
        }

        isLoading = false
    }

    /// Loads data with animation for smoother transitions when changing time range
    private func loadDataAnimated() async {
        do {
            let newDays = try await container.dayRepository.getDays(
                from: selectedTimeRange.startDate,
                to: Date()
            )

            withAnimation(.easeInOut(duration: 0.3)) {
                days = newDays
            }
        } catch {
            print("Failed to load data: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    HistoryView()
        .environment(AppContainer(healthKitService: MockHealthKitService()))
}
