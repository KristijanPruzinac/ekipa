# WagZ mobile

Native Flutter client for the same WagZ public API as the web app. Android and iOS project scaffolds are included. There is no separate mobile database or admin login.

## Build and install without a local emulator

Use **Actions → WagZ mobile → Run workflow** to build on GitHub's Ubuntu runner. The default public API origin is `https://wagz.com.hr`; do not add `/api`, credentials, a query, or a fragment. Select `signed-release` for a release APK and Android app bundle, `unsigned-release` for packaging verification without an installable app, or `debug` for a development APK. There is no automatic change of signing mode if configuration is missing.

The workflow uses Flutter **3.44.7 / Dart 3.12.2** and Java 17, installs locked dependencies, runs analysis and all unit/widget tests, then embeds the public API address. Signed releases require four repository secrets: `WAGZ_ANDROID_KEYSTORE_BASE64`, `WAGZ_ANDROID_KEYSTORE_PASSWORD`, `WAGZ_ANDROID_KEY_ALIAS`, and `WAGZ_ANDROID_KEY_PASSWORD`. Partial configuration fails. The runner keeps temporary signing files private and removes them after the build; they are never uploaded as artifacts.

Download `wagz-android-signed-release-<run-number>` from the successful run. Open `app-release.apk` on an Android phone to install; Android may ask you to allow installation from the app used to open it. The `.aab` is packaging for a future Google Play upload and cannot be installed directly. Artifacts are retained for seven days. The workflow does not publish to a store.

Pushes and pull requests affecting mobile code run analysis and tests only. APK builds require a manual run with the deployed API address. The workflow does not run an emulator. This keeps Gradle, the Android SDK, and emulator RAM/disk use off the development computer; prefer this path on a machine that has run out of memory or disk during a native build. The API must be reachable from the phone when the app runs.

Release APKs use the app's persistent private key. Updates must retain that key, application ID `hr.wagz.wagz_mobile`, and an appropriate version code. The current version remains `0.1.0+1`. An older debug APK has a different signature and must be uninstalled before installing this release. No Google Play or Apple account has been configured; store distribution remains pending owner account setup.

## Private signing and recovery

Local releases read the gitignored `android/key.properties`, pointing at a private keystore outside the repository. An authorized owner can create a new app key once with `tool/create-local-signing.ps1`; it refuses to overwrite existing signing material. On this Windows host it restricts the private directory and properties to the current user and SYSTEM. It creates a recovery ZIP containing the key and credentials under `%USERPROFILE%/.wagz-private/android/`. The owner must keep a separate private offline copy; a second copy on the same disk does not protect against disk loss. Never attach this backup to a release or commit it.

