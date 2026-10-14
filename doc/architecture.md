# qr_scan_fx — Architecture

> Phase 1 deliverable. This document is the build contract for Phases 2–6.
> Companion document: [`animation-spec.md`](animation-spec.md).

---

## 1. Goals and non-goals

### Goals

1. A **premium scanner overlay**: Apple Vision / Google Lens / fintech-grade motion.
2. **UI layer only** — the package never owns the camera.
3. **Zero knowledge of QR payloads.** See §11 for the enforced boundary.
4. **Zero heavy dependencies** in the core. `flutter` + `flutter_test` only.
5. **Composable style library**: every enum combination renders without exceptions,
   and every style is a small file on top of one shared base class.
6. 60/120 fps friendly, allocation-free `paint()`.

### Non-goals

- No camera, no decoding, no image processing, no platform channels.
- No network I/O of any kind.
- No payment logic, no EMV parsing. The package *documents* how to do this safely in
  a host app; it never implements it.
- No persistence. Nothing is written to disk, prefs, logs, or analytics.

---

## 2. Package layout

File-per-style is a hard rule: **a new style is a new file, under 50 lines.**
`<style>` denotes the enum variant name. Shared math lives in `geometry/`, shared
paint helpers in `layers/paint/`.

```
qr_scan_fx/
  lib/qr_scan_fx.dart                     # exports ONLY (no logic, no impl)
  lib/main.dart                           # dev-only camera host (not published API)
  lib/src/
    # ---- public surface -------------------------------------------------
    widget/qr_scan_fx.dart                # QrScanFx widget (+ .banking(), .preset())
    widget/scan_fx_status_notice.dart     # banking status pill (message + retry)
    controller/qr_scan_fx_controller.dart # public controller (ValueListenable<ScanFxState>)
    # ---- theme ----------------------------------------------------------
    theme/qr_scan_fx_theme.dart           # ThemeExtension<QrScanFxTheme> + 14 presets
    theme/scan_fx_style.dart              # every style enum + every *Options class
    theme/scan_fx_motion.dart             # durations/curves/springs (motion spec)
    theme/scan_fx_tunables.dart           # intensity/speed/glow/radius + ScanFxPalette
    theme/scan_fx_recipe.dart             # ScanPreset recipes (5 one-liners)
    theme/scan_fx_labels.dart             # localizable semantics copy
    # ---- geometry / input ----------------------------------------------
    geometry/scan_fx_target.dart          # rect | corners target value object
    geometry/scan_geometry_mapper.dart    # sensor space -> widget space
    geometry/scan_fx_quad.dart            # animatable quad (4 corners + rect)
    geometry/scan_fx_shapes.dart          # shared quad geometry helpers
    geometry/scan_frame_path.dart         # the one scan-area outline builder
    # ---- state machine (pure Dart, no flutter deps) ---------------------
    state/scan_fx_state.dart
    state/scan_fx_state_machine.dart      # trigger/transition table
    # ---- physics / curves (pure Dart) -----------------------------------
    physics/scan_fx_spring.dart           # spring-simulated driven value
    physics/scan_fx_curves.dart           # the custom curve catalog
    physics/scan_fx_timed_value.dart      # retargetable timed value
    # ---- animation core ------------------------------------------------
    animation/scan_fx_director.dart       # owns controllers, builds ScanFxFrame
    animation/scan_fx_frame.dart          # immutable per-tick snapshot
    # ---- layer system --------------------------------------------------
    layers/scan_layer.dart                # abstract ScanLayer + ScanLayerKind
    layers/scan_layer_stack.dart          # ordered/hideable/replaceable stack
    layers/scan_layer_painter.dart        # the single CustomPainter
    layers/scan_fx_registry.dart          # the one enum -> class mapping
    layers/paint/scan_paint_cache.dart    # Paint/gradient cache
    layers/paint/scan_path_cache.dart     # Path/outline cache
    layers/paint/scan_glow.dart           # glow bloom helpers (blur-based)
    # ---- one directory per category; one file per style -----------------
    layers/backdrop/*.dart                # solidDim, blurredFrost, vignette, ...
    layers/frame/*.dart                   # roundedSquare, squircle, hexagon, ...
    layers/corners/*.dart                 # rounded, sharp, dot, chamfered, ...
    layers/beam/*.dart                    # line, softGradientBar, aurora, ...
    layers/reticle/*.dart                 # springSnap, smoothMorph, glitchLock, ...
    layers/effects/success/*.dart         # checkMorph, confetti, ...
    layers/effects/error/*.dart           # shake, glitch, crossMorph, ...
    layers/idle/*.dart                    # breathing, floating, shimmer, still
    layers/hint/scan_hint_layer.dart      # the idle hint widget
  example/                                # camera-free demos (banking_demo, …)
  test/                                   # unit, widget, registry, banking, security
  doc/
    architecture.md  animation-spec.md  payment-qr-guide.md
  screenshots/                            # hero + previews (for pub.dev)
```

