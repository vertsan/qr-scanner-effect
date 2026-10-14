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
  lib/src/
    # ---- public surface -------------------------------------------------
    widgets/qr_scan_fx.dart               # QrScanFx widget (+ .banking(), .preset())
    widgets/scan_fx_builders.dart         # typedefs: overlay/torch/gallery/hint/confirm
    widgets/scan_fx_semantics.dart        # Semantics + announce policy
    widgets/confirmation_host.dart        # banking confirmation slot host
    controller/qr_scan_fx_controller.dart # public controller (ValueListenable<ScanFxState>)
    theme/qr_scan_fx_theme.dart           # ThemeExtension<QrScanFxTheme>
    theme/scan_fx_style.dart              # every style enum + sealed custom variants
    theme/scan_fx_motion.dart             # durations/curves/springs (motion spec)
    theme/scan_fx_tunables.dart           # intensity/speed/glow/radius (live-tunable)
    theme/scan_fx_presets.dart            # 12+ named presets
    theme/scan_fx_recipe.dart             # ScanPreset recipes (5 one-liners)
    theme/scan_fx_palette.dart            # color utils (contrast, lerp, tonal)
    # ---- geometry / input ----------------------------------------------
    geometry/scan_fx_target.dart          # rect | corners target value object
    geometry/scan_geometry_mapper.dart     # sensor space -> widget space
    geometry/scan_fx_rect.dart             # animatable quad (4 corners + rect)
    geometry/squircle.dart                # squircle/rounded-poly path math
    # ---- state machine (pure Dart, no flutter deps) ---------------------
    state/scan_fx_state.dart
    state/scan_fx_state_machine.dart
    state/scan_fx_transition_table.dart
    # ---- physics / curves (pure Dart) -----------------------------------
    physics/scan_fx_spring.dart           # SpringDescription factory + solver
    physics/scan_fx_motion_value.dart     # spring-simulated driven value
    physics/scan_fx_curves.dart           # curve catalog
    physics/scan_fx_damped_sine.dart      # shake / wobble generator
    # ---- animation core ------------------------------------------------
    animation/scan_fx_director.dart       # owns controllers, builds ScanFxFrame
    animation/scan_fx_frame.dart          # immutable per-tick snapshot
    animation/scan_fx_ambient.dart        # looping channel phases
    animation/scan_fx_revision.dart       # repaint revision counter
    # ---- layer system --------------------------------------------------
    layers/scan_layer.dart                # abstract ScanLayer
    layers/scan_layer_stack.dart          # ordered/hideable/replaceable stack
    layers/scan_layer_painter.dart        # the single CustomPainter
    layers/paint/scan_paint_cache.dart    # Paint/Path/gradient cache
    layers/paint/scan_glow.dart           # shader-or-blur glow abstraction
    layers/paint/scan_squircle_clip.dart  # feathered cutout path
    # ---- backdrop (widget + optional paint) -----------------------------
    layers/backdrop/*.dart                # solid_dim, blurred_frost, vignette, ...
    # ---- frame + corners ------------------------------------------------
    layers/frame/*.dart
    layers/corners/*.dart
    # ---- beam -----------------------------------------------------------
    layers/beam/*.dart
    # ---- reticle (lock styles) ------------------------------------------
    layers/reticle/*.dart
    # ---- effects (success / error) --------------------------------------
    layers/effects/success/*.dart
    layers/effects/error/*.dart
    # ---- idle motion ----------------------------------------------------
    layers/idle/*.dart
    # ---- banking --------------------------------------------------------
    banking/banking_recipe.dart
    # ---- diagnostics ----------------------------------------------------
    diagnostics/scan_fx_profiler.dart     # debug-only frame budget probe
  shaders/glow.frag                       # optional FragmentShader glow
  example/                                # Style Studio + banking_demo
  test/  test/golden/  test/compat/
  doc/                                    # these documents
  screenshots/                            # hero GIF + WebP previews
```

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
- Default order: `backdrop → frame → corners → beam → reticle → effects → hint`.
- `ScanLayerPainter` is the only `CustomPainter` in the tree. It iterates the
  stack; `shouldRepaint` returns `oldDelegate.revision != revision ||
  oldDelegate.stack != stack || oldDelegate.size != size`.

### Style → implementation mapping

Every style is an enum variant resolving to a concrete layer via a `switch`
(single source of truth in `theme/scan_fx_style.dart` → `scan_fx_registry.dart`
helpers). `custom(...)` variants carry a user `Path`/`CustomPainter`.

| Category | Variants | Implemented in | LOC target |
|---|---|---|---|
| Frame shape | `roundedSquare, squircle, circle, hexagon, diamond, cornersOnly, fullBorder, dashedBorder, bracketsThin, bracketsBold, viewfinderCross, custom(Path)` | `layers/frame/<style>.dart` | ≤ 45 each |
| Corner style | `rounded, sharp, chamfered, dot, pill, doubleLine, glowing, animatedDraw` | `layers/corners/<style>.dart` | ≤ 45 |
| Beam | `line, softGradientBar, glowingLaser, doubleLaser, radar, gridScan, dotMatrix, waveform, pulseRings, aurora, none` | `layers/beam/<style>.dart` | ≤ 50 |
| Backdrop | `solidDim, blurredFrost, vignette, gradientFade, animatedNoise, spotlight, none` | `layers/backdrop/<style>.dart` | ≤ 45 |
| Lock | `springSnap, smoothMorph, zoomIn, pulseLock, bracketCollapse, ringContract, scanlineSweepOver, particleBurst, glitchLock, none` | `layers/reticle/<style>.dart` | ≤ 50 |
| Success | `checkMorph, rippleBurst, confettiMini, glowFlash, colorWash, cornersFlash, hapticOnly, none` | `layers/effects/success/<style>.dart` | ≤ 45 |
| Error | `shake, redPulse, crossMorph, fadeBlink, none` | `layers/effects/error/<style>.dart` | ≤ 40 |
| Idle | `breathing, floating, shimmer, still` | `layers/idle/<style>.dart` | ≤ 35 |

`cornersOnly`/`bracketsThin`/`bracketsBold`/`fullBorder`/`dashedBorder` reuse the
`corners` opacity channel; `frame` and `corners` are separate layers so any frame
can pair with any bracket style (e.g. `circle` + `bracketsBold`).

**Idle styles are modifiers, not layers.** `ScanFxIdleMotion` feeds the ambient
phase into the frame quad transform (`breathing` = scale 1±0.012; `floating` =
±3px translate; `shimmer` = moving specular stop; `still` = identity). Keeping them
as modifiers is what makes "every combination works" true — idle never conflicts
with a frame style.

### Beam options

`ScanBeamOptions(direction, motion, speed, thickness, trail, curve)`
- `direction`: `vertical, horizontal, diagonal, radial` (honors `TextDirection`).
- `motion`: `loop, pingPong, random`.
- `trail`: `0..1` fade length behind the head.
- `curve`: which easing shapes the head's position curve.

Lock and success options follow the same pattern:
`ScanLockOptions(padding, cornerFollow, pulseStrength, overshoot)`,
`ScanSuccessOptions(intensity, particles, duration)`.

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
  QrScanFxTheme.defaults(Brightness)`. Registered globally via
  `ThemeData(extensions: [QrScanFxTheme.aurora()])`.
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

- 12+ presets: `aurora, minimalLight, neonCyber, monoGlass, sunsetGradient,
  oceanDeep, matrixGreen, roseGold, midnightPurple, bankingBlue, cleanWhite,
  highContrast`.
- 5 recipes: `QrScanFx.preset(ScanPreset.cyberpunk | appleVision | minimalBank |
  retroLaser | playfulPop)` — each is a `(theme, layerStack, tunables, options)`
  tuple, so a recipe fully determines the look in one line.

---

## 9. Banking / fintech mode

`QrScanFx.banking(...)` applies `BankingRecipe`:

| Rule | Implementation |
|---|---|
| No particles/glitch/confetti/neon | layers `particleBurst`, `glitchLock`, `confettiMini`, `animatedNoise`, `aurora`, `matrixGreen` are removed from the stack by construction, not just disabled |
| Subtle breathing frame, soft beam | `idle: breathing` @ amplitude 0.008, `beam: softGradientBar` |
| Durations < 400 ms | `ScanFxMotion.banking()` — every transition ≤ 380 ms, springs critically damped |
| Neutral blue/white/dark palette | `bankingBlue` / `cleanWhite` |
| `success` == "Code scanned" | `semanticsLabels.success = 'Code scanned'`; README states this explicitly |
| Confirmation slot | `confirmationBuilder(context, ConfirmationRequest(scanId))` shown on `locked`; the package passes **no payload**, only that a code was scanned |
| `invalid` + retry | `invalid` state + `invalidMessage` slot + `onRetry` |
| Torch + gallery on by default | default builders provided unless disabled |
| 4.5:1 contrast | `ScanFxPalette.ensureContrast` at theme construction; enforced by test |
| Large text | hint/confirmation use `TextStyle` from theme and scale with `textScaler` |

`BankingRecipe` also pins `lockHoldMs` and disables `random` beam motion — the
package must feel *calm and predictable*.

---

## 10. Accessibility

- `MediaQuery.maybeDisableAnimationsOf(context)` → `motion.reduceMotion`. Output:
  a static frame, fades ≤ 120 ms, no ambient loop, no particles. State changes
  still announced.
- `ScanFxSemantics`: `Semantics(liveRegion: true, label: labelFor(state),
  container: true)`; `SemanticsService.announce` fired **only** on state change
  (never per tick), throttled to 1 per 500 ms, respecting `MediaQuery.accessibleNavigation`.
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
- No `dart:io`, no `http`, no `shared_preferences`, no logging in the core.
- `test/security/no_payload_access_test.dart` proves it by:
  1. lints/`grep`-style source scan asserting no `dart:io`/`http`/`print`/`debugPrint`
     in `lib/` (a test that reads `lib/**` and fails on forbidden patterns), and
  2. a behavioral test: drive every controller method with a payload-looking string
     through the *only* string-accepting API (`invalid('...')`) and assert via a
     `Zone`/`print` spy that nothing is emitted, no file handles open, and the
     controller's public surface exposes only geometry.

- `doc/payment-qr-guide.md` (Phase 5) covers EMV QR validation, CRC-16/CCITT check,
  merchant/currency fields, confirmation screens, anti-spoofing UX (fake sticker
  overlays, "verify the merchant name" copy, dynamic QR + amount checks), and
  `FLAG_SECURE` / secure-screen guidance.

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
4. Glow: `ScanGlow.paint(...)` uses the optional `FragmentShader` when loaded,
   otherwise a cached `MaskFilter.blur` `Paint`. Blur sigma scales with `glow`
   tunable so demos can dial cost down.
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
| `golden` | golden | every preset + one sample per style enum variant |
| `compat` | widget test | **all** style combinations render with no exception/overflow (matrix over the 8 categories) |
| `security` | unit + source scan | §11 |

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
6. **No camera dependency in the core**; `mobile_scanner` appears in `example/` only.
7. **FragmentShader glow is optional and loadable at runtime**, with a blur fallback
   when the asset/shader isn't available (web edge cases, custom builds).

## 15. Open item for the gate

Only one, non-blocking: whether the package should live at the repo root (decision
#1) or under a nested `qr_scan_fx/` directory. Everything else is settled and
Phases 2–6 can proceed as soon as Phase 1 is approved.
