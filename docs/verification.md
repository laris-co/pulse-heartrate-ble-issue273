# Hardware verification ledger

Date: 2026-09-29. Keep measurements, full Bluetooth logs, device IDs, and screenshots
out of Git. Health data stays on the receiving device.

## Success criteria

1. Android and iOS apps both build, with synthetic parser regression tests.
2. On real hardware, scan for Heart Rate Service `0x180D`; select the user's watch;
   discover Measurement `0x2A37`; enable notifications; observe live measurements.
3. Exercise stop/disconnect/rescan without stale BPM being presented as live.
4. Post a clearly labelled synthetic phone notification. Distinguish phone posting
   from confirmed display on the Garmin watch.
5. Compare actual Android and iOS setup/debug friction, not theoretical capability.

## Current evidence

| Check | Evidence / status |
| --- | --- |
| Android available | Samsung Galaxy A14 (SM-A146P), Android 14, initially ADB connected; BLE feature present; Bluetooth ON. Later wireless ADB became offline (`Host is down`); not treated as an app failure. |
| Apple hardware available | Physical iPad Pro 12.9-inch (5th generation), iPadOS 26.5, paired with Xcode; Developer Mode enabled. Not an iPhone. |
| Actual watch companion | Latest user report: the watch is connected to the iPad. Earlier iPhone inspection found two saved Forerunner 245 Music entries, both Not Connected. Do not silently change, delete or recreate either device relationship. |
| Watch identity | User screenshots: Garmin Forerunner 245 Music. User confirms Broadcast Heart Rate is ON. |
| Garmin Connect on A14 | No Garmin package found in the installed-package list for the inspected user. Do not infer that another device/user is unpaired. |
| Android shell notification | An explicitly synthetic notification was posted and its own NotificationRecord was verified. The shell-origin tag is `link`. This proves Android posting only, not Garmin delivery. |
| Android app runtime | Initial debug APK installed and launched; Nearby Devices permission accepted; bounded filtered scan completed with no `0x180D` devices found. No claim that Garmin lacks support—range/mode/advertising remain unresolved. Updated APK is build/lint/test verified but not reinstalled after ADB went offline. |
| iPad app runtime | Signed app and UI-test runner launched successfully. The notification/settings run completed two tests with zero failures; the exact own-app notification permission prompt was accepted by the targeted SpringBoard alert handler. |
| iPhone signing | Existing profile did not include iPhone. User explicitly approved registering iPhone and retaining Garmin pairing; Xcode provisioning then passed that gate. UI-test target needed generated Info.plist for code signing (fixed). |
| iPhone app runtime | Signed app and test runner launched. Initial test failed at a SpringBoard permission prompt (`Not requested`). Retest passed on physical iPhone at 13:01 Bangkok time: one UI test, zero failures, and the app's own delivered-notification record contained the diagnostic request. No system prompt was present in the successful run, so fresh-install permission-handler execution is not yet proven. |
| iPhone notification delivery | **Verified on phone:** `Pulse diagnostic`, generic body without heart-rate data, five-second local trigger. This does not prove Garmin display. |
| Background phone delivery | Passed on physical iPhone at 13:12 Bangkok time; app was backgrounded before the trigger. Own delivered-notification record was confirmed after returning. |
| Own-app notification settings | Read through Apple's API on physical iPhone: authorization Authorized; Notification Center, alerts and Lock Screen Enabled; **Show Previews Never**. Garmin documents Always/When Unlocked as a forwarding requirement, making previews a concrete configuration mismatch. No setting changed during this probe. |
| Approved preview correction | User first approved When Unlocked, then explicitly requested **Always**. Changed only Pulse HR Diagnostic's Show Previews. Apple's own-app API read back **Always**, and a fresh background notification passed phone delivery at 13:17 Bangkok time. Global/other-app settings and pairing were not changed. User clarified the alert still appeared only on iPhone, **not Garmin**; the privacy-setting correction alone did not resolve forwarding. |
| Watch Smart Notifications | User confirmed Status On and Not During Activity notifications enabled. This is user-reported watch state, not an app-verified setting. |
| Bluetooth forwarding-settings probe | Initial navigation probe safely skipped. Corrected read-only navigation reached iPhone Bluetooth: **two saved Forerunner 245 Music rows both explicitly report Not Connected**. No row was tapped, deleted or re-paired because the saved entries are indistinguishable. The iPhone's Share System Notifications value was not inspected; the later iPad-to-watch delivery nevertheless worked empirically. Private local row diagnosis is in `iphone-garmin-row-diagnosis.xcresult`; its temporary row-text logging was removed from normal tests. |
| Connection recovery attempt | Launched the already-installed Garmin Connect app to allow its existing connection logic to run. Launch succeeded; this alone does not prove reconnection. No re-pairing or account change was performed. |
| Standard HR service | No live Garmin measurement verified on either new mobile app. |
| iPad notification delivery | **Verified on iPad:** local/background diagnostic delivery and own notification settings Authorized, Notification Center/Alerts/Lock Screen Enabled, previews Always. The retained test artifact used an older `DeliveredOnPhone` key, but the physical target was the iPad; current source uses device-neutral wording. |
| Watch notification delivery | **Passed through iPad.** The iPhone test reached the phone but the user reported nothing on Garmin; both inspected iPhone watch entries were Not Connected. The later iPad delivered-record test passed, and the user explicitly confirmed that the physical Garmin watch displayed **Pulse diagnostic**. This verifies one end-to-end synthetic notification without health data. |
| iPad live-HR scan | **Scan flow passed; sensor connection did not.** The first UI-test attempt stopped at the Bluetooth permission prompt due to an XCTest alert-query mismatch. After the handler was stabilized, the physical-iPad test passed with privacy-safe output `scanStatus=Idle`, `sensorCount=0`, `containsForerunner=false`. This verifies permission and bounded scanning, but not watch discovery, GATT connection or live HR. |
| Model-specific BLE mode | Pending hardware retest. Forerunner 245 documentation routes compatible third-party app heart-rate transmission through **START → Virtual Run**. The next test should leave the watch on its pairing screen, before the activity timer, while the iPad runs the filtered `0x180D` scan. Do not treat the legacy HR-widget ANT+ broadcast instructions as BLE proof. |

