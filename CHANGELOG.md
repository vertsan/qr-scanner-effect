# Changelog

All notable changes to this package are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project aims to
adhere to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0

The first release. `qr_scan_fx` draws a premium QR-scanner overlay; it is a
renderer, never a scanner — it receives geometry, returns pixels, and has no API
that could accept, store, log or transmit decoded content.

### Added

- **The overlay widget.** `QrScanFx` in an imperative form (drive a
  `QrScanFxController`) or a declarative form (`state` + `detectedBounds` /
  `detectedCorners`), with optional builder slots for underlays, overlays and a
  hint.
- **A five-state lifecycle with two terminals.** `idle → scanning → detected →
  locked → success | error | invalid`, driven by a pure-Dart state machine.
  `detected → locked` advances on its own after a short hold, so the lock reads as
  *focus* rather than *snap*.
- **A layer system.** Ten ordered slots — backdrop, frame, corners, beam, focus
  reticle, success, error, generic effects and hint — each independent, hideable,
  replaceable and reorderable through `ScanLayerStack`.
- **60 styles across 8 families**, mixed and matched freely: 9 frame shapes,
  8 corner treatments, 11 beams, 6 backdrops, 9 lock-on flourishes, 7 success
  effects, 6 fault effects and 4 idle motions. Every combination is supported.
- **14 presets** (`dark`, `light`, `bankingBlue`, `aurora`, `neonCyber`,
  `monoGlass`, `sunsetGradient`, `oceanDeep`, `matrixGreen`, `roseGold`,
  `midnightPurple`, `cleanWhite`, `highContrast`, `minimalLight`) plus
  `QrScanFxTheme.random()`.
- **5 one-line recipes** — `cyberpunk`, `appleVision`, `minimalBank`,
  `retroLaser`, `playfulPop` — reachable through `QrScanFx.preset`.
- **Live tuning.** `ScanFxTunables` changes intensity, speed, glow, corner radius,
  beam thickness and blur at runtime without resetting an animation in flight.
- **Banking mode.** `QrScanFx.banking()` fixes a calm theme (no particles, no
  glitch, no confetti, no neon), caps every transition under 400 ms, and adds
  three host seats: `confirmationBuilder` on success, `messageBuilder` on failure
  and `controlsBuilder` always. `ScanFxStatusNotice` is the default failure pill,
  carrying the host's message and an optional retry.
- **Accessibility.** `MediaQuery.disableAnimations` is honoured by never skipping
  a state transition — effects render to their steady state instead. The lifecycle
  is exposed as a `Semantics(liveRegion: true)` whose label is localisable through
  `ScanFxSemanticsLabels`, and beam direction and hint placement follow
  `TextDirection`.
- **Geometry mapping.** `ScanGeometryMapper` turns sensor-space detections into
  widget space for `BoxFit.cover` / `contain` previews, including mirroring,
  quarter turns and four-corner (rotated or skewed) targets.
- **A single ticker, a single `CustomPaint`.** One `Ticker` drives every animated
  layer; the paint repaints through a `Listenable` without rebuilding the widget
  tree, and the ticker stops when nothing is moving and for the duration of
  `pause()`.

### Security

- The package has **no** API that accepts, stores, logs or transmits a QR
  payload. Public controller methods take `ScanFxTarget`, `Rect` or `List<Offset>`
  only.
- The only runtime dependency is the Flutter SDK. No `dart:io`, no HTTP client,
  no persistence, no analytics, no platform channel.
- This is enforced, not just documented: `test/scan_fx_security_test.dart` reads
  every file under `lib/src/` and fails if one imports a forbidden library,
  opens a platform channel, calls `print`, or mentions decoded content at all.

### Notes

- Built for Dart `>=3.4.0` and Flutter `>=3.19.0`. Android, iOS, web, macOS,
  Windows and Linux.
- `mobile_scanner` is a **dev** dependency, used only by the camera host that
  ships with the repository (`lib/main.dart`) and by the examples. It is not part
  of the published package.
