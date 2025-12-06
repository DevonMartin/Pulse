//
//  TrainingExample.swift
//  Pulse
//
//  Created by Devon Martin on 12/6/2025.
//

import Foundation

/// A single training example for the personalized readiness model.
///
/// Each example pairs normalized health features with a "ground truth" label
/// derived from the user's subjective energy ratings.
struct TrainingExample: Sendable, Equatable {
    /// The normalized feature vector for this day
    let features: FeatureVector

    /// The target label (blended energy score, scaled to 20-100)
    let label: Double

    /// The date this example is from
    let date: Date
}
