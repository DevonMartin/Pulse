//
//  CheckInHistoryList.swift
//  Pulse
//
//  Created by Devon Martin on 12/4/2025.
//

import SwiftUI

/// Displays a grouped list of historical check-ins.
struct CheckInHistoryList: View {
    let checkIns: [CheckIn]

    /// Check-ins grouped by date section
    private var groupedCheckIns: [(section: DateSection, checkIns: [CheckIn])] {
        let calendar = Calendar.current
        var groups: [DateSection: [CheckIn]] = [:]

        for checkIn in checkIns {
            let section = DateSection.from(date: checkIn.timestamp, calendar: calendar)
            groups[section, default: []].append(checkIn)
        }

        // Sort each group by timestamp descending
        for (section, items) in groups {
            groups[section] = items.sorted { $0.timestamp > $1.timestamp }
        }

        // Return in section order
        return DateSection.allCases.compactMap { section in
            guard let items = groups[section], !items.isEmpty else { return nil }
            return (section: section, checkIns: items)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedCheckIns, id: \.section) { group in
                    Section {
                        ForEach(group.checkIns) { checkIn in
                            CheckInRow(checkIn: checkIn)
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

/// Logical groupings for check-in dates.
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

// MARK: - Check-In Row

private struct CheckInRow: View {
    let checkIn: CheckIn

    @State private var isExpanded = false

    /// Whether this check-in has health data attached
    private var hasHealthData: Bool {
        checkIn.healthSnapshot != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main row content
            HStack(spacing: 12) {
                // Type icon
                Image(systemName: checkIn.type == .morning ? "sun.horizon.fill" : "moon.fill")
                    .font(.title2)
                    .foregroundStyle(checkIn.type == .morning ? .orange : .indigo)
                    .frame(width: 32)

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(checkIn.type == .morning ? "Morning Check-in" : "Evening Reflection")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(checkIn.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Energy level badge
                EnergyBadge(level: checkIn.energyLevel)

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
                if let snapshot = checkIn.healthSnapshot {
                    HealthSnapshotDetail(snapshot: snapshot)
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

// MARK: - Missing Health Data View

private struct MissingHealthDataView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            Text("Health Snapshot")
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

            Text("No health data was recorded for this check-in")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
    }
}

// MARK: - Energy Badge

private struct EnergyBadge: View {
    let level: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill")
                .font(.caption2)
            Text("\(level)")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
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

// MARK: - Health Snapshot Detail

private struct HealthSnapshotDetail: View {
    let snapshot: HealthMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            Text("Health Snapshot")
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                if let hr = snapshot.restingHeartRate {
                    MetricPill(
                        icon: "heart.fill",
                        label: "Resting HR",
                        value: "\(Int(hr)) bpm",
                        color: .red
                    )
                }

                if let hrv = snapshot.hrv {
                    MetricPill(
                        icon: "waveform.path.ecg",
                        label: "HRV",
                        value: "\(Int(hrv)) ms",
                        color: .pink
                    )
                }

                if let _ = snapshot.sleepDuration {
                    MetricPill(
                        icon: "bed.double.fill",
                        label: "Sleep",
                        value: snapshot.formattedSleepDuration ?? "",
                        color: .indigo
                    )
                }

                if let steps = snapshot.steps {
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
    let mockCheckIns = [
        CheckIn(
            type: .morning,
            energyLevel: 4,
            healthSnapshot: HealthMetrics(
                date: Date(),
                restingHeartRate: 58,
                hrv: 65,
                sleepDuration: 7.5 * 3600,
                steps: 8500
            )
        ),
        CheckIn(
            timestamp: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
            type: .morning,
            energyLevel: 3,
            healthSnapshot: nil
        ),
        CheckIn(
            timestamp: Calendar.current.date(byAdding: .day, value: -3, to: Date())!,
            type: .morning,
            energyLevel: 5,
            healthSnapshot: HealthMetrics(
                date: Calendar.current.date(byAdding: .day, value: -3, to: Date())!,
                restingHeartRate: 55,
                hrv: 72,
                sleepDuration: 8.2 * 3600,
                steps: 12000
            )
        )
    ]

    CheckInHistoryList(checkIns: mockCheckIns)
}
