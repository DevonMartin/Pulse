//
//  ReadinessCalculator.swift
//  Pulse
//
//  Created by Devon Martin on 12/4/2025.
//

import Foundation

// MARK: - Protocol

/// Defines the interface for calculating readiness scores.
///
/// The app interacts with this protocol, allowing us to:
/// 1. Test with predictable mock calculations
/// 2. Swap algorithms without changing other code
/// 3. A/B test different scoring approaches in the future
protocol ReadinessCalculatorProtocol: Sendable {
    /// Calculates a readiness score from health metrics and user input.
    ///
    /// - Parameters:
    ///   - metrics: Health data from HealthKit (some fields may be nil)
    ///   - energyLevel: User's subjective energy rating (1-5), nil if no check-in
    /// - Returns: A ReadinessScore with breakdown and confidence indicator
    nonisolated func calculate(from metrics: HealthMetrics?, energyLevel: Int?) -> ReadinessScore?
}

// MARK: - Implementation

/// Calculates readiness scores using population-based norms.
///
/// This is the v1 algorithm that uses general population ranges rather than
/// personalized baselines. Future versions will incorporate historical data
/// for personalized scoring.
///
/// ## Scoring Philosophy
/// Each metric is scored 0-100 based on how favorable the value is:
/// - HRV: Higher is better (indicates parasympathetic recovery)
/// - Resting HR: Lower is better (indicates cardiovascular efficiency)
/// - Sleep: 7-9 hours is optimal (too little OR too much can indicate issues)
/// - Energy: Direct mapping from user's 1-5 rating
///
/// ## Weights
/// - HRV: 30% - Most reliable recovery indicator
/// - Sleep: 25% - Critical for recovery
/// - Energy: 25% - Subjective but valuable signal
/// - Resting HR: 20% - Useful but more variable
///
/// This struct is explicitly nonisolated since it performs pure computation
/// with no mutable state, making it safe to use from any isolation context.
struct ReadinessCalculator: ReadinessCalculatorProtocol, Sendable {
    nonisolated init() {}

    nonisolated func calculate(from metrics: HealthMetrics?, energyLevel: Int?) -> ReadinessScore? {
        // Calculate individual component scores
        let hrvScore = metrics?.hrv.map { scoreHRV($0) }
        let rhrScore = metrics?.restingHeartRate.map { scoreRestingHeartRate($0) }
        let sleepScore = metrics?.sleepDuration.map { scoreSleep($0) }
        let energyScore = energyLevel.map { scoreEnergy($0) }

        // Build the breakdown
        let breakdown = ReadinessBreakdown(
            hrvScore: hrvScore,
            restingHeartRateScore: rhrScore,
            sleepScore: sleepScore,
            energyScore: energyScore
        )

        // Need at least one component to calculate a score
        guard breakdown.componentCount > 0 else {
            return nil
        }

        // Calculate weighted average of available components
        let finalScore = calculateWeightedScore(breakdown: breakdown)

        // Determine confidence based on data availability
        let confidence = determineConfidence(componentCount: breakdown.componentCount)

        return ReadinessScore(
            date: metrics?.date ?? Date(),
            score: finalScore,
            breakdown: breakdown,
            confidence: confidence,
            healthMetrics: metrics,
            userEnergyLevel: energyLevel
        )
    }

    // MARK: - Component Scoring Functions

    /// Scores HRV (Heart Rate Variability) on a 0-100 scale.
    ///
    /// Population norms for HRV (SDNN in ms):
    /// - < 20ms: Very low (poor recovery, high stress)
    /// - 20-40ms: Below average
    /// - 40-60ms: Average
    /// - 60-100ms: Above average (good recovery)
    /// - > 100ms: Excellent (athletes, very fit individuals)
    private nonisolated func scoreHRV(_ hrv: Double) -> Int {
        switch hrv {
        case ..<20:
            // 0-20ms → score 10-30
            return Int(10 + (hrv / 20) * 20)
        case 20..<40:
            // 20-40ms → score 30-50
            return Int(30 + ((hrv - 20) / 20) * 20)
        case 40..<60:
            // 40-60ms → score 50-70
            return Int(50 + ((hrv - 40) / 20) * 20)
        case 60..<100:
            // 60-100ms → score 70-90
            return Int(70 + ((hrv - 60) / 40) * 20)
        default:
            // 100ms+ → score 90-100
            return min(100, Int(90 + ((hrv - 100) / 50) * 10))
        }
    }

