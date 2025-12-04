//
//  ReadinessBreakdown.swift
//  Pulse
//
//  Created by Devon Martin on 12/4/2025.
//

import Foundation

/// Individual component scores that make up the overall readiness score.
///
/// Each component is scored 0-100 independently, then weighted to produce
/// the final score. Nil values indicate the metric wasn't available.
nonisolated struct ReadinessBreakdown: Equatable, Sendable {

    // MARK: - Component Scores (0-100 each, nil if unavailable)

    /// Score based on heart rate variability.
    /// Higher HRV generally indicates better recovery.
    let hrvScore: Int?

    /// Score based on resting heart rate.
    /// Lower RHR generally indicates better cardiovascular fitness and recovery.
    let restingHeartRateScore: Int?

    /// Score based on sleep duration.
    /// 7-9 hours is considered optimal for most adults.
    let sleepScore: Int?

    /// Score based on user's subjective energy level.
    /// Direct mapping from their 1-5 rating.
    let energyScore: Int?

    // MARK: - Weights

    /// The weights used for each component in the final calculation.
    /// These are stored so we can show users how their score was calculated.
    static let weights: [Component: Double] = [
        .hrv: 0.30,
        .restingHeartRate: 0.20,
        .sleep: 0.25,
        .energy: 0.25
    ]

    /// Components that can contribute to the readiness score
    enum Component: String, CaseIterable, Sendable {
        case hrv = "HRV"
        case restingHeartRate = "Resting HR"
        case sleep = "Sleep"
        case energy = "Energy"
    }

    // MARK: - Computed Properties

    /// Returns which components have data
    var availableComponents: [Component] {
        var components: [Component] = []
        if hrvScore != nil { components.append(.hrv) }
        if restingHeartRateScore != nil { components.append(.restingHeartRate) }
        if sleepScore != nil { components.append(.sleep) }
        if energyScore != nil { components.append(.energy) }
        return components
    }

    /// Returns the number of components with data (0-4)
    var componentCount: Int {
        availableComponents.count
    }

    /// Returns a dictionary of component scores for display
    var componentScores: [Component: Int] {
        var scores: [Component: Int] = [:]
        if let hrv = hrvScore { scores[.hrv] = hrv }
        if let rhr = restingHeartRateScore { scores[.restingHeartRate] = rhr }
        if let sleep = sleepScore { scores[.sleep] = sleep }
        if let energy = energyScore { scores[.energy] = energy }
        return scores
    }
}

// MARK: - Debug Description

extension ReadinessBreakdown: CustomStringConvertible {
    var description: String {
        let parts = [
            hrvScore.map { "HRV: \($0)" },
            restingHeartRateScore.map { "RHR: \($0)" },
            sleepScore.map { "Sleep: \($0)" },
            energyScore.map { "Energy: \($0)" }
        ].compactMap { $0 }

        return "Breakdown(\(parts.joined(separator: ", ")))"
    }
}
