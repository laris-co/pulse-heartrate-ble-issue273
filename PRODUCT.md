# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users

Nat wants a separate pulse-only app to use on iPhone and iPad with the existing Garmin Forerunner 245 Music. Wider distribution is undecided.

## Product Purpose

Make the working live heart-rate connection pleasant to watch and simple to use, with animation and clear readings. The user explicitly rejected reopening the diagnostic app and requested a **new app, only pulse stuff**.

## Operating Context

A native SwiftUI implementation already receives standard BLE Heart Rate Service measurements. The physical iPad received ten valid updates with the watch in Virtual Run. The current Garmin companion pairing must remain unchanged.

## Capabilities and Constraints

- The new app lives in `pulse/`, with its own app identity and installation, alongside the unchanged `ios/` diagnostic app.
- Reuse the verified CoreBluetooth manager and parser; no notification controls or diagnostic dashboard in the new app.
- Current BPM is available. Energy and RR fields are packet-optional; parser support does not establish that the watch supplies them.
- Motion can represent reported rate, not ECG or exact measured beat timing.
- Foreground-only, on-device, in-memory data. No accounts, uploads, session recording, CSV, medical scoring or higher-heart-rate rewards.
- Never show synthetic preview data as live readings. No stale value presented as current.
- iPhone/iPad are confirmed platforms; a mini-game, brand name and wider sharing are still open and are not prerequisites for this pulse-only first app.

## Evidence on Hand

`docs/verification.md` records the successful iPad ten-update test. Existing `ios/Sources/App/HeartRateBluetoothManager.swift` and `ios/Sources/HeartRateParser/HeartRateMeasurement.swift` contain the tested BLE/parser implementation. The later 17:09 diagnostic rerun failed before confirming active scanning; it does not erase the earlier verified run or establish a new live connection.

## Product Principles

- One subject: pulse, with animation subordinate to honest data.
- Keep the proven diagnostic app available and unchanged.
- Clear connection, waiting, freshness, missing-data and disconnection states.
- Native iPhone and iPad behavior, accessibility, and reduced-motion support.
