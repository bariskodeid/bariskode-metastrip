# Phase 6 Device Checklist

**Status:** Scheduled; no lane is complete
**Target milestone:** Release hardening
**Scope:** Functional smoke + ZIP memory boundary + memory sampling per lane

Each lane row requires evidence capture before marking Passed. Host-side tests
do not satisfy device evidence.

## Lanes

| Lane ID | Device | OS | Build | Entry gate |
|---:|---|---|---|---|
| L1 | Samsung SM M205G | Android 8.1 | Debug APK | Lane gate: debug APK installed |
| L2 | Modern Android physical | Current supported API | Debug APK | Lane gate: Lane 1 findings triaged |
| L3 | iOS simulator | Supported runtime | iOS debug build | Lane gate: iOS debug build available |
| L4 | iOS physical | Supported iOS version | Release-signed build | Lane gate: signing/profile + Files access available |
| L5 | ZIP stress on Android | Lanes 1-2 | Debug APK | Lane gate: functional Android lane passes |
| L6 | ZIP stress on iOS physical | Lane 4 device | Release-signed build | Lane gate: functional iOS lane passes |

## Pre-Run Checklist

- [ ] `git rev-parse HEAD` recorded
- [ ] `flutter --version` recorded
- [ ] Fixture manifest version and SHA-256 recorded
- [ ] Debug APK / iOS build available at expected path
- [ ] Device is charged / connected / trusted
- [ ] Storage access grant path known for the device

## Lane 1 — Samsung SM M205G / Android 8.1

Build and install:
```bash
flutter analyze
flutter test
flutter build apk --debug
adb -s 3201fbb0c40a1615 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s 3201fbb0c40a1615 shell am start -n com.bariskode.metastrip/.MainActivity
```

Capture logs:
```bash
adb -s 3201fbb0c40a1615 logcat -c
adb -s 3201fbb0c40a1615 logcat -s flutter:V ActivityManager:V chromium:V > lane1-logcat.txt
```

Memory sample (idle):
```bash
adb -s 3201fbb0c40a1615 shell dumpsys meminfo com.bariskode.metastrip | rg TOTAL
```

| Check | Pass criteria | Evidence |
|---:|---|---|
| Install succeeds | `Success` from `adb install`; app launches without crash | `lane1-logcat.txt` + screenshot |
| Picker grants and cancels | Viewer and Remover pickers open, select supported fixture, cancel returns cleanly; no phantom queue item | Screenshot + logcat grep `picker\|cancel\|queue` |
| Output grant | SAF tree URI granted; output folder persists for session | Settings state screenshot + logcat |
| Reopen output | Clean copy visible from Android file UI and compatible viewer | Photo/screen record |
| Original preservation | SHA-256 of input file before and after is equal | `sha256sum` before/after |
| PNG selective | Requested tEXt/iTXt fields absent in output; report lists removed IDs | Viewer result screenshot + output parse |
| PDF selective | Result labeled best-effort attempted/unverified | Screenshot + log line |
| Full cleanup | Supported formats produce clean copy or explicit failure; PDF limitation visible | Per-format output files |
| Cancel during batch | Queue reaches canceled state; no partial output | Logcat grep `cancel\|clear\|reset` |
| Retry after denial | Recovery possible without app restart where designed | Logcat + retry screenshots |
| Output collision | Collision-safe names used; existing output unchanged | Folder listing |
| App lifecycle | Background/foreground during picker, processing, result | No crash; logcat clean |
| Low storage / access denial | Explicit failure; no partial output; originals unchanged | Logcat + error message screenshot |
| Peak RSS baseline | Idle TOTAL PSS/RSS < 80 MB | `lane1-peak-rss.txt` |
| Peak RSS boundary | TOTAL PSS/RSS during Z02 case < 180 MB | `lane1-peak-rss.txt` |
| Recovery | RSS returns to within 10% of baseline within 30 s after final batch | `lane1-peak-rss.txt` timestamp deltas |

ZIP stress cases (L5 shares this lane):
| Check | Pass criteria | Evidence |
|---:|---|---|
| Z01 32 MiB minus 1 byte | Valid operation; output reparses; original unchanged | Output hash + parse result |
| Z02 exactly 32 MiB | Valid operation; output reparses; original unchanged | Output hash + parse result |
| Z03 32 MiB plus 1 byte | Fails closed; no output installed; original unchanged | Logcat + folder listing |
| Z04 malformed sizes | Mismatch rejected explicitly | Logcat |
| Z05 high compression | Bounded decode stops above limit; no crash/OOM | Logcat + memory sample |
| Z06 many entries | Deterministic limit behavior | Logcat |
| Z07 sequential batches | No unbounded RSS growth; no stale output | `lane1-peak-rss.txt` + folder listing |
| Z08 cancellation | Coherent cancel; no partial output; retry works | Logcat |
| Z09 low-memory pressure | No crash/OOM; completes or fails explicitly | Logcat + device free memory |
| Z10 malformed structure | Preflight/decode fails closed | Logcat |

