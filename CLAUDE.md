# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**조구만 뽀모도로 (Joguman Pomodoro)** — A single-screen Flutter Pomodoro timer app with animated characters, circular dial interaction, and multi-language support. Version 1.0.4+17, Dart SDK >=3.4.4 <4.0.0.

## Common Commands

```bash
flutter pub get                    # Install dependencies
flutter analyze                    # Run static analysis (uses flutter_lints)
flutter test                       # Run tests
flutter test test/widget_test.dart # Run a single test file
flutter run                        # Run on connected device/emulator
flutter build apk                  # Build Android APK
flutter build ios                  # Build iOS app
```

## Architecture

### State Management: Provider (ChangeNotifier)

Three providers initialized via `MultiProvider` in `main.dart`:

- **DataProvider** (`lib/providers/data_provider.dart`) — Core timer logic: countdown state (`currSec`, `currMillisec`), `Timer.periodic()` at 100ms intervals, notification scheduling, vibration, app lifecycle tracking (`leaveDate`/`alarmDate` for background resume), and wake lock management.
- **AngleProvider** (`lib/providers/angle_provider.dart`) — Stores rotation angle (radians) for the circular dial touch interaction.
- **ThemeProvider** (`lib/providers/theme_provider.dart`) — Two-theme system (index 0/1) persisted via Hive. Themes correspond to two animated characters: apple and washing machine.

### App Initialization Chain (`main()`)

Hive init → portrait lock → local notification init → timezone init → EasyLocalization init → `runApp()`

### Widget Hierarchy

`EasyLocalization` → `MultiProvider` → `AppLifecycleHandler` (WidgetsBindingObserver) → `ResponsiveSizer` → `MaterialApp` → `HomeScreen`

### Key Widgets (`lib/widgets/`)

- **PomodoroCast** — Custom circular clock dial with touch-to-set-time. Handles angle calculations, clamping (0–60 min), and haptic feedback.
- **TimerWidget** — Displays MM:SS using custom number images with `Selector` for optimized rebuilds.
- **AppleMotionWidget / WashMotionWidget** — Animated characters that change animation state at timer progress milestones (1/3, 2/3).
- **MyGif** — GIF wrapper with completion callbacks.

### Single Screen

`HomeScreen` (`lib/screens/home_screen.dart`) is the only screen. It uses `IndexedStack` to switch between two themed layouts. No router or navigation framework.

### Utilities (`lib/utility.dart`)

Standalone functions for asset precaching, notification scheduling, vibration control, sound mode detection, and permission handling. These are called from providers and widgets, not organized as extension methods.

### App Lifecycle Handling

`AppLifecycleHandler` in `main.dart` observes lifecycle via `WidgetsBindingObserver`. When the app resumes from background, `DataProvider.setTimerByLifecycle()` recalculates remaining time using `leaveDate`/`alarmDate` timestamps.

## Localization

Uses `easy_localization` with JSON files in `assets/translations/`. Supported locales: en, ko, ja, zh-Hans, zh-Hant. Fallback: en.

## Data Persistence

Hive (NoSQL) via `hive_flutter` — used for persisting theme preference. No complex data models or migrations.

## Platform Notes

- Portrait-only orientation lock
- Android: requires `SCHEDULE_EXACT_ALARM` permission for notifications
- iOS: configured for critical alerts and background audio (partially disabled)
- Wake lock active during timer countdown via `wakelock_plus`
