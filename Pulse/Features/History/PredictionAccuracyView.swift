//
//  PredictionAccuracyView.swift
//  Pulse
//
//  Created by Devon Martin on 12/4/2025.
//

import SwiftUI
import Charts

/// Displays prediction accuracy history and statistics.
struct PredictionAccuracyView: View {
    let predictions: [Prediction]
    let timeRange: TimeRange

    /// Resolved predictions only (have actual scores)
    private var resolvedPredictions: [Prediction] {
        predictions.filter { $0.isResolved }
    }

    /// Sorted chronologically for charting
    private var sortedPredictions: [Prediction] {
        resolvedPredictions.sorted { $0.targetDate < $1.targetDate }
    }

    /// Compute stats from the current predictions (updates with time range)
    private var computedStats: PredictionAccuracyStats {
        let resolved = resolvedPredictions
        guard !resolved.isEmpty else {
            return PredictionAccuracyStats(
                totalPredictions: 0,
                averageError: 0,
                averageAccuracy: 0,
                excellentCount: 0,
                goodCount: 0,
                fairCount: 0,
                poorCount: 0,
                recentTrend: nil
            )
        }

        var totalError = 0
        var excellentCount = 0
        var goodCount = 0
        var fairCount = 0
        var poorCount = 0

        for prediction in resolved {
            guard let error = prediction.absoluteError else { continue }
            totalError += error

            switch error {
            case 0...5: excellentCount += 1
            case 6...10: goodCount += 1
            case 11...15: fairCount += 1
            default: poorCount += 1
            }
        }

        let averageError = Double(totalError) / Double(resolved.count)

        // Calculate trend from recent vs older predictions
        let sortedByDate = resolved.sorted { $0.targetDate > $1.targetDate }
        let recentTrend: Double?
        if sortedByDate.count >= 10 {
            let recentErrors = sortedByDate.prefix(5).compactMap { $0.absoluteError }
            let olderErrors = sortedByDate.dropFirst(5).prefix(5).compactMap { $0.absoluteError }

            if !recentErrors.isEmpty && !olderErrors.isEmpty {
                let recentAvg = Double(recentErrors.reduce(0, +)) / Double(recentErrors.count)
                let olderAvg = Double(olderErrors.reduce(0, +)) / Double(olderErrors.count)
                recentTrend = olderAvg - recentAvg // Positive = improving (lower error)
            } else {
                recentTrend = nil
            }
        } else {
            recentTrend = nil
        }

        return PredictionAccuracyStats(
            totalPredictions: resolved.count,
            averageError: averageError,
            averageAccuracy: max(0, 100 - averageError),
            excellentCount: excellentCount,
            goodCount: goodCount,
            fairCount: fairCount,
            poorCount: poorCount,
            recentTrend: recentTrend
        )
    }

    /// Determines appropriate X-axis stride based on time range
    private var xAxisStride: Calendar.Component {
        switch timeRange {
        case .week:
            return .day
        case .month:
            return .weekOfYear
        case .all:
            return resolvedPredictions.count > 60 ? .month : .weekOfYear
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
            return resolvedPredictions.count > 60
                ? .dateTime.month(.abbreviated)
                : .dateTime.month(.abbreviated).day()
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Accuracy stats summary (computed from current predictions)
                if computedStats.totalPredictions > 0 {
                    accuracyStatsCard(computedStats)
                }

                // Accuracy breakdown chart
                if !resolvedPredictions.isEmpty {
                    accuracyChartCard
                }

                // Prediction history list
                predictionHistoryCard
            }
            .padding()
        }
    }

    // MARK: - Accuracy Stats Card

    private func accuracyStatsCard(_ stats: PredictionAccuracyStats) -> some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Prediction Accuracy")
                    .font(.headline)
                Spacer()
                if let trend = stats.recentTrend {
                    trendBadge(trend: trend)
                }
            }

            // Main stats
            HStack(spacing: 24) {
                // Average accuracy
                VStack(spacing: 4) {
                    Text(String(format: "%.0f%%", stats.averageAccuracy))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(accuracyColor(stats.averageAccuracy))
                    Text("Accuracy")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 40)

                // Average error
                VStack(spacing: 4) {
                    Text(String(format: "%.1f", stats.averageError))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("Avg Error")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 40)

                // Total predictions
                VStack(spacing: 4) {
                    Text("\(stats.totalPredictions)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("Predictions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            // Breakdown bars
            VStack(spacing: 8) {
                accuracyBar(
                    label: "Excellent (0-5 pts)",
                    count: stats.excellentCount,
                    total: stats.totalPredictions,
                    color: .mint
                )
                accuracyBar(
                    label: "Good (6-10 pts)",
                    count: stats.goodCount,
                    total: stats.totalPredictions,
                    color: .green
                )
                accuracyBar(
                    label: "Fair (11-15 pts)",
                    count: stats.fairCount,
                    total: stats.totalPredictions,
                    color: .orange
                )
                accuracyBar(
                    label: "Poor (15+ pts)",
                    count: stats.poorCount,
                    total: stats.totalPredictions,
                    color: .red
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func trendBadge(trend: Double) -> some View {
        HStack(spacing: 4) {
            Image(systemName: trend > 0 ? "arrow.up.right" : (trend < 0 ? "arrow.down.right" : "arrow.right"))
                .font(.caption2)
            Text(trend > 0 ? "Improving" : (trend < 0 ? "Declining" : "Stable"))
                .font(.caption2)
        }
        .foregroundStyle(trend > 0 ? .green : (trend < 0 ? .red : .secondary))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background((trend > 0 ? Color.green : (trend < 0 ? Color.red : Color.secondary)).opacity(0.2))
        .clipShape(Capsule())
    }

    private func accuracyBar(label: String, count: Int, total: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: total > 0 ? geometry.size.width * CGFloat(count) / CGFloat(total) : 0)
                }
            }
            .frame(height: 12)

            Text("\(count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
        }
    }

    // MARK: - Accuracy Chart Card

    private var accuracyChartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accuracy Over Time")
                .font(.headline)

            Chart(sortedPredictions) { prediction in
                if let error = prediction.absoluteError {
                    BarMark(
                        x: .value("Date", prediction.targetDate, unit: .day),
                        y: .value("Error", error)
                    )
                    .foregroundStyle(errorColor(error))
                    .cornerRadius(4)
                }
            }
            .chartYScale(domain: 0...30)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 10, 20, 30]) { value in
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
                AxisMarks(values: .stride(by: xAxisStride)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: xAxisFormat)
                }
            }
            .frame(height: 150)

            // Legend
            HStack(spacing: 16) {
                legendItem(color: .mint, label: "Excellent")
                legendItem(color: .green, label: "Good")
                legendItem(color: .orange, label: "Fair")
                legendItem(color: .red, label: "Poor")
            }
            .font(.caption2)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Prediction History Card

    private var predictionHistoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prediction History")
                .font(.headline)

            ForEach(predictions.sorted(by: { $0.targetDate > $1.targetDate })) { prediction in
                PredictionHistoryRow(prediction: prediction)

                if prediction.id != predictions.sorted(by: { $0.targetDate > $1.targetDate }).last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func accuracyColor(_ accuracy: Double) -> Color {
        switch accuracy {
        case 90...100: return .mint
        case 80..<90: return .green
        case 70..<80: return .orange
        default: return .red
        }
    }

    private func errorColor(_ error: Int) -> Color {
        switch error {
        case 0...5: return .mint
        case 6...10: return .green
        case 11...15: return .orange
        default: return .red
        }
    }
}

