---
name: "Pulse"
description: "A native pulse instrument built around a live 3D cartoon heart and an honest one-minute trend."
colors:
  background: "#F7E8F8"
  foreground: "#27082A"
  secondary: "#5D3F67"
  action: "#4B2459"
  control-surface: "#ECDAF5"
  separator: "#B59ABE"
  chart-line: "#6D0B73"
  heart: "#F02152"
  ribbon-plum: "#5A326B"
  ribbon-plum-highlight: "#84549B"
  ribbon-plum-shadow: "#40214E"
  ribbon-lavender: "#A872E0"
  ribbon-lavender-highlight: "#CFADF4"
  ribbon-lavender-shadow: "#8053B1"
  ribbon-pink: "#E5B4EA"
  ribbon-pink-highlight: "#F6D8F6"
  ribbon-pink-shadow: "#C586D0"
  ribbon-shadow: "#2A1031"
typography:
  display:
    fontFamily: "SF Pro, system-ui"
    fontSize: "88pt"
    fontWeight: 700
  title:
    fontFamily: "SF Pro, system-ui"
    fontSize: "22pt"
    fontWeight: 700
  headline:
    fontFamily: "SF Pro, system-ui"
    fontSize: "17pt"
    fontWeight: 600
  body:
    fontFamily: "SF Pro, system-ui"
    fontSize: "17pt"
    fontWeight: 400
  label:
    fontFamily: "SF Pro, system-ui"
    fontSize: "15pt"
    fontWeight: 400
rounded:
  capsule: "999pt"
  circle: "999pt"
spacing:
  compact-gutter: "22pt"
  wide-gutter: "34pt"
  standard-gap: "10pt"
  touch-target: "44pt"
components:
  button-primary:
    backgroundColor: "{colors.action}"
    textColor: "{colors.background}"
    typography: "{typography.headline}"
    rounded: "{rounded.capsule}"
    height: "52pt"
  button-icon:
    backgroundColor: "{colors.control-surface}"
    textColor: "{colors.foreground}"
    rounded: "{rounded.circle}"
    size: "44pt"
---

# Design System: Pulse

## Overview

**Creative North Star: "Kinetic Pulse Instrument"**

“Kinetic Pulse Instrument” is descriptive shorthand for the implemented visual system, not a user quotation. The interface treats pulse as one measured subject: a glossy, real 3D cartoon heart occupies the expressive field, while a large numeric reading and one-minute trend keep the data legible and honest.

The system is native, spacious, and focused rather than diagnostic. Pale lavender and plum establish the light appearance; asset-catalog counterparts preserve the same hierarchy in Dark Mode. Motion remains subordinate to fresh data and stops for stale data, pause, Reduce Motion, and privacy-safe presentation.

**Key Characteristics:**
- One kinetic sculpture, one current reading, and one recent trend.
- Adaptive plum, lavender, and pink assets with native SwiftUI controls.
- Compact portrait stacking and a separate iPad landscape split.
- Explicit demo, waiting, stale, missing-data, and privacy-safe states.

## Colors

The normative frontmatter values are the light appearances of the named Xcode color assets; their implemented Dark Mode counterparts are recorded in `.impeccable/design.json`.

### Primary
- **Action Plum:** Tints interactive controls and the capsule action.
- **Chart Plum:** Gives the trend a single, high-contrast data voice.

### Secondary
- **Heart Cherry:** Opaque named `PulseHeart` material color; light `#F02152`, dark `#FF3366`. Scene lights provide highlights and shading, not baked pixels.
- **Legacy Ribbon Palette:** Retained for the existing app icon; ribbons no longer render in the pulse field.

### Neutral
- **Lavender Ground:** Fills the screen and navigation-bar background.
- **Ink Plum:** Carries primary text and symbols.
- **Muted Plum:** Carries timestamps, demo labels, axes, and supporting text.
- **Control Lavender:** Fills the circular motion control.
- **Soft Separator:** Draws chart grids and dividers without introducing a card boundary.

**The Adaptive Palette Rule.** Use the named asset colors rather than hard-coded view colors so light and dark appearances change together.

## Typography

