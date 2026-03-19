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
- Basic `HomeScreen`: one question at a time, **Next** / **Back**, large mic (placeholder until `speech_to_text`)

Confirm when you want the next step: speech-to-text + wiring answers + **Save** to SQLite.
