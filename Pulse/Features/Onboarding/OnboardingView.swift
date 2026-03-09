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
/// 4. Apple Watch — why a Watch is essential for health data
/// 5. Gets Smarter Over Time — personalization journey
/// 6. Set Your Schedule — check-in times + notification permission
/// 7. Health Access — HealthKit permission request
struct OnboardingView: View {
    @Environment(AppContainer.self) private var container

    @State private var currentPage = 0
    @State private var showContent = false
    @State private var isRequestingAuth = false
    @State private var showNoDataWarning = false

    // Schedule page state
    @State private var morningTime: Date = {
        Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    }()
    @State private var eveningTime: Date = {
        Calendar.current.date(bySettingHour: 19, minute: 0, second: 0, of: Date()) ?? Date()
    }()
    @State private var scheduleSaved = false
    @State private var remindersEnabled = true
    @AccessibilityFocusState private var accessibilityFocus: Int?

    /// Namespace shared with RootView for the launch-to-onboarding icon transition.
    var heroAnimation: Namespace.ID

    /// True while the splash overlay is visible; drives the matchedGeometry anchor.
    var splashActive: Bool

    /// True after the splash-to-onboarding animation finishes and the floating icon is removed.
    var showIcon: Bool

    /// Called when onboarding completes (sets the persistent flag in the parent).
    var onComplete: () -> Void

    private let pageCount = 7

    var body: some View {
        TabView(selection: $currentPage) {
            welcomePage.accessibilityHidden(currentPage != 0).tag(0)
            howItWorksPage.accessibilityHidden(currentPage != 1).tag(1)
            readinessScorePage.accessibilityHidden(currentPage != 2).tag(2)
            watchPage.accessibilityHidden(currentPage != 3).tag(3)
            personalizationPage.accessibilityHidden(currentPage != 4).tag(4)
            schedulePage.accessibilityHidden(currentPage != 5).tag(5)
            permissionPage.accessibilityHidden(currentPage != 6).tag(6)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .allowsHitTesting(showIcon)
        .overlay(alignment: .bottom) {
            pageIndicator
                .padding(.bottom, 16)
                .opacity(showContent ? 1 : 0)
        }
        .background(Color(.systemBackground))
        .onChange(of: splashActive) { _, active in
            if !active {
                withAnimation(.easeIn(duration: 0.5).delay(0.15)) {
                    showContent = true
                }
            }
        }
        .task {
            try? await Task.sleep(for: .milliseconds(500))
            accessibilityFocus = 0
        }
        .onChange(of: currentPage) { oldPage, newPage in
            // Save schedule if the user swiped forward past the schedule page
            if oldPage == 5 && newPage > 5 {
                saveSchedule()
            }
            // Move VoiceOver focus to the top of the new page after transition settles
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                accessibilityFocus = newPage
            }
        }
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 32) {
                Image("LaunchImage")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .opacity(showIcon ? 1 : 0)
                    .matchedGeometryEffect(
                        id: "appIcon",
                        in: heroAnimation,
                        properties: .position,
                        isSource: !splashActive
                    )

                Text("Welcome to Pulse")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .opacity(showContent ? 1 : 0)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Welcome to Pulse")
            .accessibilityFocused($accessibilityFocus, equals: 0)

            Text("Track how you feel alongside what your body is doing, and start to see what actually affects your energy, recovery, and performance.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .opacity(showContent ? 1 : 0)

            Spacer()

            nextButton("Get Started", page: 1)
                .opacity(showContent ? 1 : 0)
        }
    }

    // MARK: - Page 2: How It Works

