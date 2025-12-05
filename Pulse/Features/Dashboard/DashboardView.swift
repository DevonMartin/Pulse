//
//  DashboardView.swift
//  Pulse
//
//  Created by Devon Martin on 12/1/2025.
//

import SwiftUI

/// The main dashboard showing today's status and prompting for check-in if needed.
///
/// This is the primary view users see when opening the app.
/// It shows:
/// - Whether they've completed their morning check-in
/// - Their energy level if checked in
/// - Today's health metrics summary
struct DashboardView: View {
    @Environment(AppContainer.self) private var container

    @State private var morningCheckIn: CheckIn?
    @State private var eveningCheckIn: CheckIn?
    @State private var todaysMetrics: HealthMetrics?
    @State private var readinessScore: ReadinessScore?
    @State private var tomorrowsPrediction: Prediction?
    @State private var isLoading = true
    @State private var showingMorningCheckIn = false
    @State private var showingEveningCheckIn = false
    @State private var errorMessage: String?

    // MARK: - Time Windows (can be user-configurable later)

    /// Hour when morning check-in window ends (default: 4 PM / 16:00)
    private let morningWindowEndHour: Int = 16

    /// Hour when evening check-in window starts (default: 5 PM / 17:00)
    private let eveningWindowStartHour: Int = 17

    /// Current hour for time-based UI decisions
    private var currentHour: Int {
        Calendar.current.component(.hour, from: Date())
    }

    /// Whether we're in the morning check-in window
    private var isMorningWindow: Bool {
        currentHour < morningWindowEndHour
    }

