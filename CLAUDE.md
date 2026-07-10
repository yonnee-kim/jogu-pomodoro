# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**조구만 뽀모도로 (Joguman Pomodoro)** — A single-screen Flutter Pomodoro timer app with swappable character "skins", a circular dial interaction, and multi-language support. Dart SDK >=3.4.4 <4.0.0 (version/build number in `pubspec.yaml`).

## Common Commands

```bash
flutter pub get                              # Install dependencies
flutter analyze                              # Static analysis (flutter_lints)
flutter test                                 # Run all tests
flutter test test/skins/skin_registry_test.dart  # Run a single test file
flutter run                                  # Run on connected device/emulator
flutter build apk                            # Build Android APK
flutter build ios                            # Build iOS app
```

## Architecture

### State Management: Provider (ChangeNotifier)

Three providers initialized via `MultiProvider` in `main.dart`:

- **DataProvider** (`lib/providers/data_provider.dart`) — Core timer logic: countdown state (`currSec`, `currMillisec`), `Timer.periodic()` at 100ms intervals, schedules the end notification when the timer starts, and tracks `leaveDate`/`leaveMillisec` for background resume.
- **AngleProvider** (`lib/providers/angle_provider.dart`) — Rotation angle (radians) for the circular dial touch interaction.
- **ThemeProvider** (`lib/providers/theme_provider.dart`) — Current skin index persisted via Hive (`themeBox`/`themeIndex`). `currentSkin` returns the active `SkinConfig`; `addThemeIndex()` cycles through registered skins.

### Skin System (primary extension point)

Skins are declarative configs, not subclasses:

- **`lib/models/skin_config.dart`** — `SkinConfig`: colors, dial/clock-hand assets, `motionWidgetBuilder` (center character animation), per-skin button assets, asset lists for precaching (`precacheImagePaths`, `prefetchGifPaths`), and optional builder hooks (`backgroundBuilder`, `timerPainterBuilder`, `dialOverlayBuilder`, `dialBackgroundBuilder`, `timerOverlayBuilder`).
- **`lib/skins/skin_registry.dart`** — `skinConfigs` list (currently apple, wash, school) plus `sharedImagePaths` used by every skin.
- **Adding a skin**: create `lib/skins/<id>/` with a `<id>_skin.dart` exporting a `SkinConfig` → import + register it in `skin_registry.dart` → add its asset folder(s) to the `assets:` section of `pubspec.yaml`.
- **Logic/widget separation**: pure functions live in `*_logic.dart` (e.g. `apple_motion_logic.dart` maps timer progress at 1/3 and 2/3 milestones to GIF paths) so they are unit-testable without widget tests.
- Rendering styles differ per skin: apple/wash animate GIFs (via `MyGif`/`gif_view`); school draws with `CustomPainter`s (`school_lane_painter.dart`) and a static background widget.

### Single Screen & Key Widgets

`HomeScreen` (`lib/screens/home_screen.dart`) is the only screen — no router. It builds one `PomodoroCast` per registered skin inside an `IndexedStack` (all skins stay built; the index switches). It also contains `BottomButtonWidet` (play/stop + skin-change buttons, per-skin assets) and a `_debugAspectRatio` flag that shows a slider for testing screen ratios.

- **PomodoroCast** (`lib/widgets/pomodoro_cast.dart`) — Circular clock dial with touch-to-set-time, angle clamping (0–60 min), haptic feedback; customized per skin via the `SkinConfig` builder hooks.
- **TimerWidget** (`lib/widgets/timer_widget.dart`) — Displays MM:SS using custom number images with `Selector` for optimized rebuilds.

### App Initialization Chain (`main()`)

Hive init → portrait lock → local notification init → timezone init → EasyLocalization init → open `themeBox` → `runApp()`

Widget hierarchy: `EasyLocalization` → `MultiProvider` → `AppLifecycleHandler` → `ResponsiveSizer` → `MaterialApp` → `HomeScreen`

### App Lifecycle Handling

Split across two observers:

- `AppLifecycleHandler` (`main.dart`) forwards state changes to `DataProvider.setLifecycleState()`.
- `HomeScreen.didChangeAppLifecycleState`: on `inactive`, stores departure time via `DataProvider.setLeaveDateTime()`; on `resumed`, calls `setTimerByLifecycle()` (`lib/utility.dart`) which recomputes remaining time from `leaveDate`/`leaveMillisec` and restarts the timer.

### Utilities (`lib/utility.dart`)

Standalone functions (not extension methods), called from providers and widgets: skin-aware asset precaching, notification scheduling (`flutter_local_notifications` + `alarm` package), vibration, sound-mode detection, permission handling.

## Tests

`test/` mirrors `lib/` (models, providers, skins). Skin tests cover registry integrity, asset path existence (`asset_paths_test.dart`), skin config values, and pure motion logic. When adding a skin, add matching tests under `test/skins/<id>/`.

## Localization

`easy_localization` with JSON files in `assets/translations/`. Locales: en, ko, ja, zh-Hans, zh-Hant. Fallback: en.

## Data Persistence

Hive (`hive_flutter`) — only the skin index (`themeBox`/`themeIndex`). No data models or migrations.

## Platform Notes

- Portrait-only orientation lock
- Android: requires `SCHEDULE_EXACT_ALARM` permission for notifications
- iOS: configured for critical alerts and background audio (partially disabled)
- Wake lock active while `HomeScreen` is mounted via `wakelock_plus`
