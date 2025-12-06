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

        // Predict with only day of week (not enough features)
        let metrics = HealthMetrics(
            date: Date(),
            restingHeartRate: nil,
            hrv: nil,
            sleepDuration: nil
        )

        let result = await model.predict(from: metrics)

        if case .insufficientData = result {
            // Expected - only dayOfWeek available (1 feature)
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
                dayOfWeek: 0.5
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
                dayOfWeek: 0.5
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

    // MARK: - Helper Methods

    private func createTrainingExamples(count: Int) -> [TrainingExample] {
        var examples: [TrainingExample] = []
        for i in 0..<count {
            let features = FeatureVector(
                hrvNormalized: Double.random(in: 0.3...0.7),
                rhrNormalized: Double.random(in: 0.3...0.7),
                sleepNormalized: Double.random(in: 0.4...0.8),
                dayOfWeek: Double(i % 7) / 6.0
            )
            let label = Double.random(in: 50...80)
            let date = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
            examples.append(TrainingExample(features: features, label: label, date: date))
        }
        return examples
    }
}
