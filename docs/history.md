# Garmin-relevant development history

Research date: 2026-09-29. Researcher: Oracle AI, using Relic CLI and local source inspection.

The earlier FleetPad / JSONL Observatory results in the conversation were unrelated.
Neither project proves that an iOS or Android Garmin heart-rate app already existed.

## Ten Relic search passes

The bounded history pass used these queries over 2026-08-01 through 2026-09-30:

1. `Forerunner 245`
2. `Garmin BLE`
3. `Garmin heart rate`
4. `Garmin notification`
5. `ANCS iOS`
6. `CoreBluetooth Garmin`
7. `Garmin app`
8. `Android BLE scan`
9. `Forerunner notification`
10. `iPhone Garmin`

Relic ranks search terms rather than guaranteeing an exact phrase. Results were
treated as leads, not proof, and relevant transcript events / local files were
checked. Index freshness and missing sessions limit any claim of absence.

## Timeline (UTC)

| Date | Who / what | Evidence boundary |
| --- | --- | --- |
| 2026-08-24–25 | Neo Oracle AI sessions investigated ESP32 ANCS firmware against iPhone notifications; Garmin was used as a comparison recipient. | Firmware interoperability work, **not** a standalone iOS Garmin app. Sources: `relic://2026-08/defaults/codex/01a0347c-f4f7-76e3-a565-ecb35460056c:3739`, `:3762`, `:4088`, `:6597`; `relic://2026-08/defaults/claude/1d2aa5f8:3665`. |
| 2026-09-15 15:12 | Neo Oracle AI, commissioned by Nat, reported a real Android BLE scan and decoded 20 nearby devices after macOS Bluetooth permission blocked its Mac scanner. Android notification capture/test-post detection also worked. | No Garmin heart-rate packet was established. Full OMP transcript event `relic://2026-09/defaults/omp/01a0a50b-48d0-7000-b9c9-d6401892c2b9:1498` distinguishes completed broad scanning from an HR path still awaiting broadcast. |
| 2026-09-15 | Neo created `tools/ble/hr-scan.swift`, `ble-scan.swift`, and `parse-btsnoop.py` in `laris-co/neo-oracle`. | These are macOS CoreBluetooth utilities / an Android snoop-log parser, not mobile apps. Source comments attribute them to Neo, commissioned by Nat. Files are untracked in that checkout: no Git author or commit date can be asserted. |
| 2026-09-16 | A separate Neo worktree contains `tools/notifcapture-android` and a debug APK. | Android notification-capture app, not proof of a Garmin HR client. |
| 2026-09-29 | Pulse opened `laris-co/pulse-oracle#273` and delegated to Nexus through `laris-co/nexus-oracle#11`; the target repository initially contained only a README. | M0 proposed Android first. The user then explicitly requested **try both** and **find the easiest**, approving Android + iOS diagnostic prototypes. |

## What this does not prove

- A matching search hit is not a deployed app or live watch connection.
- A Git/account author is not necessarily the person who wrote every line; AI
  implementation is attributed separately above.
- Garmin Express setup screenshots establish the model and an Express connection,
  not standard BLE Heart Rate Service notifications or smart-notification delivery.
- macOS Swift source is not an iOS app merely because it uses CoreBluetooth.

New prototypes in this repository are built by Oracle AI for Nat. Hardware claims
are recorded separately in `verification.md`; no prior experiment is reused as
proof of present success.