**Banking is not a directory.** There is no `banking_recipe.dart` because
`QrScanFx.banking()` is a factory that fixes the theme and installs the default
failure seat — the same engine, the same layers. A separate render path would be a
second thing to keep correct for no gain.

**Why `layers/backdrop/*` is special:** a true frosted backdrop needs
`BackdropFilter`, which is a *widget*, not a paint call. Each backdrop entry
implements `ScanBackdrop` (a layer) and may additionally expose
`Widget? buildEffect(BuildContext, ScanFxFrame)`. The widget composes:
`Stack(child → backdrop widgets → RepaintBoundary(CustomPaint(painter)))`.
Vignette/gradient/tint/solid-dim have **no** widget part and paint inside the
`CustomPainter`, so they cost nothing extra.

---

## 3. Data flow

```
host app (mobile_scanner / camera+MLKit / any source)
        │  raw detection: Rect bounds  OR  List<Offset> corners (sensor space)
        ▼
QrScanFxController.lockOn(bounds|corners)
        │  geometry only — payload string is never accepted by this API
        ▼
ScanGeometryMapper  ──►  ScanFxRect (widget-space quad, normalized to the overlay)
        │
        ▼
ScanFxDirector  ──(tick)──►  ScanFxFrame (immutable snapshot, rebuilt per tick)
        │                          │
        │                          ├─► ScanLayerStack.paint(canvas, size, frame)
        │                          ├─► ScanFxSemantics (announce on state change)
        │                          └─► onStateChanged(ScanFxState)
        ▼
ScanLayerPainter (single CustomPainter, RepaintBoundary-wrapped)
```

The controller is the **only** mutation entry point. The director is the only
place that owns an `AnimationController`. Layers are pure functions of
`(canvas, size, frame)`.

---

## 4. Input model

### `ScanFxTarget`

```dart
sealed class ScanFxTarget {
  const ScanFxTarget();
  factory ScanFxTarget.rect(Rect bounds, {bool normalized = false});
  factory ScanFxTarget.corners(List<Offset> corners, {bool normalized = false,
      bool flipX = false, bool flipY = false, int quarterTurns = 0});
}
```

- `rect` → axis-aligned. Mapped to 4 corners internally; identical downstream path.
- `corners` → 4 points, any order is tolerated (sorted into a convex ring by
  centroid angle), supports rotation, perspective, and non-square quads.
- `normalized: true` means coordinates are `0..1` relative to the **sensor** frame.
- `flipX/flipY/quarterTurns` bridge front-camera mirroring and sensor rotation,
  the two mistakes that break most scanner overlays.

### `ScanGeometryMapper`

Pure function, unit-tested in isolation:

```
mapRectToWidget(...)  // sensor rect + sensorSize -> widget rect
mapCorners(...)       // 4 sensor corners  -> 4 widget offsets
```

Aspect-ratio handling matches the preview's fit mode:

| Preview fit | Mapping |
|---|---|
| `BoxFit.cover` | scale = max(w/sw, h/sh); center-crop |
| `BoxFit.contain` | scale = min(...); letterbox |

Plus `sensorResolution` for exactness on web (`videoWidth/videoHeight`).

### `ScanFxRect`

The single animatable geometry primitive: `topLeft, topRight, bottomRight,
bottomLeft` as offsets, plus a lazily-derived `Rect`/`Path`. It exposes
`lerpFrom(a, b, t)` (per-corner), `scaleAbout`, `inflate`, and `applyPadding`.
All four layers that follow a target (frame, corners, beam, reticle) read the
*mapped* `ScanFxRect`, never the raw input.

---

## 5. State machine

`ScanFxState` (7 values):

```
idle ──► scanning ──► detected ──► locked ──► success
                        │            │
                        └────────────┴────────► error
                        └────────────┴────────► invalid
any ──► reset() ──► scanning (or idle when no target has ever been set)
```

