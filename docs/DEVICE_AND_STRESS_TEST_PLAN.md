# Device and Stress Test Plan

**Owner:** Release verification owner (assign before execution)
**Status:** Scheduled; no lane is complete
**Target milestone:** Phase 8 device validation and release hardening
**Scope:** Platform picker/output flows and ZIP-family 32 MiB in-memory repack boundary

This plan records executable release-hardening work. A checked test row requires
captured evidence; host unit/widget tests alone do not complete any device lane.
Do not change the registered Viewer or Remover support sets based on this plan.

## 1. Execution Schedule

Run lanes in this order. Record the operator, build identifier, OS/device,
fixture manifest revision, start/end status, and evidence location for each run.

| Order | Lane | Owner | Status | Target milestone | Entry gate |
|---:|---|---|---|---|---|
| 1 | Samsung SM M205G, Android 8.1, serial `3201fbb0c40a1615` | Assign release verifier | Scheduled | Phase 8 device validation | Debug APK and fixture set available |
| 2 | Modern Android physical device, current supported API target | Assign release verifier | Scheduled | Phase 8 device validation | Lane 1 findings triaged |
| 3 | iOS simulator on a supported runtime | Assign iOS verifier | Scheduled | Phase 8 device validation | iOS debug build available |
| 4 | iOS physical device on a supported iOS version | Assign iOS verifier | Scheduled | Release hardening | Signing/profile and Files access available |
| 5 | ZIP/OpenXML/ODF memory boundary suite on Android lanes 1-2 | Assign performance verifier | Scheduled | Release hardening | Device functional lane passes |
| 6 | ZIP/OpenXML/ODF memory boundary suite on iOS physical device | Assign performance verifier | Scheduled | Release hardening | Physical iOS functional lane passes |

The iOS simulator lane validates app flow and sandbox/file-provider behavior
available to the simulator. It does not substitute for the physical iOS lane,
which is required for real Files providers, lifecycle pressure, and device
memory observations. SAF-specific assertions apply only to Android.

## 2. Build and Evidence Setup

1. Record `git rev-parse HEAD`, `flutter --version`, and the fixture manifest
   checksum in the run record.
2. Run the latest host verification and record actual output; do not copy the
   documentation snapshot as test evidence.
3. Build/install without changing production format declarations:

```bash
flutter analyze
flutter test
flutter build apk --debug
adb -s 3201fbb0c40a1615 install -r build/app/outputs/flutter-apk/app-debug.apk
flutter run -d 3201fbb0c40a1615
```

4. For each case, retain sanitized logs, input/output hashes, output reparse
   results, screenshots where useful, and memory samples. Never retain private
   metadata values in shared logs.
5. Evidence location: `<fill: test run artifact path or CI URL>`.
6. Fixture manifest: `<fill: version/path and SHA-256>`.

## 3. Device Functional Matrix

Run every applicable row on both Android physical lanes and both iOS lanes.
Mark SAF-only rows N/A on iOS with a reason; do not mark them passed.