## Lane 2 — Modern Android Physical Device

Same checklist as Lane 1. Replace device serial and path placeholders.
Use the same fixture manifest revision.

Build and install:
```bash
flutter build apk --debug
adb -s <SERIAL> install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s <SERIAL> shell am start -n com.bariskode.metastrip/.MainActivity
```

Capture logs:
```bash
adb -s <SERIAL> logcat -c
adb -s <SERIAL> logcat -s flutter:V ActivityManager:V chromium:V > lane2-logcat.txt
```

Memory sample:
```bash
adb -s <SERIAL> shell dumpsys meminfo com.bariskode.metastrip | rg TOTAL
```

| Check | Pass criteria | Evidence |
|---:|---|---|
| Install succeeds | `Success`; app launches | `lane2-logcat.txt` + screenshot |
| Functional matrix D01-D12 | Same pass criteria as Lane 1 | Per-case screenshots/logs |
| Peak RSS baseline | < 80 MB | `lane2-peak-rss.txt` |
| Peak RSS boundary | < 180 MB | `lane2-peak-rss.txt` |
| Recovery | Within 10% of baseline within 30 s | `lane2-peak-rss.txt` |

## Lane 3 — iOS Simulator

Build and run:
```bash
flutter build ios --simulator
open build/ios/iphonesimulator/Runner.app
# Or:
flutter run -d <SIMULATOR_UDID>
```

Capture logs:
```bash
xcrun simctl spawn booted log stream --predicate 'subsystem == "com.apple.Foundation" OR processImagePath contains "Runner"' > lane3-log.txt
```

| Check | Pass criteria | Evidence |
|---:|---|---|
| Install and launch | App appears in simulator; no crash on launch | Screenshot + `lane3-log.txt` |
| Picker grants and cancels | iOS picker opens; select fixture and cancel returns cleanly | Screenshot + log |
| Output grant | Folder chosen and remembered for session | Settings screenshot |
| Reopen output | File visible in Files app | Screen recording |
| Original preservation | Input file unchanged | Checksum before/after |
| PNG selective | Requested fields absent; report visible | Viewer screenshot |
| PDF selective | Labeled attempted/unverified | Screenshot |
| Full cleanup | Clean copy produced or explicit failure | Output files |
| Cancel during batch | Coherent canceled state | Log |
| Retry after denial | Recovery without restart where designed | Log + screenshots |
| Output collision | Collision-safe names | Folder listing |
| App lifecycle | Background/foreground without crash | Log |
| Low storage / access denial | Explicit failure; no partial output | Log + screenshot |
| Peak RSS baseline | Footprint within device limits; record baseline trace | `.trace` export |
| Peak RSS boundary | No jetsam or termination; record peak trace | `.trace` export |
| Recovery | RSS returns toward baseline within 30 s | `.trace` export |

## Lane 4 — iOS Physical Device

Build and install:
```bash
flutter build ios --release
# Install via Xcode or:
xcrun simctl install <DEVICE_UDID> build/ios/iphoneos/Runner.app
xcrun simctl launch <DEVICE_UDID> com.bariskode.metastrip
```

If using Xcode:
- Open `ios/Runner.xcworkspace`
- Select physical device
- Run (`Cmd+R`)

Capture logs:
```bash
xcrun xctrace record --device '<DEVICE NAME>' --time-limit 30m --template 'Allocations' --output lane4-allocations.trace
```

Console memory warnings:
```bash
xcrun simctl spawn <DEVICE_UDID> log stream --predicate 'eventMessage contains "memory warning"' > lane4-memory-warnings.txt
```

| Check | Pass criteria | Evidence |
|---:|---|---|
| Install succeeds | Provisioning/profile accepted; app launches | Screenshot + `lane4-allocations.trace` |
| Picker grants and cancels | Files picker works; cancel returns cleanly | Screenshot + log |
| Output grant | Files location chosen and persists | Settings screenshot |
| Reopen output | Clean copy visible in Files app | Screen recording |
| Original preservation | Input unchanged | Checksum |
| PNG selective | Fields removed; report visible | Viewer screenshot |
| PDF selective | Attempted/unverified label shown | Screenshot |
| Full cleanup | Clean copy produced or explicit failure | Output files |
| Cancel during batch | Coherent canceled state | Log |
| Retry after denial | Recovery without restart | Log + screenshots |
| Output collision | Collision-safe names | Folder listing |
| App lifecycle | Background/foreground without crash | Log |
| Low storage / access denial | Explicit failure; no partial output | Log + screenshot |
| Peak RSS baseline | Recorded within limits | `.trace` export |
| Peak RSS boundary | No jetsam; recorded peak | `.trace` export |
| Recovery | RSS returns toward baseline within 30 s | `.trace` export |
| Memory warnings | None during boundary case, or explicit handling without crash | `lane4-memory-warnings.txt` |

