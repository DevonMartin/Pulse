//
//  Item.swift
//  Pulse
//
//  Created by Devon Martin on 12/1/2025.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date = Date()

    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
