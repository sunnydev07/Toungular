# Toungular

Toungular is an Android-first, English-first learning app with a Flutter client
and a TypeScript/Express API. This repository is independent of Stimuler: it
contains no Stimuler runtime dependency, assets, credentials, endpoints, or
server implementation.

## Prerequisites

- Flutter 3.47.5 and Dart 3.13.4. On Windows, add
  `C:\\Users\\sunny\\flutter\\bin` to `PATH` (or use your own Flutter stable
  installation).
- Android SDK Platform 36, Build-Tools, and platform-tools. Accept licenses
  with `flutter doctor --android-licenses`.
- Node.js 22 or later and npm.

Run `flutter doctor` before building the mobile app. If Android tooling is
missing, install it with Android Studio's SDK Manager, then accept the SDK
licenses again.

## Backend setup

```powershell
cd backend
Copy-Item .env.example .env
npm install
npm run prisma:generate
npm run dev
```

The development API listens on `http://localhost:3000`. `.env` is intentionally
ignored by Git. Replace the sample `JWT_SECRET` with a unique local value. Keep
speech, AI, storage, billing, ad, and other provider credentials server-side;
leave optional provider values blank until Toungular-owned accounts are
configured.

The initial Prisma configuration uses SQLite at `backend/prisma/dev.db`. Data
models and migrations are introduced in the next backend task.

## Mobile setup

```powershell
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

`API_BASE_URL` is a compile-time Dart value. `10.0.2.2` reaches the host machine
from the Android emulator. For a physical device, start the backend on a network
reachable interface and substitute your computer's LAN address, for example
`http://192.168.1.25:3000`. Cleartext HTTP is enabled only for debug Android
builds to support local development; production API URLs must use HTTPS.

## Repository layout

- `mobile/` — Flutter Android client (`com.toungular.app`).
- `backend/` — TypeScript/Express API and Prisma development configuration.
- `backend/storage/` — ignored local upload workspace; only `.gitkeep` is
  versioned.

No live speech, AI, advertising, billing, or purchase-verification provider is
configured by this skeleton. Later features must report unavailable providers
clearly rather than inventing feedback, transcripts, or scores.