**Display Font:** Apple system typography (San Francisco family)
**Body Font:** Apple system typography (San Francisco family)
**Label/Mono Font:** System monospaced digits inside the current BPM, counts, and range values

**Character:** A single native family keeps the interface immediate and trustworthy. Scale, weight, and monospaced numerals—not a second typeface—create the hierarchy.

### Hierarchy
- **Display** (bold, 88pt `@ScaledMetric`): Current BPM only; the wide layout scales it by 1.15 and permits a 0.64 minimum scale factor.
- **Title** (bold Title 2): The “Last 60 seconds” heading and prominent section values.
- **Headline** (semibold Headline): Signal status, primary action, and short state labels.
- **Body** (Body): Explanatory sheet and connection copy.
- **Label** (Subheadline): Freshness, demo disclosure, axes, and supporting labels.

**The Reading First Rule.** Reserve the display scale for the current pulse value; all explanations remain in Dynamic Type styles.

## Layout

The root is a native `NavigationStack` with an inline title, a trailing watch control, and a scrolling safe-area-aware content region. Content is capped at 720pt in compact layouts and 1160pt in wide layouts, with 22pt and 34pt horizontal gutters respectively.

Compact layouts stack sculpture, reading, trend, range, and the primary action. At standard Dynamic Type, the art height is `clamp(available height - 505pt, 200pt, 270pt)`; accessibility sizes use 250pt. The chart is 138pt high normally and 250pt at accessibility sizes. The native capsule action is at least 52pt high.

Wide layout activates at width 760pt or greater when width also exceeds height by a factor of 1.04. It places the 420–590pt sculpture field on the left and a reading/trend column no wider than 520pt on the right, separated by 54pt.

## Elevation & Depth

The interface is flat outside the focal sculpture: there are no custom card shadows or stacked decorative panels. Depth comes from a watertight SceneKit triangle mesh with smooth normals and a physically based material (roughness 0.22, metalness 0.08). White key, pink rim, lavender fill, and ambient lights reveal its volume. A soft ellipse grounds it: 14pt blur, 14% light / 28% dark opacity, offset by 33% of the art-field height. The scene uses 4× antialiasing and on-demand rendering.

**The Sculpture Owns Depth Rule.** Keep surrounding controls and data surfaces visually flat so the kinetic field remains the only dimensional object.

## Shapes

The signature silhouette is a rounded cartoon love-heart, not an anatomical model. Its closed front/back mesh carries genuine volume, studio highlights, and a pointed base. It is not a flat image rotated in space. Interactive emphasis uses native capsules for the primary action and circles for icon controls; sheets, lists, navigation, and row geometry retain platform-native shapes.

## Components

### Primary Action
- **Shape:** Full-width native capsule with a 52pt minimum height.
- **Color:** Action Plum fill with Lavender Ground foreground.
- **Typography:** Native Headline.
- **Behavior:** Opens the watch-selection sheet; it does not imply a connection before selection.

### Icon Controls
- **Shape:** 44×44pt minimum target; the motion control uses a circular Control Lavender surface.
- **Icons:** SF Symbols only (`applewatch`, `pause.fill`, `play.fill`, `info.circle`, `arrow.up.left.and.arrow.down.right`, `xmark`).
- **Behavior:** The motion control freezes the sculpture only and is disabled when a fresh visible reading is unavailable or Reduce Motion is on.

### Pulse Sculpture
- **Rendering:** A custom ~4,200-vertex SceneKit mesh, driven by a main-thread SwiftUI timeline at up to 30 updates/second. No competing scene animation loop.
- **Motion:** A nonuniform squash/rebound repeats at reported BPM; phase remains continuous across rate changes. Pause, stale/missing data, Reduce Motion, privacy-safe mode, offscreen, and inactive scene stop autonomous motion. This visualizes rate, not individual beat timing.
- **Interaction:** Bounded drag rotates the geometry; Reduce Motion disables spatial drag. Expansion opens an immersive native full-screen stage using the same store and shared pause state, never another connection.
- **Accessibility:** Decorative and hidden from accessibility; the textual reading supplies meaning.

