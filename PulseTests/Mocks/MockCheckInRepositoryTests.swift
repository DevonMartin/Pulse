//
//  MockCheckInRepositoryTests.swift
//  PulseTests
//
//  Created by Devon Martin on 12/1/2025.
//

import Testing
@testable import Pulse
import Foundation

struct MockCheckInRepositoryTests {

    // MARK: - Save Tests

    @Test func saveAddsCheckInToList() async throws {
        let repository = await MockCheckInRepository()
        let checkIn = await CheckIn(type: .morning, energyLevel: 4)

        try await repository.save(checkIn)

        let checkIns = await repository.checkIns
        #expect(checkIns.count == 1)
        #expect(checkIns.first?.energyLevel == 4)
    }

    @Test func saveIncrementsCallCount() async throws {
        let repository = await MockCheckInRepository()

        try await repository.save(CheckIn(type: .morning, energyLevel: 3))
        try await repository.save(CheckIn(type: .morning, energyLevel: 4))

        let callCount = await repository.saveCallCount
        #expect(callCount == 2)
    }

    @Test func saveThrowsConfiguredError() async {
        let repository = await MockCheckInRepository()
        let expectedError = NSError(domain: "TestError", code: 123)
        await repository.setError(expectedError)

        do {
            try await repository.save(CheckIn(type: .morning, energyLevel: 3))
            #expect(Bool(false), "Expected error to be thrown")
        } catch {
            #expect((error as NSError).code == 123)
        }
    }

    @Test func savePreservesCheckInProperties() async throws {
        let repository = await MockCheckInRepository()
        let id = UUID()
        let timestamp = Date()
        let snapshot = HealthMetrics(
            date: timestamp,
            restingHeartRate: 62,
            hrv: 45,
            sleepDuration: 7 * 3600,
            steps: 8000,
            activeCalories: 350
        )
        let checkIn = await CheckIn(
            id: id,
            timestamp: timestamp,
            type: .evening,
            energyLevel: 5,
            healthSnapshot: snapshot
        )

        try await repository.save(checkIn)

        let saved = await repository.checkIns.first
        #expect(saved?.id == id)
        #expect(saved?.type == .evening)
        #expect(saved?.energyLevel == 5)
        #expect(saved?.healthSnapshot == snapshot)
    }

    // MARK: - Get Today's CheckIn Tests

    @Test func getTodaysCheckInReturnsMorningCheckIn() async throws {
        let repository = await MockCheckInRepository()
        let checkIn = await CheckIn(type: .morning, energyLevel: 5)
        try await repository.save(checkIn)

        let result = try await repository.getTodaysCheckIn(type: .morning)

        #expect(result != nil)
        #expect(result?.energyLevel == 5)
    }

    @Test func getTodaysCheckInReturnsNilForDifferentType() async throws {
        let repository = await MockCheckInRepository()
        let checkIn = await CheckIn(type: .morning, energyLevel: 5)
        try await repository.save(checkIn)

        let result = try await repository.getTodaysCheckIn(type: .evening)

        #expect(result == nil)
    }

    @Test func getTodaysCheckInReturnsNilForYesterdaysCheckIn() async throws {
        let repository = await MockCheckInRepository()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let checkIn = await CheckIn(timestamp: yesterday, type: .morning, energyLevel: 4)
        try await repository.save(checkIn)

        let result = try await repository.getTodaysCheckIn(type: .morning)

        #expect(result == nil)
    }

    @Test func getTodaysCheckInReturnsNilWhenEmpty() async throws {
        let repository = await MockCheckInRepository()

        let result = try await repository.getTodaysCheckIn(type: .morning)

        #expect(result == nil)
    }

    @Test func getTodaysCheckInThrowsConfiguredError() async {
        let repository = await MockCheckInRepository()
        await repository.setError(NSError(domain: "Test", code: 1))

        do {
            _ = try await repository.getTodaysCheckIn(type: .morning)
            #expect(Bool(false), "Expected error")
        } catch {
            // Expected
        }
    }

    // MARK: - Get CheckIns in Range Tests

    @Test func getCheckInsReturnsCheckInsInRange() async throws {
        let repository = await MockCheckInRepository()
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = Calendar.current.date(byAdding: .day, value: -2, to: today)!

        try await repository.save(CheckIn(timestamp: today, type: .morning, energyLevel: 5))
        try await repository.save(CheckIn(timestamp: yesterday, type: .morning, energyLevel: 4))
        try await repository.save(CheckIn(timestamp: twoDaysAgo, type: .morning, energyLevel: 3))

        let results = try await repository.getCheckIns(from: yesterday, to: today)

        #expect(results.count == 2)
    }

