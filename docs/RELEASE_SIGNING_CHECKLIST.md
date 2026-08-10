# Release Build & Signing Validation Checklist

This checklist records the required steps to validate a production-ready release build.
Complete each item on a physical Android device and iOS device before publishing.

## Prerequisites
- Production keystore file and credentials available to authorized release owner only.
- Do not store keystore secrets in source control or CI logs.
- Use `KEYSTORE_PATH`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD` for build-time injection when using CI.

## Android

1. Verify signing config:
   - `key.properties` present with valid `storeFile`, `storePassword`, `keyAlias`, `keyPassword`.
   - OR environment variables exported: `KEYSTORE_PATH`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`.
2. Build release APK/AAB:
   - `flutter build apk --release`
   - OR `flutter build appbundle --release`
3. Verify APK/AAB signature:
   - Android: `apksigner verify --verbose build/app/outputs/flutter-apk/app-release.apk`
   - Confirm v1/v2/v3 scheme signatures present.
4. Install and smoke-test on physical Android device:
   - Picker, SAF output grant, processing, result screens, cancel, reset, settings sync.
5. Test App Bundle install via Play Internal Testing if applicable.

## iOS

1. Verify signing identity and provisioning profile in Xcode project settings.
2. Build release IPA:
   - `flutter build ios --release`
3. Export IPA via Xcode Organizer or `xcodebuild -exportArchive`.
4. Install and smoke-test on physical iOS device:
   - File picker, output folder grant, processing, result screens, cancel, reset, settings sync.

## Cross-Platform

1. Run `flutter analyze` on release branch with no issues.
2. Run `flutter test` with all tests passing.
3. Verify no keystore/secrets leaked in build artifacts.
4. Verify release build has:
   - `isDebuggable = false`
   - `isMinifyEnabled = true`
   - `isShrinkResources = true`
   - ProGuard rules applied (`proguard-rules.pro`).
5. Capture final version code/version name and update `CHANGELOG.md` and `SETUP_COMPLETE.md`.

## Evidence

Attach screenshots/logs from device smoke tests and signature verification output to the release record.
