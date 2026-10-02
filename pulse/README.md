# Pulse

A separate, pulse-only native app for iPhone and iPad, built by Oracle AI.
Bundle ID: `co.laris.PulseLive`. It installs alongside **Pulse HR Diagnostic**;
no existing Garmin companion pairing is changed.

Current results and remaining gaps: [VERIFICATION.md](VERIFICATION.md).

## Connect

### Pulse Link — no Virtual Run (development prototype)

1. Install the signed `fr245m` build from [`../watch`](../watch/README.md) in the
   watch's `GARMIN/APPS` directory, then disconnect USB and open **Pulse Link**.
2. On the Apple device already paired to the watch, open **Pulse → Choose watch →
   Authorize a Garmin watch**. Garmin Connect provides the device authorization.
3. Return to Pulse, select the authorized Forerunner, and choose **Open Pulse Link
   on watch** if needed. Confirm that request on the watch.

Both apps must stay foreground for this prototype. No activity timer or recording
is started. This iPad / Forerunner 245 Music pair passed ten live-response and
disconnect checks; iPhone Connect IQ reception is not yet physically verified.
iPad support remains experimental. See [verification](VERIFICATION.md).

### Alternative: standard Bluetooth heart-rate sensor

1. On the Forerunner 245 Music, open **START → Virtual Run** and leave its
   compatible-app pairing screen open. Starting the workout timer is unnecessary.
2. Open **Pulse → Choose watch → Scan for sensors** and allow Pulse's Bluetooth
   permission if requested.
3. Select your broadcasting watch. Fresh positive BPM readings animate the
   sculpture and populate the last-minute chart.

Keep Pulse in the foreground. Leaving the app disconnects and clears its readings.
To reconnect, choose and scan again. This is a standard BLE heart-rate sensor
connection, not replacement Garmin Connect onboarding.

## What you see

- A real 3D cartoon heart with studio lighting, nonuniform beating, and drag-to-
  rotate interaction. Its cadence follows fresh reported BPM approximately, not
  an ECG or individually detected heartbeat timings.
- Tap the expand icon beside the heart for a full-screen heart and BPM stage.
  Close returns to the existing real-time 60-second pulse trend.
- Current BPM, freshness, and up to 60 readings from the last 60 seconds.
- Low/high for the visible window. Missing/invalid periods remain graph gaps.
- A reading older than five seconds is not displayed as live.
- Pause freezes only the heart; readings continue. Reduce Motion, stale/missing
  data, privacy-safe mode, offscreen and inactive scenes stop autonomous motion.
- Native watch/details sheets, Dark Mode, Dynamic Type, and iPad landscape layout.

No notifications, account, uploads, saved sessions, CSV, medical scoring, or game
rewards. Real readings are held only in memory. The reused BLE manager and parser
remain in `../ios/Sources`; the diagnostic app is unchanged.

## Build and test

Requires Xcode with iOS 17+ SDK support and XcodeGen. The official Garmin ConnectIQ
package is pinned to revision `f0d29ff691d700a132d86205ed9bb091e336c2f7`.

```sh
cd pulse
swift test
xcodegen generate
xcodebuild -project Pulse.xcodeproj -scheme Pulse \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build-for-testing
# Run on an available simulator:
xcodebuild -project Pulse.xcodeproj -scheme Pulse \
  -destination 'platform=iOS Simulator,id=<simulator-UUID>' \
  CODE_SIGNING_ALLOWED=NO test
```

For device signing, use your own `DEVELOPMENT_TEAM`; never commit profiles/keys.

Explicit developer launch arguments:
- `--demo`: clearly labeled authored synthetic data; never a fallback for BLE.
- `--demo-stale`: synthetic stale-signal UI regression case.
- `--privacy-safe-hardware-test`: hides BPM/chart/details, exposing only status
  and accepted callback count for hardware verification.

The real-device UI test is skipped unless compiled with
`PULSE_ALLOW_REAL_GARMIN_CONNECTION`. It selects only a unique advertised
Forerunner/FR245 heart-rate sensor, checks ten positive callbacks, then disconnects
and verifies clearing. Name/service matching is not device authentication.
Hardware proof and simulator proof must be reported separately.

The separate `testReceiveTenConnectIQMeasurementsWithoutVirtualRun` case requires
`PULSE_ALLOW_CONNECTIQ_CONNECTION`. It allows a bounded manual Garmin Connect
authorization, selects only one uniquely matching authorized watch, checks the
installed Pulse Link app, ten accepted positive responses, a fresh Live reading
at that count gate, and disconnect clearing. It never
uses the BLE scan route. The only persistent app metadata is a one-use, five-minute
authorization timestamp; device identifiers and heart-rate readings are not saved.

When multiple entries exist, the test waits for a manual choice unless its runner
environment pins `PULSE_CIQ_EXPECTED_WATCH_NAME` to an independently identified
exact name. `testOpenPulseLinkForManualUse` is a separate opt-in setup smoke that
leaves the normal app open; it is not a live-heart-rate proof.

## Rendering maintenance

The heart uses built-in SceneKit behind a narrow SwiftUI wrapper, with no new
third-party dependency. The app targets iOS 17+. SceneKit is deprecated in the
current iOS 26 SDK, so a future renderer migration may be needed. The requested
30fps cap is not a battery or sustained frame-rate guarantee. No anatomical
model, ECG, or beat-to-beat measurement is inferred from the Garmin BPM stream.
