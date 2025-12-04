//
//  TrendsChartView.swift
//  Pulse
//
//  Created by Devon Martin on 12/4/2025.
//

import SwiftUI
import Charts

/// Displays a line chart of readiness scores over time.
struct TrendsChartView: View {
    let scores: [ReadinessScore]
    let timeRange: TimeRange

    /// Scores sorted chronologically for charting
    private var sortedScores: [ReadinessScore] {
        scores.sorted { $0.date < $1.date }
    }

    /// Determines appropriate X-axis stride based on time range and data count
    private var xAxisStride: Calendar.Component {
        switch timeRange {
        case .week:
            return .day
        case .month:
            return .weekOfYear
        case .all:
            // For all time, use weeks if less than ~60 days, otherwise months
            return scores.count > 60 ? .month : .weekOfYear
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
            return scores.count > 60
                ? .dateTime.month(.abbreviated)
                : .dateTime.month(.abbreviated).day()
        }
    }

    /// Average score for the period
    private var averageScore: Int? {
        guard !scores.isEmpty else { return nil }
        let total = scores.reduce(0) { $0 + $1.score }
        return total / scores.count
    }

    /// The score range for better visualization
    private var scoreRange: ClosedRange<Int> {
        guard let minScore = scores.map(\.score).min(),
              let maxScore = scores.map(\.score).max() else {
            return 0...100
        }
        // Add padding to the range
        let padding = 10
        let lower = max(0, minScore - padding)
        let upper = min(100, maxScore + padding)
        return lower...upper
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Summary card
                summaryCard

                // Chart
                chartCard

                // Score list
                scoreListCard
            }
            .padding()
        }
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        HStack(spacing: 24) {
            // Average score
            VStack(spacing: 4) {
                Text(averageScore.map { "\($0)" } ?? "--")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(averageScore.map { scoreColor(for: $0) } ?? .secondary)
                Text("Average")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 40)

            // Total entries
            VStack(spacing: 4) {
                Text("\(scores.count)")
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
        guard sortedScores.count >= 2 else { return "minus" }
        let recent = sortedScores.suffix(3).map(\.score)
        let earlier = sortedScores.prefix(3).map(\.score)
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
        guard sortedScores.count >= 2 else { return .secondary }
        let recent = sortedScores.suffix(3).map(\.score)
        let earlier = sortedScores.prefix(3).map(\.score)
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

            Chart(sortedScores) { score in
                LineMark(
                    x: .value("Date", score.date, unit: .day),
                    y: .value("Score", score.score)
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
                    x: .value("Date", score.date, unit: .day),
                    y: .value("Score", score.score)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [scoreColor(for: score.score).opacity(0.3), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Date", score.date, unit: .day),
                    y: .value("Score", score.score)
                )
                .foregroundStyle(scoreColor(for: score.score))
                .symbolSize(40)
            }
            .chartYScale(domain: scoreRange, type: .linear)
            .animation(.easeInOut(duration: 0.3), value: sortedScores.map(\.id))
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

    // MARK: - Score List Card

    private var scoreListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Scores")
                .font(.headline)

            ForEach(sortedScores.reversed()) { score in
                HStack {
                    // Date
                    VStack(alignment: .leading, spacing: 2) {
                        Text(score.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                        Text(score.scoreDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Score badge
                    Text("\(score.score)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(scoreColor(for: score.score)))

                    // Confidence indicator
                    Image(systemName: confidenceIcon(for: score.confidence))
                        .font(.caption)
                        .foregroundStyle(confidenceColor(for: score.confidence))
                        .frame(width: 20)
                }
                .padding(.vertical, 8)

                if score.id != sortedScores.first?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func scoreColor(for score: Int) -> Color {
        switch score {
        case 0...40: return .red
        case 41...60: return .orange
        case 61...80: return .green
        case 81...100: return .mint
        default: return .gray
        }
    }

    private func confidenceIcon(for confidence: ReadinessConfidence) -> String {
        switch confidence {
        case .full: return "checkmark.circle.fill"
        case .partial: return "circle.lefthalf.filled"
        case .limited: return "circle.dashed"
        }
    }

    private func confidenceColor(for confidence: ReadinessConfidence) -> Color {
        switch confidence {
        case .full: return .green
        case .partial: return .orange
        case .limited: return .red
        }
    }
}

// MARK: - Preview

#Preview {
    let mockScores = (0..<7).map { daysAgo -> ReadinessScore in
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        let score = Int.random(in: 50...90)
        return ReadinessScore(
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
    }

    TrendsChartView(scores: mockScores, timeRange: .week)
}
