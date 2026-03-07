//
//  PersonalizedReadinessModelTests.swift
//  PulseTests
//
//  Created by Devon Martin on 12/6/2025.
//

import Testing
@testable import Pulse
import Foundation

/// Tests for the PersonalizedReadinessModel.
///
/// Verifies:
/// 1. Training with minimum examples
/// 2. Training with insufficient data
/// 3. Prediction accuracy
/// 4. Score clamping to valid range
/// 5. Status tracking
@MainActor
struct PersonalizedReadinessModelTests {

    // MARK: - Training Tests

    @Test func trainWithMinimumExamplesSucceeds() async {
        let model = PersonalizedReadinessModel()

        let examples = createTrainingExamples(count: 3)
        let success = await model.train(on: examples)

        #expect(success == true)

        let status = await model.status
        if case .trained(let count, _) = status {
            #expect(count == 3)
        } else {
            Issue.record("Expected trained status")
        }
    }

    @Test func trainWithTwoExamplesFails() async {
        let model = PersonalizedReadinessModel()

        let examples = createTrainingExamples(count: 2)
        let success = await model.train(on: examples)

        #expect(success == false)

        let status = await model.status
        #expect(status == .notTrained)
    }

    @Test func trainWithEmptyExamplesFails() async {
        let model = PersonalizedReadinessModel()

        let success = await model.train(on: [])

        #expect(success == false)
    }

    @Test func trainWithManyExamplesSucceeds() async {
        let model = PersonalizedReadinessModel()

        let examples = createTrainingExamples(count: 50)
        let success = await model.train(on: examples)

        #expect(success == true)

        let count = await model.trainingExampleCount
        #expect(count == 50)
    }

    // MARK: - Prediction Tests

    @Test func predictWithoutTrainingReturnsNotTrained() async {
        let model = PersonalizedReadinessModel()
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: 60,
            hrv: 50,
            sleepDuration: 8 * 3600
        )

        let result = await model.predict(from: metrics)