### Full-screen Heart
- **Composition:** Heart first, readable BPM and status below in portrait; heart beside the reading in landscape. Content caps at 1,400pt with 24pt horizontal gutters; accessibility sizes use a scrolling stack.
- **Controls:** Native Close and pause/play actions with 44pt minimum targets. Readings continue while motion is paused.
- **Truth:** Fresh synthetic mode says “Demo · Sample data” and “Sample signal”; stale mode says “Signal paused” with an em dash. The caption states that motion follows rate, not individual beats.

### Current Reading
- **Content:** Bold monospaced BPM digits, a smaller baseline-aligned BPM unit, state/freshness text, and an explicit demo label when synthetic.
- **Missing or private values:** Use an em dash rather than retaining a stale number.

### Recent Trend
- **Line:** 3pt Chart Plum stroke with round joins and monotone interpolation.
- **Window:** Stable 60-second x-axis labeled “60s ago” and “Now”; y-domain is padded from visible samples.
- **Gaps:** Split the line when segment identifiers change or adjacent samples are more than five seconds apart; isolated readings render as points.

### Native Sheets
- **Structure:** Navigation stacks with inline titles, grouped native lists, and a Done action.
- **Purpose:** Watch selection and factual pulse details remain focused, dismissible sub-tasks.

### App Icon
- **Asset:** A 1024×1024 opaque RGB PNG in the native app-icon asset set.
- **Image:** The existing plum, lavender, and pink ribbon family interwoven on a pale lavender ground, without text.

**The Honest Motion Rule.** Animate only from a fresh visible pulse; never use the sculpture to imply ECG timing or a current value when the signal is stale.

## Do's and Don'ts

### Do:
- **Do** keep the sculpture, current reading, trend, range, and primary watch action in one clear hierarchy.
- **Do** use named adaptive color assets, Dynamic Type, SF Symbols, 44pt controls, and native sheets.
- **Do** preserve missing-data gaps and label synthetic demo data explicitly.
- **Do** freeze motion for pause, stale data, Reduce Motion, and privacy-safe presentation.

### Don't:
- **Don't** turn the surface into a diagnostic dashboard, card grid, or notification-control panel.
- **Don't** draw ECG spikes or describe the sculpture as exact heartbeat timing.
- **Don't** display a stale or privacy-redacted BPM as current.
- **Don't** add decorative depth outside the heart sculpture.

## Garmin Watch-App Extension

This extension applies only to the foreground `fr245m` watch-app. It does not replace the iOS design system above and does not describe a Garmin system watch face.

### Direction

- Lead with a useful local clock: abbreviated date, large time that follows the device's 12/24-hour setting, fresh BPM, and a quiet state footer.
- Use the rounded cartoon heart requested by the user, not the earlier anatomical direction. Six pre-rendered sprites provide 3D-style highlight and shadow within the device palette; the watch does not render a live 3D mesh.
- Treat motion as a rate visualization. It follows reported BPM but never represents ECG timing or individually detected beats.
- Preserve the black ground, white native numerals, pink/red heart, and restrained pink, plum, and lavender accents shown in the simulator-approved states.

### Interaction and Honest Motion

- On the clock, **START** pauses or resumes heart motion. In link details only, **START** sends the existing manual link test.
- **UP** and **DOWN** toggle link details. **BACK** returns from details to the clock; from the clock, it exits normally.
- Request animation updates at about 6fps only for a fresh, visible, unpaused clock reading. Stop animation for missing or stale data, user pause, link details, and view hide.
- Retain the independent 1 Hz display refresh so stale BPM clears even after sensor events stop.
- Make no all-day or background battery claim; foreground battery cost is unmeasured.

### Review Boundary

The 2026-09-29 simulator evidence covers waiting, live, paused, stale, 12-hour, 24-hour, details, return, and exit states. Clock/phase/frame and response regressions pass 9/9. The release artifact is 19,452 bytes with SHA-256 `80bf0cb97fe0bd5d7d7ba6a74cb36efa131279b112bf435c5118c27cb0c466fb`.

A designer-available substitute review gave the scored stale-state and pause-state fixes a **Ship** disposition. That disposition is limited to those reviewed fixes, not an unqualified approval of the full watch surface.

The user selected simulator-only testing. This release has not been installed on the physical watch, so hardware performance remains unverified. The earlier ten-response iPad proof applies only to the previous watch build.