    private var howItWorksPage: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    VStack(spacing: 8) {
                        Text("How It Works")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .accessibilityFocused($accessibilityFocus, equals: 1)

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
                            description: "Over time, you'll see which metrics actually predict how you perform, not just how you feel in the moment."
                        )
                    }
                    .padding(.horizontal)
                }
            }
            .scrollBounceBehavior(.basedOnSize)

            nextButton("Continue", page: 2)
        }
    }

    // MARK: - Page 3: Readiness Score

    private var readinessScorePage: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Your Readiness Score")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .accessibilityFocused($accessibilityFocus, equals: 2)

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
                }
            }
            .scrollBounceBehavior(.basedOnSize)

            nextButton("Continue", page: 3)
        }
    }

    // MARK: - Page 4: Apple Watch

    private var watchPage: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    VStack(spacing: 8) {
                        Text("Wear Your Watch")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .accessibilityFocused($accessibilityFocus, equals: 3)

                        Text("Pulse relies on data from Apple Watch to build your readiness score")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 60)

                    ZStack {
                        Image(systemName: "applewatch.and.arrow.forward")
                            .font(.system(size: 64))
                            .foregroundStyle(.orange)
                    }
                    .padding(.top, 8)
                    .accessibilityHidden(true)

                    VStack(spacing: 16) {
                        watchDataRow(
                            icon: "heart.fill",
                            color: .red,
                            title: "Heart Rate & HRV",
                            description: "Measured overnight and throughout the day by your Watch's sensors"
                        )

                        watchDataRow(
                            icon: "bed.double.fill",
                            color: .indigo,
                            title: "Sleep Tracking",
                            description: "Wear your Watch to bed so Pulse can measure how long and how well you slept"
                        )

                        watchDataRow(
                            icon: "figure.walk",
                            color: .green,
                            title: "Activity & Workouts",
                            description: "Your iPhone tracks steps and calories, but a Watch adds workout detection and more accurate data"
                        )
                    }
                    .padding(.horizontal)
                }
            }
            .scrollBounceBehavior(.basedOnSize)

            Text("Without a Watch, Pulse won't have heart rate, HRV, or sleep data; your score will rely mostly on your energy check-ins.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
                .padding(.top, 12)
                .accessibilityLabel("Without a Watch, Pulse won't have heart rate, heart rate variability, or sleep data; your score will rely mostly on your energy check-ins.")

            nextButton("Continue", page: 4)
                .padding(.top, 12)
        }
    }

    // MARK: - Page 5: Personalization

    private var personalizationPage: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    VStack(spacing: 8) {
                        Text("Gets Smarter Over Time")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .accessibilityFocused($accessibilityFocus, equals: 4)

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
                            title: "First Few Days",
                            description: "Scores use proven general patterns: HRV, resting heart rate, sleep, and your energy ratings.",
                            progress: 0.33
                        )

                        personalizationStage(
                            icon: "brain.head.profile",
                            color: .blue,
                            title: "Days 3–30",
                            description: "After 3 days of check-ins, an on-device model starts learning your personal patterns and gradually shapes your score.",
                            progress: 0.66
                        )

                        personalizationStage(
                            icon: "brain.fill",
                            color: .green,
                            title: "30+ Days",
                            description: "Your score is fully personalized. It reflects what actually predicts a good day for you, not just population averages.",
                            progress: 1.0
                        )
                    }
                    .padding(.horizontal)
                }
            }
            .scrollBounceBehavior(.basedOnSize)

            Text("All learning happens on your device. Your data never leaves your phone.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 32)
                .padding(.top, 12)

            nextButton("Continue", page: 5)
                .padding(.top, 12)
        }
    }

    // MARK: - Page 6: Set Your Schedule

    private var schedulePage: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    VStack(spacing: 8) {
                        Text("Set Your Schedule")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .accessibilityFocused($accessibilityFocus, equals: 5)

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
                            .accessibilityHidden(true)

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
                            .accessibilityHidden(true)

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
                                .accessibilityHidden(true)
                            Text("Remind me at these times")
                                .font(.subheadline)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    Text("\"Morning\" is whenever your day starts and \"Evening\" is when you're winding down. It doesn't have to be AM and PM. You can change these anytime in Settings.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 32)
                }
            }
            .scrollBounceBehavior(.basedOnSize)

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

    // MARK: - Page 7: Permission Request

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
            VStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)

                Text("Allow Health Access")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Allow Health Access")
            .accessibilityFocused($accessibilityFocus, equals: 6)

            Text("Pulse reads health data from your Apple Watch or iPhone to power your readiness score. Nothing is shared or sent anywhere; all data stays on your device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 6) {
				healthDataPill(icon: "waveform.path.ecg", color: .red, label: "Resting Heart Rate")
                healthDataPill(icon: "heart.fill", color: .pink, label: "Heart Rate Variability")
                healthDataPill(icon: "bed.double.fill", color: .indigo, label: "Sleep")
                healthDataPill(icon: "figure.walk", color: .green, label: "Steps")
                healthDataPill(icon: "flame.fill", color: .orange, label: "Active Energy")
                healthDataPill(icon: "figure.run", color: .mint, label: "Workouts")
            }
            .padding(.horizontal, 40)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Pulse will access: Resting Heart Rate, Heart Rate Variability, Sleep, Steps, Active Energy, and Workouts")
        }
    }

    private var noDataWarningContent: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)

                Text("No Health Data Found")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("No Health Data Found")

            Text("If you declined access, open the Health app, tap your profile picture, then Privacy \u{2192} Apps \u{2192} Pulse to enable access. If you don't have health data yet, Pulse will start tracking when data becomes available.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(currentPage + 1) of \(pageCount)")
        .accessibilitySortPriority(-1)
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
        let expandedDescription = description.replacingOccurrences(of: "HRV", with: "heart rate variability")
        return HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }
            .accessibilityHidden(true)

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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(expandedDescription)")
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Example readiness score: 74 out of 100, Good. Breakdown: Resting heart rate 80%, Heart rate variability 70%, Sleep 85%, Energy 60%.")
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

            Text("\(Int(value * 100))%")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)
        }
    }

    private func componentRow(color: Color, title: String, detail: String) -> some View {
        let expandedTitle = switch title {
        case "Resting HR": "Resting heart rate"
        case "HRV": "Heart rate variability"
        default: title
        }
        return HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 4, height: 28)
                .accessibilityHidden(true)

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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(expandedTitle): \(detail)")
    }

    private func personalizationStage(icon: String, color: Color, title: String, description: String, progress: CGFloat) -> some View {
        let expandedTitle = title.replacingOccurrences(of: "–", with: " to ")
        let expandedDescription = description
            .replacingOccurrences(of: "HRV", with: "heart rate variability")
        return HStack(alignment: .top, spacing: 14) {
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
            .accessibilityHidden(true)

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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(expandedTitle): \(expandedDescription)")
    }

    private func watchDataRow(icon: String, color: Color, title: String, description: String) -> some View {
        let expandedTitle = title.replacingOccurrences(of: "HRV", with: "Heart Rate Variability")
        return HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }
            .accessibilityHidden(true)

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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(expandedTitle): \(description)")
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }

    // MARK: - Actions

    /// Persists the chosen check-in times, notification preference, and
    /// requests notification permission on first call. Times are always
    /// saved so the user can go back, adjust, and have changes stick.
    private func saveSchedule() {
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

        // Only request permission once — subsequent saves just update times
        if remindersEnabled && !scheduleSaved {
            scheduleSaved = true
            Task {
                _ = await container.notificationService.requestAuthorization()
                await container.notificationService.scheduleCheckInReminders()
            }
        }
    }

    private func saveScheduleAndContinue() {
        saveSchedule()
        withAnimation { currentPage = 6 }
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

private struct OnboardingPreview: View {
    @Namespace private var animation

    var body: some View {
        OnboardingView(heroAnimation: animation, splashActive: false, showIcon: true, onComplete: {})
            .environment(AppContainer(healthKitService: MockHealthKitService()))
    }
}

#Preview("Onboarding") {
    OnboardingPreview()
}
