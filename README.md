# MindTape

Private, voice-first journaling for Android (Flutter). Everything stays on-device.

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

## Features

- **Daily entry (one per calendar day)** — SQLite via `DatabaseService`, `JournalEntry` with optional `ReflectionMode`.
- **How to reflect** (first visit each day):
  - **Minimum** — three short prompts.
  - **Deep** — eight guided prompts (titles + optional subtitle cues in the UI).
  - **Mind dump** — single free-form note (voice or typing).
- **Home** — step-by-step flow where relevant; mic + multiline text fields; back arrow returns to mode chooser.
- **History** — newest first; **Detail** — full readout for that day (layout depends on mode).
- **Speech** — `speech_to_text`: tap mic to start/stop; live transcription in the active field.

## CI/CD (GitHub Actions)

Pushing a version tag matching `v*` (e.g. `v1.0.0`) on a branch that includes `.github/workflows/android-release.yml` will:

1. Build a **signed** release APK.
2. Attach **`mindtape.apk`** to a **GitHub Release** for that tag.

Typical flow:

1. Merge work into `main`.
2. `git tag vX.Y.Z && git push origin vX.Y.Z`
3. Download **`mindtape.apk`** from the release page.

### Android signing secrets

Add these under **Settings → Secrets and variables → Actions** ([docs](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions#creating-secrets-for-a-repository)).

| Secret | Value |
|--------|--------|
| `RELEASE_KEYSTORE_BASE64` | Your `.jks` file as **one continuous line** of base64 (no line breaks inside the secret). |
| `RELEASE_KEYSTORE_PASSWORD` | Keystore password — same as `storePassword` in `android/key.properties`. |
| `RELEASE_KEY_ALIAS` | Same as `keyAlias` in `android/key.properties`. |
| `RELEASE_KEY_PASSWORD` | Key password — same as `keyPassword` in `android/key.properties`. |

**Encode the keystore** (adjust the path; release builds often use `android/app/mindtape-release-key.jks`):

```bash
# macOS — one line to clipboard
base64 -i android/app/mindtape-release-key.jks | tr -d '\n' | pbcopy
```

```bash
# Linux (GNU coreutils) — print one line, then paste into the secret
base64 -w0 android/app/mindtape-release-key.jks
```

**New keystore** (only if you do not have one yet; keep `.jks` and passwords out of git — they are in `.gitignore`):

```bash
keytool -genkey -v -keystore android/app/mindtape-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias mindtape
```

Point `android/key.properties` at that file (`storeFile=...`) for local `flutter build apk --release`.

Optional — [GitHub CLI](https://cli.github.com/): `printf '%s' 'value' | gh secret set SECRET_NAME` for text secrets; for the keystore, pasting the base64 in the web UI is usually easiest.

**If CI reports `keystore password was incorrect`:** the base64 must decode to the **same** `.jks` you use locally, and the four secrets must match `key.properties` (store vs key password is a common mix-up). Re-type secrets with no accidental spaces; regenerate base64 if the file changed.