    /// Whether we're in the evening check-in window
    private var isEveningWindow: Bool {
        currentHour >= eveningWindowStartHour
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Readiness score card (shown when we have a score)
                    if let score = readinessScore {
                        ReadinessScoreCard(score: score)
                    }

                    // Tomorrow's prediction card (shown after evening check-in or if we have one)
                    if let prediction = tomorrowsPrediction {
                        TomorrowPredictionCard(prediction: prediction)
                    }

                    // Single contextual check-in card
                    CheckInCard(
                        morningCheckIn: morningCheckIn,
                        eveningCheckIn: eveningCheckIn,
                        isLoading: isLoading,
                        isMorningWindow: isMorningWindow,
                        isEveningWindow: isEveningWindow,
                        onMorningCheckInTapped: { showingMorningCheckIn = true },
                        onEveningCheckInTapped: { showingEveningCheckIn = true }
                    )

                    // Today's metrics card
                    TodaysMetricsCard(metrics: todaysMetrics)

                    // Error display
                    if let error = errorMessage {
                        Text(error)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .padding()
                    }
                }
                .padding()
                .animation(.easeInOut(duration: 0.3), value: isLoading)
            }
            .navigationTitle("Dashboard")
            .refreshable {
                await loadData()
            }
            .sheet(isPresented: $showingMorningCheckIn) {
                CheckInView {
                    Task { await loadData() }
                }
            }
            .sheet(isPresented: $showingEveningCheckIn) {
                EveningCheckInView {
                    Task { await loadData() }
                }
            }
            .task {
                await requestAuthorizationAndLoadData()
            }
        }
    }

    // MARK: - Data Loading

    private func requestAuthorizationAndLoadData() async {
        do {
            try await container.healthKitService.requestAuthorization()
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func loadData() async {
        errorMessage = nil

        // Load check-ins and metrics concurrently
        async let morningTask: () = loadMorningCheckIn()
        async let eveningTask: () = loadEveningCheckIn()
        async let metricsTask: () = loadTodaysMetrics()
        async let predictionTask: () = loadTomorrowsPrediction()

        await morningTask
        await eveningTask
        await metricsTask
        await predictionTask

        // Calculate readiness score from loaded data and save it
        await calculateAndSaveReadinessScore()

        isLoading = false
    }

    private func calculateAndSaveReadinessScore() async {
        guard let score = container.readinessCalculator.calculate(
            from: todaysMetrics,
            energyLevel: morningCheckIn?.energyLevel
        ) else {
            readinessScore = nil
            return
        }

        readinessScore = score

        // Save the score for historical tracking
        do {
            try await container.readinessScoreRepository.save(score)
        } catch {
            print("Failed to save readiness score: \(error)")
        }
    }

    private func loadMorningCheckIn() async {
        do {
            morningCheckIn = try await container.checkInRepository.getTodaysCheckIn(type: .morning)
        } catch {
            print("Failed to load morning check-in: \(error)")
        }
    }

    private func loadEveningCheckIn() async {
        do {
            eveningCheckIn = try await container.checkInRepository.getTodaysCheckIn(type: .evening)
        } catch {
            print("Failed to load evening check-in: \(error)")
        }
    }

    private func loadTodaysMetrics() async {
        do {
            todaysMetrics = try await container.healthKitService.fetchMetrics(for: Date())
        } catch {
            print("Failed to load today's metrics: \(error)")
        }
    }

    private func loadTomorrowsPrediction() async {
        do {
            // First try to get existing prediction for tomorrow
            let calendar = Calendar.current
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
            tomorrowsPrediction = try await container.predictionRepository.getPrediction(for: tomorrow)
        } catch {
            print("Failed to load prediction: \(error)")
        }
    }
}

// MARK: - Readiness Score Card

/// Displays the calculated readiness score prominently.
private struct ReadinessScoreCard: View {
    let score: ReadinessScore

    var body: some View {
        VStack(spacing: 16) {
            // Header with confidence badge
            HStack {
                Text("Today's Readiness")
                    .font(.headline)

                Spacer()

                ConfidenceBadge(confidence: score.confidence)
            }

            // Main score display
            HStack(alignment: .center, spacing: 24) {
                // Score circle
                ZStack {
                    Circle()
                        .stroke(scoreColor.opacity(0.2), lineWidth: 12)

                    Circle()
                        .trim(from: 0, to: CGFloat(score.score) / 100)
                        .stroke(scoreColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text("\(score.score)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())

                        Text(score.scoreDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 120, height: 120)
                .animation(.easeInOut(duration: 0.5), value: score.score)

                // Breakdown
                VStack(alignment: .leading, spacing: 8) {
					BreakdownRow(
						label: "Resting HR",
						score: score.breakdown.restingHeartRateScore,
						color: .red
					)
                    BreakdownRow(
                        label: "HRV",
                        score: score.breakdown.hrvScore,
                        color: .pink
                    )
                    BreakdownRow(
                        label: "Sleep",
                        score: score.breakdown.sleepScore,
                        color: .indigo
                    )
                    BreakdownRow(
                        label: "Energy",
                        score: score.breakdown.energyScore,
                        color: .orange
                    )
                }
            }

            // Recommendation
            Text(score.recommendation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var scoreColor: Color {
        switch score.score {
        case 0...40: return .red
        case 41...60: return .orange
        case 61...80: return .green
        case 81...100: return .mint
        default: return .gray
        }
    }
}

/// Shows a single breakdown row with label and score bar.
private struct BreakdownRow: View {
    let label: String
    let score: Int?
    let color: Color

    /// Computed property to track for animation
    private var animatableScore: Int {
        score ?? 0
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .leading)

            if let score = score {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color.opacity(0.2))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(width: geometry.size.width * CGFloat(score) / 100)
                    }
                }
                .frame(height: 8)

                Text("\(score)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, alignment: .trailing)
                    .contentTransition(.numericText())
            } else {
                Text("--")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: animatableScore)
    }
}

/// Badge showing the confidence level of the score.
private struct ConfidenceBadge: View {
    let confidence: ReadinessConfidence

    var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor.opacity(0.2))
            .foregroundStyle(backgroundColor)
            .clipShape(Capsule())
    }

    private var label: String {
        switch confidence {
        case .full: return "Full Data"
        case .partial: return "Partial Data"
        case .limited: return "Limited Data"
        }
    }

    private var backgroundColor: Color {
        switch confidence {
        case .full: return .green
        case .partial: return .orange
        case .limited: return .red
        }
    }
}

// MARK: - Tomorrow's Prediction Card

/// Displays tomorrow's predicted readiness score.
private struct TomorrowPredictionCard: View {
    let prediction: Prediction

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Label("Tomorrow's Forecast", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(.purple)

                Spacer()

                ConfidenceBadge(confidence: prediction.confidence)
            }

            // Prediction display
            HStack(spacing: 20) {
                // Predicted score
                VStack(spacing: 4) {
                    Text("\(prediction.predictedScore)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreColor)
                        .contentTransition(.numericText())

                    Text(prediction.scoreDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Visual indicator
                VStack(alignment: .trailing, spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: trendIcon)
                            .foregroundStyle(scoreColor)
                        Text(trendText)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    Text(sourceLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            // Explanation
            Text(explanationText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.purple.opacity(0.1), Color.purple.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var scoreColor: Color {
        switch prediction.predictedScore {
        case 0...40: return .red
        case 41...60: return .orange
        case 61...80: return .green
        case 81...100: return .mint
        default: return .gray
        }
    }

    private var trendIcon: String {
        switch prediction.predictedScore {
        case 0...40: return "arrow.down.circle.fill"
        case 41...55: return "minus.circle.fill"
        case 56...75: return "equal.circle.fill"
        case 76...100: return "arrow.up.circle.fill"
        default: return "questionmark.circle.fill"
        }
    }

    private var trendText: String {
        switch prediction.predictedScore {
        case 0...40: return "Rest day ahead"
        case 41...55: return "Take it easy"
        case 56...75: return "Moderate day"
        case 76...100: return "Great day ahead"
        default: return "Unknown"
        }
    }

    private var sourceLabel: String {
        switch prediction.source {
        case .rules: return "Rules-based prediction"
        case .blended: return "Hybrid prediction"
        case .ml: return "Personalized ML"
        }
    }

    private var explanationText: String {
        "Based on today's sleep, HRV, activity, and energy levels"
    }
}

// MARK: - Unified Check-In Card

/// A single contextual check-in card that shows the appropriate state based on:
/// - Time of day (morning vs evening window)
/// - Check-in completion status (morning done, evening done, both done)
private struct CheckInCard: View {
    let morningCheckIn: CheckIn?
    let eveningCheckIn: CheckIn?
    let isLoading: Bool
    let isMorningWindow: Bool
    let isEveningWindow: Bool
    let onMorningCheckInTapped: () -> Void
    let onEveningCheckInTapped: () -> Void

    /// Determines what state to show
    private var cardState: CardState {
        if isLoading { return .loading }

        let hasMorning = morningCheckIn != nil
        let hasEvening = eveningCheckIn != nil

        // Evening done - show completion (regardless of morning status)
        if hasEvening {
            return .allComplete
        }

        // Evening window, evening not done
        if isEveningWindow {
            return .eveningPending
        }

        // Morning window
        if isMorningWindow {
            if !hasMorning {
                return .morningPending
            } else {
                return .waitingForEvening
            }
        }

        // Between windows (4-5 PM gap)
        if hasMorning {
            return .waitingForEvening
        }

        // Fallback: morning not done, not in morning window, not evening yet
        return .morningMissed
    }

    private enum CardState {
        case loading
        case morningPending      // Morning window, no check-in yet
        case waitingForEvening   // Morning done, waiting for evening window
        case eveningPending      // Evening window, can check in
        case allComplete         // Both check-ins done
        case morningMissed       // Past morning window, no morning check-in
    }

    var body: some View {
        VStack(spacing: 16) {
            switch cardState {
            case .loading:
                loadingView

            case .morningPending:
                morningPromptView

            case .waitingForEvening:
                waitingForEveningView

            case .eveningPending:
                eveningPromptView

            case .allComplete:
                allCompleteView

            case .morningMissed:
                morningMissedView
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(backgroundGradient)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .animation(.easeInOut(duration: 0.3), value: cardState)
    }

    // MARK: - Card States

    private var loadingView: some View {
        HStack {
            ProgressView()
            Text("Checking status...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var morningPromptView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sun.horizon.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text("Good Morning!")
                .font(.headline)

            Text("Start your day with a quick check-in")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Check In Now") {
                onMorningCheckInTapped()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding(.vertical, 8)
    }

    private var waitingForEveningView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Label("Morning Check-In", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)

                Text("Come back this evening for your next check-in")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let checkIn = morningCheckIn {
                EnergyBadge(level: checkIn.energyLevel)
            }
        }
    }

    private var eveningPromptView: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.stars.fill")
                .font(.largeTitle)
                .foregroundStyle(.purple)

            Text("Good Evening!")
                .font(.headline)

            Text("Wrap up your day and see tomorrow's prediction")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Evening Check-In") {
                onEveningCheckInTapped()
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .controlSize(.regular)
        }
        .padding(.vertical, 8)
    }

    private var allCompleteView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("All Done for Today", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)

            Text("Check back tomorrow morning!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var morningMissedView: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.orange)

            Text("Morning check-in window passed")
                .font(.headline)

            if isEveningWindow {
                Text("You can still do your evening check-in")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("Evening Check-In") {
                    onEveningCheckInTapped()
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .controlSize(.regular)
            } else {
                Text("Evening check-in available after 5 PM")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Styling

    private var backgroundGradient: some View {
        Group {
            switch cardState {
            case .eveningPending, .allComplete:
                LinearGradient(
                    colors: [Color.purple.opacity(0.1), Color.purple.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            default:
                Color.clear
            }
        }
    }
}

/// A colored badge showing the energy level.
private struct EnergyBadge: View {
    let level: Int

    var body: some View {
        Text("\(level)")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(Circle().fill(energyColor))
    }

    private var energyColor: Color {
        switch level {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        case 5: return .mint
        default: return .gray
        }
    }
}

// MARK: - Today's Metrics Card

/// Displays a summary of today's health metrics.
private struct TodaysMetricsCard: View {
    let metrics: HealthMetrics?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Metrics")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                MetricTile(
                    title: "Resting HR",
                    value: metrics?.restingHeartRate.map { "\(Int($0))" },
                    unit: "bpm",
                    icon: "heart.fill",
                    color: .red
                )

                MetricTile(
                    title: "HRV",
                    value: metrics?.hrv.map { "\(Int($0))" },
                    unit: "ms",
                    icon: "waveform.path.ecg",
                    color: .pink
                )

                MetricTile(
                    title: "Sleep",
                    value: metrics?.formattedSleepDuration,
                    unit: nil,
                    icon: "bed.double.fill",
                    color: .indigo
                )

                MetricTile(
                    title: "Steps",
                    value: metrics?.steps.map { $0.formatted() },
                    unit: nil,
                    icon: "figure.walk",
                    color: .green
                )
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

/// A single metric tile in the grid.
private struct MetricTile: View {
    let title: String
    let value: String?
    let unit: String?
    let icon: String
    let color: Color

    /// Display value for animation tracking
    private var displayValue: String {
        value ?? "--"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(displayValue)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(value != nil ? .primary : .tertiary)
                    .contentTransition(.numericText())

                if let unit = unit, value != nil {
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.3), value: displayValue)
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
        .environment(AppContainer(healthKitService: MockHealthKitService()))
}