## Lane 5 — ZIP Stress Android (Lanes 1-2)

Run on the same device(s) as Lanes 1 and 2 after functional lanes pass.

Build and install:
```bash
flutter build apk --debug
adb -s <SERIAL> install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s <SERIAL> shell am start -n com.bariskode.metastrip/.MainActivity
```

Memory sampling during stress:
```bash
adb -s <SERIAL> shell "while true; do echo $(date '+%Y-%m-%d %H:%M:%S'); dumpsys meminfo com.bariskode.metastrip | rg TOTAL; sleep 2; done" > lane5-peak-rss.txt
```

| Check | Pass criteria | Evidence |
|---:|---|---|
| Z01 32 MiB minus 1 byte | Valid operation; output reparses; original unchanged | Output hash + parse |
| Z02 exactly 32 MiB | Valid operation; output reparses; original unchanged | Output hash + parse |
| Z03 32 MiB plus 1 byte | Fails closed; no output; original unchanged | Logcat + folder listing |
| Z04 malformed sizes | Explicit rejection | Logcat |
| Z05 high compression | Bounded decode stops; no crash/OOM | Logcat + memory |
| Z06 many entries | Deterministic limit behavior | Logcat |
| Z07 sequential batches | No unbounded RSS growth; no stale output | `lane5-peak-rss.txt` |
| Z08 cancellation | Coherent cancel; no partial output; retry works | Logcat |
| Z09 low-memory pressure | No crash/OOM; explicit failure if unable | Logcat + `MemFree` |
| Z10 malformed structure | Preflight/decode fails closed | Logcat |
| Peak RSS boundary | < 180 MB during Z02 | `lane5-peak-rss.txt` |
| Recovery | Within 10% of baseline within 30 s | `lane5-peak-rss.txt` timestamps |

## Lane 6 — ZIP Stress iOS Physical

Run on the same device as Lane 4 after functional lane passes.

Build and install:
```bash
flutter build ios --release
xcrun simctl install <DEVICE_UDID> build/ios/iphoneos/Runner.app
xcrun simctl launch <DEVICE_UDID> com.bariskode.metastrip
```

Memory trace:
```bash
xcrun xctrace record --device '<DEVICE NAME>' --time-limit 30m --template 'Allocations' --output lane6-allocations.trace
```

| Check | Pass criteria | Evidence |
|---:|---|---|
| Z01 32 MiB minus 1 byte | Valid operation; output reparses; original unchanged | Output hash + parse |
| Z02 exactly 32 MiB | Valid operation; output reparses; original unchanged | Output hash + parse |
| Z03 32 MiB plus 1 byte | Fails closed; no output; original unchanged | Log + folder listing |
| Z04 malformed sizes | Explicit rejection | Log |
| Z05 high compression | Bounded decode stops; no crash/OOM | Log + trace |
| Z06 many entries | Deterministic limit behavior | Log |
| Z07 sequential batches | No unbounded RSS growth; no stale output | `lane6-allocations.trace` |
| Z08 cancellation | Coherent cancel; no partial output; retry works | Log |
| Z09 low-memory pressure | No crash/OOM; explicit failure if unable | Log + memory warnings |
| Z10 malformed structure | Preflight/decode fails closed | Log |
| Peak RSS boundary | No jetsam; recorded peak | `.trace` export |
| Recovery | RSS returns toward baseline within 30 s | `.trace` export |
| Memory warnings | None during boundary case, or explicit handling without crash | `lane4-memory-warnings.txt` |

## Evidence Requirements

Per lane, retain:
- Timestamped logcat / Console / `.trace` exports
- Screenshots or screen recordings for each functional row
- Input/output SHA-256 checksums
- Output parse/reparse results
- Memory sample files with device state annotations
- Fixture manifest SHA-256 used for the run

Do not retain private metadata values in shared logs. Sanitize filenames and
paths before sharing.

## Run Record Template

| Lane | Operator | Build/commit | Device/UDID | Date | Result | Evidence path | Issues |
|---|---|---|---|---|---|---|---|
| L1 Samsung / Android 8.1 |  |  | 3201fbb0c40a1615 |  |  |  |  |
| L2 Modern Android |  |  |  |  |  |  |  |
| L3 iOS simulator |  |  |  |  |  |  |  |
| L4 iOS physical |  |  |  |  |  |  |  |
| L5 ZIP stress Android |  |  |  |  |  |  |  |
| L6 ZIP stress iOS |  |  |  |  |  |  |  |

Update this record from observed runs only. Do not infer a pass from host
tests, successful compilation, simulator-only execution, or absence of a
reported failure.
