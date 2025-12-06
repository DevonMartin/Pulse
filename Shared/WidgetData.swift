//
//  WidgetData.swift
//  Pulse
//
//  Created by Devon Martin on 12/6/2025.
//

import Foundation

/// Data structure shared between the main app and widget extension.
/// Stored as JSON in the App Group container.
struct WidgetData: Codable {
    let score: Int?
    let scoreDescription: String?
    let morningCheckInComplete: Bool
    let eveningCheckInComplete: Bool
    let personalizationDays: Int
    let personalizationTarget: Int
    let lastUpdated: Date
}
