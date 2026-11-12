# Attendance Tracker for College

A Flutter app for keeping a clear, personal record of college attendance. Track classes by subject, follow your timetable, and see how your attendance is trending—all from one place.

[![Flutter](https://img.shields.io/badge/Flutter-3.44+-02569B?logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.12+-0175C2?logo=dart&logoColor=white)](https://dart.dev/)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)](https://www.android.com/)
[![Status](https://img.shields.io/badge/Status-Preview-orange)](#android-preview-apk)

## Android preview APK

[**Download the preview APK**](https://github.com/Biswas-here/Attendance-Tracker-for-clg/releases/latest/download/attendance-tracker-preview.apk) · [Download the complete source bundle](https://github.com/Biswas-here/Attendance-Tracker-for-clg/releases/latest/download/attendance-tracker-source.zip)

This is a preview build for sideload testing. The available APK is signed with the Android debug key; it is not a production release. Android may ask you to allow installation from your browser or file manager. Only install APKs you trust.

## What it does

- **Ledger** — mark classes present or absent and review daily attendance.
- **Timetable** — browse scheduled classes and attendance by date.
- **Subjects** — manage subjects and see subject-level attendance.
- **Analytics** — review attendance trends and summary charts.
- **Settings** — personalize app preferences and manage CSV import/export.
- **Local-first storage** — attendance records and preferences are stored on the device.
- **Reminders** — receive class attendance prompts where notifications are supported.

## Screenshots

The cards below are **placeholders**, not screenshots or representations of the running app. They reserve space for real captures to be added later.

| Ledger | Timetable | Subjects |
|:---:|:---:|:---:|
| **Screenshot coming soon** | **Screenshot coming soon** | **Screenshot coming soon** |

| Analytics | Settings |
|:---:|:---:|
| **Screenshot coming soon** | **Screenshot coming soon** |

## Build from source

### Requirements

- Flutter SDK (Dart is included with Flutter)
- Android Studio or Android SDK tools
- An Android device with USB debugging enabled, or an Android emulator

### Run locally

Download and extract the [complete source bundle](https://github.com/Biswas-here/Attendance-Tracker-for-clg/releases/latest/download/attendance-tracker-source.zip). Run these commands from the extracted project folder:

```bash
flutter pub get
flutter run
```

### Build an Android APK

```bash
flutter build apk --release
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`. Configure your own Android release signing key before distributing a production build. Never commit signing keys or passwords.

## Tech stack

- Flutter and Dart
- Provider for state management
- SQLite (`sqflite`) and shared preferences for local data
- `fl_chart` for analytics
- Flutter local notifications for reminders
- CSV import/export and local file sharing

## Project status

The source bundle contains the Flutter project, including `lib/`, `android/`, and `test/`. Features and platform support may change. The Android APK is a preview build; other platform targets have not been verified for release.

## License

No open-source license has been selected yet. Until a license is added, the source remains under its default copyright terms.
