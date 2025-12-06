//
//  PersonalizedReadinessModel.swift
//  Pulse
//
//  Created by Devon Martin on 12/6/2025.
//

import Foundation

/// A personalized ML model that learns individual readiness patterns.
///
/// This model is trained on the user's own data to learn what "readiness"
/// means for them specifically, rather than using population averages.
///
/// ## Algorithm
/// Uses weighted linear regression with ridge regularization:
/// - Input: Normalized health metrics (HRV, RHR, sleep, day of week)
/// - Output: Predicted readiness score (20-100)
/// - Label: Blended energy (40% AM + 60% PM)
///
/// Linear regression is chosen over complex models because:
/// - Works well with small datasets (even 3-5 examples)
/// - Fast training on-device
/// - Interpretable coefficients
/// - Sufficient for capturing personal patterns
///
/// ## Persistence
/// The trained weights are saved to UserDefaults and loaded on subsequent
/// launches. Re-training happens automatically when new data is available.
actor PersonalizedReadinessModel {

    // MARK: - Types

    /// Result of a prediction attempt
    enum PredictionResult: Sendable {
        case success(score: Int)
        case insufficientData
        case modelNotTrained
        case error(Error)
    }

    /// Training status
    enum TrainingStatus: Equatable, Sendable {
        case notTrained
        case training
        case trained(exampleCount: Int, lastTrainedAt: Date)
        case failed(String)
    }

    // MARK: - Model Parameters

    /// Learned weights for each feature + bias term
    /// Order: [bias, hrv, rhr, sleep, dayOfWeek]
    private var weights: [Double]?

    /// Current training status
    private(set) var status: TrainingStatus = .notTrained

    /// Minimum examples required for training
    private let minimumExamplesForTraining = 3

    /// Ridge regularization parameter (prevents overfitting)
    private let ridgeLambda: Double = 0.1

    // MARK: - Persistence Keys

    private let weightsKey = "PersonalizedReadinessModel.weights"
    private let exampleCountKey = "PersonalizedReadinessModel.exampleCount"
    private let lastTrainedKey = "PersonalizedReadinessModel.lastTrained"

    // MARK: - Initialization

    init() {}

    // MARK: - Model Loading

    /// Loads previously trained weights from UserDefaults.
    ///
    /// Call this on app launch to restore the trained model.
    func loadSavedModel() {
        guard let savedWeights = UserDefaults.standard.array(forKey: weightsKey) as? [Double],
              savedWeights.count == 5 else {
            status = .notTrained
            return
        }

        weights = savedWeights

        let exampleCount = UserDefaults.standard.integer(forKey: exampleCountKey)
        let lastTrained = UserDefaults.standard.object(forKey: lastTrainedKey) as? Date ?? Date.distantPast

        status = .trained(exampleCount: exampleCount, lastTrainedAt: lastTrained)
    }

    // MARK: - Training

    /// Trains the model on provided training examples using linear regression.
    ///
    /// - Parameter examples: Training examples with features and labels
    /// - Returns: True if training succeeded, false otherwise
    @discardableResult
    func train(on examples: [TrainingExample]) -> Bool {
        guard examples.count >= minimumExamplesForTraining else {
            status = .notTrained
            return false
        }

        status = .training

        // Build design matrix X and target vector y
        // X has shape (n, 5): [1, hrv, rhr, sleep, dayOfWeek] for each example
        // y has shape (n,): label for each example

        let n = examples.count
        let featureCount = 5  // bias + 4 features

        var X = [Double](repeating: 0, count: n * featureCount)
        var y = [Double](repeating: 0, count: n)

        for (i, example) in examples.enumerated() {
            let features = example.features.toArray()
            X[i * featureCount + 0] = 1.0  // bias term
            X[i * featureCount + 1] = features[0]  // hrv
            X[i * featureCount + 2] = features[1]  // rhr
            X[i * featureCount + 3] = features[2]  // sleep
            X[i * featureCount + 4] = features[3]  // dayOfWeek
            y[i] = example.label
        }

        // Solve using normal equations with ridge regularization:
        // w = (X^T X + lambdaI)^(-1) X^T y

        guard let w = solveRidgeRegression(X: X, y: y, n: n, p: featureCount) else {
            status = .failed("Linear algebra error during training")
            return false
        }

        weights = w

        // Save to UserDefaults
        UserDefaults.standard.set(w, forKey: weightsKey)
        UserDefaults.standard.set(examples.count, forKey: exampleCountKey)
        UserDefaults.standard.set(Date(), forKey: lastTrainedKey)

        status = .trained(exampleCount: examples.count, lastTrainedAt: Date())
        return true
    }

    // MARK: - Inference

    /// Predicts a readiness score from health metrics.
    ///
    /// - Parameter metrics: The health metrics to base the prediction on
    /// - Returns: Prediction result with score or failure reason
    func predict(from metrics: HealthMetrics?) -> PredictionResult {
        guard let w = weights else {
            return .modelNotTrained
        }

        // Create feature extractor with current training count
        // This determines whether to use opinionated or linear normalization
        let featureExtractor = FeatureExtractor(trainingExampleCount: trainingExampleCount)
        let features = featureExtractor.extractFeatures(from: metrics)

        // Check if we have enough feature data
        guard features.availableFeatureCount >= 2 else {
            return .insufficientData
        }

        // Compute prediction: w[0] + w[1]*x1 + w[2]*x2 + ...
        let x = features.toArray()
        var prediction = w[0]  // bias
        for i in 0..<4 {
            prediction += w[i + 1] * x[i]
        }

        // Clamp to valid range and round
        let clampedScore = max(20, min(100, Int(round(prediction))))
        return .success(score: clampedScore)
    }

    /// Returns the number of training examples used.
    var trainingExampleCount: Int {
        switch status {
        case .trained(let count, _):
            return count
        default:
            return 0
        }
    }

    // MARK: - Linear Algebra (Ridge Regression)

    /// Solves ridge regression using manual implementation.
    ///
    /// Computes: w = (X^T X + lambdaI)^(-1) X^T y
    ///
    /// For small matrices (5x5), we use Gaussian elimination with partial pivoting
    /// instead of LAPACK to avoid deprecation warnings and complexity.
    ///
    /// - Parameters:
    ///   - X: Design matrix (n x p), row-major
    ///   - y: Target vector (n)
    ///   - n: Number of examples
    ///   - p: Number of features (including bias)
    /// - Returns: Weight vector (p) or nil if computation fails
    private func solveRidgeRegression(X: [Double], y: [Double], n: Int, p: Int) -> [Double]? {
        // Compute X^T X (p x p matrix)
        var XtX = [Double](repeating: 0, count: p * p)
        for i in 0..<p {
            for j in 0..<p {
                var sum = 0.0
                for k in 0..<n {
                    sum += X[k * p + i] * X[k * p + j]
                }
                XtX[i * p + j] = sum
            }
        }

        // Add ridge regularization: X^T X + lambdaI
        // Don't regularize bias term (index 0)
        for i in 1..<p {
            XtX[i * p + i] += ridgeLambda
        }

        // Compute X^T y (p vector)
        var Xty = [Double](repeating: 0, count: p)
        for i in 0..<p {
            var sum = 0.0
            for k in 0..<n {
                sum += X[k * p + i] * y[k]
            }
            Xty[i] = sum
        }

        // Solve (X^T X + lambdaI) w = X^T y using Gaussian elimination
        return solveLinearSystem(A: XtX, b: Xty, n: p)
    }

    /// Solves Ax = b using Gaussian elimination with partial pivoting.
    ///
    /// - Parameters:
    ///   - A: n x n matrix (row-major)
    ///   - b: n-element vector
    ///   - n: Size of the system
    /// - Returns: Solution vector x, or nil if singular
    private func solveLinearSystem(A: [Double], b: [Double], n: Int) -> [Double]? {
        // Create augmented matrix [A | b]
        var aug = [[Double]](repeating: [Double](repeating: 0, count: n + 1), count: n)
        for i in 0..<n {
            for j in 0..<n {
                aug[i][j] = A[i * n + j]
            }
            aug[i][n] = b[i]
        }

        // Forward elimination with partial pivoting
        for col in 0..<n {
            // Find pivot
            var maxRow = col
            var maxVal = abs(aug[col][col])
            for row in (col + 1)..<n {
                if abs(aug[row][col]) > maxVal {
                    maxVal = abs(aug[row][col])
                    maxRow = row
                }
            }

            // Check for singularity
            if maxVal < 1e-10 {
                return nil
            }

            // Swap rows
            if maxRow != col {
                let temp = aug[col]
                aug[col] = aug[maxRow]
                aug[maxRow] = temp
            }

            // Eliminate column
            for row in (col + 1)..<n {
                let factor = aug[row][col] / aug[col][col]
                for j in col..<(n + 1) {
                    aug[row][j] -= factor * aug[col][j]
                }
            }
        }

        // Back substitution
        var x = [Double](repeating: 0, count: n)
        for i in stride(from: n - 1, through: 0, by: -1) {
            var sum = aug[i][n]
            for j in (i + 1)..<n {
                sum -= aug[i][j] * x[j]
            }
            x[i] = sum / aug[i][i]
        }

        return x
    }
}
