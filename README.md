# Pulse: Energy Analyzer

An iOS app that helps you understand how your daily activity impacts your energy and recovery. Pulse analyzes HealthKit data—heart rate variability, resting heart rate, sleep, and activity—to generate a personalized readiness score each morning.

## Features

- **Readiness Score**: Daily score based on your biometrics and personal baselines
- **Check-Ins**: Morning and evening self-reports to track subjective energy levels
- **Personal ML Model**: Predictions improve over time as the app learns your patterns
- **Widgets**: Glanceable readiness score and check-in reminders

## Technical Highlights

- SwiftUI + SwiftData with iOS 17+ APIs
- HealthKit integration with background delivery
- On-device Core ML for personalized predictions
- CloudKit sync for cross-device continuity
- Widget extension with App Group data sharing

## Requirements

- iOS 17.0+
- Apple Watch (for HRV and resting heart rate data)
- Apple Developer account (for HealthKit entitlements)

## Architecture

The app follows MVVM with dependency injection, organized by feature:
```
Pulse/
├── App/           # Entry point and DI container
├── Core/          # Domain models, services, utilities
├── Features/      # Dashboard, CheckIn, History, Insights, Settings
├── Persistence/   # SwiftData entities and repositories
├── ML/            # Core ML model and feature extraction
└── Styles/        # Design tokens
```

## Development

1. Clone the repository
2. Open `Pulse.xcodeproj` in Xcode 15+
3. Select your development team in Signing & Capabilities
4. Build and run on a physical device (HealthKit requires a real device)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
