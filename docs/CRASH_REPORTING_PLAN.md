# Crash Reporting Plan — MetaStrip (Risk 3)

**Decision (top):** Adopt **Firebase Crashlytics** for MetaStrip's first crash-reporting layer.

Rationale in one line: the Android side is *already* Firebase-wired (`com.google.gms.google-services` plugin, Firebase BoM, `firebase-analytics`, and a committed `google-services.json` for `com.bariskode.metastrip`), so Crashlytics is the lowest-effort path to close Risk 3, it is free with no event cap, and the one privacy gap it has (no `beforeSend` hook) is fully mitigable with a centralized redaction layer that reuses MetaStrip's existing path-stripping discipline. **Sentry** is the documented alternative and is the stronger pick *only* if the team wants a non-Google / self-hostable backend or built-in pre-send scrubbing.

This is a decision + implementation plan only. No source, `pubspec.yaml`, or other doc is modified here.

---

## 0. Current State (evidence)

| Fact | Source |
|---|---|
| Android Gradle already applies `com.google.gms.google-services`, Firebase BoM `34.17.0`, `firebase-analytics` | `android/app/build.gradle.kts` |
| `google-services.json` committed for `com.bariskode.metastrip` (project `bariskode-metastrip`) | `android/app/google-services.json` |
| **iOS has no `GoogleService-Info.plist`** → Firebase not yet set up for iOS | `ios/Runner/` listing |
| Release build: `isMinifyEnabled=true`, `isShrinkResources=true`, proguard + `proguard-rules.pro`, `ndk.debugSymbolLevel="SYMBOL_TABLE"` | `android/app/build.gradle.kts` |
| **No Flutter `--split-debug-info`** → Dart stack frames in release crashes are un-symbolicated today | build commands / CI |
| No `firebase_crashlytics` / `sentry_flutter` / any analytics dep in `pubspec.yaml` | `pubspec.yaml` |
| Existing "error sanitization" = UI basename-only + generic error strings; **no** `beforeSend` equivalent | `processing_screen.dart:156,162` (`.split(RegExp(r'[/\\]')).last`), `remover_bloc.dart` generic messages |
| Flavors exist: `main_prod.dart` / `main_dev.dart` | `lib/main_*.dart` |

Implication: Crashlytics completes the *already-started* Firebase integration on Android; iOS is one extra config step.

---

## 1. Offline Behavior — both buffer and flush later

- **Crashlytics:** caches reports on-device and uploads when connectivity returns; respects `setCrashlyticsCollectionEnabled`. No real-time requirement.
- **Sentry:** same model — events are buffered and sent on the next network opportunity; `Sentry.init` works fully offline, queued envelopes flush later.

**Stated implication for an offline-only app:** MetaStrip makes no network calls in normal operation, and many users may be processing files fully offline. A crash captured while offline will **only upload once the device is online again** — which may be never for a user who never opens the app online. This is **acceptable**: crash data is diagnostic, not user-content, and the app's value does not depend on it. We still gate collection behind an explicit opt-in (see §5) so the privacy posture is transparent. Both SDKs are safe to ship; neither will block the UI or fail processing when offline.

---

## 2. Setup Burden

| Step | Crashlytics (this repo) | Sentry |
|---|---|---|
| Backend | Firebase project **already exists** (`bariskode-metastrip`); Android `google-services.json` **already committed** | Create Sentry project, copy **DSN** (a single string secret) |
| Android native | Add `com.google.firebase.crashlytics` Gradle plugin + `firebase-crashlytics` dep (gms plugin + BoM already present) | Add `sentry-android` + `io.sentry:sentry-android-gradle-plugin` + `sentry.properties` (DSN) |
| iOS native | Add `GoogleService-Info.plist` + `FirebaseCore` init in `AppDelegate`/`GeneratedPluginRegistrant` | Add Sentry SDK init in `AppDelegate.swift` + `sentry.properties` |
| Dart | `firebase_core` + `firebase_crashlytics` deps; `await Firebase.initializeApp()` | `sentry_flutter` dep; `await SentryFlutter.init(...)` |

**Lighter for a solo/offline app?** Ambiguous on paper — Sentry needs *no* Google account, no `google-services.json`, no GMS plugin chain, just a DSN. But **this repo has already paid the Firebase cost on Android**, so finishing Crashlytics is incremental there, while Sentry would either leave the unused Firebase `firebase-analytics` dependency in place (dead weight) or require removing it. Net: **Crashlytics is lighter *for this specific repo***; Sentry is lighter *for a greenfield* offline app.

---

## 3. Privacy & Redaction Strategy

