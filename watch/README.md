# Pulse Link for Garmin Forerunner 245 Music

Pulse Link is a foreground Connect IQ watch-app that combines a local clock, the latest fresh heart-rate reading, and the Oracle Voice cat in a glowing orb that beats with your pulse. It reads the watch's configured heart-rate source without changing sensor pairing. It is not a system watch face and does not run as an all-day background display.

The heart uses six pre-rendered, compiler-scaled sprites to provide 3D-style shading on the watch's limited palette. The user requested this cartoon form instead of an anatomical heart. It is not a real-time 3D mesh, an ECG, or a visualization of individually measured beats.

## The cat sprite

Since 2026-10-02 the pulse sprite is the Oracle Voice app icon (a Siamese cat in a glowing orb),
cut out by [`tools/make_cat_assets.py`](tools/make_cat_assets.py) into `resources/drawables/oracle_cat.png`
(1254 x 1254, the same canvas as the old heart so the six scale percentages in `drawables.xml` keep the
on-watch size at about 92 px) and a 40 x 40 `launcher_icon.png`. To go back to the cartoon heart,
point the six `Heart0`–`Heart5` bitmaps in `drawables.xml` at `cartoon_heart.png` again; that file is
kept in the repo.

```sh
uv run --with pillow python watch/tools/make_cat_assets.py <path to the Oracle Voice AppIcon.png>
```

## Clock and controls

The clock honors the device's 12/24-hour setting and shows the date, current fresh BPM, pulse state, and recent phone-link activity.

| Button | Clock | Link details |
| --- | --- | --- |
| **START** | Pause or resume heart motion | Send the manual link test |
| **UP** / **DOWN** | Open link details | Return to the clock |
| **BACK** | Exit the app | Return to the clock; press again to exit |

The heart's six-frame squash/rebound cycle is paced from the reported BPM. The view requests updates at about 6fps only while the clock is visible and the pulse is fresh and unpaused. Animation stops when the reading is missing or stale, motion is paused, link details are open, or the view is hidden. The controller's independent 1 Hz refresh remains active while the app runs so a reading older than 3000 ms clears to `--` and the heart returns to rest.

Foreground battery cost has not been measured. No all-day battery-life claim is made.

## Manual link test

Open link details, then press **START** to send the fixed string `pulse-link-watch-test` to the registered phone app. This manual transport probe contains no heart rate, nonce, identifier, or other user data, and it is never sent automatically. The same single-flight guard used by pulse responses prevents the test from sending while another transmission is active.

The details screen reports `Link test sending`, followed by `Link test sent` or `Link test failed`. `Phone RX` is a monotonic count of phone-message callback invocations, including malformed messages and messages skipped while a transmission is active.

## Claude status (page 2)

The phone app can push a display-only status message; the watch shows its `text` as a green line
under the cat, and **DOWN** opens page 2 with the full status (UP still opens link details):

```text
{ "v": 1, "type": "status", "text": "pulse Opus 5.5 ctx 61%", "title": "Claude", "ctx": 61,
  "lines": ["pulse", "Opus 5.5", "608k / 1000k  rb", "ba2d0b1a  14:26"] }
```

- `text` is required (cut to 30 characters); `title` (12), `ctx` (0-100, draws the bar: green
  below 50, orange below 80, red above) and up to 4 `lines` (22 characters each) are optional.
- A status is never answered, stored or forwarded; it is shown for 10 minutes after it arrives.
- [`tools/claude_status.py`](tools/claude_status.py) builds this message from the newest Claude Code
  transcript of a project (last turn's token usage and model).
- Simulator: **Settings > Connection Type > BLE before the app starts**, then **Simulation > Phone
  App Message** with the JSON above. With BLE switched on later, no message reaches the app.

## Phone protocol

The app registers for phone-app messages while it is running. Apart from the explicit manual link test, it sends nothing unless it receives a valid request:

```text
{ "v": 1, "type": "request", "nonce": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" }
```

For a valid, non-duplicate request received while no transmission is active, it replies once:

```text
{ "v": 1, "type": "pulse", "nonce": "...", "bpm": 72, "ageMs": 418 }
```

- `bpm` is `0` when no positive heart-rate sample is at most 3000 ms old.
- `ageMs` is the stale sentinel `4000` when no sensor timestamp is available, including the system-timer rollover boundary; otherwise it is the measured sensor age.
- Requests are ignored while a transmission is active. Duplicate nonces and malformed requests are ignored.
- There is no unsolicited pulse transmission, logging, storage, GPS, workout/session recording, network request, or notification behavior.

Because the request schema contains no timestamp or expiry, Connect IQ cannot distinguish a new request from a valid request Garmin Connect queued before app startup. The iOS side should use a new UUID for every live request and ignore replies whose nonce is no longer pending.

## Build

Install the official Connect IQ SDK and the `fr245m` device files. Keep the Garmin developer key outside this directory; the app root's ignored `.evidence/` directory is suitable. Then run:

```sh
CONNECTIQ_DEVELOPER_KEY=/absolute/path/to/developer_key \
MONKEYC=/absolute/path/to/monkeyc \
./watch/build.sh
```

The warning-free signed release output is written to `watch/build/PulseLink.prg`. Neither the developer key nor Garmin SDK/device files belong in this repository.

The verified 2026-09-29 simulator release is 19,452 bytes with SHA-256 `80bf0cb97fe0bd5d7d7ba6a74cb36efa131279b112bf435c5118c27cb0c466fb`. Clock, phase, frame, and response-contract tests pass 9/9. Simulator review covers waiting, live, paused, stale, 12-hour, 24-hour, details, clock return, and exit states; see [`../docs/watch-clock-verification.md`](../docs/watch-clock-verification.md).

This release has not been installed on physical hardware because the user selected simulator-only testing. Ten accepted watch-to-iPad responses prove only the previous build; a new physical install and reception test remain required for hardware sign-off.

## Lifecycle and permissions

- Target: `fr245m`; app type: foreground `watch-app`.
- Permissions: `Sensor` and `Communications` only.
- Start: enable the configured heart-rate sensor source, register the phone-message callback, and start the 1 Hz stale-display refresh.
- View show/hide: start or stop the approximately 6fps animation timer.
- Stop/exit: stop the display timer, unregister the callback, disable sensor events, and release enabled sensors.
