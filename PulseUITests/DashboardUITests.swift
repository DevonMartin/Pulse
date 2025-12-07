//
//  DashboardUITests.swift
//  PulseUITests
//
//  Created by Devon Martin on 12/7/2025.
//

import XCTest

/// UI tests for Dashboard functionality.
///
/// These tests verify the visual states of the Dashboard based on:
/// - Time window (morning vs evening)
/// - Check-in status (complete vs incomplete)
/// - Score ranges and their descriptions
/// - Metrics availability
/// - Cross-day schedules (e.g., 6 PM - 6 AM for night shift workers)
///
/// Launch arguments:
/// - `--uitesting`: Enable UI testing mode
/// - `--morning-window` / `--evening-window`: Override time window
/// - `--no-checkin` / `--with-checkin` / `--both-checkins-complete`: Check-in state
/// - `--no-morning-checkin`: Simulates missed first check-in
/// - `--score-poor` / `--score-moderate` / `--score-excellent`: Score range (default: good)
/// - `--cross-day-schedule`: Simulates 6 PM - 6 AM schedule (user day spans two calendar days)
final class DashboardUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Screenshot Helper

    /// Directory where screenshots are saved during UI tests.
    /// Screenshots are saved to /tmp/PulseUITestScreenshots/ (accessible from host Mac)
    private static let screenshotDirectory = URL(fileURLWithPath: "/tmp/PulseUITestScreenshots")

    /// Captures a screenshot, attaches it to the test results, and saves to disk.
    private func takeScreenshot(name: String) {
        let screenshot = app.screenshot()

        // Attach to test results
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        // Save to disk for easy viewing
        saveScreenshotToDisk(screenshot: screenshot, name: name)
    }

    /// Saves screenshot PNG to /tmp/PulseUITestScreenshots/
    private func saveScreenshotToDisk(screenshot: XCUIScreenshot, name: String) {
        let fileManager = FileManager.default

        // Create directory if needed
        try? fileManager.createDirectory(at: Self.screenshotDirectory, withIntermediateDirectories: true)

        let fileURL = Self.screenshotDirectory.appendingPathComponent("\(name).png")
        try? screenshot.pngRepresentation.write(to: fileURL)
    }

    // MARK: - Readiness Score Label Tests

    @MainActor
    func testReadinessCardShowsPendingInMorningWindow() throws {
        app.launchArguments = ["--uitesting", "--morning-window", "--no-checkin"]
        app.launch()

        let readinessCard = app.staticTexts["Today's Readiness"]
        XCTAssertTrue(readinessCard.waitForExistence(timeout: 5))

        takeScreenshot(name: "Readiness-Pending-Morning")

        // Should show "Pending" label when waiting for first check-in
        let pendingLabel = app.staticTexts["Pending"]
        XCTAssertTrue(pendingLabel.exists, "Expected 'Pending' label in first check-in window without check-in")

        let pendingMessage = app.staticTexts["Complete your first check-in to see your readiness score"]
        XCTAssertTrue(pendingMessage.exists, "Expected pending message for first check-in")
    }

    @MainActor
    func testReadinessCardShowsMissedAfterMorningWindow() throws {
        app.launchArguments = ["--uitesting", "--evening-window", "--no-morning-checkin"]
        app.launch()

        let readinessCard = app.staticTexts["Today's Readiness"]
        XCTAssertTrue(readinessCard.waitForExistence(timeout: 5))

        takeScreenshot(name: "Readiness-Missed-Evening")

        // Should show "Missed" label when first check-in window has passed
        let missedLabel = app.staticTexts["Missed"]
        XCTAssertTrue(missedLabel.exists, "Expected 'Missed' label after first check-in window without check-in")

        let missedMessage = app.staticTexts["First check-in window has passed. Check in tomorrow for your score."]
        XCTAssertTrue(missedMessage.exists, "Expected missed message for tomorrow")
    }

    // MARK: - Score Description Tests

    @MainActor
    func testReadinessCardShowsGoodDescription() throws {
        // Default score range is "good" (61-80)
        app.launchArguments = ["--uitesting", "--morning-window", "--with-checkin"]
        app.launch()

        let readinessCard = app.staticTexts["Today's Readiness"]
        XCTAssertTrue(readinessCard.waitForExistence(timeout: 5))

        takeScreenshot(name: "Score-Good-75")

        // Should show "Good" description for score 75
        let goodLabel = app.staticTexts["Good"]
        XCTAssertTrue(goodLabel.exists, "Expected 'Good' description for score in 61-80 range")
    }

    @MainActor
    func testReadinessCardShowsExcellentDescription() throws {
        app.launchArguments = ["--uitesting", "--morning-window", "--with-checkin", "--score-excellent"]
        app.launch()

        let readinessCard = app.staticTexts["Today's Readiness"]
        XCTAssertTrue(readinessCard.waitForExistence(timeout: 5))

        takeScreenshot(name: "Score-Excellent-90")

        // Should show "Excellent" description for score 90
        let excellentLabel = app.staticTexts["Excellent"]
        XCTAssertTrue(excellentLabel.exists, "Expected 'Excellent' description for score in 81-100 range")
    }

    @MainActor
    func testReadinessCardShowsModerateDescription() throws {
        app.launchArguments = ["--uitesting", "--morning-window", "--with-checkin", "--score-moderate"]
        app.launch()

        let readinessCard = app.staticTexts["Today's Readiness"]
        XCTAssertTrue(readinessCard.waitForExistence(timeout: 5))

        takeScreenshot(name: "Score-Moderate-55")

        // Should show "Moderate" description for score 55
        let moderateLabel = app.staticTexts["Moderate"]
        XCTAssertTrue(moderateLabel.exists, "Expected 'Moderate' description for score in 41-60 range")
    }

    @MainActor
    func testReadinessCardShowsPoorDescription() throws {
        app.launchArguments = ["--uitesting", "--morning-window", "--with-checkin", "--score-poor"]
        app.launch()

        let readinessCard = app.staticTexts["Today's Readiness"]
        XCTAssertTrue(readinessCard.waitForExistence(timeout: 5))

        takeScreenshot(name: "Score-Poor-35")

        // Should show "Poor" description for score 35
        let poorLabel = app.staticTexts["Poor"]
        XCTAssertTrue(poorLabel.exists, "Expected 'Poor' description for score in 0-40 range")
    }

    // MARK: - Score Recommendations Tests

    @MainActor
    func testReadinessCardShowsGoodRecommendation() throws {
        app.launchArguments = ["--uitesting", "--morning-window", "--with-checkin"]
        app.launch()

        let readinessCard = app.staticTexts["Today's Readiness"]
        XCTAssertTrue(readinessCard.waitForExistence(timeout: 5))

        takeScreenshot(name: "Recommendation-Good")

        let recommendation = app.staticTexts["You're ready for a productive day"]
        XCTAssertTrue(recommendation.exists, "Expected good recommendation text")
    }

    @MainActor
    func testReadinessCardShowsExcellentRecommendation() throws {
        app.launchArguments = ["--uitesting", "--morning-window", "--with-checkin", "--score-excellent"]
        app.launch()

        let readinessCard = app.staticTexts["Today's Readiness"]
        XCTAssertTrue(readinessCard.waitForExistence(timeout: 5))

        takeScreenshot(name: "Recommendation-Excellent")

        let recommendation = app.staticTexts["You're at your best today"]
        XCTAssertTrue(recommendation.exists, "Expected excellent recommendation text")
    }

    @MainActor
    func testReadinessCardShowsModerateRecommendation() throws {
        app.launchArguments = ["--uitesting", "--morning-window", "--with-checkin", "--score-moderate"]
        app.launch()

        let readinessCard = app.staticTexts["Today's Readiness"]
        XCTAssertTrue(readinessCard.waitForExistence(timeout: 5))

        takeScreenshot(name: "Recommendation-Moderate")

        let recommendation = app.staticTexts["A lighter day might serve you well"]
        XCTAssertTrue(recommendation.exists, "Expected moderate recommendation text")
    }

    @MainActor
    func testReadinessCardShowsPoorRecommendation() throws {
        app.launchArguments = ["--uitesting", "--morning-window", "--with-checkin", "--score-poor"]
        app.launch()

        let readinessCard = app.staticTexts["Today's Readiness"]
        XCTAssertTrue(readinessCard.waitForExistence(timeout: 5))

        takeScreenshot(name: "Recommendation-Poor")

        let recommendation = app.staticTexts["Take it easy today and prioritize rest"]
        XCTAssertTrue(recommendation.exists, "Expected poor recommendation text")
    }

    // MARK: - Metrics Card Tests

    @MainActor
    func testMetricsCardShowsDataOnNewDay() throws {
        app.launchArguments = ["--uitesting", "--morning-window", "--no-checkin"]
        app.launch()

        let metricsCard = app.staticTexts["Today's Metrics"]
        XCTAssertTrue(metricsCard.waitForExistence(timeout: 5))

        takeScreenshot(name: "Metrics-Card")

        // Verify metric labels are present
        XCTAssertTrue(app.staticTexts["Resting HR"].exists, "Expected Resting HR label")
        XCTAssertTrue(app.staticTexts["HRV"].exists, "Expected HRV label")
        XCTAssertTrue(app.staticTexts["Sleep"].exists, "Expected Sleep label")
        XCTAssertTrue(app.staticTexts["Energy"].exists, "Expected Energy label")
    }

    // MARK: - Check-In Card Tests

    @MainActor
    func testCheckInCardShowsFirstCheckInPrompt() throws {
        app.launchArguments = ["--uitesting", "--morning-window", "--no-checkin"]
        app.launch()

        // Should show time-agnostic prompt
        let prompt = app.staticTexts["Ready to Start?"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 5), "Expected 'Ready to Start?' prompt")

        takeScreenshot(name: "CheckIn-First-Prompt")

        // Should show "First Check-In" button
        let checkInButton = app.buttons["First Check-In"]
        XCTAssertTrue(checkInButton.exists, "Expected 'First Check-In' button")
    }

    @MainActor
    func testCheckInCardShowsWaitingForSecondCheckIn() throws {
        app.launchArguments = ["--uitesting", "--morning-window", "--with-checkin"]
        app.launch()

        // Should show completion status for first check-in
        let completedLabel = app.staticTexts["First Check-In"]
        XCTAssertTrue(completedLabel.waitForExistence(timeout: 5), "Expected 'First Check-In' completion label")

        takeScreenshot(name: "CheckIn-Waiting-For-Second")

        // Should show message about second check-in
        let waitingMessage = app.staticTexts["Come back later for your second check-in"]
        XCTAssertTrue(waitingMessage.exists, "Expected waiting message for second check-in")
    }

    @MainActor
    func testCheckInCardShowsSecondCheckInPrompt() throws {
        app.launchArguments = ["--uitesting", "--evening-window", "--with-morning-checkin"]
        app.launch()

        // Should show time-agnostic prompt
        let prompt = app.staticTexts["Time for Check-In #2"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 5), "Expected 'Time for Check-In #2' prompt")

        takeScreenshot(name: "CheckIn-Second-Prompt")

        // Should show second check-in button
        let checkInButton = app.buttons["Second Check-In"]
        XCTAssertTrue(checkInButton.exists, "Expected 'Second Check-In' button")
    }

    @MainActor
    func testCheckInCardShowsCompletedWhenBothCheckInsDone() throws {
        app.launchArguments = ["--uitesting", "--evening-window", "--both-checkins-complete"]
        app.launch()

        let completeMessage = app.staticTexts["All Done for Today"]
        XCTAssertTrue(completeMessage.waitForExistence(timeout: 5), "Expected 'All Done for Today' message")

        takeScreenshot(name: "CheckIn-All-Complete")

        let seeYouMessage = app.staticTexts["See you next time!"]
        XCTAssertTrue(seeYouMessage.exists, "Expected 'See you next time!' message")
    }

    @MainActor
    func testCheckInCardShowsSecondPromptWhenFirstMissed() throws {
        // Even if first check-in was missed, during second window the card shows second check-in prompt
        app.launchArguments = ["--uitesting", "--evening-window", "--no-morning-checkin"]
        app.launch()

        // Should show second check-in prompt (eveningPending state takes priority in evening window)
        let prompt = app.staticTexts["Time for Check-In #2"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 5), "Expected 'Time for Check-In #2' prompt in second window")

        takeScreenshot(name: "CheckIn-Second-First-Missed")

        // Should offer second check-in
        let checkInButton = app.buttons["Second Check-In"]
        XCTAssertTrue(checkInButton.exists, "Expected 'Second Check-In' button")
    }

    // MARK: - Cross-Day Schedule Tests (6 PM - 6 AM)
    // These tests verify the app works correctly for users whose "day" spans two calendar days
    // (e.g., night shift workers starting their day at 6 PM)

    @MainActor
    func testCrossDayScheduleFirstCheckInPrompt() throws {
        // User's day starts at 6 PM, first check-in window is 6 PM - 10 PM
        app.launchArguments = ["--uitesting", "--cross-day-schedule", "--morning-window", "--no-checkin"]
        app.launch()

        // Should show time-agnostic prompt (works for any schedule)
        let prompt = app.staticTexts["Ready to Start?"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 5), "Expected 'Ready to Start?' prompt for cross-day schedule")

        takeScreenshot(name: "CrossDay-First-Prompt")

        let checkInButton = app.buttons["First Check-In"]
        XCTAssertTrue(checkInButton.exists, "Expected 'First Check-In' button")
    }

    @MainActor
    func testCrossDayScheduleWaitingForSecond() throws {
        // User completed first check-in (e.g., at 7 PM), waiting for second window (11 PM+)
        app.launchArguments = ["--uitesting", "--cross-day-schedule", "--morning-window", "--with-checkin"]
        app.launch()

        let completedLabel = app.staticTexts["First Check-In"]
        XCTAssertTrue(completedLabel.waitForExistence(timeout: 5), "Expected 'First Check-In' completion label")

        takeScreenshot(name: "CrossDay-Waiting-For-Second")

        // Should use time-agnostic language
        let waitingMessage = app.staticTexts["Come back later for your second check-in"]
        XCTAssertTrue(waitingMessage.exists, "Expected time-agnostic waiting message")
    }

    @MainActor
    func testCrossDayScheduleSecondCheckInPrompt() throws {
        // User's second check-in window (11 PM+)
        app.launchArguments = ["--uitesting", "--cross-day-schedule", "--evening-window", "--with-morning-checkin"]
        app.launch()

        // Should show time-agnostic prompt
        let prompt = app.staticTexts["Time for Check-In #2"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 5), "Expected 'Time for Check-In #2' prompt")

        takeScreenshot(name: "CrossDay-Second-Prompt")

        let checkInButton = app.buttons["Second Check-In"]
        XCTAssertTrue(checkInButton.exists, "Expected 'Second Check-In' button")
    }

    @MainActor
    func testCrossDayScheduleAllComplete() throws {
        // Both check-ins done for cross-day schedule
        app.launchArguments = ["--uitesting", "--cross-day-schedule", "--evening-window", "--both-checkins-complete"]
        app.launch()

        let completeMessage = app.staticTexts["All Done for Today"]
        XCTAssertTrue(completeMessage.waitForExistence(timeout: 5), "Expected 'All Done for Today' message")

        takeScreenshot(name: "CrossDay-All-Complete")

        // Time-agnostic message works for any schedule
        let seeYouMessage = app.staticTexts["See you next time!"]
        XCTAssertTrue(seeYouMessage.exists, "Expected 'See you next time!' message")
    }

    @MainActor
    func testCrossDayScheduleReadinessScore() throws {
        // Verify readiness score displays correctly for cross-day schedule
        app.launchArguments = ["--uitesting", "--cross-day-schedule", "--morning-window", "--with-checkin"]
        app.launch()

        let readinessCard = app.staticTexts["Today's Readiness"]
        XCTAssertTrue(readinessCard.waitForExistence(timeout: 5))

        takeScreenshot(name: "CrossDay-Readiness-Score")

        // Should show score and description normally
        let goodLabel = app.staticTexts["Good"]
        XCTAssertTrue(goodLabel.exists, "Expected score description for cross-day schedule")
    }

    @MainActor
    func testCrossDayScheduleMissedFirstCheckIn() throws {
        // User missed first check-in window (past 10 PM), now in second window
        app.launchArguments = ["--uitesting", "--cross-day-schedule", "--evening-window", "--no-morning-checkin"]
        app.launch()

        // Readiness card should show "Missed"
        let missedLabel = app.staticTexts["Missed"]
        XCTAssertTrue(missedLabel.waitForExistence(timeout: 5), "Expected 'Missed' label for cross-day missed check-in")

        takeScreenshot(name: "CrossDay-Missed-First")

        // But should still be able to do second check-in
        let checkInButton = app.buttons["Second Check-In"]
        XCTAssertTrue(checkInButton.exists, "Expected 'Second Check-In' button even when first was missed")
    }
}