Crash reports carry stack traces + exception strings. In a metadata-stripper, the PII risk is **filesystem paths** (e.g. `/storage/emulated/0/Download/photo.jpg`, `C:\Users\...\scan.png`) and possibly **filename/values** that reach an exception message or a `log()` call — never file *contents* (those are never loaded into crash context).

**Critical SDK difference:**
- **Sentry has `beforeSend` / `beforeSendCallback`** — an event can be scrubbed (or dropped) *before it leaves the device*. This is the strongest privacy guarantee.
- **Crashlytics has NO `beforeSend` hook.** A recorded event is sent as-is; you cannot intercept it pre-transmission. Redaction must therefore happen **before** `recordError` / `log` / `setCustomKey` is called.

Because we chose Crashlytics, enforce redaction at the **throw/log site**, mirroring MetaStrip's existing discipline:

1. **Reuse the existing pattern.** `processing_screen.dart` already shows only `file.name` (basename) via `.split(RegExp(r'[/\\]')).last`. Apply the same transform to anything we ever pass toward Crashlytics.
2. **Add a single redaction helper** (new file, e.g. `lib/core/crash_reporting/crash_redactor.dart`):
   - `String sanitizeForCrashReport(String input)` — strips absolute-path tokens with a regex (Android `/storage/...`, `/data/...`; Windows `C:\...`; generic `/`-separated absolute paths) and replaces them with `<path>`; reduces any filename to basename.
   - Mirror the UI regex `RegExp(r'[/\\]')` so behavior is consistent with the existing sanitization.
3. **Centralize the reporting call.** Route *every* crash through one wrapper (e.g. `reportError(Object error, StackTrace? stack)` in the same new file) that:
   - runs `sanitizeForCrashReport` over `error.toString()`,
   - **never** calls `Crashlytics.log()` / `setCustomKey()` with a full input path,
   - attaches at most a basename + format/extension (non-identifying), and only if useful.
4. **Wire `FlutterError.onError` and `PlatformDispatcher.instance.onError`** through that wrapper (prod flavor only).
5. **Opt-in gate:** add a Settings toggle ("Send crash reports", default **off** for a privacy-first offline app). Call `FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(enabled)` from the Settings cubit. This makes the offline/privacy posture explicit and user-controlled — stronger than Crashlytics' lack of `beforeSend`.

If the team later prefers not to depend on Google for crash data, Sentry's `beforeSendCallback` is the drop-in privacy upgrade (same redactor can live inside the callback instead of the pre-`recordError` layer).

---

## 4. Cost & Lock-in

| | Crashlytics | Sentry |
|---|---|---|
| Free tier | Free, **no event cap** (part of Firebase Spark) | Free up to **5,000 events/month**; paid above |
| Backend ownership | Google (proprietary, GMS-coupled) | Open-source SDK; **self-hostable** (Sentry On-Prem) or sentry.io |
| Vendor lock-in | High — tied to Google account + `google-services.json` + GMS | Low — standard DSN, portable, can self-host |
| Extra infra here | None new (Firebase project exists) | None new (Sentry account) |

For MetaStrip's crash volume (a niche offline utility), both free tiers suffice. The differentiator is **lock-in**: Crashlytics couples us to Google/GMS; Sentry is vendor-neutral and self-hostable. Given the app's *raison d'être* is local-only privacy, that irony is worth noting — but crash telemetry is diagnostic metadata, not user file content, so Google coupling is a low-risk trade for the lower setup cost here.

---

## 5. iOS / Android Config + Symbolication

Both SDKs need Flutter `--split-debug-info` + `--obfuscate` to make release crashes readable. The repo's `ndk.debugSymbolLevel="SYMBOL_TABLE"` covers **native (NDK/C++)** symbols only — it does **not** symbolicate Dart/Flutter frames. That extra step is mandatory for useful crash reports.

**Release build command (add to release flow / CI):**
```
flutter build appbundle --flavor prod -t lib/main_prod.dart \
  --release --obfuscate --split-debug-info=build/symbols
# and/or
flutter build apk --flavor prod -t lib/main_prod.dart \
  --release --obfuscate --split-debug-info=build/symbols
```
Keep `build/symbols/` (or upload it) — it is required to deobfuscate later.

**Crashlytics symbol upload:**
- Add `id("com.google.firebase.crashlytics")` to `android/app/build.gradle.kts` and the Crashlytics Gradle classpath in the root `build.gradle[.kts]`.
- Add `implementation("com.google.firebase:firebase-crashlytics")` to the app deps.
- The Gradle plugin auto-adds `:app:firebaseCrashlyticsUploadSymbolsRelease`, which uploads native symbols during assemble. For **Flutter/Dart** symbols, either:
  - run `flutter symbolize -i build/symbols/app.android-<arch>.symbols --output=<report>` to read individual reports locally, or
  - upload the Flutter symbol files to Crashlytics via the symbol-server step in CI.
