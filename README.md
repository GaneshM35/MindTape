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
- `JournalEntry` model and SQLite `DatabaseService`
- Basic `HomeScreen`: one question at a time, **Next** / **Back**, large mic
- Speech-to-text wired up via `speech_to_text`
  - Tap mic to start listening
  - Tap mic again to stop
  - Recognized text updates live in the answer box

**MVP phase 2:** save the four answers for the day to SQLite, **History** (past days), and **Detail** (full Q&A for one day).

## CI/CD (GitHub Actions)

Milestone releases are created when you push a version tag like `v1.0.0`.

1. Merge your milestone changes to `main`.
2. Create a tag: `vX.Y.Z` (example: `v1.0.0`) and push it to GitHub.
3. GitHub Actions will:
   - build a signed Android release APK (`app-release.apk`)
   - publish a GitHub Release for that tag with the APK attached

### Android signing secrets

Store these secrets in your GitHub repo settings:
- `RELEASE_KEYSTORE_BASE64`
- `RELEASE_KEYSTORE_PASSWORD`
- `RELEASE_KEY_ALIAS`
- `RELEASE_KEY_PASSWORD`
