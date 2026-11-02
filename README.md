# Lurk

Lurk is a Flutter app for finding gaming teammates and managing parties.

## Admin account credentials

- Email: superuser@gmail.com
- Password: superuser123

## Features

- Player accounts, profiles, gaming preferences, availability, and identity verification.
- Party discovery, search filters, personalized recommendations, and Quick Match.
- Party creation, invitations, host controls, voice chat, and participation history.
- Direct messages, party chat, and push notifications.
- Teammate ratings, player reports, and blocking.

## Technology

- **Flutter and Riverpod** — application UI and state management.
- **Firebase** — authentication, Firestore data, Realtime Database presence, and FCM notifications.
- **Supabase Storage** — profile photos and verification images.
- **Agora** — voice chat, with a token server hosted on Render.
- **Cloudflare Workers** — notification delivery.

## Getting started

Install Flutter with Dart 3.12.2 or a compatible later 3.x version. Use an Android device or emulator to test voice chat and notifications.

From the project root:

```sh
flutter pub get
flutter devices
flutter run -d <device-id>
```

The checked-in configuration targets the shared Lurk backend. Voice chat and notifications use hosted services; local servers are not required for normal app use.

To build an Android release APK:

```sh
flutter build apk --release
```

## Configuration

- Firebase settings: `lib/firebase_options.dart` and `android/app/google-services.json`.
- Supabase initialization: `lib/main.dart`; storage policies are in `supabase/`.
- Voice endpoint: `config/voice.json`. Override it at launch with `--dart-define=VOICE_TOKEN_URL=<url>`.
- Notification endpoint: `NOTIFICATION_WORKER_URL`, with a hosted default in `NotificationTriggerService`.
- Firebase access rules and indexes: `firestore.rules`, `database.rules.json`, and `firestore.indexes.json`.

Server credentials belong in server environment variables or secrets, never in Flutter assets or source control.

Backend setup and deployment:

- [Voice token server](tools/voice-server/README.md)
- [Notification worker](tools/notification-worker/)

## Project structure

| Directory | Purpose |
| --- | --- |
| `lib/features/` | Screens, widgets, and feature-specific models. |
| `lib/core/` | Shared theme, widgets, configuration, and game catalogue. |
| `lib/providers/` | Riverpod providers. |
| `lib/services/` | Data access and service integrations. |
| `assets/` | Images and sound effects. |
| `test/` | Flutter tests and Firebase security-rule tests. |
| `tools/` | Voice token server and notification worker. |
| `supabase/` | Storage policies and verification setup SQL. |

## Tests

```sh
flutter analyze
flutter test
```

Security-rule tests require Node.js 22 or later, the Firebase CLI, and Java:

```sh
npm ci --prefix test/firestore
firebase emulators:exec --only firestore,database --project demo-lurk-tests "node --test --test-concurrency=1 test/firestore/*.test.mjs"
```

See `tools/voice-server/README.md` for voice-server setup. Run notification-worker tests with `npm test --prefix tools/notification-worker` after installing its dependencies.
