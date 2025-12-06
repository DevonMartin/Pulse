//
//  ReadinessScore.swift
//  Pulse
//
//  Created by Devon Martin on 12/4/2025.
//

import Foundation

/// Indicates how much data contributed to a readiness score.
/// More data generally means a more reliable score.
enum ReadinessConfidence: String, Codable, Sendable {
    /// All four metrics available (HRV, RHR, Sleep, Energy)
    case full
    /// 2-3 metrics available
    case partial
    /// Only 1 metric available - score is speculative
    case limited
}

/// A calculated readiness score for a specific date.
///
/// This is a domain model representing how recovered/ready the user is.
/// The score ranges from 0-100, where:
/// - 0-40: Poor readiness (consider rest)
/// - 41-60: Moderate readiness (light activity okay)
/// - 61-80: Good readiness (normal activity)
/// - 81-100: Excellent readiness (peak performance day)
nonisolated struct ReadinessScore: Identifiable, Equatable, Sendable {
    let id: UUID
    let date: Date
    let score: Int
    let breakdown: ReadinessBreakdown
    let confidence: ReadinessConfidence

    /// The health metrics that were used to calculate this score
    let healthMetrics: HealthMetrics?

    /// The user's subjective energy level (1-5) that was factored in
    let userEnergyLevel: Int?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        score: Int,
        breakdown: ReadinessBreakdown,
        confidence: ReadinessConfidence,
        healthMetrics: HealthMetrics? = nil,
        userEnergyLevel: Int? = nil
    ) {
        self.id = id
        self.date = date
        self.score = max(0, min(100, score)) // Clamp to 0-100
        self.breakdown = breakdown
        self.confidence = confidence
        self.healthMetrics = healthMetrics
        self.userEnergyLevel = userEnergyLevel
    }
}

// MARK: - Convenience

extension ReadinessScore {
    /// Human-readable description of the score
    var scoreDescription: String {
        ReadinessStyles.description(for: score)
    }

    /// Suggested action based on score
    var recommendation: String {
        ReadinessStyles.recommendation(for: score)
    }

    /// Returns true if this score is from today
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
}
