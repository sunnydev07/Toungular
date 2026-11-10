# Toungular 🎙️📚

[![Flutter](https://img.shields.io/badge/Flutter-3.47.5-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13.4-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Node.js](https://img.shields.io/badge/Node.js-22+-339933?logo=nodedotjs&logoColor=white)](https://nodejs.org)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.9-3178C6?logo=typescript&logoColor=white)](https://www.typescriptlang.org)
[![Prisma](https://img.shields.io/badge/Prisma-6.19-2D3748?logo=prisma&logoColor=white)](https://www.prisma.io)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)](https://developer.android.com)
[![License](https://img.shields.io/badge/License-Proprietary-red)](#)

**Toungular** is a modern, Android-first spoken English learning platform built independently from the ground up. It delivers comprehensive spoken practice, adaptive learning roadmaps, spaced repetition vocabulary, and transparent, science-backed fluency feedback.

---

## 🌟 Highlights & Capabilities

| Feature | Description | Status |
|---|---|---|
| 🎙️ **Speaking Studio** | Local audio capture, instant playback, editable transcripts, and transparent algorithmic pace (WPM), filler density, and lexical variety metrics. | ✅ Implemented |
| 🧠 **SRS Vocabulary Engine** | Modified interval-based spaced repetition scheduler (`again`, `hard`, `good`, `easy`) with offline queue sync and active recall testing. | ✅ Implemented |
| 🎯 **Placement & Baseline** | Fixed 20-item vocabulary recall assessment and dual standardized speaking prompts for longitudinal progress tracking without prompt drift. | ✅ Implemented |
| 🗺️ **Roadmap & Courses** | Multi-course curriculum with modular lesson activities (vocabulary, grammar, pronunciation, integrated) and offline caching. | ✅ Implemented |
| 💬 **AI Coach & Role-Play** | Multi-turn conversation scenarios (interview, travel, workplace) with turn-aware coaching and explicit graceful provider-fallback states. | ✅ Implemented |
| ⏱️ **IELTS-Style Practice** | Timed speaking sections (Part 1 interview, Part 2 long-turn, Part 3 discussion) with preparation/response countdown timers and attempt history. | ✅ Implemented |
| 📊 **Progress & Habits** | Longitudinal skill breakdown, streak tracking, activity heatmaps, and Android local notification reminders. | ✅ Implemented |
| 🛡️ **Privacy & Compliance** | In-app account deletion cascading all user data; zero raw voice data stored on servers (audio remains in app-private storage). | ✅ Implemented |
| 💎 **Ad & Billing Boundary** | Ad slots (banner & rewarded bonus) strictly guarded by `AdPlacementPolicy`—**never interrupting active speaking**—with server-side entitlement validation. | ✅ Implemented |

---

## 🏗️ System Architecture

```
toungular/
├── mobile/                  # Flutter Android Client (com.toungular.app)
│   ├── android/             # Android project with desugaring & permissions
│   ├── lib/
│   │   ├── app/             # Routing (go_router), global lifecycle, shell
│   │   ├── core/            # Networking (Dio), storage, theme, state
│   │   ├── features/        # Feature modules: auth, speaking, coach, ielts,
│   │   │                    # courses, vocabulary, progress, monetization
│   │   └── shared/          # Typed API and domain models
│   └── pubspec.yaml
│
├── backend/                 # TypeScript / Express API
│   ├── prisma/              # Prisma schema & SQLite / PostgreSQL migrations
│   │   ├── schema.prisma    # SQLite schema (default for local dev)
│   │   └── postgresql/      # PostgreSQL schema & migrations for production
│   ├── src/
│   │   ├── routes/v1.ts     # Express 5 typed REST endpoints
│   │   ├── services/        # Business logic: auth, speaking, coach, ielts...
│   │   └── middleware/      # JWT authentication, validation, error handling
│   └── storage/             # Local database & transient file storage
│
└── docs/                    # Specifications, research plans, and architecture docs
```

---

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK**: 3.47.5 / Dart 3.13.4 (`flutter doctor` should verify Android toolchain)
- **Android SDK**: Platform 36/37, Build Tools 36.0.0, NDK r28c, and CMake 3.22.1
- **Node.js**: v22.x or later with npm

---

### 1. Setup and Run the Backend API

```powershell
cd backend

# Create local environment config
Copy-Item .env.example .env

# Install dependencies
npm install

# Generate Prisma Client & apply SQLite migrations
npm run prisma:generate
npx prisma migrate deploy --schema prisma/schema.prisma

# Seed original curriculum and vocabulary
npm run seed

# Build TypeScript & start server
npm run build
npm start
```

The API will listen on `http://localhost:3000`.

> **Note for PostgreSQL**: Set `DATABASE_URL="postgresql://user:pass@host:5432/toungular"` in `.env`, then run `npm run prisma:generate:postgres` and `npm run prisma:migrate:postgres`.

---

### 2. Run the Flutter Mobile App

```powershell
cd mobile

# Resolve Flutter dependencies
flutter pub get

# Run on Android Emulator (10.0.2.2 maps to host localhost)
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000

# For a physical Android device on the same local network:
# flutter run --dart-define=API_BASE_URL=http://<YOUR_COMPUTER_LAN_IP>:3000
```

---

### 3. Build the Android Debug APK

To compile an installable Android debug APK:

```powershell
cd mobile
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

The output APK is assembled at:
```
mobile/build/app/outputs/flutter-apk/app-debug.apk
```

---

## 🔒 Security, Privacy & Compliance

- **Zero Audio Leakage**: Audio recordings remain inside the Android app's private cache directory. Transcripts and transparent metrics are synchronized to the API; no raw voice bytes are retained long-term on the server.
- **Account Deletion**: Full compliance with Google Play Store data safety requirements. A user can trigger complete account deletion via `DELETE /v1/me` or directly from the in-app Account Settings screen.
- **Server-Side Provider Secrets**: All third-party AI, speech synthesis, and analytics credentials are kept strictly server-side; no secrets are ever embedded in the mobile binary.
- **Non-Intrusive Ads**: Google Mobile Ads are disabled by default (`ADS_ENABLED=false`). When enabled for development, `AdPlacementPolicy` enforces that ads are never shown during active recording, lesson activities, or voice sessions.

---

## 🔬 Science-Backed Roadmap (Superpowers)

Toungular is engineered to incorporate findings from cognitive psychology, Second-Language Acquisition (SLA), and speech science:

1. **Speech Shadowing Engine** (Hamada 2016, 2024 meta-analysis): Parallel audio prosody tracking and acoustic alignment against native models.
2. **Graduated Anxiety Reduction System** (Affective Filter Hypothesis): Step-ladder practice from anonymous whispering to live interactive scenarios.
3. **Phoneme-Level Articulation Drills**: Acoustic formant comparison and minimal-pair identification based on learner L1 interference.
4. **Contextual Comprehensible Input (i+1)**: Automated CEFR lexical tagging and adaptive readability adjustment.

See [`docs/TOUNGULAR-SUPERPOWERS-PLAN.md`](docs/TOUNGULAR-SUPERPOWERS-PLAN.md) and [`docs/Opencode-Handoff.md`](docs/Opencode-Handoff.md) for full citations and specifications.