| ID | Scenario | Procedure | Required result |
|---|---|---|---|
| D01 | Picker | Open Viewer and Remover pickers; select supported PNG/PDF fixtures and reject/cancel once | Selection/cancel returns cleanly; no phantom queue item or output |
| D02 | Output grant | Android: choose an SAF tree. iOS: choose/confirm an available output location | Grant persists for the session and write errors are explicit |
| D03 | Reopen output | Open each generated clean copy from the platform file UI and a compatible external viewer | Output exists, is readable, and resolves from the selected location |
| D04 | Original preservation | Hash inputs before and after successful and failed operations | Original path, bytes, size, and hash are unchanged |
| D05 | PNG selective | Select one or more tEXt/iTXt fields in Viewer, send to Remover, process, and re-extract output | Requested text fields are absent within verified PNG scope; report lists removed IDs and validates output; record unselected-field observations without generalizing preservation |
| D06 | PDF selective | Select one or more DocInfo fields, process, and inspect result | Operation is labeled best-effort attempted/unverified; no removed-field or structural-validation claim appears |
| D07 | Full cleanup | Run supported cleanup for representative registered formats, including PNG, PDF, one audio, one OpenXML, and one ODF fixture | Clean copy is produced or explicit failure occurs; PDF limitation remains visible |
| D08 | Cancel | Cancel during a multi-file batch and during a ZIP-family operation | Queue reaches a coherent canceled state; no partial installed output; originals unchanged |
| D09 | Retry | Retry after picker denial, revoked/invalid output access, malformed input, and cancellation | Recovery is possible without app restart where designed; rejected attempts leave no output |
| D10 | Output collision | Repeat the same successful operation into one folder | Collision-safe names are used; existing output and original are unchanged |
| D11 | App lifecycle | Background/foreground during picker, processing, and result viewing | No crash or corrupt output; interrupted work resolves explicitly |
| D12 | Low storage/access | Exercise write denial or constrained storage using platform-supported controls | Explicit failure, no partial installed output, originals unchanged |

## 4. ZIP Memory Stress Matrix

The aggregate boundary is **32 MiB (33,554,432 bytes) of cumulative
decompressed content** for the in-memory repack path. Generate equivalent
fixtures for generic ZIP parsing where applicable, OpenXML (`docx`, `xlsx`,
`pptx`), and ODF (`odt`, `ods`, `odp`). Generic ZIP remains Viewer-only; this
suite does not enable ZIP removal.

Use exact aggregate payload targets and record archive size, declared aggregate,
actual aggregate, entry count, compression ratio, and expected route.

| ID | Corpus | Aggregate decompressed content | Required result |
|---|---|---:|---|
| Z01 | Valid ZIP/OpenXML/ODF | 32 MiB minus 1 byte | Valid supported operations complete; outputs reparse and originals remain unchanged |
| Z02 | Valid ZIP/OpenXML/ODF | Exactly 32 MiB | Valid supported operations complete; outputs reparse and originals remain unchanged |
| Z03 | Valid ZIP/OpenXML/ODF | 32 MiB plus 1 byte | Repack-required operation fails closed; no output is installed; original remains unchanged |
| Z04 | Malformed declared sizes | Below/at/above boundary combinations with understated and overstated central/local sizes | Declared/actual mismatch is rejected explicitly without crash or output |
| Z05 | High compression ratio | Small archive with actual expansion below, at, and above 32 MiB | Bounded decode stops above limit; no crash/OOM or rejected output |
| Z06 | Many entries | Aggregate below/at/above boundary near the configured entry-count guard | Limit behavior is deterministic; accepted output reparses; rejected case writes no output |
| Z07 | Sequential batches | Repeat `<fill: batch count>` batches of mixed ZIP/OpenXML/ODF boundary fixtures | No unbounded RSS growth, crash, OOM, stale output, or original mutation |
| Z08 | Cancellation | Cancel before decode, during a long batch, and before output installation | Cancellation is coherent; no partial installed output; subsequent retry works |
| Z09 | Low-memory behavior | Apply platform memory pressure while processing at/near boundary | No crash/OOM; operation completes or fails explicitly with no rejected output |
| Z10 | Malformed structure | ZIP64, multi-disk, encrypted, duplicate/traversal path, bad descriptor/CRC, unsupported compression | Preflight/decode fails closed; no output; original unchanged |

For accepted OpenXML/ODF outputs, reparse the package and verify required
package relationships/content types or ODF first stored `mimetype` constraints.
Do not describe generic ZIP Viewer parsing as ZIP metadata removal.

## 5. Peak RSS Measurement

Use a consistent sampling interval and include idle baseline, pre-operation,
peak operation, post-operation, and post-batch recovery samples.

### Android — Samsung SM M205G / Android 8.1