    /// Scores Resting Heart Rate on a 0-100 scale.
    ///
    /// Population norms for RHR (bpm):
    /// - > 90: High (poor fitness or stress)
    /// - 80-90: Above average
    /// - 70-80: Average
    /// - 60-70: Good
    /// - 50-60: Very good (athletes)
    /// - < 50: Excellent (elite athletes) - but watch for bradycardia
    private nonisolated func scoreRestingHeartRate(_ rhr: Double) -> Int {
        switch rhr {
        case 90...:
            // 90+ bpm → score 10-30
            return max(10, Int(30 - ((rhr - 90) / 20) * 20))
        case 80..<90:
            // 80-90 bpm → score 30-50
            return Int(50 - ((rhr - 80) / 10) * 20)
        case 70..<80:
            // 70-80 bpm → score 50-65
            return Int(65 - ((rhr - 70) / 10) * 15)
        case 60..<70:
            // 60-70 bpm → score 65-80
            return Int(80 - ((rhr - 60) / 10) * 15)
        case 50..<60:
            // 50-60 bpm → score 80-95
            return Int(95 - ((rhr - 50) / 10) * 15)
        case 40..<50:
            // 40-50 bpm → score 90-100 (athlete range)
            return Int(90 + ((50 - rhr) / 10) * 10)
        default:
            // < 40 bpm → cap at 85 (could indicate issues)
            return 85
        }
    }

    /// Scores sleep duration on a 0-100 scale.
    ///
    /// Optimal sleep for adults is 7-9 hours. Both too little
    /// and too much sleep can indicate recovery issues.
    private nonisolated func scoreSleep(_ duration: TimeInterval) -> Int {
        let hours = duration / 3600

        switch hours {
        case ..<4:
            // < 4 hours → score 10-25
            return Int(10 + (hours / 4) * 15)
        case 4..<5:
            // 4-5 hours → score 25-40
            return Int(25 + ((hours - 4) / 1) * 15)
        case 5..<6:
            // 5-6 hours → score 40-60
            return Int(40 + ((hours - 5) / 1) * 20)
        case 6..<7:
            // 6-7 hours → score 60-80
            return Int(60 + ((hours - 6) / 1) * 20)
        case 7..<8:
            // 7-8 hours → score 80-95
            return Int(80 + ((hours - 7) / 1) * 15)
        case 8..<9:
            // 8-9 hours → score 95-100
            return Int(95 + ((hours - 8) / 1) * 5)
        case 9..<10:
            // 9-10 hours → score 90-95 (slightly too much)
            return Int(95 - ((hours - 9) / 1) * 5)
        default:
            // 10+ hours → score 70-85 (oversleeping can indicate issues)
            return max(70, Int(90 - ((hours - 10) / 2) * 10))
        }
    }

    /// Scores user's subjective energy level on a 0-100 scale.
    ///
    /// Direct mapping from 1-5 scale:
    /// - 1 (Very Low) → 20
    /// - 2 (Low) → 40
    /// - 3 (Moderate) → 60
    /// - 4 (High) → 80
    /// - 5 (Very High) → 100
    private nonisolated func scoreEnergy(_ level: Int) -> Int {
        let clamped = max(1, min(5, level))
        return clamped * 20
    }

    // MARK: - Score Aggregation

    /// Calculates the weighted average of available component scores.
    ///
    /// When some components are missing, their weights are redistributed
    /// proportionally among the available components.
    private nonisolated func calculateWeightedScore(breakdown: ReadinessBreakdown) -> Int {
        var weightedSum: Double = 0
        var totalWeight: Double = 0

        let weights = ReadinessBreakdown.weights

        if let hrv = breakdown.hrvScore {
            let weight = weights[.hrv]!
            weightedSum += Double(hrv) * weight
            totalWeight += weight
        }

        if let rhr = breakdown.restingHeartRateScore {
            let weight = weights[.restingHeartRate]!
            weightedSum += Double(rhr) * weight
            totalWeight += weight
        }

        if let sleep = breakdown.sleepScore {
            let weight = weights[.sleep]!
            weightedSum += Double(sleep) * weight
            totalWeight += weight
        }

        if let energy = breakdown.energyScore {
            let weight = weights[.energy]!
            weightedSum += Double(energy) * weight
            totalWeight += weight
        }

        // Normalize by total weight (redistributes missing weights)
        guard totalWeight > 0 else { return 0 }
        return Int(round(weightedSum / totalWeight))
    }

    /// Determines confidence level based on how many components have data.
    private nonisolated func determineConfidence(componentCount: Int) -> ReadinessConfidence {
        switch componentCount {
        case 4: return .full
        case 2...3: return .partial
        default: return .limited
        }
    }
}

// MARK: - Mock Implementation

/// A mock calculator for testing and SwiftUI previews.
struct MockReadinessCalculator: ReadinessCalculatorProtocol, Sendable {
    let mockScore: ReadinessScore?
    let shouldReturnNil: Bool

    nonisolated init(mockScore: ReadinessScore? = nil, shouldReturnNil: Bool = false) {
        self.mockScore = mockScore
        self.shouldReturnNil = shouldReturnNil
    }

    nonisolated func calculate(from metrics: HealthMetrics?, energyLevel: Int?) -> ReadinessScore? {
        if shouldReturnNil { return nil }

        if let mock = mockScore {
            return mock
        }

        // Return a default score for previews
        return ReadinessScore(
            score: 75,
            breakdown: ReadinessBreakdown(
                hrvScore: 70,
                restingHeartRateScore: 75,
                sleepScore: 80,
                energyScore: 80
            ),
            confidence: .full
        )
    }
}