- `ScanFxStateMachine` is **pure Dart** (`state/`, no `flutter/` import) so the
  transition table is testable without a pump.
- Transitions are declarative in `scan_fx_transition_table.dart`: each entry is
  `(from, to, trigger, guard, autoAdvance?)`.
- `autoAdvance` defaults: `idle→scanning` on first frame; `detected→locked` after
  `lockHoldMs` (140 ms) — so `detected` is a *transient*, and `locked` is the
  steady "target acquired" state. `autoLock: false` keeps `detected` sticky.
- Terminal states: `success`, `error`, `invalid`. They hold their final frame
  until `reset()` or a new `lockOn()` (which re-enters via `detected`).
- `pause()` / `resume()` are **orthogonal** to state: they freeze the director's
  tickers and keep the last frame. `isPaused` is exposed as a separate listenable
  so state semantics are never polluted.

Illegal transitions are ignored (and asserted in debug) rather than throwing, so a
noisy detection source can never crash a host app.

---

## 6. Controller and director

### `QrScanFxController`

`ChangeNotifier` + `ValueListenable<ScanFxState>`.

```dart
ScanFxState get value;                 // ValueListenable<ScanFxState>
ValueListenable<bool> get isPaused;
ValueListenable<double> get lockProgress;

void lockOn(ScanFxTarget target);
void success();
void error([String? message]);
void invalid([String? message]);
void reset();
void pause();  void resume();
void setTunables(ScanFxTunables);      // live, no animation reset
void attach(ScanFxDirector);           // internal, by the widget
void detach();
```

- Owns the state machine and a `ScanFxRect` *target* only.
- **No payload-bearing parameter exists anywhere on the public API.** The only
  drawable message is the host-supplied `invalid`/`error` string, which the
  package treats as opaque text it never logs.
- `setTunables` mutates a `ValueNotifier<ScanFxTunables>`; the director picks it up
  on the next tick and (for `speed`) rescales controller durations *preserving the
  current value*, so nothing jumps.

### `ScanFxDirector`

- Implemented with `TickerProviderStateMixin` on the widget's state.
- Owns **at most 3** `AnimationController`s, never one-per-layer:
  | Controller | Purpose | Lifecycle |
  |---|---|---|
  | `_ambient` | loops (`duration: 1s`, `repeat()`); drives breathing/beam/shimmer phases | created in `initState`, disposed in `dispose` |
  | `_transition` | the state morph timeline (`duration: timings(state)`; or spring-driven, unbounded) | retargeted per transition |
  | `_burst` | one-shot effect overlays (ripple/confetti/flash/shake) | reused; retriggered with `from: 0` |
- On each tick it builds one `ScanFxFrame` and bumps `_revision`.
- `speedMultiplier` rescales all three controllers' durations; spring simulations
  are re-seeded from `(value, velocity)`.
- `reduceMotion` (from `MediaQuery.disableAnimations`) swaps the timing table for
  the static variant (§ animation-spec §9).

---

## 7. Layer system

```dart
abstract class ScanLayer {
  const ScanLayer({this.kind, this.visible = true, this.opacity = 1.0});
  ScanLayerKind get kind;
  bool get wantsRepaint;                 // false => static, skipped after first paint
  void paint(Canvas canvas, Size size, ScanFxFrame frame);
  Widget? buildEffect(BuildContext context, ScanFxFrame frame) => null; // backdrop only
}

class CustomScanLayer extends ScanLayer {           // user injection
  const CustomScanLayer({required this.painter, ScanLayerKind kind = ScanLayerKind.effects});
  final CustomPainter painter;
}
```

- `ScanLayerStack` is an ordered list of `(ScanLayer, visible)`; the widget's
  `layers:` builder receives the default stack and may **reorder, hide, replace,
  or append**, e.g. `stack.replace(ScanLayerKind.beam, MyBeam())`,
  `stack.hide(ScanLayerKind.hint)`, `stack.insert(2, CustomScanLayer(...))`.
- Default order: `backdrop → frame → corners → beam → reticle → success → error →
  hint`. Success and error have **separate layer kinds** rather than sharing one
  `effects` slot, so `hide(ScanLayerKind.success)` does not also hide the fault
  burst. `effects` remains as the generic default kind for a `CustomScanLayer`.
