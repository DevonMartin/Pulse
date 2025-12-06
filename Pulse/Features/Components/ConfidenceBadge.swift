//
//  ConfidenceBadge.swift
//  Pulse
//
//  Created by Devon Martin on 12/6/2025.
//

import SwiftUI

/// Badge showing the confidence level of a score or prediction.
///
/// Used across multiple features to indicate data quality:
/// - Dashboard: Readiness score and prediction confidence
/// - History: Historical score confidence levels
struct ConfidenceBadge: View {
    let confidence: ReadinessConfidence

    var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor.opacity(0.2))
            .foregroundStyle(backgroundColor)
            .clipShape(Capsule())
    }

    private var label: String {
        switch confidence {
        case .full: return "Full Data"
        case .partial: return "Partial Data"
        case .limited: return "Limited Data"
        }
    }

    private var backgroundColor: Color {
        switch confidence {
        case .full: return .green
        case .partial: return .orange
        case .limited: return .red
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ConfidenceBadge(confidence: .full)
        ConfidenceBadge(confidence: .partial)
        ConfidenceBadge(confidence: .limited)
    }
    .padding()
}
