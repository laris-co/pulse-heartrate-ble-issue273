# No–Virtual Run prototype

Requested by Nat; implementation by Oracle AI. This is a development experiment,
with a passed physical iPad live-reception gate and the scope limits below.

## Latest result

After the dictionary-construction fix and hash-verified watch install, the exact
`Forerunner 245 Music (2)` target passed the physical iPad test on 2026-09-29:
at least ten accepted positive nonce-bound Connect IQ responses, latest status
Live at the count gate, then disconnect clearing count to zero and status away
from Live. The test used normal polling, not the queued or listen-only probes.
Result: `.evidence/ciq-ipad-fixed-watch-live.xcresult` (one passed, no failures),
with runner configuration `PulseFixedWatch.xctestrun` preserved in the device
build products. No real BPM values were exported. The watch was running our
foreground Pulse Link app; no Virtual Run activity was needed.

This does not prove iPhone reception, background/all-day operation, ten distinct
physiological samples, or general iPad compatibility. The normal visual app is
separate from the privacy-test screen, which deliberately hides BPM and charts.

## Route

A foreground **Pulse Link** Connect IQ watch app reads the watch's configured
heart-rate source without changing sensor pairing. The native **Pulse** companion requests small messages over Garmin's
Connect IQ Bluetooth connection. Garmin Connect authorizes device selection;
it does not need to relay each reading or remain foreground.

- Watch app ID: `32f2d775123041a7ac0c38e3a3f4551b`.
- Initial target: `fr245m` (Forerunner 245 Music).
- iOS companion: existing `co.laris.PulseLive`, callback `pulselive-ciq`.
- Official iOS SDK revision: `f0d29ff691d700a132d86205ed9bb091e336c2f7`.
- Existing standard-BLE/Virtual Run path remains available, but only one source
  may feed a session. The diagnostic app and companion pairing stay unchanged.
- iPad is an experimental route, not promised official Garmin compatibility.
  Switching the watch's pairing to another device requires a separate decision.

## Message contract

Phone request, at most one pending, every two seconds:

```json
{"v":1,"type":"request","nonce":"random-request-UUID"}
```

Watch response:

```json
{"v":1,"type":"pulse","nonce":"same-request-UUID","bpm":72,"ageMs":100}
```

The example value is synthetic. The watch reports zero if no fresh positive
sensor value exists. The phone checks exact selected device/app, schema, integer
values, matching unused nonce, request expiry, and sensor age. Late, duplicate,
malformed and unrelated replies cannot become a new live reading. Measurement
time is conservatively anchored to request time minus reported sensor age, not
blindly to message arrival. No health values should appear in test logs.

## Boundaries

Foreground-only. Opening the custom watch app is still necessary; this is not an
all-day watch-face background service. No activity timer, GPS, FIT recording,
cloud, account creation, session files, notifications, store publication or
external upload is part of this prototype. Data is held in memory only and is
cleared on leaving/disconnecting. Only a five-minute, one-use authorization
timestamp persists, to recover a legitimate Garmin callback after process
relaunch; it contains no device identifier or health values. Do not change the
user's Garmin pairing.

Garmin's proprietary SDK remains a pinned external dependency; do not copy its
binaries into this repository. SDK downloads, device logs and developer keys
stay outside tracked source. Any SDK license-acceptance dialog is a user gate.

## Verification gates

1. Foundation protocol tests: schema/range/types, expiry, nonce mismatch, replay,
   unavailable value, conservative freshness timestamp.
2. Existing signal/parser regression tests and native iOS build/UI smoke.
3. Watch compiler and simulator checks for the exact device target.
4. Signed native install and one-time Garmin Connect device authorization.
5. Confirm the exact Pulse Link app is installed, open it, receive ten **real**
   callbacks with no health values exported; then verify disconnect/clear.

A simulator test, compiled `.prg`, or successful GCM handoff is not gate 5.

## Current evidence — 2026-09-29

- Foundation tests: 24 passed; final simulator UI suite: five passed and three
  physical-only cases skipped on each of the iPhone and iPad simulators.
- Simulator build/static analysis and signed iPad build succeeded.
- Connect IQ 9.2.0 compiled a signed release for exact target `fr245m` with no
  warnings. It launched in the Forerunner 245 Music simulator without a runtime
  error (synthetic/simulator evidence only).
- The 9,164-byte PRG was copied to the physical watch's `GARMIN/APPS/PulseLink.prg`
  using user-approved OpenMTP. Read-back SHA-256 matched the build:
  `12553d48567e12f909fe994b691afea733d30eb12a751299db47ca700a1d72c0`.
- The user found Pulse Link on the watch. After unlocking the iPad, Garmin Connect
  authorization returned two saved watch entries. The test then selected only
  the exact `Forerunner 245 Music (2)` name matching the USB-connected watch,
  verified that selected name, and reached the SDK's installed-app ready state.
- The exact-target test sent the open-app request but timed out after 90 seconds
  waiting for `Live`; the observed status remained `Waiting for pulse`. Therefore
  connection/installed-app checks passed, but **ten-reading reception is not yet
  proven**. No re-pairing or firmware changes were performed.