- `ScanLayerPainter` is the only `CustomPainter` in the tree. It iterates the
  stack; `shouldRepaint` returns `oldDelegate.revision != revision ||
  oldDelegate.stack != stack || oldDelegate.size != size`.

### Style → implementation mapping

Every style is an enum variant resolving to a concrete layer via an exhaustive
`switch` in `layers/scan_fx_registry.dart`. The enums live in
`theme/scan_fx_style.dart`; each variant has exactly one file under its category
directory.

| Category | Variants | Directory | LOC budget |
|---|---|---|---|
| Frame shape | `roundedSquare, squircle, circle, cornersOnly, hexagon, diamond, fullBorder, dashedBorder, viewfinderCross` | `layers/frame/<style>.dart` | ≤ 55 each |
| Corner style | `rounded, sharp, dot, chamfered, pill, doubleLine, glowing, animatedDraw` | `layers/corners/<style>.dart` | ≤ 55 |
| Beam | `line, softGradientBar, glowingLaser, doubleLaser, radar, gridScan, dotMatrix, waveform, pulseRings, aurora, none` | `layers/beam/<style>.dart` | ≤ 60 |
| Backdrop | `solidDim, blurredFrost, vignette, gradientFade, spotlight, none` | `layers/backdrop/<style>.dart` | ≤ 55 |
| Lock | `springSnap, smoothMorph, zoomIn, pulseLock, ringContract, scanlineSweepOver, particleBurst, glitchLock, none` | `layers/reticle/<style>.dart` | ≤ 60 |
| Success | `checkMorph, colorWash, glowFlash, rippleWaves, confetti, cornersFlash, none` | `layers/effects/success/<style>.dart` | ≤ 55 |
| Error | `shake, redPulse, fadeBlink, glitch, crossMorph, none` | `layers/effects/error/<style>.dart` | ≤ 55 |
| Idle | `breathing, floating, shimmer, still` | `layers/idle/<style>.dart` | ≤ 45 |

Phase 4 filled in the vocabulary above and, in doing so, **dropped five
near-duplicates** rather than shipping them for the sake of the count:
`bracketsThin`/`bracketsBold` (the corner *style* already controls arm length and
stroke weight), `animatedNoise` (indistinguishable from `vignette` at 60 fps),
`bracketCollapse` (a slower `ringContract`), and `hapticOnly` (a success style
cannot haptically confirm anything without a third-party channel, which the package
does not take). A host who wants a `Path` frame injects it as a `CustomScanLayer`
— the same seam that has always existed — rather than through an enum variant that
would have to carry state.

The lock styles are nine *distinct* flourishes that all share one confirmation ring
drawn by `ScanReticleLayer`; see `doc/animation-spec.md` §4.4 for the per-style
flourish and the spring it rides. `glitch` is the fault style used by both `error`
and `invalid`, and it degrades to a calm in-place tint on `invalid` rather than
displacing the geometry.

**Frame shape owns the outline.** `ScanFrameLayer.shape` is authoritative, and the
director copies it into `ScanFxFrame.frameShape`; the frame stroke, the backdrop
cutout and every cached outline are all built from that one value through
`ScanFramePath.of`. This is what makes a `stack.replace(frame, …)` keep the dimmed
cutout registered with the stroked border instead of silently disagreeing with it.

**Idle styles are modifiers, not layers.** A `ScanFxIdleModifier` produces a
`ScanFxIdleTransform` that the director folds into the frame quad (`breathing` =
scale 1±0.012; `floating` = ±3px translate; `shimmer` = moving specular stop;
`still` = identity). Keeping them as modifiers is what makes "every combination
works" true — idle never conflicts with a frame style.

### Beam options

`ScanBeamOptions(direction, motion, period, thickness, trail, glow)`
- `direction`: `vertical, horizontal, diagonal, radial` (honors `TextDirection`);
  `diagonal`/`radial` set `hasBand = false` and draw rail-free.
- `motion`: `loop, pingPong, random`.
- `period`: the sweep's full cycle, pre-divided by every applied speed factor.
- `trail`: `0..1` fade length behind the head.
- `glow`: extra bloom on the head, independent of `glowStrength`.

Lock, success, error and backdrop options follow the same shape:
`ScanLockOptions(padding, cornerFollow, pulseStrength)`,
`ScanSuccessOptions(checkStrokeWidth, rippleWaves, particleCount)`,
`ScanErrorOptions(shakeAmplitude, pulseCount, crossStrokeWidth)`,
`ScanBackdropOptions(dimOpacity, deepenedOpacity, feather, blurSigma, tintOpacity)`.

