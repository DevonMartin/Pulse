//
//  DayHistoryList.swift
//  Pulse
//
//  Created by Devon Martin on 12/6/2025.
//

import SwiftUI

/// Displays a grouped list of historical Days with their check-in slots.
struct DayHistoryList: View {
    let days: [Day]

    /// Days grouped by date section
    private var groupedDays: [(section: DateSection, days: [Day])] {
        let calendar = Calendar.current
        var groups: [DateSection: [Day]] = [:]

        for day in days {
            let section = DateSection.from(date: day.startDate, calendar: calendar)
            groups[section, default: []].append(day)
        }

        // Sort each group by startDate descending
        for (section, items) in groups {
            groups[section] = items.sorted { $0.startDate > $1.startDate }
        }

        // Return in section order
        return DateSection.allCases.compactMap { section in
            guard let items = groups[section], !items.isEmpty else { return nil }
            return (section: section, days: items)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedDays, id: \.section) { group in
                    Section {
                        ForEach(group.days) { day in
                            DayCard(day: day)
                        }
                    } header: {
                        SectionHeader(title: group.section.title)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Date Section

/// Logical groupings for dates.
private enum DateSection: Int, CaseIterable {
    case today
    case yesterday
    case thisWeek
    case lastWeek
    case thisMonth
    case older

    var title: String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .thisWeek: return "This Week"
        case .lastWeek: return "Last Week"
        case .thisMonth: return "This Month"
        case .older: return "Older"
        }
    }

    static func from(date: Date, calendar: Calendar) -> DateSection {
        if calendar.isDateInToday(date) {
            return .today
        } else if calendar.isDateInYesterday(date) {
            return .yesterday
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            return .thisWeek
        } else if let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: Date()),
                  calendar.isDate(date, equalTo: lastWeekStart, toGranularity: .weekOfYear) {
            return .lastWeek
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .month) {
            return .thisMonth
        } else {
            return .older
        }
    }
}

// MARK: - Section Header

private struct SectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color(.systemBackground))
    }
}

// MARK: - Day Card

/// A card displaying a single Day with both check-in slots.
private struct DayCard: View {
    let day: Day

    @State private var isExpanded = false

    /// Whether this day has health data attached
    private var hasHealthData: Bool {
        day.healthMetrics != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main row content
            HStack(spacing: 12) {
                // Date display
                VStack(alignment: .center, spacing: 2) {
                    Text(day.startDate.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(day.startDate.formatted(.dateTime.day()))
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .frame(width: 44)

                // Check-in slots
                VStack(alignment: .leading, spacing: 8) {
                    CheckInSlotRow(
                        icon: "sun.horizon.fill",
                        iconColor: .orange,
                        label: "Morning",
                        slot: day.firstCheckIn
                    )

                    CheckInSlotRow(
                        icon: "moon.fill",
                        iconColor: .indigo,
                        label: "Evening",
                        slot: day.secondCheckIn
                    )
                }

                Spacer()

                // Readiness score badge (or placeholder for alignment)
                if let score = day.readinessScore {
                    ReadinessScoreBadge(score: score.score)
                } else {
                    PlaceholderScoreBadge()
                }

                // Expand chevron - red if no health data
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(hasHealthData ? Color(.tertiaryLabel) : Color.red.opacity(0.6))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }

            // Expanded content
            if isExpanded {
                if let metrics = day.healthMetrics {
                    HealthMetricsDetail(metrics: metrics)
                        .padding(.top, 12)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    MissingHealthDataView()
                        .padding(.top, 12)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Check-In Slot Row

private struct CheckInSlotRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let slot: CheckInSlot?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(iconColor)
                .frame(width: 16)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if let slot = slot {
                EnergyBadge(level: slot.energyLevel)
            } else {
                PlaceholderEnergyBadge()
            }
        }
    }
}

// MARK: - Readiness Score Badge

private struct ReadinessScoreBadge: View {
    let score: Int

    var body: some View {
        Text("\(score)")
            .font(.title3)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .frame(width: 44, height: 44)
            .background(Circle().fill(ReadinessStyles.color(for: score)))
    }
}

// MARK: - Placeholder Score Badge

private struct PlaceholderScoreBadge: View {
    var body: some View {
        Text("--")
            .font(.title3)
            .fontWeight(.bold)
            .foregroundStyle(.secondary)
            .frame(width: 44, height: 44)
            .background(Circle().fill(Color(.tertiarySystemFill)))
    }
}

// MARK: - Energy Badge

private struct EnergyBadge: View {
    let level: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 8))
            Text("\(level)")
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(energyColor))
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

// MARK: - Placeholder Energy Badge

private struct PlaceholderEnergyBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 8))
            Text("--")
                .font(.caption2)
                .fontWeight(.semibold)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color(.tertiarySystemFill)))
    }
}

