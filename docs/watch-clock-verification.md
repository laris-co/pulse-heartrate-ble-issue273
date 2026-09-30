# Pulse Link cartoon-heart clock — simulator verification

Date: 2026-09-29. Scope: the existing `fr245m` foreground watch-app only. The user selected **keep testing in simulator first**. This build has **not been installed on the physical watch**; its existing app and iPad pairing were left unchanged.

## Requested experience

- Local time (honoring the device's 12/24-hour preference) and abbreviated date.
- A rounded cartoon heart with pre-rendered 3D shading, replacing the initial anatomical illustration at the user's request.
- Fresh local BPM next to the heart; `--` and a resting heart when unavailable or older than 3000 ms.
- A six-frame squash/rebound cycle paced from reported BPM. It is a rate visualization, **not measured individual beats, ECG, or a live 3D mesh renderer**.
- START pauses/resumes motion; the paused footer explicitly shows `START: resume`. UP/DOWN opens transport details. START in details retains the existing fixed-string link test; BACK returns to the clock, then exits normally.
- The successful iPad request/reply protocol, nonce validation, and sample-age rules remain unchanged. The clock footer reflects whether a valid phone request was accepted in the past six seconds, not a promise of persistent connectivity.

## Fresh evidence

Release artifact: `watch/build/PulseLink.prg` (ignored build output), **19,452 bytes**.

SHA-256: `80bf0cb97fe0bd5d7d7ba6a74cb36efa131279b112bf435c5118c27cb0c466fb`.

| Check | Result | Evidence |
| --- | --- | --- |
| Release compile | PASS; warning-free | `.evidence/watch-clock/release-build-final.log` |
| Test compile | PASS; warning-free | `.evidence/watch-clock/test-build-final.log` |
| Clock/phase/frame unit tests and response contract regressions | PASS, 9/9 | `.evidence/watch-clock/tests-final.log` |
| Live animation | 3 distinct heart-only pixel states in 8 captures | `.evidence/watch-clock/animation-check.json` |
| START pause | Heart pixels unchanged across paused captures; textual state changes | same JSON; `fr245m-paused.png` |
| 12h and 24h layout | Readable, no text overlap | `fr245m-live.png`, `fr245m-24h.png` |
| Sensor interruption | Old BPM clears to `--`; heart rests | `fr245m-stale.png` |
| Details and BACK | Details visible; BACK returns to clock; second BACK exits to simulator idle | `fr245m-details.png`; direct simulator observation |
| Asset provenance | Both shipping PNGs carry provenance; cartoon exact generation prompt embedded | `embed-prompt.mjs --scan watch/resources/drawables`: 2 rasters, 0 missing |
| Independent code review | APPROVE; no material findings; pre-hint independent rebuild matched, final hint change separately reviewed | native `watch_clock_review` reports |
| Visual review fix verdict | Both scored issues resolved: centered stale heart and explicit START resume hint; ship for simulator-only scope | native `watch_clock_finish` verdict; `.evidence/watch-clock/stale-heart-bounds.json` |

Screenshots are under `.impeccable/review/watch-clock/`. All BPM values in these screenshots come from **Garmin Simulator Data Simulation**, not from the user's watch and not from a production fallback. No synthetic values were added to production code. The app never writes pulse data to files.

## Practical limits

The Forerunner 245 Music uses a 240×240, 64-color MIP display. Six small compiler-scaled resources provide shaded cartoon depth without runtime texture transforms. The view requests animation at about six frames per second only while visible with a fresh, unpaused pulse; the independent 1 Hz refresh clears stale readings. Animation stops in `onHide`, and sensor/communications/display-timer cleanup remains in the app lifecycle.

This stays a **watch-app**, not a default system watch face. Garmin's watch-face app type does not support the Sensor/Communications modules needed by this prototype. Foreground battery cost has not been measured; no all-day/background claim is made. See [Garmin app types](https://developer.garmin.com/connect-iq/connect-iq-basics/app-types/) and [resource compiler documentation](https://developer.garmin.com/connect-iq/articles/core-topics/Resources.html).

The previous watch build already delivered ten accepted live responses to the physical iPad. That historical proof does **not** establish physical performance of this newly skinned build. A later USB installation and fresh watch-to-iPad reception test remain before hardware sign-off.
