# Pulse Garmin diagnostics

Small native Android and iOS/iPadOS prototypes, built by Oracle AI for Nat.
Tracking: [Pulse #273](https://github.com/laris-co/pulse-oracle/issues/273) and
[Nexus #11](https://github.com/laris-co/nexus-oracle/issues/11).

## New pulse-only app

[**Pulse**](pulse/README.md) is a separate native iPhone/iPad app combining the
chosen animated ribbon sculpture and last-minute trend. It has its own bundle ID
and no notification/debug dashboard; the original diagnostic apps remain available.

## Which app is easiest?

**Use the Apple device that is actually connected to the watch.** The latest
hardware state reported by the user is that this Forerunner is connected to the
iPad, while both saved Forerunner entries inspected on the iPhone were Not
Connected. Posting on a different phone/tablet does not test the active bridge.

Android offers convenient ADB/logcat diagnostics for BLE investigation. That does
not make Android the easiest notification route when the watch is connected to an
Apple companion device.
The dated hardware results and unverified steps are in
[docs/verification.md](docs/verification.md).

## Features and limits

- User-initiated scan, explicit sensor selection, BLE Heart Rate Service `0x180D`
  discovery and `0x2A37` notification subscription.
- Bounds-checked uint8/uint16 BPM, optional energy and RR interval parsing.
- Foreground-only, latest reading in memory; disconnect/background clears it.
- Synthetic **local OS notification** without health data. Garmin delivery is a
  separate phone/watch integration, not a write to the heart-rate characteristic.
- No health-data uploads, network permission on Android, cloud service or account
  in either prototype. No session recording/CSV yet; that is a later issue gate.
- Live-heart-rate connection and watch notification delivery require separate
  hardware proof; a successful build, parser test or local notification alone is
  not proof of either. Both Apple routes were verified separately on the iPad.

The 2026-09-29 iPad test did complete the notification route end to end: the app's
delivered-notification record passed, and the user explicitly confirmed that the
physical Garmin displayed **Pulse diagnostic**. This happened because the watch was
connected to that iPad and mirrored its notification through the companion bridge.
That notification result does not by itself prove the separate live-heart-rate route.

An earlier physical-iPad BLE smoke test passed the permission and scan flow but found
zero `0x180D` sensors. After the user placed the watch in **Virtual Run**, the opt-in
hardware test found the named Forerunner/FR245 sensor, selected it, subscribed to
`0x2A37`, received at least ten valid measurement callbacks, disconnected, verified
that state/count cleared, and completed a start/stop rescan. No raw health value was
exported; the test did not start an activity timer or change pairing. The candidate
was identified by its advertised name and HRS service in this controlled test, not
by independent device authentication.

## Apple notification test

1. Install the signed app on the **iPhone or iPad currently connected to the watch**.
2. Open **Pulse HR Diagnostic** and tap **Request permission and notify in 5 seconds**.
3. Allow this app's notifications. The test replaces the previous diagnostic
   notification rather than scheduling an unbounded sequence.
4. Confirm the device notification, then separately confirm the watch shows
   **Pulse diagnostic**. Do not include heart-rate data in this test.
5. If the device succeeds but the watch does not: verify the existing Bluetooth
   connection, Garmin Smart Notifications, **Share System Notifications** where
   the OS exposes it, Notification Center/previews and Focus/DND. Do not
   unpair/re-pair automatically.

**Check notification settings** reports this app's own iOS permissions and alert
settings, without changing them. **Open this app's Settings** opens the public iOS
Settings page if a correction is needed. Neither action reads other apps' notifications.

Garmin's [smart-notification instructions](https://www8.garmin.com/manuals/webhelp/forerunner245/EN-US/GUID-599D739A-21A7-4EF2-98F4-29258D407B47.html)
and [iPhone notification troubleshooting](https://support.garmin.com/en-IE/?faq=jusyWiwXtF4512Rb8jnLOA)
describe those companion/watch gates. Garmin's published compatibility material
names iPhone rather than promising full iPad support, so this repository records
the iPad result as an empirical device test, not a general compatibility claim.

## Can this app pair like Garmin Connect?

- **Direct heart-rate link: yes.** While the watch broadcasts the standard BLE
  Heart Rate Service, this app can scan, let the user choose it, connect and
  subscribe to `0x2A37`. This is a sensor connection, not Garmin account/device
  onboarding.
- **Replacement for Garmin Connect pairing: no public equivalent is implemented.**
  Smart notifications use the Apple notification bridge and the watch's active
  companion relationship; they are not arbitrary writes to the Heart Rate GATT
  service. Apple's protocol for accessories is ANCS.
- **Garmin-native custom app option:** a Connect IQ watch app plus companion app is
  possible, but Garmin's companion SDK still starts with Garmin Connect Mobile
  discovering the device and installing/communicating with the Connect IQ app.

References: [Apple ANCS](https://developer.apple.com/library/archive/documentation/CoreBluetooth/Reference/AppleNotificationCenterServiceSpecification/Introduction/Introduction.html),
[Garmin Connect IQ iOS companion SDK](https://github.com/garmin/connectiq-companion-app-sdk-ios),
and [Garmin iOS compatibility guidance](https://support.garmin.com/en-US/?faq=pvL8aWsaLU2iKyvF8VrpP9).

### Forerunner 245 Music live-HR test

For this model, use Garmin's documented Bluetooth-capable **Virtual Run** route;
do not assume the legacy Heart Rate widget broadcast is BLE:

1. On the watch, select **START → Virtual Run**.
2. Leave the watch on its compatible-app pairing screen. Do not start the activity
   timer yet.
3. In Pulse HR Diagnostic, run the filtered `0x180D` scan and select the watch if
   it appears.
4. This route passed on the physical iPad with at least ten valid callbacks plus
   disconnect/clear/rescan verification. If a timer is later started by user choice,
   finish the test with **STOP → Discard → Yes** to avoid saving a test activity.

See Garmin's [Virtual Run pairing instructions](https://www8.garmin.com/manuals/webhelp/forerunner245/EN-US/GUID-9F45EF2C-D6D5-4583-B4C6-A386743B650A.html)
and [activity stop/discard options](https://www8.garmin.com/manuals/webhelp/forerunner245/EN-US/GUID-996CC115-E86F-4FA9-8C13-1405A9A7485F.html).

## Build and verify

Android (Android SDK platforms 35+, JDK 17+, Gradle with AGP 9.4.0):

```sh
cd android
gradle --no-daemon check :app:assembleDebug
# APK: app/build/outputs/apk/debug/app-debug.apk
```

iOS (Xcode and XcodeGen):

```sh
cd ios
swift test
xcodegen generate
xcodebuild -project PulseHeartRateBLE.xcodeproj -scheme PulseHeartRateBLE \
  -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
```

See [ios/README.md](ios/README.md) for device builds/UI tests. Set your own
`DEVELOPMENT_TEAM` for signed builds; never commit provisioning profiles or keys.
Device signing requires a valid profile containing the target device.

## History

[docs/history.md](docs/history.md) records ten Relic search passes and distinguishes
earlier ANCS firmware/macOS scanners from these new mobile prototypes. FleetPad
and JSONL Observatory are unrelated to the Garmin implementation.

## License

MIT — see [LICENSE](LICENSE).
