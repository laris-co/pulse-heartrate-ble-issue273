# Pulse test build — 2026-09-29

Built and verified by Oracle AI. This records the **new `co.laris.PulseLive` app**,
not the earlier diagnostic app's hardware result.

## iPad / iPhone 3D heart update

The central ribbons are replaced with an actual closed 3D cartoon-heart mesh,
not a flat asset. The existing live BPM, 60-second trend, transport, and pairing
are preserved. The immersive stage shares the same store and pause control.

Fresh evidence under `.evidence/ios-heart/`:
- **30 Foundation tests passed**, including six mesh/topology/deformation tests
  (`foundation-current.log`).
- **12 runnable iPad UI tests passed**, with three intentional hardware-gated
  skips (`ipad-motion.xcresult`): fresh/stale/privacy, connection routes, expanded
  stage, shared pause, pixel changes during beating, pixel stability while
  paused, drag rotation, largest Dynamic Type, and dashboard landscape.
- iPhone: the four initial heart UI cases passed (`iphone-final.xcresult`), and
  all **three interaction/large-text tests passed** (`iphone-motion.xcresult`).
- Final demo-truth correction: **two targeted tests per device passed**
  (`ipad-reviewed.xcresult`, `iphone-reviewed.xcresult`), including the explicit
  “Sample signal” assertion and unchanged stale-state handling.
- Signed device build and simulator build passed. **Xcode static analysis passed**
  (`static-analysis.log`); Swift parsing, JSON/plist validation and whitespace
  checks passed. No standalone SwiftLint tool/configuration is present.
- The compiled simulator and device assets both verify opaque `PulseHeart`
  colors. A bug where integer-form alpha `"1"` compiled as 1/255 was corrected
  to normalized `"1.000"`; both light/dark renders were recaptured.
- **Physical iPad live regression passed:** ten accepted positive Connect IQ
  responses, fresh Live status, and disconnect clearing
  (`ipad-live-heart.xcresult`, one test, zero failures). Evidence records only
  callback count, not physiological values. The only subsequent product change
  replaced the synthetic fullscreen “Live” label with “Sample signal”; transport,
  animation, real-device labels and reading logic were unchanged.

The final signed, demo-label-corrected build was installed and launched on the
physical iPad. `ipad-final-handoff.xcresult` passed the normal-app exact-watch
setup and left Pulse foreground; it is a setup check, not a second live-count proof.
The Garmin pairing and physical watch binary were not changed.

### Scoped visual verdict

A fresh designer substituted for the unavailable Impeccable finish-reviewer.
The final verdict is **ship for its three scored fixes**: unambiguous demo status,
updated design persistence, and the required recaptures/test evidence. It is not
an unqualified whole-app approval or a claim of measured hardware frame rate.
The writer role was blocked by the thread limit, so documentation was merged
inline and checked by the independent designer. Authoritative synthetic captures:
`.impeccable/review/ios-heart/ipad-fullscreen.png` and
`iphone-fullscreen-dark.png`. No new raster asset was introduced by the iOS heart.

Hardware battery use, sustained rendering performance, VoiceOver traversal and
system Reduce Motion toggling are not measured by these tests. Reduce Motion and
lifecycle gates were code-reviewed; geometry beating/pause/drag were dynamically
verified. SceneKit is built-in but deprecated in the current SDK. The new Garmin
clock skin remains **simulator-only**, per the user's request; this test uses the
previous proven physical Pulse Link build.

## Original pre-heart baseline


- Signal model and Connect IQ protocol/authorization: **24 tests** (freshness,
  missing/zero, bounds, reset, count, gaps, schema, nonce, expiry and relaunch).
- Reused BLE parser: **8 tests**.
- Watch response contract on exact `fr245m`: **3 tests**.
- Final simulator UI suite: **10 passed**, five each on iPhone and iPad. **6 real-
  hardware executions were intentionally skipped** (three per simulator).
- Simulator build-for-testing and Xcode static analysis succeeded.
- Signed physical-device build succeeded.
- The earlier BLE-only Pulse build installed and launched on iPad and iPhone.
  The corrected Connect IQ build passed the physical iPad test: exact-watch
  authorization/readiness, at least ten accepted positive nonce-bound responses,
  a fresh Live reading at the count gate, and disconnect clearing to zero/non-Live.
  Result: `.evidence/ciq-ipad-fixed-watch-live.xcresult`, one test passed with no
  failures. This is new Pulse hardware proof, not the older diagnostic result.
- Fresh iPad Bluetooth permission acceptance and active scanning worked.
- Swift syntax parsing, plist validation, and `git diff --check` passed.
- All five generated design/icon rasters carry prompt provenance.

Simulator UI tests cover empty state, explicit synthetic demo/details, stale
redaction, standard-size action visibility, and iPad landscape layout activation.
Demo screenshots contain only authored synthetic values, not real health data.
Xcode warned only that App Intents metadata was skipped because no AppIntents
framework is used. No standalone SwiftLint configuration/tool is present.

## Hardware scope and remaining gaps

The foreground **Pulse Link** Connect IQ route now works on this physical iPad /
Forerunner 245 Music pair with the custom watch app open—no Virtual Run activity
is used. The initial watch failure was traced using its captured crash log and
an exact symbol map to the first response Dictionary mutation. The literal-based
packet builder passed three watch contract tests, was installed with a matching
read-back SHA-256, and then passed the live reception/disconnect regression.
See [the complete prototype evidence](../docs/connect-iq-prototype.md).

This proves accepted responses, not ten distinct physiological samples, sustained
background operation, or general iPad compatibility. The Connect IQ route has
not yet been physically verified on iPhone. Both custom apps must stay foreground.

The alternative standard-BLE test in this new app previously found no compatible
broadcasting sensor. Earlier BLE success belongs to the older diagnostic app and
is not relabelled as a new Pulse BLE pass. That alternative still needs its own
physical regression. Pairing alone does not provide an all-day/background stream.

## Historical ribbon visual finish status

This is retained historical evidence, not the new heart verdict above. The user
explicitly replaced only the central ribbon shape; the old reference gate was
not forced or recategorized as a pass.

Phone, iPad portrait, Dark Mode and accessibility-text-size simulator captures
exist under `.impeccable/review`. The first independent reviewer required a
sculpture rebuild and tighter phone composition. Those changes were implemented;
a subsequent regression correction fixed clipping and chart endpoint labels.

The automated reference comparison remains **67.3%**, below its 72% hero gate.
The gate was **not forced**. The native app's chrome and composition differ from
the generated reference, and ribbon intersections still need visual refinement.
The workflow's responsive script expects web desktop/mobile captures, so native
captures were not renamed or fabricated to bypass it. This is an installed test
build, **not a claim of completed visual sign-off**.

## Scope preserved

`ios/` and `android/` remain unchanged. The new app has no notification access,
account, cloud-upload client, saved health data, session export, scoring or game rewards.
Only a short-lived authorization timestamp persists for Garmin callback recovery.
Real readings remain in memory and clear when inactive/disconnected. The user’s
Garmin companion pairing was not changed. Device logs/profiles/results remain in
ignored `.evidence/`, outside version control.