---

## 8. Theme and tunables

### `QrScanFxTheme extends ThemeExtension<QrScanFxTheme>`

- `const` constructor, `copyWith` for **every** field, value equality, `lerp`.
- Groups: `colors` (frame, frameGlow, beam, backdropTint, dim, success, error,
  invalid, hintText, scrim), `alpha`/`stroke` (frameWidth, cornerWidth, beamWidth,
  glowStrength, dimOpacity, feather), `shape` (cornerRadius, frameShape, cornerStyle),
  `styles` (beamStyle, backdropStyle, lockStyle, successStyle, errorStyle, idleStyle),
  `motion` (ScanFxMotion), `tunables` (ScanFxTunables), `typography` (hint/confirm text
  styles), `semanticsLabels` (localizable strings).
- Resolution: `widget theme ?? Theme.of(context).extension<QrScanFxTheme>() ??
  QrScanFxTheme.dark|light` (by ambient `Brightness`). Register a global default
  with `ThemeData(extensions: [QrScanFxTheme.aurora])`.
- `QrScanFxTheme.fromColorScheme(ColorScheme)`: derives frame/beam/tint from
  `primary`/`surface`/`onSurface`, guaranteeing WCAG 4.5:1 for overlay text via
  `ScanFxPalette.ensureContrast`.
- `QrScanFxTheme.random({seed})`: deterministic-ish palette for demos; always runs
  through `ensureContrast`.

### `ScanFxTunables` (live-tunable, no animation reset)

`intensity (0..1)`, `speedMultiplier (>0)`, `glow (0..1)`, `cornerRadius (>=0)`,
plus `beamThickness`, `blurSigma`. Held in a `ValueNotifier`; changes are picked up
per tick. `speed` rescaling preserves progress; `cornerRadius`/`glow` are pure
paint inputs; `intensity` scales alpha and glow amplitude. All clamped, never null.

### Presets and recipes

- 14 presets — `dark, light, aurora, neonCyber, monoGlass, sunsetGradient,
  oceanDeep, matrixGreen, roseGold, midnightPurple, bankingBlue, minimalLight,
  cleanWhite, highContrast` — each a `const QrScanFxTheme`. `minimalLight` and
  `cleanWhite` are the light-room pair; `highContrast` is the WCAG stress case.
- 5 recipes: `ScanPreset { cyberpunk, appleVision, minimalBank, retroLaser,
  playfulPop }`, resolved by `ScanFxRecipes.theme(preset)` and applied in one line
  by `QrScanFx.preset(ScanPreset.…)`. A recipe is a *theme*, not a sealed bundle:
  it pins the palette and the styles that belong with it, and the host layers
  anything else on with `copyWith`. `doc/animation-spec.md` §10 is the table, and
  `test/scan_fx_recipe_test.dart` pins it.

---

## 9. Banking / fintech mode

`QrScanFx.banking(...)` is a thin factory over `QrScanFx` that fixes the theme to
`QrScanFxTheme.bankingBlue` and installs a default failure seat. It is a *theme*
choice, not a separate render path — the same engine, the same layers.

| Rule | Implementation |
|---|---|
| No particles/glitch/confetti/neon | `bankingBlue` names none of the loud styles (`success: colorWash`, `error: fadeBlink`, `lock: smoothMorph`, `beam: softGradientBar`, `backdrop: solidDim`). A theme that names no loud style cannot render one, however it is driven — and a test pins those choices |
| Subtle breathing frame, soft beam | `idle: breathing`, `beam: softGradientBar` |
| Durations < 400 ms | `ScanFxMotion.banking` — every transition ≤ 380 ms, `calmLockSpring` critically damped |
| Neutral blue/white/dark palette | `bankingBlue` |
| `success` == "Code scanned" | `labels.success = 'Code scanned'`; the README states the boundary explicitly |
| Confirmation slot | `confirmationBuilder` is built on `success` and inserted into the overlay stack. The package passes only a `BuildContext` — **no payload, no amount, no outcome** |
| `invalid` + retry | `messageBuilder` defaults to a `ScanFxStatusNotice` carrying `controller.message` plus a retry button wired to `onRetry` |
| Torch + gallery | a `controlsBuilder` seat, always built, so the host lays `mobile_scanner`'s own controls out against the frame instead of over it. The package owns no camera |
| 4.5:1 contrast | `bankingBlue` fixes the hint and state colours, and `test/scan_fx_banking_test.dart` measures `ScanFxPalette.contrastRatio` for each |
| Large text | the notice and hints are widgets using `Wrap`, so a `textScaler` of 2.0 wraps instead of clipping — pinned by a test that would surface any overflow |