## Notification route is not the HR route

HR: watch broadcasts → mobile BLE central → service discovery → `0x2A37` subscribe.

Smart notification: our app posts a local OS notification → active companion-device
notification integration → connected watch. Do not send arbitrary GATT writes to
the HR measurement characteristic to simulate a message.

Garmin's manual: pair compatible phone, then hold UP → Phone → Smart Notifications
→ Status → On. Activity/non-activity settings, DND/Focus, app filters, privacy and
phone-side notification access can affect delivery. Do not silently re-pair a
watch, grant notification-listener access, or change DND just to make a test pass.

On iOS/iPadOS, a local notification proves only that device posted it. The relevant
forwarding test must originate on the Apple device currently connected to the watch.
The 2026-09-29 iPad test plus the user's explicit physical-watch observation proves
one end-to-end diagnostic notification. It does not establish general Garmin iPad
compatibility or the separate live-heart-rate connection.

## Primary references

- [Garmin Bluetooth HR broadcast compatibility](https://support.garmin.com/nl-NL/?faq=Zj1947s6pqAHzBCAhLhrC9) — Forerunner 245 series listed; actual firmware/mode still needs hardware verification.
- [Forerunner 245 legacy HR-widget broadcast instructions](https://www8.garmin.com/manuals/webhelp/forerunner245/EN-US/GUID-57A88A77-3813-4E79-9DB1-FC95B06F01BA.html) — describes ANT+; not the BLE test path.
- [Forerunner 245 Virtual Run pairing](https://www8.garmin.com/manuals/webhelp/forerunner245/EN-US/GUID-9F45EF2C-D6D5-4583-B4C6-A386743B650A.html) — compatible third-party app pairing precedes starting the activity timer.
- [Forerunner 245 stop/discard options](https://www8.garmin.com/manuals/webhelp/forerunner245/EN-US/GUID-996CC115-E86F-4FA9-8C13-1405A9A7485F.html) — if a timer is started, discard the test activity only by user choice.
- [Forerunner 245 smart notifications](https://www8.garmin.com/manuals/webhelp/forerunner245/EN-US/GUID-599D739A-21A7-4EF2-98F4-29258D407B47.html).
- [Android BLE central/GATT concepts](https://developer.android.com/develop/connectivity/bluetooth/ble/ble-overview).
- [Android Bluetooth diagnostic tools](https://source.android.com/docs/core/connect/bluetooth/verifying_debugging).
- [Apple CoreBluetooth sample](https://developer.apple.com/documentation/corebluetooth/transferring-data-between-bluetooth-low-energy-devices).
- [Apple local notifications](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app).
- [Apple Notification Center Service](https://developer.apple.com/library/archive/documentation/CoreBluetooth/Reference/AppleNotificationCenterServiceSpecification/Introduction/Introduction.html) — accessory notification bridge; separate from BLE HRS.
- [Garmin Connect IQ iOS companion SDK](https://github.com/garmin/connectiq-companion-app-sdk-ios) — Garmin Connect Mobile performs initial device discovery and Connect IQ app install/communication.
- [Garmin iOS compatibility guidance](https://support.garmin.com/en-US/?faq=pvL8aWsaLU2iKyvF8VrpP9) — lists iPhone; this project does not generalize its iPad observation into an official support claim.

## Scope gates

The user approved trying both diagnostic apps after M0. Session recording/CSV and
publication remain later issue gates, not completed by these prototypes. No cloud,
store publication, account creation, push to main, or merge is part of this test.

## Verification commands

- Android: `gradle --no-daemon check :app:assembleDebug` — passed; `check` runs the
  dependency-free parser regression and lint. Only the empty framework test task
  is disabled; parser regressions are not skipped.
- iOS: `swift test` — 8 parser tests passed; unsigned device and simulator builds
  plus UI `build-for-testing` passed. These do not substitute for real watch proof.
- Physical-device artifact: the then-named
  `testBackgroundNotificationDeliveredOnPhone` passed on the iPad. The source now
  uses the device-neutral name `testBackgroundNotificationDeliveredOnDevice`; its
  behavior is unchanged. XCTest verifies the app's delivered record; the user's
  explicit observation separately verifies display on the Garmin.

Build/test logs and device result bundles are private, uncommitted local evidence
under ignored `.evidence/`. Relevant artifacts include `android-verification.log`,
`ios-parser-tests.log`, and the initial `notification-iphone-delivery.log` /
`notification-iphone-delivery.xcresult`, plus successful retest artifacts
`notification-iphone-prompt-fix.log` / `.xcresult`. They are not published with this repository;
the ledger records their outcomes without exporting device identifiers or readings.
The successful iPad scan-flow artifact is `ipad-hr-scan-stable-prompt.log` with its
local `.xcresult`; it contains no BPM or RR value.

## Easiest route, after user clarification

For raw BLE development, Android was quickest to install, grant permission and
inspect using ADB. Apple device testing incurred provisioning, signing, unlock and
system-alert overhead. For **this user's notification goal**, use whichever Apple
device is actually connected to the watch; the latest reported companion is the
iPad, while the inspected iPhone entries were Not Connected.

The installed app does not require a Mac or USB cable to run. Optional wireless
Xcode debugging needs prior pairing and suitable same-network connectivity; that
is separate from the Apple-device-to-watch Bluetooth connection.

## Forwarding follow-up

The app now has an explicit **Check notification settings** action. It reads only
its own authorization, Notification Center, alerts, Lock Screen and preview settings,
and warns about disabled Notification Center or previews set to Never. Its Settings
button opens only the app's public iOS Settings page; neither action changes permissions.

After the user reported no Garmin alert, the consolidated physical-device run
completed with **two tests passed, one safely skipped, zero failures**. The initial
background-only run was interrupted at locked-device preflight, before test execution,
to consolidate the diagnostics. Successful results are in local ignored
`iphone-forwarding-diagnostics.log` / `.xcresult`; exported text-only attachments
include the own-app settings values above. No forwarding setting or pairing was changed.
The user separately approved changing only this app's preview setting, finally choosing
Always. The one-off action was verified in `iphone-preview-always-retest.log` / `.xcresult`,
then removed from the normal UI test source so routine tests cannot change privacy settings.
The Apple app cannot prove a watch displayed its alert.

## iPad notification evidence

The signed physical-iPad run in local ignored
`ipad-notification-delivery.log` / `.xcresult` completed the background-delivery
and own-settings tests: two tests, zero failures. It verified only this app's iPad
notification record and settings. No BPM or RR interval was retained. XCTest cannot
observe the watch display; the user separately confirmed that the physical Garmin
showed **Pulse diagnostic**, completing the end-to-end notification evidence.

## What direct pairing means here

The prototype can act as a BLE central for the standard Heart Rate Service when
the watch broadcasts it. That is independent of Garmin Connect onboarding and of
the companion relationship that forwards smart notifications. There is no public,
general Garmin Connect replacement pairing flow implemented here. A Connect IQ
watch/companion app is a separate architecture and still uses Garmin Connect Mobile
for initial discovery and installation according to Garmin's companion SDK.
