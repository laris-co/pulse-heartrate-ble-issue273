---
version: 1
slug: "watch-source-pulseview-mc"
primary_target: "watch/source/PulseView.mc"
related_targets: ["watch/source/PulseInputDelegate.mc"]
---

# Pulse Link timepiece

Mode: Operate with an expressive pulse visualization. Narrow extension of the existing Garmin foreground Pulse Link screen, not an iOS redesign or a system watch-face conversion. The user explicitly chose the physical Garmin and requested a full clock and a realistic 3D beating heart, then explicitly preferred a rounded cartoon 3D heart shape. Existing iOS comp gates belong to the unchanged iOS surface, not this watch screen.

## Direction contract

THESIS: A useful watch clock that keeps the proven live pulse bridge intact.
OWN-WORLD: Existing black Garmin ground, white native numerals, pink/red rounded cartoon heart with sculpted highlights and plum shadows.
STORY: Read time and fresh pulse at a glance; pause motion with START; UP/DOWN reveal transport details.
FIRST VIEWPORT: Local date above large time; dimensional heart left of large BPM; a quiet current link-state footer, all inside the round 240px display.
FORM: Precisely requested local extension, no concept seed required. Compile a generated transparent heart into six small beat-size resources; never imply ECG, individual beat detection, or continuous background service.
FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Constraints

Watch-app remains foreground-only. Freshness and request/nonce protocol unchanged. Heart animation pauses for missing/stale sensor data or user pause. No synthetic BPM in production. BACK exits normally; details are optional and retain the manual link test. New app skin requires fresh simulator verification. The user selected simulator-only testing for now: do not install this build on the watch. Earlier hardware proof belongs to the previous build.