The payment-specific narrative — what belongs in `confirmationBuilder`, what must
not, and where the package's responsibility ends — is
`doc/payment-qr-guide.md`.

---

## 10. Accessibility

- `MediaQuery.maybeDisableAnimationsOf(context)` → `motion.reduceMotion`. Output:
  a static frame, fades ≤ 120 ms, no ambient loop, no particles. State changes
  still announced.
- `ScanFxSemantics`: `Semantics(liveRegion: true, label: labelFor(state),
  container: true)`; the announcement is **implicit** — the label changes with the
  state, so the platform announces the transition and no imperative
  `SemanticsService.announce` (deprecated) is used. `detected` and `locked` share
  wording so the auto-lock hold never double-speaks.
- Labels are theme-localizable strings, not hardcoded: "Scanning", "Code detected",
  "Code scanned", "Invalid code".
- Layout: portrait/landscape/tablet safe areas; RTL-safe (hint slide and beam
  direction follow `Directionality`, buttons use `PositionedDirectional`).
- Web/desktop: overlay renders with no camera at all (the `child` is optional) —
  verified by a widget test on a null child.

---

## 11. Security boundary (enforced in code + test)

The package has **no** API that accepts, stores, or transmits a QR payload string.

- Public controller methods take `ScanFxTarget`/`Rect`/`List<Offset>` only.
- No `String` payload flows into any layer; the only strings are host-supplied UI
  copy (`error`/`invalid` messages, hint text) which are treated as opaque and
  never `print`ed.
- No `dart:io`, no HTTP client, no `shared_preferences`, no logging, no platform
  channel in the core. `pubspec.yaml` declares exactly one runtime dependency: the
  Flutter SDK.
- `test/scan_fx_security_test.dart` proves it against the source rather than by
  promise. It reads every file under `lib/src/` and the barrel, strips comments,
  and fails if any of them:
  1. imports `dart:io` / `dart:isolate` / `dart:ffi` / `package:flutter/services.dart`
     / an HTTP client / a webview / a camera plugin / the Firebase SDK;
  2. references `MethodChannel`, `EventChannel`, `BinaryMessenger`, `HttpClient`,
     `Socket`, `Process`, `File` or `Directory`, or calls `print` / `debugPrint` /
     `developer.log`;
  3. contains `displayValue`, `rawValue`, `barcode`, `decodedText` or
     `payloadText` in code.
  It additionally reads `pubspec.yaml` and fails if the runtime dependency list is
  anything other than `[flutter]`, and asserts that only the dev-only entrypoint
  (`lib/main.dart`) may name the camera plugin.
- A behavioural companion in the same suite constructs a controller, drives it
  through the only string-accepting API (`invalid('…')`) and asserts that the
  geometry-only surface still holds and the message is cleared as the state moves
  on.

- `doc/payment-qr-guide.md` covers the host/package boundary, the recommended
  detect→acquire→decode→validate→confirm flow, what belongs in
  `confirmationBuilder` and what must not, `invalid` vs `error` and retry,
  anti-spoofing UX (amount from *your* validated result, never the raw payload),
  and a security checklist.

---

## 12. Performance budget

Rules (verified by `scan_fx_profiler.dart` in debug and by golden/benchmark tests):

1. `paint()` allocates **nothing** — no `Paint()`, `Path()`, `List`, `Gradient`,
   `Rect` beyond cached fields. Cache lives in `ScanPaintCache`, keyed by
   `(size, radius, style, colorHash)`, invalidated on change.
2. One `CustomPainter` → one `RepaintBoundary`. The camera `child` is a sibling,
   never rebuilt by our ticks.
3. `Path` reuse: `Path.reset()` + re-`addX` only when geometry delta > 0.25 px,
   else reuse the previous `Path`.
