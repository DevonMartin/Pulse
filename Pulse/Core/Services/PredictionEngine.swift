//
//  PredictionEngine.swift
//  Pulse
//
//  Created by Devon Martin on 12/4/2025.
//

import Foundation

// MARK: - Protocol

/// Defines the interface for generating readiness predictions.
///
/// The prediction engine takes today's data and forecasts tomorrow's readiness.
/// This creates labeled training data for personalized ML:
/// - Input: today's metrics and energy level
/// - Output: tomorrow's predicted score → later compared to actual
protocol PredictionEngineProtocol: Sendable {
    /// Generates a prediction for tomorrow's readiness based on today's data.
    ///
    /// - Parameters:
    ///   - todayMetrics: Health metrics from today
    ///   - todayEnergyLevel: User's reported energy level today (1-5)
    ///   - todayScore: Today's calculated readiness score (optional baseline)
    /// - Returns: A prediction for tomorrow, or nil if insufficient data
    nonisolated func predictTomorrow(
        todayMetrics: HealthMetrics?,
        todayEnergyLevel: Int?,
        todayScore: Int?
    ) -> Prediction?

    /// The current prediction mode (rules, blended, or ml)
    nonisolated var currentSource: PredictionSource { get }
}

// MARK: - Implementation

/// Rules-based prediction engine for forecasting tomorrow's readiness.
///
/// ## Prediction Philosophy
///
/// Tomorrow's readiness depends on:
/// 1. **Today's recovery state**: Current HRV, RHR, sleep quality
/// 2. **Activity impact**: Today's activity can boost or drain tomorrow
/// 3. **Momentum**: Trends in the data (improving vs declining)
///
/// ## Rules-Based Approach (v1)
///
/// This initial version uses heuristics based on sports science research:
/// - Sleep under 6h → expect 10-15 point drop tomorrow
/// - High activity + good sleep → expect slight boost
/// - Low HRV trend → expect lower readiness
/// - High energy today → often sustains into tomorrow
///
/// As we collect prediction vs reality data, we'll train a personalized
/// CoreML model to replace/augment these rules.
struct PredictionEngine: PredictionEngineProtocol, Sendable {

    // MARK: - Configuration

    /// Base dampening factor - predictions shouldn't swing wildly day-to-day
    private let dampingFactor: Double = 0.7

    /// Minimum confidence required to make a prediction
    private let minimumDataPoints: Int = 1

    // MARK: - Protocol Conformance

    var currentSource: PredictionSource { .rules }

    func predictTomorrow(
        todayMetrics: HealthMetrics?,
        todayEnergyLevel: Int?,
        todayScore: Int?
    ) -> Prediction? {
        // Need at least some data to make a prediction
        let hasMetrics = todayMetrics?.hasAnyData ?? false
        let hasEnergy = todayEnergyLevel != nil
        let hasScore = todayScore != nil

        guard hasMetrics || hasEnergy || hasScore else {
            return nil
        }

        // Calculate base prediction score
        let predictedScore = calculatePredictedScore(
            metrics: todayMetrics,
            energyLevel: todayEnergyLevel,
            todayScore: todayScore
        )

        // Determine confidence based on data quality
        let confidence = determineConfidence(
            metrics: todayMetrics,
            energyLevel: todayEnergyLevel,
            todayScore: todayScore
        )

        // Target date is tomorrow
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!

        return Prediction(
            createdAt: Date(),
            targetDate: tomorrow,
            predictedScore: predictedScore,
            confidence: confidence,
            source: currentSource,
            inputMetrics: todayMetrics,
            inputEnergyLevel: todayEnergyLevel
        )
    }

    // MARK: - Prediction Logic

