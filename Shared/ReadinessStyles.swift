//
//  ReadinessStyles.swift
//  Pulse
//
//  Created by Devon Martin on 12/6/2025.
//

import SwiftUI

/// Centralized styling for readiness scores.
/// Use this to ensure consistent colors and descriptions across the app and widget.
enum ReadinessStyles {

    // MARK: - Score Ranges

    /// Score thresholds for each category
    static let poorRange = 0...40
    static let moderateRange = 41...60
    static let goodRange = 61...80
    static let excellentRange = 81...100

    // MARK: - Colors

    /// Returns the appropriate color for a readiness score
    static func color(for score: Int) -> Color {
        switch score {
        case poorRange: return .red
        case moderateRange: return .orange
        case goodRange: return .green
        case excellentRange: return .mint
        default: return .gray
        }
    }

    // MARK: - Descriptions

    /// Returns the human-readable description for a readiness score
    static func description(for score: Int) -> String {
        switch score {
        case poorRange: return "Poor"
        case moderateRange: return "Moderate"
        case goodRange: return "Good"
        case excellentRange: return "Excellent"
        default: return "Unknown"
        }
    }

    /// Returns a recommendation based on the score
    static func recommendation(for score: Int) -> String {
        switch score {
        case poorRange: return "Take it easy today and prioritize rest"
        case moderateRange: return "A lighter day might serve you well"
        case goodRange: return "You're ready for a productive day"
        case excellentRange: return "You're at your best today"
        default: return ""
        }
    }
}