Target thresholds for this device:
- Baseline RSS: < 80 MB
- Peak RSS for boundary case: < 180 MB
- Recovery: < 10% from baseline within 30 seconds

1. Package/process lookup command:
   ```bash
   adb -s 3201fbb0c40a1615 shell pidof com.bariskode.metastrip
   ```
   Fallback:
   ```bash
   adb -s 3201fbb0c40a1615 shell ps -A | rg metastrip
   ```

2. Primary RSS command/tool:
   ```bash
   adb -s 3201fbb0c40a1615 shell dumpsys meminfo com.bariskode.metastrip
   ```
   Sample the `TOTAL` PSS/RSS values. For a lighter single-PID view:
   ```bash
   adb -s 3201fbb0c40a1615 shell procrank | rg metastrip
   ```
   If Perfetto profiling is desired, use:
   ```bash
   adb -s 3201fbb0c40a1615 perfetto --out /data/local/tmp/metastrip.perfetto -t 30s -b 64k \
     -o memory_config.pb
   adb -s 3201fbb0c40a1615 pull /data/local/tmp/metastrip.perfetto .
   ```
   On Android 8.1 the shell `dumpsys meminfo` path is the most reliable.

3. Sampling interval and automation command:
   ```bash
   adb -s 3201fbb0c40a1615 shell "while true; do dumpsys meminfo com.bariskode.metastrip | rg TOTAL; sleep 2; done"
   ```
   Redirect to a timestamped file:
   ```bash
   adb -s 3201fbb0c40a1615 shell "while true; do echo $(date '+%Y-%m-%d %H:%M:%S'); dumpsys meminfo com.bariskode.metastrip | rg TOTAL; sleep 2; done" > peak-rss-samsung-m205g.txt
   ```

4. Capture native heap, Dart heap where available, total PSS/RSS, device free
   memory, and process death/LMK evidence.
   - Native heap: `Native Heap` row from `dumpsys meminfo`.
   - Dart heap: not directly exposed on Android 8.1; infer from `TOTAL` minus
     native + graphics + stack when needed.
   - Total PSS/RSS: use `TOTAL` line from `dumpsys meminfo`.
   - Device free memory:
     ```bash
     adb -s 3201fbb0c40a1615 shell cat /proc/meminfo | rg MemFree\|Buffers\|Cached
     ```
   - Process death/LMK evidence:
     ```bash
     adb -s 3201fbb0c40a1615 logcat -d -s ActivityManager:V
     ```
     Look for `low_memory`, `kill`, or `OOM` messages against the app PID.

### iOS

1. Simulator method:
   ```bash
   xcrun simctl spawn booted log stream --predicate 'subsystem == "com.apple.memory"'
   ```
   Instruments template: Xcode > Open Developer Tool > Instruments > Allocations.
   Choose the MetaStrip process and enable "Record reference counts".

2. Physical-device method:
   Xcode > Product > Profile > Instruments > Allocations / VM Tracker. Attach
   to MetaStrip on the connected device. Enable "Mark Heap" before each batch.

3. Sampling interval/export procedure:
   - Instruments: set sample interval to 1000 ms.
   - Export: after each run, choose File > Export and save `.trace` plus CSV.
   - For CLI capture on a connected device:
     ```bash
     xcrun xctrace record --device '<device name>' --time-limit 30m --template 'Allocations' --output metastrip-allocations.trace
     ```

4. Capture footprint/RSS, allocation peak, memory warning events, jetsam/device
   termination evidence, and post-batch recovery.
   - Footprint/RSS: Xcode Debug Navigator during run or `memory_pressure` log
     stream.
   - Memory warning events:
     ```bash
     xcrun simctl spawn booted log stream --predicate 'eventMessage contains "memory warning"'
     ```
     or physical device Console.app filter `memory warning`.
   - Jetsam/device termination: `log show --predicate 'eventMessage contains "jetsam"'`.
   - Post-batch recovery: record RSS at 5-second intervals for 30 seconds after
     the final batch finishes.

