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

    /// Determines appropriate X-axis stride based on time range and data count
    private var xAxisStride: Calendar.Component {
        switch timeRange {
        case .week:
            return .day
        case .month:
            return .weekOfYear
        case .all:
            return daysWithScores.count > 60 ? .month : .weekOfYear
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
            return daysWithScores.count > 60
                ? .dateTime.month(.abbreviated)
                : .dateTime.month(.abbreviated).day()
        }
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

            Divider()
                .frame(height: 40)

            // Total entries
            VStack(spacing: 4) {
                Text("\(daysWithScores.count)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                Text("Days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

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
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
                            colors: [ReadinessStyles.color(for: score).opacity(0.3), .clear],
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
