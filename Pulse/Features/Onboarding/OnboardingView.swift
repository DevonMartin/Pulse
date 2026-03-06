//
//  OnboardingView.swift
//  Pulse
//
//  Created by Devon Martin on 2/10/2026.
//

import SwiftUI

/// First-launch onboarding flow that explains the app and requests HealthKit access.
///
/// Apple requires that HealthKit apps explain what data they need and why
/// before showing the system authorization sheet. This flow satisfies
/// that requirement while also setting user expectations for the readiness
/// score, the daily check-in loop, and how personalization works over time.
///
/// Pages:
/// 1. Welcome — core value proposition
/// 2. How It Works — daily check-in rhythm
/// 3. Your Readiness Score — what the score means
/// 4. Gets Smarter Over Time — personalization journey
/// 5. Set Your Schedule — check-in times + notification permission
/// 6. Health Access — HealthKit permission request
struct OnboardingView: View {
    @Environment(AppContainer.self) private var container

    @State private var currentPage = 0
    @State private var isRequestingAuth = false
    @State private var showNoDataWarning = false
    @State private var healthKitUnavailable = false

    // Schedule page state
    @State private var morningTime: Date = {
        Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    }()
    @State private var eveningTime: Date = {
        Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date()) ?? Date()
    }()
    @State private var scheduleSaved = false
    @State private var remindersEnabled = true

    /// Called when onboarding completes (sets the persistent flag in the parent).
    var onComplete: () -> Void

    private var pageCount: Int {
        healthKitUnavailable ? 5 : 6
    }

    var body: some View {
        TabView(selection: $currentPage) {
            welcomePage.tag(0)
            howItWorksPage.tag(1)
            readinessScorePage.tag(2)
            personalizationPage.tag(3)
            schedulePage.tag(4)
            if !healthKitUnavailable {
                permissionPage.tag(5)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .overlay(alignment: .bottom) {
            pageIndicator
                .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
        .onChange(of: currentPage) { oldPage, _ in
            // Save schedule if the user swiped away from the schedule page
            if oldPage == 4 && !scheduleSaved {
                saveSchedule()
            }
        }
        .task {
            let status = await container.healthKitService.authorizationStatus
            healthKitUnavailable = (status == .unavailable)
        }
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "heart.text.square")
                .font(.system(size: 64))
                .foregroundStyle(.orange)

            VStack(spacing: 12) {
                Text("Welcome to Pulse")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Track how you feel alongside what your body is doing — and start to see what actually affects your energy, recovery, and performance.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            nextButton("Get Started", page: 1)
        }
    }

    // MARK: - Page 2: How It Works

    private var howItWorksPage: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("How It Works")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Two quick check-ins each day, combined with your health data")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 60)

            VStack(spacing: 16) {
                stepRow(
                    number: "1",
                    icon: "sun.horizon.fill",
                    color: .orange,
                    title: "Morning Check-In",
                    description: "Rate your energy level when you start your day. Pulse combines this with last night's sleep, heart rate, and HRV to calculate your readiness."
                )

                stepRow(
                    number: "2",
                    icon: "moon.stars.fill",
                    color: .purple,
                    title: "Evening Check-In",
                    description: "Reflect on how your energy held up. This is the key signal that teaches Pulse what a good or tough day looks like for you."
                )

                stepRow(
                    number: "3",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .mint,
                    title: "Discover Patterns",
                    description: "Over time, you'll see which metrics actually predict how you perform — not just how you feel in the moment."
                )
            }
            .padding(.horizontal)

            Spacer()

            nextButton("Continue", page: 2)
        }
    }

    // MARK: - Page 3: Readiness Score

    private var readinessScorePage: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Your Readiness Score")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("A daily snapshot of how prepared your body is, based on real data and how you actually feel")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 60)

            // Mock score display
            mockScoreCard

            // Component legend
			VStack(spacing: 10) {
				componentRow(
					color: .red,
					title: "Resting HR",
					detail: "Lower at rest means better recovery"
				)
				componentRow(
					color: .pink,
					title: "HRV",
					detail: "How recovered your nervous system is"
				)
				componentRow(
					color: .indigo,
					title: "Sleep",
					detail: "Duration and quality of last night's rest"
				)
				componentRow(
					color: .orange,
					title: "Energy",
					detail: "Your own rating — because you know your body"
				)
			}
            .padding(.horizontal, 24)

            Spacer()

            nextButton("Continue", page: 3)
        }
    }

    // MARK: - Page 4: Personalization

    private var personalizationPage: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("Gets Smarter Over Time")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Pulse learns what matters most for you specifically")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 60)

            VStack(spacing: 20) {
                personalizationStage(
                    icon: "brain",
                    color: .orange,
                    title: "Week 1",
                    description: "Scores use proven general patterns — HRV, resting heart rate, sleep, and your energy ratings.",
                    progress: 0.1
                )

                personalizationStage(
                    icon: "brain.head.profile",
                    color: .blue,
                    title: "Weeks 2-4",
                    description: "As you check in, an on-device model starts learning your personal patterns and gradually shapes your score.",
                    progress: 0.5
                )

                personalizationStage(
                    icon: "brain.fill",
                    color: .green,
                    title: "30+ Days",
                    description: "Your score is fully personalized. It reflects what actually predicts a good day for you — not just population averages.",
                    progress: 1.0
                )
            }
            .padding(.horizontal)

            Text("All learning happens on your device. Your data never leaves your phone.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)

            Spacer()

            nextButton("Continue", page: 4)
        }
    }

    // MARK: - Page 5: Set Your Schedule

    private var schedulePage: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("Set Your Schedule")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Choose when you'd like to check in each day")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 60)

            VStack(spacing: 20) {
                // Morning time picker
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: "sun.horizon.fill")
                            .font(.title3)
                            .foregroundStyle(.orange)
                    }

                    DatePicker(
                        "Morning",
                        selection: $morningTime,
                        displayedComponents: .hourAndMinute
                    )
                    .font(.headline)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Evening time picker
                HStack {
                    ZStack {
                        Circle()
                            .fill(Color.purple.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Image(systemName: "moon.stars.fill")
                            .font(.title3)
                            .foregroundStyle(.purple)
                    }

                    DatePicker(
                        "Evening",
                        selection: $eveningTime,
                        displayedComponents: .hourAndMinute
                    )
                    .font(.headline)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)

            // Reminder opt-in
            Toggle(isOn: $remindersEnabled) {
                HStack(spacing: 10) {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(.orange)
                    Text("Remind me at these times")
                        .font(.subheadline)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            Text("\"Morning\" is whenever your day starts and \"Evening\" is when you're winding down — it doesn't have to be AM and PM. You can change these anytime in Settings.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)

            Spacer()

            Button {
                saveScheduleAndContinue()
            } label: {
                Text("Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.orange)
            .padding(.horizontal)
            .padding(.bottom, 60)
        }
    }

    // MARK: - Page 6: Permission Request

    private var permissionPage: some View {
        VStack {
            Spacer()

            if showNoDataWarning {
                noDataWarningContent
            } else {
                permissionRequestContent
            }

            Spacer()

            if showNoDataWarning {
                noDataWarningButtons
            } else {
                Button {
                    isRequestingAuth = true
                    Task { await requestHealthKitAccess() }
                } label: {
                    Text("Allow Health Access")
                        .opacity(isRequestingAuth ? 0 : 1)
                        .overlay {
                            if isRequestingAuth {
                                ProgressView()
                            }
                        }
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.orange)
                .disabled(isRequestingAuth)
                .padding(.horizontal)
                .padding(.bottom, 60)
            }
        }
    }

    // MARK: - Permission Page Content

    private var permissionRequestContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                Text("Allow Health Access")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Pulse reads health data from your Apple Watch or iPhone to power your readiness score. Nothing is shared or sent anywhere — all data stays on your device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 6) {
				healthDataPill(icon: "waveform.path.ecg", color: .red, label: "Resting Heart Rate")
                healthDataPill(icon: "heart.fill", color: .pink, label: "Heart Rate Variability")
                healthDataPill(icon: "bed.double.fill", color: .indigo, label: "Sleep")
                healthDataPill(icon: "figure.walk", color: .green, label: "Steps")
                healthDataPill(icon: "flame.fill", color: .orange, label: "Active Energy")
                healthDataPill(icon: "figure.run", color: .mint, label: "Workouts")
            }
            .padding(.horizontal, 40)
        }
    }

    private var noDataWarningContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                Text("No Health Data Found")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("If you declined access, open the Health app, tap your profile picture, then Privacy \u{2192} Apps \u{2192} Pulse to enable access. If you don't have health data yet, Pulse will start tracking when data becomes available.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }

    private var noDataWarningButtons: some View {
        VStack(spacing: 12) {
            Button {
                if let url = URL(string: "x-apple-health://") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Open Health App")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.orange)
            .padding(.horizontal)

            Button {
                completeOnboarding()
            } label: {
                Text("Continue Anyway")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .padding(.horizontal)
            .padding(.bottom, 60)
        }
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<pageCount, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Color.primary : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
        }
    }

    // MARK: - Reusable Components

    private func nextButton(_ label: String, page: Int) -> some View {
        Button {
            withAnimation { currentPage = page }
        } label: {
            Text(label)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(.orange)
        .padding(.horizontal)
        .padding(.bottom, 60)
    }

    private func stepRow(number: String, icon: String, color: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var mockScoreCard: some View {
        HStack(alignment: .center, spacing: 20) {
            // Mock score circle
            ZStack {
                Circle()
                    .stroke(Color.green.opacity(0.2), lineWidth: 10)

                Circle()
                    .trim(from: 0, to: 0.74)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("74")
                        .font(.system(size: 32, weight: .bold, design: .rounded))

                    Text("Good")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 100, height: 100)

            // Mock breakdown bars
            VStack(alignment: .leading, spacing: 6) {
                mockBreakdownRow(label: "Resting HR", value: 0.80, color: .red)
                mockBreakdownRow(label: "HRV", value: 0.70, color: .pink)
                mockBreakdownRow(label: "Sleep", value: 0.85, color: .indigo)
                mockBreakdownRow(label: "Energy", value: 0.60, color: .orange)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func mockBreakdownRow(label: String, value: CGFloat, color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * value)
                }
            }
            .frame(height: 8)
        }
    }

    private func componentRow(color: Color, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func personalizationStage(icon: String, color: Color, title: String, description: String, progress: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 36, height: 36)

                // Mini progress bar
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(0.2))
                    .frame(width: 36, height: 4)
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color)
                            .frame(width: 36 * progress, height: 4)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func healthDataPill(icon: String, color: Color, label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(color)
                .frame(width: 20)

            Text(label)
                .font(.subheadline)

            Spacer()
        }
        .padding(.vertical, 6)
    }

    // MARK: - Actions

    /// Persists the chosen check-in times and requests notification permission.
    /// Safe to call more than once — the `scheduleSaved` flag prevents duplicate work.
    private func saveSchedule() {
        guard !scheduleSaved else { return }
        scheduleSaved = true

        let calendar = Calendar.current
        let mh = calendar.component(.hour, from: morningTime)
        let mm = calendar.component(.minute, from: morningTime)
        let eh = calendar.component(.hour, from: eveningTime)
        let em = calendar.component(.minute, from: eveningTime)

        TimeWindows.saveCheckInTimes(
            morningHour: mh, morningMinute: mm,
            eveningHour: eh, eveningMinute: em
        )

        // Persist the notification preference
        let defaults = UserDefaults(suiteName: TimeWindows.appGroupID) ?? .standard
        defaults.set(remindersEnabled, forKey: "notificationsEnabled")

        if remindersEnabled {
            Task {
                _ = await container.notificationService.requestAuthorization()
                await container.notificationService.scheduleCheckInReminders()
            }
        }
    }

    private func saveScheduleAndContinue() {
        saveSchedule()

        if healthKitUnavailable {
            completeOnboarding()
        } else {
            withAnimation { currentPage = 5 }
        }
    }

    private func requestHealthKitAccess() async {
        do {
            try await container.healthKitService.requestAuthorization()
            await MainActor.run { completeOnboarding() }
        } catch {
            withAnimation(.easeInOut(duration: 0.3)) {
                showNoDataWarning = true
            }
            isRequestingAuth = false
        }
    }

    private func completeOnboarding() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onComplete()
    }
}

// MARK: - Preview

#Preview("Onboarding") {
    OnboardingView(onComplete: {})
        .environment(AppContainer(healthKitService: MockHealthKitService()))
}
