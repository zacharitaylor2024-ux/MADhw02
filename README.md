# Campus Board — CSC 4360 Homework 02

Simple Flutter/Firebase message board with splash, email/password authentication, private user records, live public-to-signed-in messages, edit/delete ownership rules, and duplicate-safe posting.

## Setup on Windows / Android

1. Install Flutter, Android Studio emulator, Node.js, Firebase CLI, and FlutterFire CLI.
2. `flutter create message_board` and `cd message_board`.
3. Copy the **contents** of this starter into your generated `message_board` folder, replacing `pubspec.yaml` and `lib/main.dart`. Keep the generated `android/` folder and other platform boilerplate.
4. `flutter pub get`
5. Firebase console: create/select Firebase project (Cloud Quest is okay), enable **Authentication > Email/Password** and **Firestore Database**. For least risk, use a new project if Cloud Quest already has rules/data you want preserved.
6. `firebase login` then `flutterfire configure` (choose Android; creates `lib/firebase_options.dart`).
7. `firebase use --add` (choose the **same** project; alias e.g. default).
8. `firebase deploy --only firestore:rules` **CAUTION:** this replaces existing Firestore rules in the selected project.
9. Add `<uses-permission android:name="android.permission.INTERNET" />` inside the opening `<manifest>` element in `android/app/src/main/AndroidManifest.xml` (not inside `<application>`). This is required for release internet access.
10. `flutter run` on Android emulator/device.

## Architecture / data model (writer map)

- `users/{uid}`: `uid`, `firstName`, `lastName`, `role='member'`, `registrationDateTime`. Written once by registering user, with server time; readable by that user only; no client updates/deletes.
- `messages/{msgId}`: `text`, `authorUid`, `authorName`, `createdAt`, `editedAt`. Created by signed-in author, `createdAt` is server timestamp. Streamed to signed-in users, edited/deleted only by author; author/creation timestamp immutable.
- `AuthService`: all sign-in, registration, auth-state calls. `BoardService`: all message CRUD calls. `StreamBuilder` owns its subscription lifecycle.
- UI hides other users' buttons for convenience, while Firestore rules actually enforce ownership.
- Server timestamps avoid device time skew. Role is descriptive, not an admin permission.

## Extra Spice #1 — Emulator Explorer

Install Java and Firebase CLI. From the project root:

```powershell
firebase emulators:start --project demo-message-board --only auth,firestore
```

Emulator UI: http://localhost:4000

In a **second** terminal, from the Flutter project root:

```powershell
flutter run --dart-define=USE_EMULATORS=true
```

Android emulator uses `10.0.2.2` for your computer localhost. For a physical device, supply its reachable development-machine IP with `--dart-define=EMULATOR_HOST=192.168.x.x` and configure network/firewall as needed.

Register **test users** and post **test messages** using the app. Capture Emulator UI showing Auth/Firestore records and the unchanged **production** Firebase console (before/after screenshots). Never use real personal data in the emulator demonstration.

## Extra Spice #2 — Rules Unit Tester

In terminal 1, from project root (or just let test script start its emulator):

```powershell
cd rules_tests
npm install
npm test
```

This runs automated tests against the Firestore emulator using `@firebase/rules-unit-testing`. Capture passing test output including signed-out denial, other-author denial, forged author denial and author CRUD. Note: Firebase CLI / emulator tooling requires an appropriate installed Java runtime.

## Extra Spice #4 — Idempotent Alchemist

`BoardService.createOnce` uses a stable document ID per logical post and a Firestore transaction: retrying that ID skips creation when it already exists. The Board screen `... > Run duplicate-post test` intentionally launches two calls with the same ID. Both calls finish, and exactly one Firestore document should exist with that ID/text. Capture the app success banner and the Firestore database document count / search for that unique message.

Trade-off: Firestore transactions need a connection. Offline transactions can fail and must be retried once online with the same ID. The UI disables posting during the awaited call, too.

## Tests + evidence checklist

- Styled splash (capture while loading), Firebase startup and retry on failure.
- Register user A; Firestore `users/{uid}` five fields; sign out, sign in, invalid input/error.
- Initial empty board; create, live read, edit, delete own post.
- Register user B (second emulator/device); post and observe A's board update without refresh.
- Denials must originate from Firestore: signed-out read, B updating/deleting A's post, forged UID; use automated rules test output.
- Duplicate test: two calls, one message; rules unit tests; Emulator UI plus unchanged production proof.
- Install and test the **exact release APK** (Main Spice), not only debug:

```powershell
flutter analyze
flutter test
flutter build apk --release
adb install -r build\app\outputs\flutter-apk\app-release.apk
```

Run entire test sequence again on the installed APK and record device, build, expected vs observed and pass/fail.

## Required submission

1. GitHub repository link, README, meaningful commits (no service credentials).
2. Tested release `.apk` uploaded separately.
3. One Word/PDF evidence document: test date/device/repo; captioned screenshots with action, expected, observed, pass/fail; Main Spice plus three selected spices; 2 of 3 case-file arguments (undergrad); AI comparison with own **original prediction before consulting AI**, exact tool/date, primary documentation verification and actual test; assignment reflection prompts. Don't claim tests passed until run.

Official docs: https://firebase.google.com/docs/flutter/setup ; https://firebase.google.com/docs/firestore/security/get-started ; https://firebase.google.com/docs/emulator-suite ; https://firebase.google.com/docs/rules/unit-tests ; https://docs.flutter.dev/deployment/android