    @Test func getCheckInsReturnsSortedByTimestampDescending() async throws {
        let repository = await MockCheckInRepository()
        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)!

        try await repository.save(CheckIn(timestamp: yesterday, type: .morning, energyLevel: 3))
        try await repository.save(CheckIn(timestamp: today, type: .morning, energyLevel: 5))

        let results = try await repository.getCheckIns(from: yesterday, to: today)

        #expect(results.first?.energyLevel == 5) // Today should be first
        #expect(results.last?.energyLevel == 3)  // Yesterday should be last
    }

    // MARK: - Get Recent CheckIns Tests

    @Test func getRecentCheckInsRespectsLimit() async throws {
        let repository = await MockCheckInRepository()

        // Add 5 check-ins
        for i in 1...5 {
            let date = Calendar.current.date(byAdding: .hour, value: -i, to: Date())!
            let checkIn = await CheckIn(timestamp: date, type: .morning, energyLevel: i)
            try await repository.save(checkIn)
        }

        let recent = try await repository.getRecentCheckIns(limit: 3)

        #expect(recent.count == 3)
    }

    @Test func getRecentCheckInsReturnsAllWhenLimitExceedsCount() async throws {
        let repository = await MockCheckInRepository()
        try await repository.save(CheckIn(type: .morning, energyLevel: 3))
        try await repository.save(CheckIn(type: .morning, energyLevel: 4))

        let recent = try await repository.getRecentCheckIns(limit: 10)

        #expect(recent.count == 2)
    }

    @Test func getRecentCheckInsReturnsMostRecentFirst() async throws {
        let repository = await MockCheckInRepository()
        let older = Calendar.current.date(byAdding: .hour, value: -2, to: Date())!
        let newer = Calendar.current.date(byAdding: .hour, value: -1, to: Date())!

        try await repository.save(CheckIn(timestamp: older, type: .morning, energyLevel: 2))
        try await repository.save(CheckIn(timestamp: newer, type: .morning, energyLevel: 4))

        let recent = try await repository.getRecentCheckIns(limit: 2)

        #expect(recent.first?.energyLevel == 4) // Newer should be first
    }

    // MARK: - Delete Tests

    @Test func deleteRemovesCheckIn() async throws {
        let repository = await MockCheckInRepository()
        let checkIn = await CheckIn(type: .morning, energyLevel: 3)
        try await repository.save(checkIn)

        try await repository.delete(id: checkIn.id)

        let checkIns = await repository.checkIns
        #expect(checkIns.isEmpty)
    }

    @Test func deleteOnlyRemovesMatchingId() async throws {
        let repository = await MockCheckInRepository()
        let checkIn1 = await CheckIn(type: .morning, energyLevel: 3)
        let checkIn2 = await CheckIn(type: .morning, energyLevel: 4)
        try await repository.save(checkIn1)
        try await repository.save(checkIn2)

        try await repository.delete(id: checkIn1.id)

        let checkIns = await repository.checkIns
        #expect(checkIns.count == 1)
        #expect(checkIns.first?.id == checkIn2.id)
    }

    @Test func deleteDoesNothingForNonExistentId() async throws {
        let repository = await MockCheckInRepository()
        let checkIn = await CheckIn(type: .morning, energyLevel: 3)
        try await repository.save(checkIn)

        try await repository.delete(id: UUID()) // Different ID

        let checkIns = await repository.checkIns
        #expect(checkIns.count == 1)
    }

    @Test func deleteThrowsConfiguredError() async {
        let repository = await MockCheckInRepository()
        await repository.setError(NSError(domain: "Test", code: 1))

        do {
            try await repository.delete(id: UUID())
            #expect(Bool(false), "Expected error")
        } catch {
            // Expected
        }
    }

    // MARK: - Reset Tests

    @Test func resetClearsAllState() async throws {
        let repository = await MockCheckInRepository()
        try await repository.save(CheckIn(type: .morning, energyLevel: 3))
        await repository.setError(NSError(domain: "Test", code: 1))

        await repository.reset()

        let checkIns = await repository.checkIns
        let saveCount = await repository.saveCallCount
        #expect(checkIns.isEmpty)
        #expect(saveCount == 0)
    }
}

// MARK: - Helper Extension

extension MockCheckInRepository {
    func setError(_ error: Error?) async {
        self.shouldThrowError = error
    }
}