- The user subsequently confirmed that the watch displays a BPM but reports
  `Waiting for phone`. Sanitized iPad diagnostics show SDK send success and
  timeout/unavailable, with no incoming callback. A one-request non-transient
  probe (without reopening the already-open watch app) also showed send success
  and no incoming callback within ten seconds. It is a diagnostic skip, not a
  passed ten-response test. The user then reported the exact watch status
  `Send failed`: the watch accepted a request, but its response transmission
  failed. That observation followed test teardown, so it cannot distinguish an
  immediate return failure from losing the receiver after ten seconds.
- A follow-up kept the iPad foreground and registered for 90 seconds. SDK send
  again succeeded, but no receive callback or post-send suspension occurred.
  During this run the user reported `Waiting for phone` and later confirmed
  reopening Pulse Link between observations; this resets its status. No timely
  round-trip delivery is proven. The test was explicitly skipped as a live
  proof; Pulse was no longer running after the test runner completed.
- After the user confirmed Pulse Link was open again, another single-request
  90-second test had no iPad callback. The watch then showed an IQ icon with a
  red warning, suggesting a runtime crash. Crash-log retrieval is the next
  diagnostic gate; transport conclusions are provisional until that is checked.
  The user connected USB, but macOS had not yet enumerated the Garmin when
  checked. The user subsequently pressed BACK once and returned to the watch
  face, confirming that the device is responsive; no force restart was needed.
  The earlier USB check produced a false negative because its registry query
  omitted device properties. `ioreg -r -c IOUSBHostDevice -a` detected the Garmin
  vendor/product entry, and refreshing OpenMTP connected successfully.
  Only `GARMIN/APPS/LOGS/CIQ_LOG.BAK` was copied; no activity files were read.

The installed request-only source was reconstructed under the ignored
`.evidence/ciq-original-symbols/` directory. Its rebuilt PRG matches the
installed SHA-256 byte for byte, so
`.evidence/ciq-original-symbols/build/PulseLink.prg.debug.xml` is an exact map
for the pending crash log. The final diagnostic-source checks again passed:
24 Foundation tests, ten simulator UI tests (six hardware-only skips), simulator
build/static analysis, and signed iPad build. These do not resolve the physical
watch crash or prove live reception.

The corrected watch build includes a user-triggered START-button test
that transmits only the fixed public string `pulse-link-watch-test`, plus a
non-health callback count. The original installed artifact remains preserved
as `watch/build/PulseLink-request-only-12553d48.prg`. A matching iPad
`--ciq-listen-only-probe` mode registers for replies but sends no requests;
`link_test_callback` is emitted only for that literal after the exact app/device
and active-registration checks. The link-test feature alone is not live-HR proof. The original crash log was
captured before replacement.

### Confirmed watch crash

The 259-byte log identifies Pulse Link and `Unexpected Type Error` /
`Failed invoking <symbol>` at PC `0x100003be`, timestamp
`2026-09-29T12:52:17Z`, on firmware 13.00. The exact rebuilt symbol map places
this PC at the first `response.put("v", 1)` invocation (original source line
116), before `Communications.transmit`. Both the Dictionary constructor and
`put` are public APIs; the log does not prove the constructor is illegal.
The minimal avoidance is a complete dictionary literal, removing the
constructor-plus-five-mutations code shape. Three exact-`fr245m` Toybox contract
tests passed (fresh, unavailable, nonce preservation); the signed release built
and displayed in the simulator. Simulator message injection did not exercise
the callback, so it is not a hardware-equivalent reproduction.

The corrected 10,028-byte PRG was installed in `GARMIN/APPS/PulseLink.prg`. A
device-side copy back to `~/tmp/PulseLink-fix-20260929/readback/PulseLink.prg`
matched the build byte for byte, SHA-256
`bbb8aa8133961cb20ee973569904ce2563202926cae4e853895e6517ad35a287`.
OpenMTP was closed after verification. The user opened the watch app and the
physical live-reception/disconnect regression then passed, as recorded above.

DEBUG builds can show at most eight recent transport event lines in the existing
privacy-test screen, with a process-wide 100-event cap. Logging requires
`--privacy-safe-hardware-test`; normal launches do not log. Events contain only
fixed names, status enums and match/availability booleans, never BPM, sensor age,
payload values, nonces or identifiers. The additional
`--ciq-single-queued-probe` switch sends at most one total non-transient request
in that process; normal request behavior remains transient. No diagnostics or
readings are persisted by the app. The follow-up probe observes for 90 seconds
with the receiver foreground; it still expires requests after three seconds and
never counts a late response as live. Lifecycle diagnostics contain only fixed
event names, connection-state enums, and a selection-cleared boolean.

The opt-in test accepts `PULSE_CIQ_EXPECTED_WATCH_NAME` in the test runner's
environment for evidence-backed, unique exact-name selection. Otherwise multiple
matches require manual choice. A future live-test pass proves ten positive,
nonce-bound accepted CIQ responses and a Live reading at the count gate, not ten
distinct physiological samples. Keep the generated ignored `.xctestrun` alongside
the result bundle for reproducibility.

## Official references

- [Connect IQ SDK and developer agreement](https://developer.garmin.com/connect-iq/sdk/)
- [Garmin iOS companion SDK](https://github.com/garmin/connectiq-companion-app-sdk-ios)
- [Watch sensor data](https://developer.garmin.com/connect-iq/api-docs/Toybox/Sensor/Info.html)
- [Watch communications](https://developer.garmin.com/connect-iq/api-docs/Toybox/Communications.html)
