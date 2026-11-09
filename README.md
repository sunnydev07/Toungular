# Toungular

Toungular is an Android-first English-learning app built independently from the Stimuler package. It has original lessons, vocabulary, interface copy, API, scoring logic, ads configuration, and account model. It does not reproduce Stimuler's private server, account system, credentials, models, or unobserved runtime behavior.

## What is implemented

- Email registration and sign-in, session refresh, learner goals, proficiency, daily target, and IELTS intent.
- In-app account deletion with removal of the account's learning and practice data.
- A fixed 20-item vocabulary baseline with repeat checks, plus two fixed speaking prompts whose pace estimates can be compared over time.
- A course roadmap, lesson activities, local lesson cache, and queued completion/review actions for offline use.
- Spaced vocabulary cards with `again`, `hard`, `good`, and `easy` grades.
- Local speaking recording and playback, editable transcripts, transparent transcript-based estimates, and session history. Speech-to-text is not configured; learners enter or edit their transcript.
- Text-based scenario practice with saved turns and explicit unavailable status for live AI replies.
- Original IELTS-style speaking prompts with preparation/response timers, saved attempt history, resume for unfinished sets, and no official score claim.
- Progress counts, streak summary, account reminder preferences, and Android local reminders.
- Toungular entitlement/referral routes and an account-owned billing boundary. Purchase is disabled until Play products and server verification are configured.
- A Google Mobile Ads banner and optional rewarded bonus prompt using Google's test units. Ads are disabled unless `ADS_ENABLED=true`; UMP consent is checked before requests. Production app/ad IDs must come from Toungular's own account.

The app does not upload raw audio. The API stores the learner-provided transcript and practice estimates. Pronunciation analysis and AI conversation replies remain unavailable until Toungular configures providers.

## Prerequisites

- Flutter 3.47.5 / Dart 3.13.4 or a compatible stable release.
- Android SDK Platform 37 and Android Build Tools compatible with the installed Flutter release.
- Node.js 22 or later and npm.

## Start the API locally

```powershell
cd backend
Copy-Item .env.example .env
npm install
npm run prisma:generate
npm run prisma:migrate:dev
npm run seed
npm run dev
```

The API listens on `http://localhost:3000`. Replace `JWT_SECRET` in `.env` with a unique local value. The default SQLite database is stored under `backend/storage/`. PostgreSQL uses its separate Prisma schema and tracked migration history; see [backend/README.md](backend/README.md).

## Run the Android app

```powershell
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

`10.0.2.2` reaches the host computer from an Android emulator. For a physical device, use the host's LAN address and allow the device to reach port 3000. Cleartext HTTP is intended only for local debug use; release API URLs must use HTTPS.

To make a debug APK after dependencies are resolved:

```powershell
flutter build apk --debug --dart-define=API_BASE_URL=https://your-toungular-api.example
```

Flutter writes the artifact to `mobile/build/app/outputs/flutter-apk/app-debug.apk`. This is a debug-signed artifact, not a Play-ready release.

## Ads and account-owned services

Ads are disabled by default. For development with Google's test units, enable them with `--dart-define=ADS_ENABLED=true`. The Android manifest contains Google's published test AdMob application ID; replace it with an app ID from Toungular's own AdMob account before live ads. Set ad unit IDs with `ADMOB_BANNER_ID` and `ADMOB_REWARDED_ID`. The home banner and rewarded prompt are blocked during recording, without UMP consent, and for Plus entitlements.

Billing verification returns a clear unavailable response until Toungular configures a Play Billing provider. No purchase button can charge users in this state. Speech, pronunciation, AI, and text-to-speech providers are also not configured. Keep all provider secrets on the API and do not reuse Stimuler account identifiers or credentials.

## Data and Android permissions

- Microphone permission is requested only when a learner starts a speaking recording.
- Recordings stay in the app's temporary private storage; transcript text and aggregate practice estimates are sent to Toungular's API.
- Reminder notification permission is requested only when saving a reminder.
- In-app account deletion is implemented; publish a public account-deletion request URL and privacy policy, and review data-retention and Play Data Safety requirements before release.

## Layout

- `mobile/` — Flutter Android client (`com.toungular.app`).
- `backend/` — TypeScript/Express API, Prisma schema, migrations, and original seed content.
- `docs/` — product design, implementation plan, and static reference investigation notes.
