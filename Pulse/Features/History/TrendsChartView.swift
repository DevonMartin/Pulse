//
//  TrendsChartView.swift
//  Pulse
//
//  Created by Devon Martin on 12/4/2025.
//

import SwiftUI
import Charts

/// Displays summary stats and a line chart of readiness scores over time.
/// Extracts scores from Days to ensure single source of truth.
struct TrendsChartView: View {
    let days: [Day]
    let timeRange: TimeRange

    /// Days with readiness scores, sorted chronologically for charting
    private var daysWithScores: [Day] {
        days.filter { $0.readinessScore != nil }
            .sorted { $0.startDate < $1.startDate }
    }

    /// Determines appropriate X-axis stride based on time range and date span
    private var xAxisStride: Calendar.Component {
        switch timeRange {
        case .week:
            return .day
        case .month:
            return .weekOfYear
        case .all:
            let span = dateSpanInDays
            if span > 365 { return .quarter }
            if span > 90  { return .month }
            return .month
        }
    }

    /// Determines appropriate date format for X-axis labels based on time range
    private var xAxisFormat: Date.FormatStyle {
        switch timeRange {
        case .week:
            return .dateTime.weekday(.abbreviated)
        case .month:
            return .dateTime.month(.abbreviated).day()
        case .all:
            let span = dateSpanInDays
            if span > 365 { return .dateTime.month(.abbreviated).year(.twoDigits) }
            return .dateTime.month(.abbreviated)
        }
    }

    /// The number of calendar days between the first and last data point
    private var dateSpanInDays: Int {
        guard let first = daysWithScores.first?.startDate,
              let last = daysWithScores.last?.startDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0
    }

    /// Average score for the period
    private var averageScore: Int? {
        let scores = daysWithScores.compactMap { $0.readinessScore?.score }
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / scores.count
    }

    /// The score range for better visualization
    private var scoreRange: ClosedRange<Int> {
        let scores = daysWithScores.compactMap { $0.readinessScore?.score }
        guard let minScore = scores.min(),
              let maxScore = scores.max() else {
            return 0...100
        }
        let padding = 10
        let lower = max(0, minScore - padding)
        let upper = min(100, maxScore + padding)
        return lower...upper
    }