        if case .modelNotTrained = result {
            // Expected
        } else {
            Issue.record("Expected modelNotTrained result")
        }
    }

    @Test func predictAfterTrainingReturnsScore() async {
        let model = PersonalizedReadinessModel()

        // Train on some examples
        let examples = createTrainingExamples(count: 5)
        await model.train(on: examples)

        // Predict
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: 60,
            hrv: 50,
            sleepDuration: 8 * 3600
        )

        let result = await model.predict(from: metrics)

        if case .success(let score) = result {
            #expect(score >= 20)
            #expect(score <= 100)
        } else {
            Issue.record("Expected success result")
        }
    }

    @Test func predictWithInsufficientFeaturesReturnsInsufficient() async {
        let model = PersonalizedReadinessModel()

        // Train the model
        let examples = createTrainingExamples(count: 5)
        await model.train(on: examples)

        // Predict with no features (not enough)
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: nil,
            hrv: nil,
            sleepDuration: nil
        )

        let result = await model.predict(from: metrics)

        if case .insufficientData = result {
            // Expected - no features available (0)
        } else {
            Issue.record("Expected insufficientData result")
        }
    }

    @Test func predictClampsScoreToValidRange() async {
        let model = PersonalizedReadinessModel()

        // Create examples that might produce extreme predictions
        var examples: [TrainingExample] = []
        for i in 0..<10 {
            let features = FeatureVector(
                hrvNormalized: Double(i) / 10.0,
                rhrNormalized: 0.5,
                sleepNormalized: 0.5,

                morningEnergyNormalized: 0.5,
                previousDayStepsNormalized: 0.5,
                previousDayCaloriesNormalized: 0.5,
                sleepNormalizedSquared: 0.25,
                previousDayStepsNormalizedSquared: 0.25,
                previousDayCaloriesNormalizedSquared: 0.25
            )
            // Use extreme labels to potentially cause extreme predictions
            let label = i < 5 ? 20.0 : 100.0
            examples.append(TrainingExample(features: features, label: label, date: Date()))
        }

        await model.train(on: examples)

        // Try to get a prediction that might be outside range
        let extremeMetrics = HealthMetrics(
            date: Date(),
            restingHeartRate: 40, // Very good
            hrv: 100, // Very good
            sleepDuration: 12 * 3600 // Maximum
        )

        let result = await model.predict(from: extremeMetrics)

        if case .success(let score) = result {
            #expect(score >= 20, "Score should be clamped to minimum 20")
            #expect(score <= 100, "Score should be clamped to maximum 100")
        }
    }

    // MARK: - Training Example Count

    @Test func trainingExampleCountIsZeroBeforeTraining() async {
        let model = PersonalizedReadinessModel()

        let count = await model.trainingExampleCount

        #expect(count == 0)
    }

    @Test func trainingExampleCountReflectsTrainedData() async {
        let model = PersonalizedReadinessModel()

        let examples = createTrainingExamples(count: 25)
        await model.train(on: examples)

        let count = await model.trainingExampleCount

        #expect(count == 25)
    }

    // MARK: - Model Learns Patterns

    @Test func modelLearnsPositiveCorrelation() async {
        let model = PersonalizedReadinessModel()

        // Create examples where high HRV = high energy
        var examples: [TrainingExample] = []
        for i in 0..<10 {
            let hrvValue = Double(i) / 9.0 // 0 to 1
            let features = FeatureVector(
                hrvNormalized: hrvValue,
                rhrNormalized: 0.5,
                sleepNormalized: 0.5,

                morningEnergyNormalized: 0.5,
                previousDayStepsNormalized: 0.5,
                previousDayCaloriesNormalized: 0.5,
                sleepNormalizedSquared: 0.25,
                previousDayStepsNormalizedSquared: 0.25,
                previousDayCaloriesNormalizedSquared: 0.25
            )
            // Label correlates with HRV
            let label = 40.0 + hrvValue * 40.0 // 40 to 80
            examples.append(TrainingExample(features: features, label: label, date: Date()))
        }

        await model.train(on: examples)

        // Low HRV should predict lower score
        let lowHrvMetrics = HealthMetrics(date: Date(), hrv: 20) // Normalized to 0
        let lowResult = await model.predict(from: lowHrvMetrics)

        // High HRV should predict higher score
        let highHrvMetrics = HealthMetrics(date: Date(), hrv: 100) // Normalized to 1
        let highResult = await model.predict(from: highHrvMetrics)

        if case .success(let lowScore) = lowResult,
           case .success(let highScore) = highResult {
            #expect(highScore > lowScore, "Higher HRV should predict higher score")
        }
    }

    // MARK: - Polynomial Feature Learning

    @Test func modelLearnsOptimalStepCount() async {
        let model = PersonalizedReadinessModel()

        // Simulate 30 days of a person whose sweet spot is ~8k steps (normalized 0.4).
        // Other features vary randomly so the model learns to isolate the steps signal.
        var examples: [TrainingExample] = []
        for i in 0..<30 {
            let stepsNorm = Double(i % 20) / 19.0 // 0 to 1 (0 to 20k steps)
            let optimal = 0.4 // 8k steps

            // Parabola: label peaks at 80 when steps = 8k, drops to ~67 at 0 and ~51 at 20k
            let stepsEffect = -80.0 * pow(stepsNorm - optimal, 2)
            // Other features contribute a baseline but with some noise
            let hrvNorm = Double.random(in: 0.3...0.7)
            let sleepNorm = Double.random(in: 0.4...0.7)
            let label = 60.0 + stepsEffect + (hrvNorm - 0.5) * 10.0

            let features = FeatureVector(
                hrvNormalized: hrvNorm,
                rhrNormalized: Double.random(in: 0.3...0.7),
                sleepNormalized: sleepNorm,
                morningEnergyNormalized: Double.random(in: 0.3...0.7),
                previousDayStepsNormalized: stepsNorm,
                previousDayCaloriesNormalized: Double.random(in: 0.3...0.7),
                sleepNormalizedSquared: sleepNorm * sleepNorm,
                previousDayStepsNormalizedSquared: stepsNorm * stepsNorm,
                previousDayCaloriesNormalizedSquared: Double.random(in: 0.09...0.49)
            )
            examples.append(TrainingExample(features: features, label: label, date: Date()))
        }

        let success = await model.train(on: examples)
        #expect(success)

        // Predict across a range of step counts, holding other metrics constant
        let baseMetrics = HealthMetrics(date: Date(), restingHeartRate: 60, hrv: 60, sleepDuration: 7.5 * 3600)
        let stepCounts = [0, 2_000, 4_000, 6_000, 8_000, 10_000, 14_000, 18_000, 20_000]

        print("Step count vs readiness score:")
        var scores: [Int: Int] = [:]
        for steps in stepCounts {
            let prevDay = HealthMetrics(date: Date(), steps: steps, activeCalories: 400)
            let result = await model.predict(from: baseMetrics, previousDayMetrics: prevDay)
            if case .success(let score) = result {
                scores[steps] = score
                print("  \(String(format: "%5d", steps)) steps → \(score)")
            }
        }

        // 8k should beat both extremes
        if let low = scores[0], let optimal = scores[8_000], let high = scores[20_000] {
            #expect(optimal > low, "8k steps should score higher than 0 (got \(optimal) vs \(low))")
            #expect(optimal > high, "8k steps should score higher than 20k (got \(optimal) vs \(high))")
        }
    }

    // MARK: - Helper Methods

    private func createTrainingExamples(count: Int) -> [TrainingExample] {
        var examples: [TrainingExample] = []
        for i in 0..<count {
            let sleepVal = Double.random(in: 0.4...0.8)
            let stepsVal = Double.random(in: 0.2...0.6)
            let caloriesVal = Double.random(in: 0.2...0.6)
            let features = FeatureVector(
                hrvNormalized: Double.random(in: 0.3...0.7),
                rhrNormalized: Double.random(in: 0.3...0.7),
                sleepNormalized: sleepVal,
                morningEnergyNormalized: Double.random(in: 0.25...0.75),
                previousDayStepsNormalized: stepsVal,
                previousDayCaloriesNormalized: caloriesVal,
                sleepNormalizedSquared: sleepVal * sleepVal,
                previousDayStepsNormalizedSquared: stepsVal * stepsVal,
                previousDayCaloriesNormalizedSquared: caloriesVal * caloriesVal
            )
            let label = Double.random(in: 50...80)
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            examples.append(TrainingExample(features: features, label: label, date: date))
        }
        return examples
    }
}
