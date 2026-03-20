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

Add these as [repository secrets](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions#creating-secrets-for-a-repository): **GitHub repo → Settings → Secrets and variables → Actions → New repository secret**.

| Secret | Value |
|--------|--------|
| `RELEASE_KEYSTORE_BASE64` | Base64 of your `.jks` file, **one line** (no newlines). |
| `RELEASE_KEYSTORE_PASSWORD` | Same as `storePassword` in `android/key.properties`. |
| `RELEASE_KEY_ALIAS` | Same as `keyAlias` in `android/key.properties`. |
| `RELEASE_KEY_PASSWORD` | Same as `keyPassword` in `android/key.properties`. |

Generate the base64 string locally (use the path to your keystore, e.g. `android/app/mindtape-release-key.jks`):

```bash
# macOS — copy a single-line base64 string to the clipboard
base64 -i mindtape-release-key.jks -o keystore.base64
# Paste into the RELEASE_KEYSTORE_BASE64 secret in GitHub.
```

```bash
# Linux (GNU coreutils) — single line, print to terminal
base64 -w0 android/app/mindtape-release-key.jks
```

Optional — [GitHub CLI](https://cli.github.com/): after `gh auth login`, from the repo root you can set non-binary secrets with `printf '%s' 'your-value' | gh secret set SECRET_NAME`. For the keystore, paste the base64 into the web UI or use a here-doc with `gh secret set RELEASE_KEYSTORE_BASE64`.
