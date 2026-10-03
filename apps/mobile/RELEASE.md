# Android release verification — 3 October 2026

The local release APK and Android app bundle were built from the reviewed working tree using Flutter 3.44.7 / Dart 3.12.2, with public API origin `https://wagz.com.hr`. They contain the film/literature card types and large-text/semantics improvements. There is no automatic API-host fallback.

| Item | Verified value |
| --- | --- |
| Application ID | `hr.wagz.wagz_mobile` |
| Version | `0.1.0+1` (unchanged) |
| Android minimum / target | API 24 / 36 |
| Architectures | `arm64-v8a`, `armeabi-v7a`, `x86_64` |
| APK bytes | 53,026,420 |
| AAB bytes | 51,347,386 |
| APK SHA-256 | `a72730caf503dd14fc675a96f3a5cd9ac4c78b0751995a3420ebda1561fcf2ec` |
| AAB SHA-256 | `d978682ecf412e73055af1e149c00f8d38e427af4b52b3f24478642f81675409` |
| Signing certificate SHA-256 | `46702d3ad6bbef84c0515cb3c76769f7dec434c9ab50b90d5d1f8f7a40c6b052` |

`apksigner verify --verbose --print-certs` passed for the release APK with the persistent WagZ RSA-3072 signing key. `aapt dump badging` confirmed the package/version/SDK/architectures above and no debuggable flag. `jarsigner -verify` passed for the AAB; its self-signed certificate warning is expected for an Android upload key. Output paths:

- `build/app/outputs/flutter-apk/app-release.apk` — installable Android release.
- `build/app/outputs/bundle/release/app-release.aab` — future store upload package; not directly installable.

Flutter analysis reported no issues. All 27 unit/widget tests passed, including 320px at 200% text size, card/timeline/ongoing behavior, dates, filtering, source navigation, submission error handling, and accessible action names. There was no connected Android phone/emulator for this verification, so real-device installation, TalkBack and native runtime behavior remain unverified. iOS was not built on this Windows host; a Mac with Xcode and owner signing setup is still required.

The workflow now supports explicit signed release, unsigned verification, and debug modes. It refuses missing or partial signed configuration and verifies APK/AAB signatures before uploading artifacts. Keep Flutter tooling regeneration enabled when moving from tests/debug into release: `--no-pub` can leave the generated Android registrant referencing the development-only integration-test plugin, which fails release compilation. Local release builds succeeded with the normal regeneration path.

The authorized private key and owner recovery ZIP live outside the repository under `%USERPROFILE%/.wagz-private/android/`; the Git-ignored `android/key.properties` points there. Both are restricted to the owner and SYSTEM. The owner must keep a separate private offline backup, and future APK updates must retain this signing identity. CI signing secrets were provisioned separately after destination review. No Play/Apple account exists for this release, no store listing was created, and no store submission occurred. See [the mobile build and signing instructions](README.md).

**Not in these files:** branch `claude/post-release-work` removes the timeline from the Flutter home screen. The updated Flutter tests have not been run, and the APK/AAB above predate that change; a new signed build is needed before it reaches Android users.
