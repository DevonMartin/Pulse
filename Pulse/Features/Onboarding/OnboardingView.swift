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
/// before showing the system authorization sheet. This 3-page flow satisfies
/// that requirement:
/// 1. Welcome / value prop
/// 2. Health data explanation
/// 3. HealthKit permission request
struct OnboardingView: View {
    @Environment(AppContainer.self) private var container

    @State private var currentPage = 0
    @State private var isRequestingAuth = false
    @State private var showNoDataWarning = false
    @State private var healthKitUnavailable = false

    /// Called when onboarding completes (sets the persistent flag in the parent).
    var onComplete: () -> Void

    var body: some View {
        TabView(selection: $currentPage) {
            welcomePage.tag(0)
            healthDataPage.tag(1)
            if !healthKitUnavailable {
                permissionPage.tag(2)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .overlay(alignment: .bottom) {
            pageIndicator
                .padding(.bottom, 16)
        }
		.background(Color(.systemBackground))
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

            VStack(spacing: 8) {
                Text("Welcome to Pulse")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Understand how your body recovers so you can feel your best every day")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            Button {
                withAnimation { currentPage = 1 }
            } label: {
                Text("Get Started")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.orange)
            .padding(.horizontal)
            .padding(.bottom, 60)
        }
    }

    // MARK: - Page 2: Health Data Explanation

    private var healthDataPage: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("Your Health Data")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Pulse uses these metrics to calculate your readiness score")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 60)

            ScrollView {
                VStack(spacing: 10) {
                    healthDataRow(
                        icon: "heart.fill",
                        color: .pink,
                        title: "Heart Rate Variability",
                        description: "Shows how recovered your nervous system is"
                    )
                    healthDataRow(
                        icon: "waveform.path.ecg",
                        color: .red,
                        title: "Resting Heart Rate",
                        description: "A lower resting rate signals better recovery"
                    )
                    healthDataRow(
                        icon: "bed.double.fill",
                        color: .indigo,
                        title: "Sleep",
                        description: "Quality rest is the biggest factor in readiness"
                    )
                    healthDataRow(
                        icon: "figure.walk",
                        color: .green,
                        title: "Steps",
                        description: "Tracks how active you are throughout the day"
                    )
                    healthDataRow(
                        icon: "flame.fill",
                        color: .orange,
                        title: "Active Energy",
                        description: "Helps gauge how hard your body is working"
                    )
                    healthDataRow(
                        icon: "figure.run",
                        color: .mint,
                        title: "Workouts",
                        description: "Factors exercise load into your recovery"
                    )
                }
                .padding(.horizontal)
            }

            Text("You can learn more about how Pulse uses your data in Settings.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                if healthKitUnavailable {
                    completeOnboarding()
                } else {
                    withAnimation { currentPage = 2 }
                }
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

    // MARK: - Page 3: Permission Request

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
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                Text("Allow Health Access")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Pulse reads health data from your Apple Watch or iPhone. No data leaves your device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
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
                // Open the Health app so the user can navigate to
                // Data Access & Devices > Pulse to grant permissions.
                // There's no public URL to deep-link directly to
                // Health privacy settings for a specific app.
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

    private var pageCount: Int {
        healthKitUnavailable ? 2 : 3
    }

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

    // MARK: - Helpers

    private func healthDataRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Actions

    private func requestHealthKitAccess() async {
        do {
            try await container.healthKitService.requestAuthorization()

            // Complete immediately after the system sheet dismisses.
            // iOS never reveals if read permissions were actually denied
            // for read-only access, and probing for data adds a visible
            // delay. The app handles missing data gracefully throughout,
            // so we don't need to gate on it here.
			await MainActor.run { completeOnboarding() }
        } catch {
            // Authorization threw (e.g., HealthKit unavailable mid-flow).
            // Show the warning so the user can continue anyway.
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