    /// Calculates the predicted readiness score using rules-based heuristics.
    private func calculatePredictedScore(
        metrics: HealthMetrics?,
        energyLevel: Int?,
        todayScore: Int?
    ) -> Int {
        var adjustments: [Double] = []
        var weights: [Double] = []

        // Start with today's score as baseline if available
        var baseScore: Double = 65.0 // Default neutral baseline
        if let today = todayScore {
            baseScore = Double(today)
        }

        // RULE 1: Sleep Impact (most important for next-day readiness)
        if let sleep = metrics?.sleepDuration {
            let sleepHours = sleep / 3600
            let sleepAdjustment = calculateSleepImpact(hours: sleepHours)
            adjustments.append(sleepAdjustment)
            weights.append(0.35) // Sleep is heavily weighted
        }

        // RULE 2: HRV Impact (recovery indicator)
        if let hrv = metrics?.hrv {
            let hrvAdjustment = calculateHRVImpact(hrv: hrv)
            adjustments.append(hrvAdjustment)
            weights.append(0.25)
        }

        // RULE 3: Resting Heart Rate Impact
        if let rhr = metrics?.restingHeartRate {
            let rhrAdjustment = calculateRHRImpact(rhr: rhr)
            adjustments.append(rhrAdjustment)
            weights.append(0.15)
        }

        // RULE 4: Activity Impact (steps as proxy)
        if let steps = metrics?.steps {
            let activityAdjustment = calculateActivityImpact(steps: steps, sleepHours: (metrics?.sleepDuration ?? 0) / 3600)
            adjustments.append(activityAdjustment)
            weights.append(0.10)
        }

        // RULE 5: Energy Level Impact (subjective but valuable)
        if let energy = energyLevel {
            let energyAdjustment = calculateEnergyImpact(level: energy)
            adjustments.append(energyAdjustment)
            weights.append(0.15)
        }

        // Calculate weighted adjustment
        var totalAdjustment: Double = 0
        var totalWeight: Double = 0

        for (adjustment, weight) in zip(adjustments, weights) {
            totalAdjustment += adjustment * weight
            totalWeight += weight
        }

        // Normalize if we have weights
        if totalWeight > 0 {
            totalAdjustment /= totalWeight
        }

        // Apply damping to prevent wild swings
        let dampedAdjustment = totalAdjustment * dampingFactor

        // Calculate final score
        let rawScore = baseScore + dampedAdjustment
        let clampedScore = max(15, min(95, rawScore)) // Keep in realistic range

        return Int(round(clampedScore))
    }

    // MARK: - Individual Impact Calculations

    /// Calculates sleep's impact on tomorrow's readiness.
    /// More granular ranges for nuanced predictions.
    private func calculateSleepImpact(hours: Double) -> Double {
        switch hours {
        case ..<3:
            return -20.0 // Extreme sleep debt
        case 3..<4:
            return -17.0 // Severe sleep debt
        case 4..<4.5:
            return -14.0 // Very poor
        case 4.5..<5:
            return -11.0 // Poor
        case 5..<5.5:
            return -8.0  // Below average
        case 5.5..<6:
            return -5.0  // Slightly below average
        case 6..<6.5:
            return -2.0  // Slight deficit
        case 6.5..<7:
            return 1.0   // Borderline adequate
        case 7..<7.5:
            return 4.0   // Good sleep
        case 7.5..<8:
            return 6.0   // Very good
        case 8..<8.5:
            return 8.0   // Optimal
        case 8.5..<9:
            return 6.0   // Great
        case 9..<9.5:
            return 3.0   // Slightly long
        case 9.5..<10:
            return 0.0   // Long
        default:
            return -3.0  // Oversleep may indicate fatigue/illness
        }
    }

    /// Calculates HRV's impact on tomorrow's readiness.
    /// More granular ranges based on HRV variability.
    private func calculateHRVImpact(hrv: Double) -> Double {
        switch hrv {
        case ..<15:
            return -15.0 // Very low, stressed/fatigued
        case 15..<20:
            return -12.0 // Low
        case 20..<25:
            return -9.0  // Below average
        case 25..<30:
            return -6.0  // Slightly below average
        case 30..<35:
            return -3.0  // Borderline
        case 35..<40:
            return 0.0   // Average
        case 40..<50:
            return 3.0   // Above average
        case 50..<60:
            return 5.0   // Good
        case 60..<70:
            return 7.0   // Very good
        case 70..<85:
            return 9.0   // Great recovery
        case 85..<100:
            return 11.0  // Excellent recovery
        default:
            return 12.0  // Elite recovery
        }
    }

    /// Calculates RHR's impact on tomorrow's readiness.
    /// More granular ranges for heart rate sensitivity.
    private func calculateRHRImpact(rhr: Double) -> Double {
        switch rhr {
        case 95...:
            return -12.0 // Very elevated, illness likely
        case 90..<95:
            return -10.0 // Elevated, stress/illness
        case 85..<90:
            return -8.0  // High
        case 80..<85:
            return -6.0  // Above average
        case 75..<80:
            return -4.0  // Slightly above average
        case 70..<75:
            return -2.0  // Average high
        case 65..<70:
            return 0.0   // Average
        case 60..<65:
            return 2.0   // Good
        case 55..<60:
            return 4.0   // Very good
        case 50..<55:
            return 6.0   // Excellent
        case 45..<50:
            return 8.0   // Athletic
        default:
            return 10.0  // Elite athletic
        }
    }

