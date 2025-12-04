//
//  CheckInEntityTests.swift
//  PulseTests
//
//  Created by Devon Martin on 12/3/2025.
//

import Testing
@testable import Pulse
import Foundation

@MainActor
struct CheckInEntityTests {

    // MARK: - Initialization

    @Test func defaultInitializationHasExpectedValues() {
        let entity = CheckInEntity()

        #expect(entity.energyLevel == 3)
        #expect(entity.type == .morning)
        #expect(entity.healthSnapshot == nil)
    }

    @Test func initializationPreservesAllProperties() {
        let id = UUID()
        let timestamp = Date()
        let snapshot = HealthSnapshotEntity()

        let entity = CheckInEntity(
            id: id,
            timestamp: timestamp,
            type: .evening,
            energyLevel: 5,
            healthSnapshot: snapshot
        )

        #expect(entity.id == id)
        #expect(entity.timestamp == timestamp)
        #expect(entity.type == .evening)
        #expect(entity.energyLevel == 5)
        #expect(entity.healthSnapshot === snapshot)
    }

    // MARK: - Type Computed Property

    @Test func typeGetterReturnsCorrectType() {
        let morningEntity = CheckInEntity(type: .morning, energyLevel: 3)
        let eveningEntity = CheckInEntity(type: .evening, energyLevel: 4)

        #expect(morningEntity.type == .morning)
        #expect(eveningEntity.type == .evening)
    }

    @Test func typeSetterUpdatesRawValue() {
        let entity = CheckInEntity(type: .morning, energyLevel: 3)

        entity.type = .evening

        #expect(entity.typeRawValue == "evening")
        #expect(entity.type == .evening)
    }

    @Test func typeDefaultsToMorningForInvalidRawValue() {
        let entity = CheckInEntity()
        entity.typeRawValue = "invalid"

        #expect(entity.type == .morning)
    }

    // MARK: - Update from Domain Model

    @Test func updateFromCheckInUpdatesAllProperties() {
        let entity = CheckInEntity(type: .morning, energyLevel: 2)
        let newId = UUID()
        let newTimestamp = Calendar.current.date(byAdding: .hour, value: -1, to: Date())!
        let checkIn = CheckIn(
            id: newId,
            timestamp: newTimestamp,
            type: .evening,
            energyLevel: 5
        )

        entity.update(from: checkIn)

        #expect(entity.id == newId)
        #expect(entity.timestamp == newTimestamp)
        #expect(entity.type == .evening)
        #expect(entity.energyLevel == 5)
    }

    @Test func updateFromCheckInDoesNotAffectHealthSnapshot() {
        let snapshot = HealthSnapshotEntity()
        let entity = CheckInEntity(type: .morning, energyLevel: 3, healthSnapshot: snapshot)
        let checkIn = CheckIn(type: .evening, energyLevel: 4)

        entity.update(from: checkIn)

        // Snapshot should remain unchanged
        #expect(entity.healthSnapshot === snapshot)
    }

    // MARK: - Domain Model Conversion

    @Test func conversionToDomainModelPreservesProperties() {
        let id = UUID()
        let timestamp = Date()
        let metrics = HealthMetrics(
            date: timestamp,
            restingHeartRate: 62,
            hrv: 45,
            sleepDuration: 7 * 3600,
            steps: 8000,
            activeCalories: 350
        )
        let snapshot = HealthSnapshotEntity(from: metrics)

        let entity = CheckInEntity(
            id: id,
            timestamp: timestamp,
            type: .morning,
            energyLevel: 4,
            healthSnapshot: snapshot
        )

        let checkIn = CheckIn(from: entity)

        #expect(checkIn.id == id)
        #expect(checkIn.timestamp == timestamp)
        #expect(checkIn.type == .morning)
        #expect(checkIn.energyLevel == 4)
        #expect(checkIn.healthSnapshot?.restingHeartRate == 62)
    }

    @Test func conversionToDomainModelHandlesNilSnapshot() {
        let entity = CheckInEntity(type: .morning, energyLevel: 3, healthSnapshot: nil)

        let checkIn = CheckIn(from: entity)

        #expect(checkIn.healthSnapshot == nil)
    }

    // MARK: - Energy Level Boundaries

    @Test func energyLevelAcceptsValidRange() {
        for level in 1...5 {
            let entity = CheckInEntity(type: .morning, energyLevel: level)
            #expect(entity.energyLevel == level)
        }
    }

    @Test func energyLevelAcceptsOutOfRangeValues() {
        // Entity doesn't validate - that's the domain model's job
        let lowEntity = CheckInEntity(type: .morning, energyLevel: 0)
        let highEntity = CheckInEntity(type: .morning, energyLevel: 10)

        #expect(lowEntity.energyLevel == 0)
        #expect(highEntity.energyLevel == 10)
    }
}
