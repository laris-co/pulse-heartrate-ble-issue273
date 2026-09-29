# iOS/iPadOS diagnostic

This dependency-free SwiftUI app scans only for devices advertising the Bluetooth Heart Rate Service (`0x180D`). The user chooses a result before the app connects, discovers the Heart Rate Measurement characteristic (`0x2A37`), and subscribes to live measurements.

The app is deliberately foreground-only. It keeps only the latest parsed measurement in memory, clears it on disconnect/backgrounding, and neither stores nor uploads health data.

## Generate, test, and build

Requires XcodeGen and Xcode.

```sh
cd ios
swift test
xcodegen generate
xcodebuild \
  -project PulseHeartRateBLE.xcodeproj \
  -scheme PulseHeartRateBLE \
  -sdk iphonesimulator \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Build the UI smoke tests without signing or running them:

```sh
xcodebuild build-for-testing \
  -project PulseHeartRateBLE.xcodeproj \
  -scheme PulseHeartRateBLE \
  -sdk iphonesimulator \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO
```

The UI smoke suite never connects automatically. Its retained text diagnostics contain only the
scan state, sensor count, whether a result name contains `Forerunner`, and generic notification
scheduling/delivery status. Explicit settings tests retain only this app's notification
settings and Garmin connection/sharing indicators; they do not change phone settings.
The tests do not explicitly attach screenshots, device identifiers, BPM, or RR values.
Xcode may collect failure artifacts; keep result bundles local and uncommitted, and
use `-collect-test-diagnostics never` for physical-device runs to avoid verbose collection.

To prove that the app also compiles for a physical-device SDK without signing:

```sh
xcodebuild \
  -project PulseHeartRateBLE.xcodeproj \
  -scheme PulseHeartRateBLE \
  -sdk iphoneos \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  build
```

The project has team `6K28WEXX78` configured for a later authorized signed build. These commands do not sign, install, or launch the app on a device.

## Opt-in real-watch HR verification

The ordinary UI scan test never connects. The separate
`testReceiveTenGarminMeasurementsThenDisconnectAndRescan` test is skipped unless
the build explicitly defines `PULSE_ALLOW_REAL_GARMIN_CONNECTION`. Run it only with
the user's watch ready in Virtual Run and authorization to connect. It requires one
matching Forerunner result, a confirmed `0x2A37` subscription, at least ten parsed
real updates, then disconnect/clear/rescan checks. A failed or skipped run is not
live-HR proof.

All UI tests launch with `--privacy-safe-hardware-test`: actual BPM, energy, RR,
peripheral UUID and RSSI are hidden from the test UI. Only state and valid-update
count are retained. Normal user launches show the actual measurements on the device.

```sh
xcodebuild test -project PulseHeartRateBLE.xcodeproj -scheme PulseHeartRateBLE \
  -destination 'id=YOUR_DEVICE_UDID' \
  -only-testing:PulseHeartRateBLEUITests/PulseHeartRateBLEUITests/testReceiveTenGarminMeasurementsThenDisconnectAndRescan \
  'SWIFT_ACTIVE_COMPILATION_CONDITIONS=$(inherited) PULSE_ALLOW_REAL_GARMIN_CONNECTION' \
  -collect-test-diagnostics never
```

## Notification boundary

The notification diagnostic schedules a generic local notification and includes no
heart-rate data. Garmin watch delivery depends on the watch's active Apple companion
connection, Garmin integration and Smart Notifications. Reading the Heart Rate GATT
service is not a mechanism for writing phone notifications to a Garmin watch.

The physical iPad test passed local and background delivery plus an own-app settings
read: Authorized, Notification Center/Alerts/Lock Screen enabled, previews Always.
The automated result alone proves the app's iPad notification behavior, not watch
receipt. The user later reported that the watch was connected to the iPad and then
explicitly confirmed that **Pulse diagnostic** appeared on the physical Garmin.
Together those observations verify this one end-to-end iPad notification run.
Garmin's published compatibility page lists iPhone; do not generalize the successful
run into a promise of full iPad compatibility.

The physical-iPad BLE smoke test also passed after its system-prompt handler was
stabilized. Its privacy-safe result was `sensorCount=0` and
`containsForerunner=false`; no HRS connection or live measurement is claimed.

## Pairing boundary

The app can connect directly to a broadcasting standard BLE Heart Rate Service
(`0x180D`) and subscribe to measurements. It does not replace Garmin Connect's
account/device onboarding or create the companion relationship used for smart
notifications. Apple accessories receive notification metadata through
[ANCS](https://developer.apple.com/library/archive/documentation/CoreBluetooth/Reference/AppleNotificationCenterServiceSpecification/Introduction/Introduction.html),
not through the Heart Rate characteristic. A custom Garmin watch experience can use
Connect IQ, but the official
[iOS companion SDK](https://github.com/garmin/connectiq-companion-app-sdk-ios)
still depends on Garmin Connect Mobile for initial device discovery and Connect IQ
app installation/communication.

For the Forerunner 245 Music HRS test, select **START → Virtual Run** on the watch
and leave its compatible-app pairing screen open before starting any activity timer.
Then run this app's filtered `0x180D` scan. The legacy Heart Rate widget broadcast
instructions describe ANT+, so they are not evidence that the same screen advertises
BLE HRS. Live HR remains unverified. If the user later starts the activity timer,
**STOP → Discard → Yes** exits without saving the test activity. See Garmin's
[Virtual Run manual](https://www8.garmin.com/manuals/webhelp/forerunner245/EN-US/GUID-9F45EF2C-D6D5-4583-B4C6-A386743B650A.html)
and [stop/discard manual](https://www8.garmin.com/manuals/webhelp/forerunner245/EN-US/GUID-996CC115-E86F-4FA9-8C13-1405A9A7485F.html).