4. Glow: `ScanGlow` uses a cached `MaskFilter.blur` `Paint`. Blur sigma scales
   with the `glow` tunable so hosts can dial cost down; `glow == 0` skips the blur
   pass entirely. There is deliberately **no `FragmentShader`**: the blur path
   meets the frame budget on every target platform, needs no per-platform shader
   asset or runtime load, and degrades to a hard-edged draw rather than failing on
   platforms where shader compilation is unavailable (a shader would have to carry
   a fallback anyway, so it would only add a second code path to keep correct).
5. Gradients (beam, aurora) are cached per size and recreated only on size change.
6. Ambient loops run on a single controller; when `state == success/error/invalid`
   and the burst is done, `_ambient` is stopped to drop idle CPU.
7. `pause()` mutes all tickers entirely (battery).
8. `shouldRepaint` is exact (revision + stack identity + size).
9. Blur backdrop is the only expensive style; it is opt-in and documented, with a
   `blurSigma: 0` fast path that degrades to `solidDim`.

Frame budget target: **≤ 4 ms** overlay paint on a mid-range Android device for
`appleVision` recipe, ≤ 8 ms for `neonCyber` with glow + particles.

---

## 13. Testing strategy

| Layer | Test type | Coverage |
|---|---|---|
| `state/` | pure unit | transition table, guards, autoAdvance, illegal transitions, pause orthogonality |
| `geometry/` | pure unit | rect/corner mapping, cover vs contain, flip, quarterTurns, normalized input, rotated/perspective quads |
| `physics/` | pure unit | spring settles within tolerance, no NaN, damping ratios match spec table |
| `controller` | unit + widget | lockOn/success/error/invalid/reset sequences, tunable live change preserves progress |
| `widget` | widget test | state→semantics label, reduce-motion static path, null child (no camera), RTL, light/dark, textScaler 2.0 |
| `banking` | unit + widget | the three seats (confirmation / message / controls), retry wiring, host-copy over fallback, 2.0 text scale with a long message, 4.5:1 contrast |
| `recipe` | unit + widget | every preset builds, every preset is distinct, `QrScanFx.preset` renders each, the resolved theme reaches the layers |
| `golden` | golden | every preset + one sample per style enum variant |
| `compat` | widget test | **all** style combinations render with no exception/overflow (matrix over the 8 categories) |
| `security` | source scan + unit | §11, in `test/scan_fx_security_test.dart` |

CI (`.github/workflows/ci.yaml`): `dart format --set-exit-if-changed`,
`flutter analyze` (package + example, zero issues), `flutter test`,
`dart pub publish --dry-run`, `pana` (target 160/160).

---

## 14. Decisions taken in Phase 1

1. **Package root = this folder** (`D:\web\qr-scanner-effect`), not a nested
   `qr_scan_fx/` subfolder. `pubspec.yaml` declares `name: qr_scan_fx`, which is what
   pub.dev uses. *Say the word at this gate if you want a nested folder instead.*
2. **At most 3 `AnimationController`s**, not one per layer.
3. **Idle styles are modifiers**, not layers, so combinations can't conflict.
4. **`detected` is transient** (`autoLock` default true) — matches how Vision/Lens
   feel; `detected` remains sticky when `autoLock: false`.
5. **Backdrop is a hybrid** widget+layer (needed for real frosted blur).
6. **No camera dependency in the core.** `mobile_scanner` is a *dev* dependency,
   used only by the dev-only camera host at `lib/main.dart`. Nothing importable
   from the barrel may reach it — asserted by `test/scan_fx_security_test.dart`.
7. **Glow is a cached blur, never a `FragmentShader`.** The blur path meets the
   frame budget on every platform, needs no shader asset or runtime load, and
   degrades gracefully; a shader would have to carry an equivalent fallback and
   would only add a second code path to keep correct.
8. **Banking is a factory, not a mode.** `QrScanFx.banking()` fixes the theme and
   installs the default failure seat; there is no second render path.
9. **Host slots are `Builder`s inserted into the overlay stack.** Confirmation,
   message and controls are the host's, so the package passes a `BuildContext`
   and nothing else — no payload, no outcome.

## 15. Deliberate non-goals

Recorded so a later pass does not "finish" them by accident:

- No `FragmentShader` glow (§14.7).
- No `banking/` subtree (§14.8) and no `BankingRecipe` type.
- No `path_provider` / `shared_preferences` / analytics, ever (§11).
- No `detected → locked` transition removal under reduce motion: reduce motion
  shortens the hold, it never skips a state.
