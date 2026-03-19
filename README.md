# MindTape

Private, voice-first journaling for Android (Flutter). Data stays on-device.

## Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) (stable channel)
- Android SDK / device or emulator

## Run

```bash
cd MindTape
flutter pub get
flutter run
```

If Android Gradle wrapper files (`android/gradlew`, etc.) are missing, regenerate platform scaffolding without overwriting `lib/`:

```bash
flutter create . --project-name mind_tape --org com.mindtape --platforms android
```

## This step (MVP phase 1)

- Project layout under `lib/` (`models/`, `services/`, `screens/`, `widgets/`)
- `JournalEntry` model and SQLite `DatabaseService` (ready for save/history next)
- Basic `HomeScreen`: one question at a time, **Next** / **Back**, large mic
- Speech-to-text wired up via `speech_to_text`
  - Tap mic to start listening
  - Tap mic again to stop
  - Recognized text updates live in the answer box

Next (MVP phase 2): save the 4 answers for the day to SQLite, then add History and Detail screens.
