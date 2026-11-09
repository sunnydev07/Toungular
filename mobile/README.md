# Toungular Android client

Flutter app id: `com.toungular.app`; display name: `Toungular`.

## Development

```powershell
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

Use the computer's LAN IP instead of `10.0.2.2` on a physical Android device. Debug cleartext traffic is enabled for local API work only.

## Configuration

- `API_BASE_URL` — Toungular API base URL. Releases require HTTPS.
- `ADS_ENABLED` — defaults to `false`. When enabled, the app requests UMP consent before requesting test ads.
- `ADMOB_BANNER_ID` and `ADMOB_REWARDED_ID` — default to Google's published test units. Replace them and the test app ID in `android/app/src/main/AndroidManifest.xml` only with IDs from Toungular's own AdMob account.

The email-authenticated API, curriculum, review queue, speaking sessions, coach scenarios, timed IELTS-style practice, progress, reminders, entitlements, and referral routes are documented in `../backend/README.md`.

Learners can review saved IELTS-style attempts and resume unfinished sets. Account deletion is available in the account screen; publishing the required public deletion URL and privacy policy remains a release task.

Progress includes a repeatable 20-word recall check and two fixed speaking prompts. Pace values are practice estimates, not a proficiency certification.

Speaking recordings remain in temporary app-private storage. Transcripts are learner-entered/editable. The app labels transcript metrics as practice estimates and shows pronunciation/AI responses as unavailable until Toungular configures providers.

## Android output

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=https://your-toungular-api.example
```

The debug APK output is `build/app/outputs/flutter-apk/app-debug.apk`. It is not a production-signed release.
