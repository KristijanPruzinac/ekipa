# WagZ mobile

Native Flutter client for the same WagZ public API as the web app. Android and iOS project scaffolds are included. There is no separate mobile database or admin login.

## Build and install without a local emulator

Use the repository's **Actions → WagZ mobile → Run workflow** to build on GitHub's standard Ubuntu runner. Enter the deployed public HTTPS origin as `api_base_url`, for example `https://your-wagz-site.vercel.app`, without `/api`, credentials, a query, or a fragment. No repository secrets or signing keys are required.

The workflow uses Flutter **3.44.7 / Dart 3.12.2** and Java 17, installs the locked dependencies, runs `flutter analyze` and all unit/widget tests, then builds a debug APK with `WAGZ_API_BASE_URL` embedded. After it succeeds, download the `wagz-android-debug-<run-number>` artifact from the run summary, extract `app-debug.apk`, and open it on an Android phone to install. Android may ask you to allow installation from the app used to open the APK. Artifacts are retained for seven days.

Pushes and pull requests affecting mobile code run analysis and tests only. APK builds require a manual run with the deployed API address. The workflow does not run an emulator. This keeps Gradle, the Android SDK, and emulator RAM/disk use off the development computer; prefer this path on a machine that has run out of memory or disk during a native build. The API must be reachable from the phone when the app runs.

This APK is for device testing and uses a development signing key. Store signing and distribution remain separate work. A later build may have a different development key and require uninstalling the older debug app first, which removes its saved on-device preferences.

## Run

Local development uses Flutter 3.44.7 / Dart 3.12.2 and the appropriate platform SDK. Start the existing Node backend from the repository root (`npm run dev`). Then, on a computer with enough free memory and disk:

```powershell
cd apps/mobile
flutter pub get
flutter emulators --launch Medium_Phone_API_36.1
flutter run --dart-define=WAGZ_API_BASE_URL=http://10.0.2.2:3000
```

`10.0.2.2` is the Android emulator's address for the development computer. Select your emulator with `-d <device-id>` when multiple devices are available. The API base URL is required; an unconfigured app displays a recoverable configuration message.

For an Android phone connected by USB, use `adb reverse tcp:3000 tcp:3000` and run with `--dart-define=WAGZ_API_BASE_URL=http://127.0.0.1:3000`. A phone on Wi-Fi instead needs the development computer's reachable LAN address and a backend bound to that interface (`HOST=0.0.0.0`); the default backend binds only to loopback. Use your platform's shell syntax to set `HOST`.

On macOS, use an iOS simulator with `--dart-define=WAGZ_API_BASE_URL=http://127.0.0.1:3000`. Building or running iOS requires Xcode and local signing configuration; it cannot be verified on Windows. The iOS local-network exception permits local development connections. Android HTTP access is enabled only in debug builds. Use an HTTPS backend for distributable builds.

Never supply the admin key, OpenRouter key, or any other secret in a Dart define or app asset. `WAGZ_API_BASE_URL` is a public address, not a credential. Source pages open in the system browser.

## Behavior

- `GET /api/events` powers illustrated event cards, the chronological timeline, details, refresh, cancellation notices, and source links. Unknown times and prices stay unknown.
- `POST /api/tips` sends only a note, optional URL and an empty honeypot field. A success message appears after the server acknowledges the save. Failed submissions retain the entered text and never retry automatically.
- Dates and times use `Europe/Zagreb`, including daylight-saving transitions, independent of the device timezone. The full IANA database is bundled because the smaller timezone package database omits the Zagreb alias.
- The only discovery control is **Svi · Studenti · Odrasli · Stariji**, saved only on this device. Svi is chronological. Source audience evidence leads, then transparent recommendations based on published category, named program format and explicit free entry. Every event remains visible. Cancelled/postponed events receive no boost; legacy category interests are ignored. Score ties are chronological, then preserve feed order. Weights, explanations and the highlight threshold match `shared/discovery.ts`; suggestions are distinct from source audience evidence and make no eligibility/accessibility claim.
- Pastel illustrations distinguish categories without adding controls. The timeline starts collapsed behind “Otvori vremensku crtu” so upcoming cards appear sooner. Opening it previews three events on one chronological spine; users can close the chart or expand all events. Category-colored branches connect real start/end markers, with separate overlap lanes only as needed. Exact timestamp ranges show duration; date-only ends show a calendar range without invented hours, and unknown ends stay unknown. Spacing serves readability, not elapsed-time scale. Ongoing state uses API feed time. Timeline entries and cards open the same details.
- Ongoing events use a compact two-row section with an explicit total and expansion; the main cards show upcoming plans. Both groups keep the selected ranking. Cards show supported duration or known end, and unknown ends remain unknown. Refresh runs every 60 seconds only while resumed, avoids overlap, refreshes on return and retains the last feed if a request fails.
- Metadata in `event.discovery` is optional for compatibility with older public feeds. No ages, genres or popularity are inferred on the phone.

The interface, bundled DM Sans / Space Grotesk fonts, and cream/ink/lime colors match WagZ. Font licenses live in `assets/fonts/`. The geometric launcher mark is in `assets/icon.svg`; `tool/generate-icons.ps1` regenerates native PNG sizes on Windows.

## Verify

The GitHub workflow performs these checks remotely. For local checks when resources permit:

```powershell
flutter analyze
flutter test
```

For an optional local Android build, use `flutter build apk --debug --dart-define=WAGZ_API_BASE_URL=http://10.0.2.2:3000`. The debug APK is written to `build/app/outputs/flutter-apk/app-debug.apk`. The generated release signing configuration is also for local development only.

Tests cover HTTP contracts and errors, Zagreb midnight/DST boundaries, safe source links, source evidence versus recommendations, retained unmatched events, ignored legacy interests, local preferences, 320px large-text layouts, chronological range endpoints/overlap/ongoing durations, event details and successful/failed tips.

An optional native smoke test starts its own loopback HTTP fixture server inside the test process. It exercises real sockets without touching your WagZ database or submitting a live tip:

```powershell
flutter drive -d emulator-5554 --driver=test_driver/integration_test.dart --target=integration_test/mobile_smoke_test.dart
```

It captures home/feed/detail/tip screenshots in `build/screenshots/`. The fixture events are explicitly test data and never ship in the normal app entry point. There is no bundled demo feed in `lib/`.