    var body: some View {
        VStack(spacing: 16) {
            // Summary card
            summaryCard

            // Chart (only if we have scores)
            if !daysWithScores.isEmpty {
                chartCard
            }
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        HStack(spacing: 24) {
            // Average score
            VStack(spacing: 4) {
                Text(averageScore.map { "\($0)" } ?? "--")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(averageScore.map { ReadinessStyles.color(for: $0) } ?? .secondary)
                Text("Average")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Average score: \(averageScore.map { "\($0)" } ?? "no data")")

            Divider()
                .frame(height: 40)

            // Total entries
            VStack(spacing: 4) {
                Text("\(daysWithScores.count)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text(daysWithScores.count == 1 ? "Day" : "Days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(daysWithScores.count) days with scores")

            Divider()
                .frame(height: 40)

            // Trend indicator
            VStack(spacing: 4) {
                Image(systemName: trendIcon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(trendColor)
                Text("Trend")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Trend: \(trendDescription)")
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Average score: \(averageScore.map { "\($0)" } ?? "no data"). \(daysWithScores.count) \(daysWithScores.count == 1 ? "day" : "days") with \(daysWithScores.count == 1 ? "a score" : "scores"). Trend: \(trendDescription)")
    }

    private var trendIcon: String {
        let scores = daysWithScores.compactMap { $0.readinessScore?.score }
        guard scores.count >= 2 else { return "minus" }

        let recent = Array(scores.suffix(3))
        let earlier = Array(scores.prefix(3))
        let recentAvg = recent.isEmpty ? 0 : recent.reduce(0, +) / recent.count
        let earlierAvg = earlier.isEmpty ? 0 : earlier.reduce(0, +) / earlier.count

        if recentAvg > earlierAvg + 5 {
            return "arrow.up.right"
        } else if recentAvg < earlierAvg - 5 {
            return "arrow.down.right"
        } else {
            return "arrow.right"
        }
    }

    private var trendDescription: String {
        switch trendIcon {
        case "arrow.up.right": return "improving"
        case "arrow.down.right": return "declining"
        default: return "stable"
        }
    }

    private var trendColor: Color {
        let scores = daysWithScores.compactMap { $0.readinessScore?.score }
        guard scores.count >= 2 else { return .secondary }

        let recent = Array(scores.suffix(3))
        let earlier = Array(scores.prefix(3))
        let recentAvg = recent.isEmpty ? 0 : recent.reduce(0, +) / recent.count
        let earlierAvg = earlier.isEmpty ? 0 : earlier.reduce(0, +) / earlier.count

        if recentAvg > earlierAvg + 5 {
            return .green
        } else if recentAvg < earlierAvg - 5 {
            return .red
        } else {
            return .secondary
        }
    }

    /// Single fill color for the area under the chart line.
    /// Picks the higher tier between the most frequent dot color and the most recent dot color.
    private var areaFillColor: Color {
        let scores = daysWithScores.compactMap { $0.readinessScore?.score }
        guard !scores.isEmpty else { return .green }

        // Tier: 0 = poor/red, 1 = moderate/orange, 2 = good/green, 3 = excellent/mint
        func tier(for score: Int) -> Int {
            switch score {
            case ReadinessStyles.poorRange: return 0
            case ReadinessStyles.moderateRange: return 1
            case ReadinessStyles.goodRange: return 2
            case ReadinessStyles.excellentRange: return 3
            default: return 1
            }
        }

        func color(for tier: Int) -> Color {
            switch tier {
            case 0: return .red
            case 1: return .orange
            case 2: return .green
            case 3: return .mint
            default: return .green
            }
        }

        // Most frequent tier
        var tierCounts = [0: 0, 1: 0, 2: 0, 3: 0]
        for score in scores {
            tierCounts[tier(for: score), default: 0] += 1
        }
        let mostFrequentTier = tierCounts.max(by: { $0.value < $1.value })?.key ?? 2

        // Most recent tier
        let mostRecentTier = tier(for: scores.last!)

        // Pick whichever is higher on the scale
        let chosenTier = max(mostFrequentTier, mostRecentTier)
        return color(for: chosenTier)
    }

    // MARK: - Chart Card

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Readiness Over Time")
                .font(.headline)

            Chart(daysWithScores, id: \.id) { day in
                if let score = day.readinessScore?.score {
                    LineMark(
                        x: .value("Date", day.startDate, unit: .day),
                        y: .value("Score", score)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [.mint, .green, .orange, .red].reversed(),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", day.startDate, unit: .day),
                        y: .value("Score", score)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [areaFillColor.opacity(0.3), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", day.startDate, unit: .day),
                        y: .value("Score", score)
                    )
                    .foregroundStyle(ReadinessStyles.color(for: score))
                    .symbolSize(40)
                }
            }
            .chartYScale(domain: scoreRange, type: .linear)
            .chartYAxis {
                AxisMarks(position: .leading, values: .stride(by: 20)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let intValue = value.as(Int.self) {
                            Text("\(intValue)")
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: xAxisStride)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: xAxisFormat)
                }
            }
            .frame(height: 200)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Preview

#Preview {
    let calendar = Calendar.current
    let mockDays = (0..<7).map { daysAgo -> Day in
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
        let score = Int.random(in: 50...90)
        return Day(
            startDate: date,
            firstCheckIn: CheckInSlot(energyLevel: Int.random(in: 3...5)),
            secondCheckIn: CheckInSlot(energyLevel: Int.random(in: 3...5)),
            readinessScore: ReadinessScore(
                date: date,
                score: score,
                breakdown: ReadinessBreakdown(
                    hrvScore: score + Int.random(in: -10...10),
                    restingHeartRateScore: score + Int.random(in: -10...10),
                    sleepScore: score + Int.random(in: -10...10),
                    energyScore: score + Int.random(in: -10...10)
                ),
                confidence: [.full, .partial, .limited].randomElement()!
            )
        )
    }

    TrendsChartView(days: mockDays, timeRange: .week)
        .padding()
}