// MARK: - Prediction History Row

private struct PredictionHistoryRow: View {
    let prediction: Prediction

    var body: some View {
        HStack(spacing: 12) {
            // Date and accuracy status
            VStack(alignment: .leading, spacing: 4) {
                Text(prediction.targetDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .fontWeight(.medium)

                if prediction.isResolved, let error = prediction.absoluteError {
                    // Show accuracy label for resolved predictions
                    HStack(spacing: 4) {
                        Circle()
                            .fill(errorColor(error))
                            .frame(width: 8, height: 8)
                        Text(errorLabel(error))
                            .font(.caption)
                    }
                    .foregroundStyle(errorColor(error))
                } else {
                    // Show pending for unresolved
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("Pending")
                            .font(.caption)
                    }
                    .foregroundStyle(.orange)
                }
            }
            .frame(width: 100, alignment: .leading)

            Spacer()

            // Scores comparison - fixed width columns for alignment
            if prediction.isResolved, let actual = prediction.actualScore {
                HStack(spacing: 8) {
                    // Predicted
                    VStack(spacing: 2) {
                        Text("\(prediction.predictedScore)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.purple)
                        Text("Predicted")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 70)

                    // Arrow
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Actual
                    VStack(spacing: 2) {
                        Text("\(actual)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(scoreColor(actual))
                        Text("Actual")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 70)

                    // Error points display with +/- direction
                    if let signedError = prediction.signedError,
                       let absError = prediction.absoluteError {
                        Text(signedError >= 0 ? "+\(signedError)" : "\(signedError)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(width: 40)
                            .foregroundStyle(errorColor(absError))
                    }
                }
            } else {
                // Unresolved - just show prediction
                HStack(spacing: 8) {
                    VStack(spacing: 2) {
                        Text("\(prediction.predictedScore)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.purple)
                        Text("Predicted")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 70)

                    // Placeholder for alignment
                    Spacer()
                        .frame(width: 70 + 8 + 14 + 40) // actual column + spacing + arrow + badge
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func scoreColor(_ score: Int) -> Color {
        switch score {
        case 0...40: return .red
        case 41...60: return .orange
        case 61...80: return .green
        case 81...100: return .mint
        default: return .gray
        }
    }

    private func errorColor(_ error: Int) -> Color {
        switch error {
        case 0...5: return .mint
        case 6...10: return .green
        case 11...15: return .orange
        default: return .red
        }
    }

    private func errorLabel(_ error: Int) -> String {
        switch error {
        case 0...5: return "Excellent"
        case 6...10: return "Good"
        case 11...15: return "Fair"
        default: return "Poor"
        }
    }
}

// MARK: - Preview

#Preview {
    let mockPredictions = (0..<10).map { daysAgo -> Prediction in
        let calendar = Calendar.current
        let targetDate = calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
        let createdAt = calendar.date(byAdding: .day, value: -daysAgo - 1, to: Date())!
        let predicted = Int.random(in: 55...85)
        let actual = daysAgo > 0 ? predicted + Int.random(in: -12...12) : nil

        return Prediction(
            createdAt: createdAt,
            targetDate: targetDate,
            predictedScore: predicted,
            confidence: [.full, .partial].randomElement()!,
            source: .rules,
            actualScore: actual,
            actualScoreRecordedAt: actual != nil ? targetDate : nil
        )
    }

    PredictionAccuracyView(predictions: mockPredictions, timeRange: .week)
}