Measurement placeholders must be resolved and trialed before the stress lane is
marked In progress. Record tooling versions with results.

### Run Record Template

| Lane | Operator | Build/commit | Device | Date | Result | Peak RSS evidence | Functional evidence | Issues |
|---|---|---|---|---|---|---|---|---|
| Samsung SM M205G / Android 8.1 |  |  | 3201fbb0c40a1615 |  |  | `<fill: path to peak-rss-*.txt or trace>` | `<fill: path to logs/screenshots>` |  |
| Modern Android physical |  |  |  |  |  |  |  |  |
| iOS simulator |  |  |  |  |  |  |  |  |
| iOS physical |  |  |  |  |  |  |  |  |

### Fixture Manifest Template

Store one manifest per run. Reuse the same manifest revision across lanes
unless fixtures change.

```
fixture_manifest_version: 1
generated_at: YYYY-MM-DDTHH:MM:SSZ
generator: scripts/generate_device_fixtures.py
git_commit: <git rev-parse HEAD>
fixtures:
  - name: png_text_selective_01.png
    path: test/fixtures/png_text_selective_01.png
    sha256: <sha256>
    size_bytes: <int>
    extensions:
      - png
    scenario: D06 PNG selective
  - name: pdf_docinfo_selective_01.pdf
    path: test/fixtures/pdf_docinfo_selective_01.pdf
    sha256: <sha256>
    size_bytes: <int>
    extensions:
      - pdf
    scenario: D07 full cleanup
  - name: zip_openxml_32mb_docx.zip
    path: test/fixtures/zip_openxml_32mb_docx.zip
    sha256: <sha256>
    size_bytes: <int>
    extensions:
      - zip
      - docx
    scenario: Z02 boundary
  # Add remaining fixtures here
manifest_sha256: <sha256 of this file>
```

Update this manifest and record its checksum in the run record before executing
any lane.

## 6. Pass/Fail Thresholds

A lane passes only when all applicable functional rows and stress cases meet
these thresholds:

- No app crash, process death, OOM, or unhandled exception.
- Aggregate decompressed content above 32 MiB fails closed before output
  installation.
- Rejected, malformed, canceled, or over-limit operations leave no new output
  and no partial output in the selected destination.
- Original files remain byte-for-byte unchanged in every success and failure
  path.
- Valid ZIP-backed outputs at or under 32 MiB reparse and satisfy their
  OpenXML/ODF structural constraints.
- Picker grants, output writing, reopening, cancellation, and retry match the
  functional matrix without silent fallback.
- Peak RSS is recorded for every boundary and sequential-batch case. Numeric
  RSS ceilings:
  - Baseline RSS: < 80 MB
  - Peak RSS (boundary case): < 180 MB
  - Recovery: RSS returns to within 10% of post-warmup baseline within 30
    seconds after the final batch.
- Sequential batches return to within 10% of post-warmup baseline within 30
  seconds after the final batch.

Any failure blocks the corresponding device/stress gate. Triage it as product,
fixture, or harness failure, link the issue, and rerun the affected row plus its
adjacent boundary rows.

## 7. Run Record

| Lane | Operator | Build/commit | Result | Peak RSS evidence | Functional evidence | Issues |
|---|---|---|---|---|---|---|
| Samsung SM M205G / Android 8.1 | Unassigned | Pending | Scheduled | Pending | Pending | None recorded |
| Modern Android physical | Unassigned | Pending | Scheduled | Pending | Pending | None recorded |
| iOS simulator | Unassigned | Pending | Scheduled | Pending | Pending | None recorded |
| iOS physical | Unassigned | Pending | Scheduled | Pending | Pending | None recorded |

Update this table from observed runs only. Do not infer a pass from host tests,
successful compilation, simulator-only execution, or absence of a reported
failure.