After reviewing the destination repository, an authorized owner can use `tool/provision-signing-secrets.ps1 -Repository owner/repository` to send the four credentials to GitHub through standard input. The script does not print credential values. Routine builds reuse the existing key; they never generate a new one. See [Flutter's release signing guidance](https://docs.flutter.dev/deployment/android#sign-the-app).

## Run

Local development uses Flutter 3.44.7 / Dart 3.12.2 and the appropriate platform SDK. Start the existing Node backend from the repository root (`npm run dev`). Then, on a computer with enough free memory and disk:

```powershell
cd apps/mobile
flutter pub get
flutter emulators --launch Medium_Phone_API_36.1
flutter run --dart-define=WAGZ_API_BASE_URL=http://10.0.2.2:3000
```

`10.0.2.2` is the Android emulator's address for the development computer. Select your emulator with `-d <device-id>` when multiple devices are available. Without a Dart override, the app uses `https://wagz.com.hr`. Network failures display a recoverable error and retain the last feed; the app never silently changes API hosts. Existing builds configured with the legacy host continue to use that host while DNS caches clear.

For an Android phone connected by USB, use `adb reverse tcp:3000 tcp:3000` and run with `--dart-define=WAGZ_API_BASE_URL=http://127.0.0.1:3000`. A phone on Wi-Fi instead needs the development computer's reachable LAN address and a backend bound to that interface (`HOST=0.0.0.0`); the default backend binds only to loopback. Use your platform's shell syntax to set `HOST`.

On macOS, use an iOS simulator with `--dart-define=WAGZ_API_BASE_URL=http://127.0.0.1:3000`. Building or running iOS requires Xcode and local signing configuration; it cannot be verified on Windows. The iOS local-network exception permits local development connections. Android HTTP access is enabled only in debug builds. Use an HTTPS backend for distributable builds.

Never supply the admin key, OpenRouter key, or any other secret in a Dart define or app asset. `WAGZ_API_BASE_URL` is a public address, not a credential. Source pages open in the system browser.

## Behavior

- `GET /api/events` powers illustrated event cards, the chronological timeline, details, refresh, cancellation notices, and source links. Unknown times and prices stay unknown.
- `POST /api/tips` sends only a note, optional URL and an empty honeypot field. A success message appears after the server acknowledges the save. Failed submissions retain the entered text and never retry automatically.
- Dates and times use `Europe/Zagreb`, including daylight-saving transitions, independent of the device timezone. The full IANA database is bundled because the smaller timezone package database omits the Zagreb alias.
- Discovery is always chronological, with every event retained. One activity filter shows only types present in the feed, with counts and reset. No audience selector, student labels, age filters or personal scoring are shown; legacy preferences are ignored.
- Dance, workshop, film and literature have distinct sketches and readable colors on cards and timeline branches. Film means an actual screening or film programme; a filmmaking workshop remains a workshop, and a library venue alone does not make an event literary. The timeline legend shows only types in its current preview.
- Since branch `claude/post-release-work` the home screen no longer shows the timeline. The widget code remains, and the description below applies to the deployed release. Flutter tests were updated for this change but have not been run, and the Android release must be rebuilt.
- Pastel illustrations distinguish categories without adding controls. The timeline starts collapsed into a compact row behind “Otvori vremensku crtu” so upcoming cards appear sooner. Opening it previews three events on one chronological spine; users can close the chart or expand all events. Category-colored branches connect real start/end markers, with separate overlap lanes only as needed. Exact timestamp ranges show duration; date-only ends show a calendar range without invented hours, and unknown ends stay unknown. Spacing serves readability, not elapsed-time scale. Ongoing state uses API feed time. Timeline entries and cards open the same details.
- Ongoing events use a compact two-row section with an explicit total and expansion; the main cards show upcoming plans. Both groups stay chronological. Cards show supported duration or known end, and unknown ends remain unknown. Refresh runs every 60 seconds only while resumed, avoids overlap, refreshes on return and retains the last feed if a request fails.
- Metadata in `event.discovery` is optional for compatibility with older public feeds. No ages, genres or popularity are inferred on the phone.

The interface, bundled DM Sans / Space Grotesk fonts, and cream/ink/lime colors match WagZ. Font licenses live in `assets/fonts/`. The geometric launcher mark is in `assets/icon.svg`; `tool/generate-icons.ps1` regenerates native PNG sizes on Windows.

## Verify

The GitHub workflow performs these checks remotely. For local checks when resources permit:

```powershell
flutter analyze
flutter test
```

For local signed builds after configuring the private key:

```powershell
flutter build apk --release --dart-define=WAGZ_API_BASE_URL=https://wagz.com.hr
flutter build appbundle --release --dart-define=WAGZ_API_BASE_URL=https://wagz.com.hr
```

Outputs are `build/app/outputs/flutter-apk/app-release.apk` and `build/app/outputs/bundle/release/app-release.aab`. Release builds fail if signing is missing or partial. Without a signing file, explicitly setting `WAGZ_ALLOW_UNSIGNED_RELEASE=true` permits unsigned verification artifacts; these are not installable releases. For local development use `flutter build apk --debug --dart-define=WAGZ_API_BASE_URL=http://10.0.2.2:3000`.

Tests cover HTTP contracts and errors, Zagreb midnight/DST boundaries, safe source links, retained events, ignored legacy preferences, 320px layouts at 200% text size, film/literature color contrast and semantics, chronological endpoints/overlap/ongoing durations, event details and successful/failed tips. Cards and timeline entries expose one descriptive action including date, category, duration, location, price and cancellation status. Automated semantics checks do not replace real-device TalkBack/VoiceOver testing.

An optional native smoke test starts its own loopback HTTP fixture server inside the test process. It exercises real sockets without touching your WagZ database or submitting a live tip:

```powershell
flutter drive -d emulator-5554 --driver=test_driver/integration_test.dart --target=integration_test/mobile_smoke_test.dart
```

It captures home/feed/detail/tip screenshots in `build/screenshots/`. The fixture events are explicitly test data and never ship in the normal app entry point. There is no bundled demo feed in `lib/`.