// MARK: - Missing Health Data View

private struct MissingHealthDataView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            Text("Health Metrics")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                MetricPill(icon: "heart.fill", label: "Resting HR", value: "--", color: .red)
                MetricPill(icon: "waveform.path.ecg", label: "HRV", value: "--", color: .pink)
                MetricPill(icon: "bed.double.fill", label: "Sleep", value: "--", color: .indigo)
                MetricPill(icon: "figure.walk", label: "Steps", value: "--", color: .green)
            }

            Text("No health data was recorded for this day")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
    }
}

// MARK: - Health Metrics Detail

private struct HealthMetricsDetail: View {
    let metrics: HealthMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            Text("Health Metrics")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                if let hr = metrics.restingHeartRate {
                    MetricPill(
                        icon: "heart.fill",
                        label: "Resting HR",
                        value: "\(Int(hr)) bpm",
                        color: .red
                    )
                }

                if let hrv = metrics.hrv {
                    MetricPill(
                        icon: "waveform.path.ecg",
                        label: "HRV",
                        value: "\(Int(hrv)) ms",
                        color: .pink
                    )
                }

                if let _ = metrics.sleepDuration {
                    MetricPill(
                        icon: "bed.double.fill",
                        label: "Sleep",
                        value: metrics.formattedSleepDuration ?? "",
                        color: .indigo
                    )
                }

                if let steps = metrics.steps {
                    MetricPill(
                        icon: "figure.walk",
                        label: "Steps",
                        value: steps.formatted(),
                        color: .green
                    )
                }
            }
        }
    }
}

// MARK: - Metric Pill

private struct MetricPill: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Preview

#Preview {
    let mockDays = [
        Day(
            startDate: Date(),
            firstCheckIn: CheckInSlot(energyLevel: 4),
            secondCheckIn: CheckInSlot(energyLevel: 3),
            healthMetrics: HealthMetrics(
                date: Date(),
                restingHeartRate: 58,
                hrv: 65,
                sleepDuration: 7.5 * 3600,
                steps: 8500
            ),
            readinessScore: ReadinessScore(
                score: 78,
                breakdown: ReadinessBreakdown(
                    hrvScore: 75,
                    restingHeartRateScore: 80,
                    sleepScore: 82,
                    energyScore: 80
                ),
                confidence: .full
            )
        ),
        Day(
            startDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            firstCheckIn: CheckInSlot(energyLevel: 3),
            secondCheckIn: nil,
            healthMetrics: nil
        ),
        Day(
            startDate: Calendar.current.date(byAdding: .day, value: -3, to: Date())!,
            firstCheckIn: CheckInSlot(energyLevel: 5),
            secondCheckIn: CheckInSlot(energyLevel: 4),
            healthMetrics: HealthMetrics(
                date: Calendar.current.date(byAdding: .day, value: -3, to: Date())!,
                restingHeartRate: 55,
                hrv: 72,
                sleepDuration: 8.2 * 3600,
                steps: 12000
            ),
            readinessScore: ReadinessScore(
                score: 85,
                breakdown: ReadinessBreakdown(
                    hrvScore: 88,
                    restingHeartRateScore: 85,
                    sleepScore: 90,
                    energyScore: 100
                ),
                confidence: .full
            )
        )
    ]

    DayHistoryList(days: mockDays)
}
