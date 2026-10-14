# qr_scan_fx

A premium, canvas-drawn QR-scanner overlay for Flutter: focus frames, corner
brackets, scan beams, spring-driven lock-on, and success/error bursts — all
themed, all composable from small layers, and all built on a single ticker and a
single `CustomPaint`.

`qr_scan_fx` is a **renderer, not a scanner**. It never owns the camera, never
decodes anything, and never sees QR content. It takes **geometry only** — a
bounding box or four corner points — and returns pixels.

---

## Table of contents

- [Why it exists](#why-it-exists)
- [Install](#install)
- [Quick start](#quick-start)
- [Two ways to drive it](#two-ways-to-drive-it)
- [Keeping geometry aligned with the preview](#keeping-geometry-aligned-with-the-preview)
- [Lifecycle states](#lifecycle-states)
- [Themes](#themes)
- [Style vocabulary](#style-vocabulary)
- [Customizing the layer stack](#customizing-the-layer-stack)
- [Live tuning](#live-tuning)
- [Accessibility](#accessibility)
- [Security boundary](#security-boundary)
- [Performance](#performance)
- [Requirements](#requirements)
- [Project layout](#project-layout)
- [Testing](#testing)
- [Documentation](#documentation)
- [Status](#status)

---

## Why it exists

Most scanner overlays are a `Container` with a border and a Lottie file. That
falls apart the moment a code is rotated, the preview is cropped, a front camera
mirrors the frame, or the sensor is mounted sideways.

This package treats the overlay as a rendering problem:

- **Geometry in, pixels out.** The only input is a `ScanFxTarget` (a rect or four
  corners, optionally normalized and mirrored/rotated). There is no API that
  accepts decoded text.
- **One rigid object.** Frame, corner brackets, beam and reticle all read the
  same animatable quadrilateral, so the lock-on reads as one shape rather than
  four layers chasing each other.
- **Composable styles.** Every style is a small class behind an enum, so any
  frame pairs with any bracket style, and a new style is one file plus one arm in
  the registry.
- **Cheap by construction.** One `Ticker` for the whole overlay, one
  `CustomPaint`, allocation-free `paint()`, and a ticker that stops whenever
  nothing is moving.

---

## Install

`qr_scan_fx` has **no runtime dependencies** beyond Flutter itself. The package
is not yet on pub.dev, so depend on it from a path or git ref:

```yaml
dependencies:
  qr_scan_fx:
    path: ../qr-scanner-effect
    # or:
    # git:
    #   url: https://github.com/qr-scan-fx/qr_scan_fx.git
```

Then:

```dart
import 'package:qr_scan_fx/qr_scan_fx.dart';
```

Bring your own camera. Examples below use
[`mobile_scanner`](https://pub.dev/packages/mobile_scanner), but any source that
can produce a bounding box or four corners works.

---

## Quick start

```dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_scan_fx/qr_scan_fx.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final QrScanFxController _controller = QrScanFxController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final Barcode? code = capture.barcodes.firstOrNull;
    if (code == null) return;

    final List<Offset>? corners = code.corners;
    _controller.lockOn(
      corners != null && corners.length == 4
          ? ScanFxTarget.corners(corners, normalized: true)
          : ScanFxTarget.rect(code.boundingBox!, normalized: true),
    );

    // Your decoder — not this package — decides what the code *means*:
    // _controller.success();   // or .error(msg) / .invalid(msg)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: QrScanFx(
        controller: _controller,
        child: MobileScanner(onDetect: _onDetect),
      ),
    );
  }
}
```

Pass the camera preview as `child` and the overlay draws on top of it. When
`child` is omitted the overlay renders standalone over whatever is behind it,
which is what makes it testable and screenshot-able without a camera.

---

## Two ways to drive it

### Imperative — recommended for a real camera

Hold a `QrScanFxController` and call it from wherever detections arrive:

```dart
final controller = QrScanFxController();

controller.lockOn(ScanFxTarget.corners(points, normalized: true));
controller.success();
controller.error('That code is not supported');
controller.invalid('Unsupported QR schema');
controller.reset();

controller.pause();   // freezes all motion, stops the ticker
controller.resume();
```

This is the right choice for a live feed: geometry changes many times a second
and the spring tracks it continuously. A repeated `lockOn` only refreshes the
geometry — it never restarts the lock-on hold, so an overlay driven by a 30 fps
detector still reaches `locked`.

The controller is both a `ChangeNotifier` and a
`ValueListenable<ScanFxState>`, so it works with `AnimatedBuilder`,
`ValueListenableBuilder` and the widget's `onStateChanged` callback.

### Declarative — recommended for tests and previews

Pass `state` (and optionally geometry) and let the widget do the calling:

```dart
QrScanFx(
  state: ScanFxState.locked,
  detectedBounds: const Rect.fromLTWH(0.25, 0.25, 0.5, 0.5),
  normalized: true,
  child: preview,
)
```

`state` is authoritative while it is non-null; setting it back to `null` leaves
the overlay wherever the controller last was. The two modes can be combined:
`state` decides the lifecycle while `detectedBounds` / `detectedCorners` keep the
quad tracking.

---

## Keeping geometry aligned with the preview

This is where scanner overlays usually break. Supply the sensor resolution and
the same fit mode your preview widget uses, and the package does the rest:

```dart
QrScanFx(
  controller: controller,
  sensorSize: const Size(1920, 1080), // the frame that produced the detection
  previewFit: BoxFit.cover,           // must match your preview widget
  flipX: true,                        // front-camera previews
  quarterTurns: 1,                    // sensor orientation vs. preview
  child: MobileScanner(controller: camera, fit: BoxFit.cover, ...),
)
```

- `normalized: true` — coordinates are `0..1` relative to the sensor frame
  (the usual case for web and for plugins that report relative bounds).
- `flipX` / `flipY` — bridge front-camera mirroring.
- `quarterTurns` (0–3) — bridge sensor rotation.
- `sensorSize` + `previewFit` — keep the overlay aligned with a cropped or
  letterboxed preview (`cover` and `contain` are both handled).

When `sensorSize` is omitted, detection coordinates are treated as already
living in overlay space.

The mapping is a pure, unit-tested function and is also public if you want to
draw your own geometry from the same numbers:

```dart
final mapper = ScanGeometryMapper(
  sensorSize: const Size(1920, 1080),
  overlaySize: const Size(390, 844),
);
final ScanFxQuad? quad = mapper.map(
  ScanFxTarget.corners(points, normalized: true),
);
```

Corners do not need to be ordered. They are sorted into a stable convex ring so
rotated and perspective-skewed codes frame exactly, and so the lock-on animation
never twists.

---

## Lifecycle states

```
idle ──► scanning ──► detected ──► locked ──► success
                        │            │
                        └────────────┴────────► error
                        └────────────┴────────► invalid
any ──► reset() ──► scanning
```

| State | Meaning |
| --- | --- |
| `idle` | No scan session started. Ambient motion only. |
| `scanning` | Session active, no target tracked. Beam is sweeping. |
| `detected` | A target was located; the focus animation is running. |
| `locked` | The focus settled. The steady "target acquired" state. |
| `success` | A successful read. |
| `error` | A read failed. |
| `invalid` | The code was read but the host refuses it. |

`detected` is **transient** with `autoLock: true` (the default): after a short
hold it promotes itself to `locked`. Set `autoLock: false` to keep `detected`
sticky and drive the transition yourself. `success`, `error` and `invalid` hold
their final frame until `reset()` or a new `lockOn()`.

Levelling the transition rules is a pure Dart state machine
(`ScanFxStateMachine`), importable and testable without pumping widgets. Illegal
transitions are ignored rather than thrown, so a noisy detector can never crash a
host app.

`pause()` / `resume()` are orthogonal to state: they freeze the tickers and keep
the last frame, and `isPaused` is exposed as a separate listenable.

---

## Themes

`QrScanFxTheme` is a `ThemeExtension`, so it can be installed app-wide and
overridden per widget. Resolution order inside the overlay:

1. `QrScanFx(theme: ...)` — per-widget override wins.
2. `Theme.of(context).extension<QrScanFxTheme>()` — the app-wide theme.
3. `QrScanFxTheme.dark` / `QrScanFxTheme.light` — by ambient brightness.

```dart
MaterialApp(
  theme: ThemeData(
    extensions: const <ThemeExtension<dynamic>>[
      QrScanFxTheme.bankingBlue,
    ],
  ),
  // ...
);
```

Built-in themes and factories:

- `QrScanFxTheme.dark` — tuned for a camera preview at night (the default).
- `QrScanFxTheme.light` — tuned for bright environments and light shells.
- `QrScanFxTheme.bankingBlue` — calm, neutral, critically damped, every
  duration under 400 ms, neutral wording ("Code scanned").
- `QrScanFxTheme.fromColorScheme(scheme)` — derives a theme from a Material 3
  `ColorScheme`.
- `QrScanFxTheme.random(seed: 42)` — a deterministic palette for demos.

Every theme exposes color, stroke, shape, style, motion, tunable, typography and
semantics-label groups, with a full `copyWith`, value equality and `lerp`.
Colours created through `fromColorScheme` / `random` are passed through
`ScanFxPalette.ensureContrast`, so overlay text clears WCAG AA rather than hoping
for it.

```dart
QrScanFx(
  controller: controller,
  theme: QrScanFxTheme.dark.copyWith(
    cornerColor: Colors.amber,
    frameShape: ScanFrameShape.squircle,
    beamStyle: ScanBeamStyle.glowingLaser,
    motion: ScanFxMotion.banking,
  ),
)
```

---

## Style vocabulary

Styles are plain enums, which keeps themes `const`-friendly and makes exhaustive
switches (and therefore golden coverage) possible.

| Category | Values |
| --- | --- |
| Frame shape | `roundedSquare`, `squircle`, `circle`, `cornersOnly` |
| Corner brackets | `rounded`, `sharp`, `dot` |
| Beam | `line`, `softGradientBar`, `glowingLaser` |
| Backdrop | `solidDim`, `blurredFrost`, `vignette`, `gradientFade`, `none` |
| Lock-on | `springSnap`, `smoothMorph`, `zoomIn`, `none` |
| Success | `checkMorph`, `colorWash`, `glowFlash`, `none` |
| Error | `shake`, `redPulse`, `fadeBlink`, `none` |
| Idle motion | `breathing`, `floating`, `shimmer`, `still` |

`frameShape` and `cornerStyle` are independent layers, so a `circle` frame can
pair with `sharp` brackets. Idle motion is a *modifier* applied to the shared
quad rather than a layer, so it can never conflict with a frame style.

Finer control lives in option objects on the theme — `ScanBackdropOptions`,
`ScanBeamOptions`, `ScanLockOptions`, `ScanSuccessOptions`, `ScanErrorOptions`:

```dart
theme: QrScanFxTheme.dark.copyWith(
  beam: const ScanBeamOptions(
    direction: ScanBeamDirection.diagonal,
    motion: ScanBeamMotion.pingPong,
    period: Duration(milliseconds: 1800),
    thickness: 3.5,
    trail: 0.4,
    glow: 0.8,
  ),
  lock: const ScanLockOptions(padding: 16, cornerFollow: 0.85),
  backdrop: const ScanBackdropOptions(feather: 22, dimOpacity: 0.6),
)
```

---

## Customizing the layer stack

The overlay is drawn as an ordered stack. The default order is:

```
backdrop → frame → corners → beam → reticle → success → error → hint
```

The `layers` builder receives the default stack and may reorder, hide, replace or
extend it. Every mutator returns a **new** immutable stack.

```dart
QrScanFx(
  controller: controller,
  layers: (context, stack) => stack
      .hide(ScanLayerKind.hint)
      .replace(ScanLayerKind.beam, MyBeam())
      .insert(3, CustomScanLayer(MyPainter(), layerKind: ScanLayerKind.reticle)),
  child: preview,
)
```

To write your own visuals, subclass `ScanLayer` (one class per style):

```dart
class MyBeam extends ScanLayer {
  @override
  ScanLayerKind get kind => ScanLayerKind.beam;

  @override
  void paint(Canvas canvas, Size size, ScanFxFrame frame) {
    // Mutate cached Paint/Path objects — never allocate inside paint().
  }
}
```

Layers can also contribute a widget under the painter (`buildEffect`, used for a
real `BackdropFilter` frost) or above it (`buildOverlay`, used for the hint pill).
Host-facing text stays a widget so it inherits locale, text scaling and font
fallback from the host app for free.

---

## Live tuning

`ScanFxTunables` holds the knobs a host may want to change at runtime **without
resetting the animation** — the director picks them up on the next tick. Nullable
fields are overrides: `null` means "use the theme value".

```dart
controller.setTunables(
  controller.tunables.copyWith(intensity: 0.8, speed: 1.5, glow: 0.4),
);
```

| Knob | Range | Effect |
| --- | --- | --- |
| `intensity` | `0..1` | Scales alpha, glow and padding. |
| `speed` | `0.25..3` | Divisors every duration; current progress is preserved. |
| `glow` | `0..1` (or `null`) | Bloom strength; `0` removes the blur pass. |
| `cornerRadius` | px (or `null`) | Frame corner radius override. |
| `beamThickness` | px (or `null`) | Beam thickness override. |
| `blurSigma` | px (or `null`) | Frosted-backdrop blur; `0` degrades to a flat dim. |

`tunablesListenable` lets a host rebuild only when tuning changes. The same
values can be seeded per widget with `QrScanFx(tunables: ...)`.

---

## Accessibility

- **Reduce motion.** `MediaQuery.disableAnimationsOf(context)` is honored: the
  ambient loop stops, every duration is capped, springs settle in a few frames,
  and the same code path still runs — terminal effects render to their steady
  state instead of fading to nothing. State changes are still announced.
- **Screen readers.** The lifecycle state is exposed as a
  `Semantics(liveRegion: true, container: true)` whose label comes from the
  theme, so announcements are driven by the platform rather than by imperative
  calls — the variant that behaves consistently on Android and across windows.
- **Localizable copy.** All strings live in `ScanFxSemanticsLabels` on the theme;
  none are hardcoded in painters.
- **Directionality.** Beam direction and hint placement follow `TextDirection`,
  so RTL layouts mirror correctly.

---

## Security boundary

The package has **no** API that accepts, stores, or transmits a QR payload.

- Public controller methods take `ScanFxTarget`, `Rect` or `List<Offset>` only.
- No payload string flows into any layer. The only strings are host-supplied UI
  copy (`error` / `invalid` messages, hint text, semantics labels), treated as
  opaque and never logged.
- No `dart:io`, no networking, no persistence, no analytics anywhere in `lib/`.
- `success()` means "the code was scanned" — never "the payment succeeded". The
  package does not know, and must not imply, the latter. Hosts own validation and
  any payment logic.

See `doc/architecture.md` for the full boundary and its rationale.

---

## Performance

- **Exactly one `Ticker`** for the whole overlay and **exactly one
  `CustomPaint`**, wrapped in a `RepaintBoundary`. The camera `child` is a sibling
  and is never rebuilt by our ticks.
- Layers read a shared immutable frame snapshot, so a tick repaints without
  rebuilding a single widget. Only *state* changes trigger a widget rebuild
  (a handful of times per scan, never per frame).
- **The ticker stops** when nothing is moving — in the terminal states once the
  burst is done, and for the whole duration of `pause()`.
- Layers declare `animated`; a stack of static layers stops ticking entirely.
- Cached `Paint` / `Path` / geometry live on the layer instances, which the
  overlay keeps alive across rebuilds, so `paint()` does not allocate in the
  steady state.
- The blur backdrop is the only expensive style. It is opt-in, and `blurSigma: 0`
  is the documented fast path that degrades to a flat dim.

---

## Requirements

- Dart SDK `>=3.4.0 <4.0.0`
- Flutter `>=3.19.0`
- No platform channels, no camera dependency in the package itself.

---

## Project layout

```
lib/
  qr_scan_fx.dart              # the public surface (exports only)
  src/
    animation/                 # the director + the per-tick frame snapshot
    controller/                # QrScanFxController
    geometry/                  # targets, quads, shapes, sensor→overlay mapper
    layers/                    # the layer system and every concrete style
      backdrop/ frame/ corners/ beam/ reticle/ effects/ idle/ hint/
      paint/                   # shared Paint/Path/glow caches
    physics/                   # springs, curves, timed values
    state/                     # ScanFxState + the pure Dart state machine
    theme/                     # ThemeExtension, styles, motion, tunables, labels
    widget/                    # the QrScanFx widget
test/                          # widget, state-machine and registry tests
doc/
  architecture.md              # layering, data flow, performance, security
  animation-spec.md            # the timing and spring spec
```

The public API is re-exported from `lib/qr_scan_fx.dart`. Importing that file is
all a host needs.

---

## Testing

```bash
flutter analyze
flutter test
```

The suite covers the full `idle → … → reset` lifecycle, repeated detections not
restarting the hold, declarative state reporting and geometry, rotated /
mirrored / quarter-turned targets, reduce motion, controller swapping, pause /
resume, custom layer reordering, and every registry style mapping.

---

## Documentation

- [`doc/architecture.md`](doc/architecture.md) — goals, package layout, data
  flow, state machine, layer system, theme model, security boundary, performance
  budget and testing strategy.
- [`doc/animation-spec.md`](doc/animation-spec.md) — the motion language:
  durations, curves and springs, and the reasoning behind each number.
- The library doc comment in `lib/qr_scan_fx.dart` is the entry point to the API
  reference.

---

## Status

Version `0.1.0`. The overlay, controller, state machine, theme system, layer
registry and geometry mapper are implemented and covered by tests. The package
is not published to pub.dev yet, and there is no `example/` app, `CHANGELOG.md`
or `LICENSE` file in the repository at this time.