- iOS: upload dSYMs — `firebase crashlytics:symbols:upload` from `build/symbols`, or let Xcode's dSYM upload run.

**Sentry symbol upload (alternative):**
- `flutter build ... --split-debug-info=build/symbols --obfuscate`
- `sentry-cli debug-files upload --include-sources build/symbols`
- or the `sentry_dart_plugin` Gradle/Flutter task.

**Net extra step vs today:** today's release build has proguard but **no `--split-debug-info`** → crashes are obfuscated *and* unreadable. Adding `--split-debug-info` + the symbol upload closes that gap for either SDK.

---

## 6. Phased Implementation Step List

> Touches files: `pubspec.yaml`, `lib/main_prod.dart` (+ new `lib/core/crash_reporting/*` files), `android/app/build.gradle.kts`, `android/build.gradle` (root), `ios/Runner/GoogleService-Info.plist` (new), `ios/Runner/AppDelegate.swift`/`Info.plist`, `lib/features/settings/*` (opt-in toggle), and the release build command / CI (`flutter_ci.yml`).

**Phase A — Dependencies**
1. `pubspec.yaml`: add `firebase_core` and `firebase_crashlytics` under `dependencies`. (Optional: drop the unused native `firebase-analytics` if we don't want analytics.) `flutter pub get`.

**Phase B — Android native**
2. Root `android/build.gradle[.kts]`: add `classpath "com.google.firebase:firebase-crashlytics-gradle:<ver>"`.
3. `android/app/build.gradle.kts`: add `id("com.google.firebase.crashlytics")` and `implementation("com.google.firebase:firebase-crashlytics")`. (`google-services.json` already present.)

**Phase C — iOS native**
4. Download `GoogleService-Info.plist` for `com.bariskode.metastrip` and add to `ios/Runner/`.
5. Ensure `FirebaseCore` initializes (Flutter `Firebase.initializeApp()` covers it once the plist exists; verify in `AppDelegate`/plugin registrant).

**Phase D — Redaction + init (prod flavor only)**
6. New `lib/core/crash_reporting/crash_redactor.dart`: `sanitizeForCrashReport(String)` (path/basename stripping, mirroring `processing_screen.dart`) + `reportError(Object, StackTrace?)` wrapper that sanitizes before `FirebaseCrashlytics.instance.recordError`.
7. New `lib/core/crash_reporting/crash_reporting_bootstrap.dart`: `initCrashReporting()` → `await Firebase.initializeApp()`, set `FlutterError.onError` and `PlatformDispatcher.instance.onError` to the wrapper, apply the opt-in enabled flag.
8. `lib/main_prod.dart`: call `initCrashReporting()` early in `main()` **before** `app.main()` runs app logic. `main_dev.dart` intentionally does **not** init (no crash data from dev builds).

**Phase E — Privacy opt-in**
9. `lib/features/settings/*`: add "Send crash reports" toggle (default off). Settings cubit calls `setCrashlyticsCollectionEnabled(enabled)` on change. Persist via existing `SharedPreferences` storage.

**Phase F — Symbolication in release/CI**
10. Update release build command (and `RELEASE_SIGNING_CHECKLIST.md` / `flutter_ci.yml` release job) to include `--obfuscate --split-debug-info=build/symbols`.
11. Add symbol upload step: `./gradlew :app:firebaseCrashlyticsUploadSymbolsRelease` (Android) and dSYM upload (iOS) in the release pipeline; archive `build/symbols` as a CI artifact.

**Validation (cannot run device validation here — see Risk 3):**
- `flutter analyze` + `flutter test` must stay green (strict `very_good_analysis`).
- Smoke: force a thrown error in a debug prod build, confirm it sanitizes (no path in the recorded event) and respects the opt-in flag.
- Symbolication check: build release with `--split-debug-info`, verify a test crash resolves to readable Dart frames after upload.

---

## 7. Recommendation Summary

- **Pick:** Firebase Crashlytics (completes the already-present Firebase Android integration; free, no event cap).
- **Privacy mitigation (mandatory):** Crashlytics has no `beforeSend`, so add a centralized `sanitizeForCrashReport` redactor that reuses MetaStrip's existing basename-only path discipline, route all errors through it, and gate collection behind an explicit Settings opt-in (default off).
- **Symbolication (mandatory for useful reports):** today's release build lacks `--split-debug-info` → add `--obfuscate --split-debug-info=build/symbols` + symbol upload in CI.
- **Alternative:** Sentry if the team wants a non-Google / self-hostable backend or built-in `beforeSend` scrubbing; it is the privacy-superior option but adds setup here and leaves the existing Firebase footprint unused.
- **Reality check for offline-only:** reports may never upload for users who never go online — acceptable, but stated explicitly to stakeholders.