    /// Calculates activity's impact on tomorrow's readiness.
    /// More granular step ranges with sleep-dependent adjustments.
    private func calculateActivityImpact(steps: Int, sleepHours: Double) -> Double {
        let isWellRested = sleepHours >= 7

        switch steps {
        case ..<1000:
            return -4.0  // Very sedentary
        case 1000..<2000:
            return -3.0  // Sedentary
        case 2000..<3000:
            return -2.0  // Low activity
        case 3000..<4000:
            return 0.0   // Light activity
        case 4000..<5000:
            return 2.0   // Moderate-light
        case 5000..<6000:
            return 3.0   // Moderate
        case 6000..<7000:
            return 4.0   // Good activity
        case 7000..<8000:
            return isWellRested ? 5.0 : 2.0
        case 8000..<9000:
            return isWellRested ? 6.0 : 1.0
        case 9000..<10000:
            return isWellRested ? 6.0 : 0.0
        case 10000..<12000:
            return isWellRested ? 5.0 : -2.0
        case 12000..<14000:
            return isWellRested ? 3.0 : -4.0
        case 14000..<16000:
            return isWellRested ? 1.0 : -6.0
        case 16000..<18000:
            return isWellRested ? -1.0 : -8.0
        case 18000..<20000:
            return isWellRested ? -3.0 : -10.0
        default:
            return isWellRested ? -5.0 : -12.0 // Very high, fatiguing
        }
    }

    /// Calculates today's energy level impact on tomorrow.
    /// Energy tends to carry momentum - high energy often sustains.
    private func calculateEnergyImpact(level: Int) -> Double {
        switch level {
        case 1:
            return -10.0 // Very low energy today → likely tired tomorrow
        case 2:
            return -5.0  // Low energy
        case 3:
            return 0.0   // Neutral
        case 4:
            return 5.0   // Good energy momentum
        case 5:
            return 8.0   // High energy momentum
        default:
            return 0.0
        }
    }

    // MARK: - Confidence Calculation

    /// Determines prediction confidence based on available data.
    private func determineConfidence(
        metrics: HealthMetrics?,
        energyLevel: Int?,
        todayScore: Int?
    ) -> ReadinessConfidence {
        var dataPoints = 0

        // Count available data points
        if metrics?.sleepDuration != nil { dataPoints += 1 }
        if metrics?.hrv != nil { dataPoints += 1 }
        if metrics?.restingHeartRate != nil { dataPoints += 1 }
        if metrics?.steps != nil { dataPoints += 1 }
        if energyLevel != nil { dataPoints += 1 }
        if todayScore != nil { dataPoints += 1 }

        switch dataPoints {
        case 5...6:
            return .full
        case 3...4:
            return .partial
        default:
            return .limited
        }
    }
}

// MARK: - Mock Implementation

/// A mock prediction engine for testing and SwiftUI previews.
struct MockPredictionEngine: PredictionEngineProtocol, Sendable {
    let mockPrediction: Prediction?
    let mockSource: PredictionSource
    let shouldReturnNil: Bool

    init(
        mockPrediction: Prediction? = nil,
        mockSource: PredictionSource = .rules,
        shouldReturnNil: Bool = false
    ) {
        self.mockPrediction = mockPrediction
        self.mockSource = mockSource
        self.shouldReturnNil = shouldReturnNil
    }

    var currentSource: PredictionSource { mockSource }

    func predictTomorrow(
        todayMetrics: HealthMetrics?,
        todayEnergyLevel: Int?,
        todayScore: Int?
    ) -> Prediction? {
        if shouldReturnNil { return nil }

        if let mock = mockPrediction {
            return mock
        }

        // Return a sensible default for previews
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!

        return Prediction(
            targetDate: tomorrow,
            predictedScore: 72,
            confidence: .partial,
            source: mockSource,
            inputMetrics: todayMetrics,
            inputEnergyLevel: todayEnergyLevel
        )
    }
}
