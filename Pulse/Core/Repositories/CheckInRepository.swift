//
//  CheckInRepository.swift
//  Pulse
//
//  Created by Devon Martin on 12/1/2025.
//

import Foundation
import SwiftData

// MARK: - Protocol

/// Defines the interface for check-in data operations.
///
/// The app layer interacts with this protocol, never with SwiftData directly.
/// This allows us to:
/// 1. Test without a real database
/// 2. Swap storage implementations without changing app code
/// 3. Keep persistence concerns isolated from business logic
protocol CheckInRepositoryProtocol: Sendable {
    /// Saves a new check-in with an optional health snapshot
    func save(_ checkIn: CheckIn) async throws

    /// Retrieves today's check-in of the specified type, if it exists
    func getTodaysCheckIn(type: CheckInType) async throws -> CheckIn?

    /// Retrieves all check-ins within a date range
    func getCheckIns(from startDate: Date, to endDate: Date) async throws -> [CheckIn]

    /// Retrieves the most recent check-ins (for dashboard display)
    func getRecentCheckIns(limit: Int) async throws -> [CheckIn]

    /// Deletes a check-in by ID
    func delete(id: UUID) async throws
}

// MARK: - Implementation

/// SwiftData-backed implementation of CheckInRepository.
///
/// This class manages all database operations for check-ins.
/// It's marked as @ModelActor which provides:
/// - A dedicated actor context for thread-safe database access
/// - Automatic ModelContext management
@ModelActor
actor CheckInRepository: CheckInRepositoryProtocol {

    // MARK: - CheckInRepositoryProtocol

    func save(_ checkIn: CheckIn) async throws {
        // Create the health snapshot entity if we have health data
        var snapshotEntity: HealthSnapshotEntity?
        if let snapshot = checkIn.healthSnapshot {
            snapshotEntity = HealthSnapshotEntity(from: snapshot)
            modelContext.insert(snapshotEntity!)
        }

        // Create the check-in entity
        let entity = CheckInEntity(
            id: checkIn.id,
            timestamp: checkIn.timestamp,
            type: checkIn.type,
            energyLevel: checkIn.energyLevel,
            healthSnapshot: snapshotEntity
        )
        modelContext.insert(entity)

        try modelContext.save()
    }

    func getTodaysCheckIn(type: CheckInType) async throws -> CheckIn? {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

        let typeRaw = type.rawValue
        let predicate = #Predicate<CheckInEntity> { entity in
            entity.timestamp >= startOfToday &&
            entity.timestamp < endOfToday &&
            entity.typeRawValue == typeRaw
        }

        var descriptor = FetchDescriptor<CheckInEntity>(predicate: predicate)
        descriptor.fetchLimit = 1

        let results = try modelContext.fetch(descriptor)
        if let entity = results.first {
            return await CheckIn(from: entity)
        }
        return nil
    }

    func getCheckIns(from startDate: Date, to endDate: Date) async throws -> [CheckIn] {
        let predicate = #Predicate<CheckInEntity> { entity in
            entity.timestamp >= startDate && entity.timestamp <= endDate
        }

        let descriptor = FetchDescriptor<CheckInEntity>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        let results = try modelContext.fetch(descriptor)
        var checkIns: [CheckIn] = []
        for entity in results {
            checkIns.append(await CheckIn(from: entity))
        }
        return checkIns
    }

    func getRecentCheckIns(limit: Int) async throws -> [CheckIn] {
        var descriptor = FetchDescriptor<CheckInEntity>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        let results = try modelContext.fetch(descriptor)
        var checkIns: [CheckIn] = []
        for entity in results {
            checkIns.append(await CheckIn(from: entity))
        }
        return checkIns
    }

    func delete(id: UUID) async throws {
        let predicate = #Predicate<CheckInEntity> { entity in
            entity.id == id
        }

        let descriptor = FetchDescriptor<CheckInEntity>(predicate: predicate)
        let results = try modelContext.fetch(descriptor)

        for entity in results {
            // Delete associated snapshot if it exists
            if let snapshot = entity.healthSnapshot {
                modelContext.delete(snapshot)
            }
            modelContext.delete(entity)
        }

        try modelContext.save()
    }
}

// MARK: - Mock Implementation

/// A mock implementation for testing and SwiftUI previews.
actor MockCheckInRepository: CheckInRepositoryProtocol {
    var checkIns: [CheckIn] = []
    var saveCallCount = 0
    var shouldThrowError: Error?

    /// Creates a mock repository, optionally pre-populated with sample data
    init(withSampleData: Bool = false) {
        if withSampleData {
            checkIns = Self.generateSampleCheckIns()
        }
    }

    /// Generates sample historical check-ins for the past 14 days
    private static func generateSampleCheckIns() -> [CheckIn] {
        let calendar = Calendar.current
        let today = Date()

        return (1..<14).compactMap { daysAgo -> CheckIn? in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else {
                return nil
            }

            // Set time to morning (around 7-9 AM)
            let hour = Int.random(in: 7...9)
            let minute = Int.random(in: 0...59)
            guard let timestamp = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date) else {
                return nil
            }

            let energyLevel = Int.random(in: 2...5)

            // Create health snapshot for some check-ins
            let healthSnapshot: HealthMetrics? = Bool.random() ? HealthMetrics(
                date: date,
                restingHeartRate: Double.random(in: 52...72),
                hrv: Double.random(in: 25...75),
                sleepDuration: TimeInterval.random(in: 5*3600...9*3600),
                steps: Int.random(in: 3000...15000),
                activeCalories: Double.random(in: 150...650)
            ) : nil

            return CheckIn(
                timestamp: timestamp,
                type: .morning,
                energyLevel: energyLevel,
                healthSnapshot: healthSnapshot
            )
        }
    }

    func save(_ checkIn: CheckIn) async throws {
        saveCallCount += 1
        if let error = shouldThrowError {
            throw error
        }
        checkIns.append(checkIn)
    }

    func getTodaysCheckIn(type: CheckInType) async throws -> CheckIn? {
        if let error = shouldThrowError {
            throw error
        }
        let calendar = Calendar.current
        return checkIns.first { calendar.isDateInToday($0.timestamp) && $0.type == type }
    }

    func getCheckIns(from startDate: Date, to endDate: Date) async throws -> [CheckIn] {
        if let error = shouldThrowError {
            throw error
        }
        return checkIns.filter { $0.timestamp >= startDate && $0.timestamp <= endDate }
            .sorted { $0.timestamp > $1.timestamp }
    }

    func getRecentCheckIns(limit: Int) async throws -> [CheckIn] {
        if let error = shouldThrowError {
            throw error
        }
        return Array(checkIns.sorted { $0.timestamp > $1.timestamp }.prefix(limit))
    }

    func delete(id: UUID) async throws {
        if let error = shouldThrowError {
            throw error
        }
        checkIns.removeAll { $0.id == id }
    }

    // MARK: - Test Helpers

    func reset() {
        checkIns = []
        saveCallCount = 0
        shouldThrowError = nil
    }
}
