# qr_scan_fx — Animation & Motion Specification

> Phase 1 deliverable. Companion document: [`architecture.md`](architecture.md).
> Every number here is the value that ships as `ScanFxMotion.defaults()`.
> All durations are **milliseconds**; all durations are divided by
> `tunables.speedMultiplier` at runtime.

---

## 1. Time base

Three clocks drive everything (see architecture §6):

| Clock | Kind | Role |
|---|---|---|
| `ambient` | `AnimationController(duration: 1s)..repeat()` | one shared loop; per-channel phases derived from `t` |
| `transition` | retargeted per state change; `duration` from the table below, or spring-driven (unbounded) | frame/corner/beam/reticle morph |
| `burst` | one-shot, `from: 0`, reused | ripple/confetti/flash/shake overlays |

Per-channel phase offsets are **constants**, so `ambient` never needs a second
controller:

```
breathingPhase  = 0.00   period 3600ms   (0.2778 of the 1s clock → phase = (t*3.6) % 1)
floatingPhase   = 0.15   period 5200ms
shimmerPhase    = 0.40   period 2400ms
beamPhase       = 0.00   period per beam style (table §3)
pulseRingPhase  = 0.25   period 2000ms
radarPhase      = 0.00   period 2800ms
```

A channel's progress is `((t * (1000 / periodMs)) + phase) % 1.0`, computed with
precomputed reciprocals — no divisions or allocations in `paint()`.

---

## 2. Global motion constants

| Name | Value | Notes |
|---|---|---|
| `microFade` | 120 ms | reduce-motion fade cap |
| `standardFade` | 240 ms | generic cross-fade |
| `lockHoldMs` | 140 ms | `detected → locked` auto-advance |
| `settleEpsilon` | 0.001 | spring rest threshold |
| `maxOverlayTextMs` | 400 ms | banking hard cap (rule) |
| `annotationPolicy` | — | announcements are **implicit**: a `liveRegion` `Semantics` label that changes with the state (no `refreshGuard`; the label only changes on a real transition, and `detected`/`locked` share wording so the hold never double-speaks) |

---

## 3. Ambient loops

| Channel / style | Period | Curve / envelope | Amplitude |
|---|---|---|---|
| `idle.breathing` | 3600 ms | sine, `easeInOutSine` | scale ±0.012, glow 0.35→0.60 |
| `idle.floating` | 5200 ms | sine | translate ±3 px (banking ±2 px) |
| `idle.shimmer` | 2400 ms | sawtooth + smoothstep | specular stop sweep, alpha 0→0.35→0 |
| `idle.still` | — | identity | — |
| `beam.line` | 1600 ms | `easeInOutSine` | sweep 0→1 with trail 0.10 |
| `beam.softGradientBar` | 1900 ms | `easeInOutCubic` | sweep 0→1, trail 0.22 |
| `beam.glowingLaser` | 2000 ms | `easeInOutSine` | sweep 0→1, trail 0.30, glow 0.9 |
| `beam.doubleLaser` | 2400 ms | `easeInOutSine` | two heads 0.5 out of phase |
| `beam.radar` | 2800 ms | linear (radial) | 0→360°, leader fade 60° |
| `beam.gridScan` | 2000 ms | `easeInOutCubic` | horizontal sweep + static grid |
| `beam.dotMatrix` | 1600 ms | `easeInOutSine` | row-by-row dot ramp |
| `beam.waveform` | 2400 ms | sine ×3 harmonics | vertical position wave |
| `beam.pulseRings` | 2000 ms | `easeOutQuart` | rings 0→1, staggered 0.33 |
| `beam.aurora` | 6000 ms | layered simplex-ish (precomputed LUT) | 3 stops drifting |
| `beam.none` | — | — | — |

`motion.motion` (`loop | pingPong | random`) reshapes the head position:
`loop` = wrap, `pingPong` = triangle, `random` = smoothed value-noise with a
320 ms slew limiter so it never feels jittery.

---

## 4. State transition timeline

```
IDLE ─────► SCANNING ─┬─► DETECTED ──► LOCKED ──┬─► SUCCESS
                      │        (140ms)           ├─► ERROR
                      └────────────────────┬─────┴─► INVALID
                                           └────────► RESET ──► SCANNING
```

| # | Transition | Duration | Curve / spring | What moves |
|---|---|---|---|---|
| T1 | `idle → scanning` | 240 ms | `easeOutCubic` | frame alpha 0→1, hint slide-up 8px + fade, backdrop 0→`dimOpacity` |
| T2 | `scanning → detected` | **spring** ≈ 480 ms settle | spring **S1** | reticle morph: default area → target quad (per-corner); ambient breathing amplitude → 0 over 180 ms; beam retract 220 ms `easeInOutCubic` (span scale 1→0.15); backdrop deepen +0.13 over 260 ms |
| T3 | `detected → locked` | 220 ms | `easeOutCubic` | corner brackets converge 4px→0; frame/corner color → locked color (260 ms lerp); lock pulse **P1** fires |
| T4 | `locked → success` | 900 ms total | see §4.1 | success layer effects, then hold |
| T5 | `* → error` | 620 ms total | see §4.2 | shake + tint, then hold |
| T6 | `* → invalid` | 380 ms total | see §4.3 | calm blink + message slot, then hold |
| T7 | `any → reset` | **spring** ≈ 300 ms settle | spring **R1** | current quad → default area, tint → base, alpha → scan baseline |

`detected` is transient by default (`autoLock: true`) so T2 and T3 read as one
continuous "lock-on" to the eye: a spring morph followed by a soft bracket
convergence. With `autoLock: false`, `detected` holds indefinitely.

### 4.1 `locked → success` (T4)

| Effect | Start | Duration | Curve | Detail |
|---|---|---|---|---|
| `checkMorph` | 0 ms | 420 ms | `easeOutCubic` | path morph ✓; stroke via `PathMetric.trim` 0→1, 380 ms `easeInOutSine` |
| `glowFlash` | 0 ms | 400 ms | `easeOutQuint` | glow 0.7 → 1.5 → 0.5 (peak at t=0.22) |
| `cornersFlash` | 0 ms | 300 ms ×2 | `easeInOutSine` | corners alpha 1→0.15→1 twice |
| `colorWash` | 60 ms | 520 ms | `easeInOutCubic` | success color alpha 0→0.32→0 ✅ |
| `rippleWaves` | 0 ms | 620 ms | `easeOutCubic` | ✅ `ScanSuccessOptions.rippleWaves` rings (default 3). Each ring lives `0.68` of the burst and launches are spread evenly over the remaining `0.32` (`step = 0.32 / (n − 1)`), so the **last ring always dies exactly as the burst ends** — a fixed stagger would leave a ring on screen after the success state had moved on. Scale 1 → 1.5, alpha `(1 − t)² · 0.5` |
| `confetti` | 0 ms | 900 ms | ballistic | ✅ `ScanSuccessOptions.particleCount` pieces (default 22, table capacity 48). Each particle has its own `0..0.16` launch delay and lives `0.82` of the burst; alpha `1 − t³`; `g = 1.05·minSide` per unit of particle time. Position, size, rotation and the paper flip are **canvas transforms around one shared unit square**, so the style allocates nothing while it runs |
| `none` | — | — | — | no overlay; the frame still tints to the success colour, so success is never invisible |

`checkMorph`, `colorWash` and `glowFlash` leave a **persistent result** — the check
stays drawn and the wash stays tinted until `reset()`. `cornersFlash`,
`rippleWaves` and `confetti` are one-shot flourishes and decay back to zero, which
is why each of them multiplies its alpha by `(1 − burst)`: a burst that reaches
`1` must clear the canvas completely.

Total timeline 900 ms, then the final visual (tinted frame + check) **holds** until
`reset()`.

### 4.2 `* → error` (T5)

| Effect | Start | Duration | Curve | Detail |
|---|---|---|---|---|
| `shake` | 0 ms | 420 ms | damped sine, f=14 Hz, ζ=0.28 | x offset amplitude 10 px, y 0 |
| `redPulse` | 0 ms | 600 ms | `easeInOutSine` | 2 pulses, frame tint → error color @ 0.45 |
| `fadeBlink` | 0 ms | 240 ms ×2 | `easeInOutSine` | frame alpha 1→0.4→1 |
| `glitch` | 0 ms | 620 ms | stepped | ✅ 12 held steps over a fixed displacement table (`6/0 / 0/−3 / −4/0 / 0/+4 / 3/2` px, scaled by `shakeAmplitude / 10`) with two dropout windows (`0.16..0.22`, `0.44..0.50`). A **held step** reads as a fault; a smooth slide would read as an animation. On `invalid` the displacements are dropped and only the tint remains |
| `crossMorph` | 60 ms | 360 ms | `easeOutCubic` | ✕ stroke draw-in (`PathMetric`, 340 ms), drawn through `ScanFxShapes.quadPoint` so it follows rotation and perspective |
| `none` | — | — | — | no overlay; the frame still tints to the error colour |

`fadeBlink`, `redPulse` and `crossMorph` fade out with `(1 − burst)`; the frame
tint is what remains. Fault effects are shared with `invalid` and read
`frame.stateColor`, so a style never hard-codes red.

### 4.3 `* → invalid` (T6, banking-grade calm)

| Effect | Start | Duration | Curve | Detail |
|---|---|---|---|---|
| `invalidTint` | 0 ms | 240 ms | `easeInOutCubic` | frame → neutral amber/blue, **no shake** |
| `fadeBlink` | 0 ms | 200 ms ×1 | `easeInOutSine` | single soft blink |
| message slot | 80 ms | 220 ms | `easeOutCubic` | slide-up 10 px + fade in |

Banking rule: never shake, never flash red-on-white, never exceed 400 ms.

### 4.4 Lock-on flourishes (T2/T3) — the "AI focus"

The lock-on is split in two, so a theme can change the *feel* without changing
the *confirmation*:

| Part | Owned by | Behaviour |
|---|---|---|
| **focus flourish** | `ScanLockStyle` | the shape that moves while the spring is in flight |
| **confirmation ring** | `ScanReticleLayer` (always) | the single expanding ring fired once the spring settles (P1) |

Because the ring is drawn by the shared base rather than by each style, the
`pulseStrength` knob turns it off in one place and no style can forget it.

| `ScanLockStyle` | Flourish | Reads | Spring |
|---|---|---|---|
| `springSnap` | `FocusBracketReticle` | `focusRaw` | S1 |
| `smoothMorph` | `MorphReticle` | `focus` | S2 (critically damped) |
| `zoomIn` | `ZoomReticle` | `focusRaw` | S4 |
| `pulseLock` | `PulseLockReticle` | `focus` | S7 ✅ |
| `ringContract` | `RingContractReticle` | `focusRaw` | S5 ✅ |
| `scanlineSweepOver` | `ScanlineSweepOverReticle` | `focus` | S1 |
| `particleBurst` | `ParticleBurstReticle` | `focus` | S7 ✅ |
| `glitchLock` | `GlitchLockReticle` | `focusRaw` | S8 ✅ |
| `none` | — | — | — |

Every flourish obeys the same contract as `FocusBracketReticle`: it draws only
while `frame.hasTarget` is true, and its envelope fades to zero at `focus = 1`,
so the whole family is silent once the lock has landed. `pulseLock` is the
exception that proves the rule — it *is* the confirmation ring, so it delegates
entirely to the shared `ScanReticleLayer` pulse and paints no flourish of its own
(`animated => false`).

**`FocusBracketReticle` — the signature effect.** Four brackets start
`0.16 · minSide` *outside* the minimum quad and travel inwards, landing exactly on
the corner layer's brackets (same arm length, same stroke width) and dissolving
in the last `0.14` of the travel. Two consequences fall out of that design:

* the two bracket families are **never on screen together** — the reticle is the
  focus animation, not extra chrome, and it is silent at `focus = 1`;
* the hand-off is invisible, because the last frame of the flourish is
  pixel-compatible with the first frame of the corner layer.

The flourish is gated on `ScanFxFrame.hasTarget`, so it only exists while a target
is actually being acquired. Because the brackets are placed from the *live*
`ScanFxFrame.quad` — which the director already morphs from the default area onto
the target — rotation, perspective and scale are handled with no per-style code.

**Why the flourish fades to nothing at `focus = 1`.** `test/scan_fx_focus_test.dart`
rasterises each flourish and counts inked pixels, asserting `0` once the lock has
landed. That test is the guard that keeps a future style from quietly stacking a
second set of brackets on the corner layer.

---

## 5. Spring values

Flutter `SpringDescription(mass, stiffness, damping)`; `ζ = damping / (2·√(k·m))`.

| ID | Name | mass | stiffness `k` | damping `c` | ζ | Settle | Overshoot | `ScanFxMotion` field | Used by |
|---|---|---|---|---|---|---|---|---|---|
| **S1** | `reticleLock` | 1 | 180 | 19.32 | 0.72 | ~480 ms | ≈ 4 % | `lockSpring` | T2 `springSnap` ✅ (`FocusBracketReticle`), `scanlineSweepOver` |
| S2 | `reticleLockCalm` | 1 | 220 | 29.66 | 1.00 | ~340 ms | 0 % | `calmLockSpring` | banking lock, `minimalBank`, `lock.smoothMorph` ✅ |
| S4 | `zoomIn` | 1 | 200 | 16.97 | 0.60 | ~420 ms | ≈ 9 % | `zoomSpring` | `lock.zoomIn` ✅ |
| S5 | `ringContract` | 1 | 260 | 25.80 | 0.80 | ~360 ms | ≈ 1.5 % | `ringSpring` | `lock.ringContract` ✅ |
| S7 | `pulseLock` | 1 | 320 | 30.00 | 0.84 | ~280 ms | ≈ 2 % | `snapSpring` | `lock.pulseLock`, `lock.particleBurst` ✅ |
| S8 | `glitchLock` | 1 | 420 | 21.00 | 0.51 | ~520 ms | ≈ 18 % | `glitchSpring` | `lock.glitchLock` (intentionally bouncy) ✅ |
| **R1** | `resetSpring` | 1 | 260 | 32.25 | 1.00 | ~300 ms | 0 % | `resetSpring` | T7 return to the default area ✅ |
| **RX** | `reducedSpring` | 1 | 2600 | 102.0 | 1.00 | ~60 ms | 0 % | `reducedSpring` | every spring under reduce-motion ✅ |

Every row exists in `ScanFxMotion` today. A style never reads a spring field
directly — `QrScanFxTheme.lockSpring` resolves reduce-motion first, then the style,
so a style can never quietly opt back out of a reduced spring, and `null`-safe
access is impossible because the switch is exhaustive over `ScanLockStyle`.

`R1` is critically damped on purpose: returning to the scan area is a *reset*, and
an overshoot there reads as an error rather than as momentum. `RX` is the
same trick at a much higher stiffness — it settles inside a few frames so the
reduce-motion path still runs the identical code with no visible spring.

Non-spring motions:

| ID | Name | Shape |
|---|---|---|
| N1 | `errorShake` | ✅ `A·e^(−t/τ)·sin(2π·f·t)`, A=10 px, τ=120 ms, f=14 Hz, 420 ms. Applied to the quad by the director, and **only** for `ScanErrorStyle.shake`; the other fault styles are pure overlays |
| N2 | `confetti` | ✅ ballistic, `g = 1.05·minSide` per unit of particle time, per-particle delay `0..0.16`, life `0.82`, alpha `1 − t³`, plus a `cos` paper flip |
| N3 | `glitchJump` | ✅ stepped offsets (`6/0 / 0/−3 / −4/0 / 0/+4 / 3/2` px) with held jumps and 2 alpha dropouts; the displacement table is scaled by `shakeAmplitude / 10` |

**P1 — lock pulse:** an expanding ring from the locked quad — r 0.5·minSide →
1.15·minSide, alpha 0.60 → 0 — driven by the director's single `pulse` value, a
**timed** `0..1` progress of `lockConverge` (220 ms, `easeOutQuint` at the layer).
It is deliberately not a spring: layers ease the progress themselves and stop
drawing the moment it reaches `1`, which is what makes the ring free once it has
landed. A sprung progress would overshoot past `1`, blink the ring off during the
overshoot and need clamping at every read site.

**Spring seeding rule:** every spring re-target is seeded from the *current* value
and *current* velocity, achieved by re-pointing a `ScanFxSpringValue`'s
`SpringDescription` at the new target (`animateTo`) — the underlying
`SpringSimulation` is re-created from the live value and velocity, which is what
makes a mid-flight `lockOn()` during `detected` feel continuous instead of
snapping. `ScanFxSpringValue` is allocation-free once constructed.

---

## 6. Easing catalog

Two small namespaces, so a style never hard-codes a magic curve:

`ScanFxEasing` (in `theme/scan_fx_motion.dart`) — the shape of a state change:

| Member | Curve | Used for |
|---|---|---|
| `start` | `Curves.easeOutCubic` | scanning → detected reveal |
| `converge` | `Curves.easeOutCubic` | lock hold / converge |
| `burst` | `Curves.easeOutQuart` | one-shot flourish launches |
| `release` | `Curves.easeInCubic` | leaving a state |
| `ambient` | `Curves.easeInOutSine` | the shared ambient loop |
| `wash` | `Curves.easeInOutCubic` | colour washes |

`ScanFxCurves` (in `physics/scan_fx_curves.dart`) — the custom shapes that
`Curves` does not provide, each a `const` `Curve` subclass with `transformInternal`
overridden and no per-call closure:

| Member | Shape | Used for |
|---|---|---|
| `smoothstep` | 3t²−2t³ | generic smooth ramp |
| `overshootSoft` | +6 % overshoot | `checkMorph`, `crossMorph` draw-in |
| `overshootStrong` | +12 % overshoot | emphatic accents |
| `anticipateOvershoot` | −7 % dip then overshoot | playful launches |

---

## 7. Lock-on geometry math (T2)

Given the mapped target quad `Q` (4 widget-space corners) and options
`ScanLockOptions(padding, cornerFollow, overshoot)`:

1. **Pad** by `padding` (default 12 logical px, scaled by `intensity`) along each
   edge normal — not a naive `inflate`, so rotated quads pad correctly.
2. **Clamp** the padded quad to the overlay bounds, preserving aspect if the target
   would exceed the safe area on one axis.
3. **Order** corners by centroid angle into a consistent ring, so a target supplied
   as `[bl, br, tl, tr]` looks identical to `[tl, tr, br, bl]`.
4. **Per-corner lerp** from the current quad to `Q` driven by S1 (or the configured
   `lockStyle` spring). `cornerFollow < 1` blends toward the axis-aligned bounding
   rect — a calmer look for banking.
5. **Perspective**: the quad is interpolated linearly per corner. Acceptance tests
   assert no self-intersection for convex inputs and a stable center for
   near-degenerate (very thin) inputs.

Beam, corners and frame all read the *same* animated quad, which is why the
lock-on reads as one object rather than four layers chasing each other.

---

## 8. Live tuning semantics

| Tunable | Range | Effect | Reset animation? |
|---|---|---|---|
| `intensity` | 0..1 | scales alpha, glow amplitude and lock padding | no |
| `speed` | 0.25..3 (clamped) | divides every *duration* in the motion spec and scales the ambient clock | no — timed values keep their elapsed progress, so the change is a speed change rather than a restart |
| `glow` | 0..1 | blur sigma / glow strength; `0` = no blur pass | no |
| `cornerRadius` | 0..0.5·minSide | path rebuilt only when the radius actually changes | no |
| `beamThickness` | 1..24 px | gradient cache invalidated on change | no |
| `blurSigma` | 0..24 | backdrop only; `0` degrades `blurredFrost` to a flat dim | no |

`speed` is deliberately **not** applied to the springs: a spring's stiffness is what
gives the lock-on its weight, and scaling it would change the *feel* rather than the
pace. Speeding the overlay up therefore tightens the cross-fades and the beam while
the lock still lands with the same overshoot.

---

## 9. Reduce-motion mapping

When `MediaQuery.disableAnimations == true`:

| Full motion | Reduce motion |
|---|---|
| ambient loops (breathing/floating/shimmer/beam) | frozen at `t = 0.35`; beam drawn as a static soft bar |
| T1 (240 ms) | 120 ms fade |
| T2 spring morph | 120 ms `easeOutCubic` quad lerp, **no overshoot** |
| T2 hold window (140 ms) | **still runs**, capped at `microFade` (120 ms) |
| T3 pulse | removed |
| T4 success (900 ms) | 200 ms `colorWash` + static check mark |
| T5 error (620 ms) | 200 ms tint to error color, no shake/flash |
| T6 invalid (380 ms) | 200 ms tint + message fade |
| `FocusBracketReticle` / `ZoomReticle` | flourish frozen at its landed state → **nothing drawn** (both are silent at `focus = 1`) |
| `confetti` | held as a static scatter at `t = 0.45`, alpha `0.5` |
| `glitch` | held as a steady in-place tint (no jumps, no dropouts) |
| `rippleWaves` | one settled ring at `1 + 0.4·expansion`, alpha `steadyState` |

An effect must never be *removed* by reduce-motion, only calmed: a burst effect
that exists purely as motion has to pick a steady state it can hold instead. That
is what the third column above records.

The cap is structural: `ScanFxMotion.effective(duration)` returns
`min(duration, microFade)` whenever reduce-motion is set, and springs fall back to
`reducedSpring` (a very stiff spring that settles in a few frames) rather than
being skipped. The same code path therefore runs; only the geometry of the motion
changes.

Reduce-motion **never removes a state transition**. In particular the
`detected → locked` hold is *not* disabled — a scanner whose state machine never
advances is broken, not calm. It is shortened to `microFade` instead.

Effects must additionally define a steady state, because the director *jumps* a
burst to its end under reduce-motion (`_feedback.jumpTo(1)`): an effect that only
"fades out" would be invisible. Each effect therefore has an explicit
`steadyState(frame, peak)` it holds instead — a wash stays tinted, a glow stays
lit, a rim stays lit.

State changes are still announced to screen readers, via the `liveRegion`
`Semantics` node whose label changes with the state (`SemanticsService.announce`
is deprecated in favour of implicit announcements, and the implicit form is the
only one that is correct across multiple windows).

---

## 10. Motion presets (recipes)

A recipe is a palette plus the styles that belong with it, resolved by
`ScanFxRecipes.theme(ScanPreset)` and applied in one line by
`QrScanFx.preset(ScanPreset.…)`. `test/scan_fx_recipe_test.dart` pins the table
below: every recipe must resolve to a distinct theme, and every resolved theme
must build a stack.

| Recipe | Base palette | Frame | Corners | Beam | Backdrop | Lock (spring) | Success | Error |
|---|---|---|---|---|---|---|---|---|
| `cyberpunk` | `neonCyber` | roundedSquare | glowing | doubleLaser | vignette | glitchLock (S8) | checkMorph | shake |
| `appleVision` | `monoGlass` | squircle (r=34) | rounded | softGradientBar | spotlight | smoothMorph (S2) | glowFlash | fadeBlink |
| `minimalBank` | `bankingBlue` | roundedSquare | rounded | softGradientBar | solidDim | smoothMorph (S2) | colorWash | fadeBlink |
| `retroLaser` | `matrixGreen` | fullBorder | sharp | line | gradientFade | scanlineSweepOver (S1) | cornersFlash | glitch |
| `playfulPop` | `roseGold` | roundedSquare | pill | pulseRings | vignette | particleBurst (S7) | confetti | crossMorph |

Idle is `breathing` for all five (the base palettes' default); a host who wants
`shimmer` or `floating` layers it on with `copyWith`, which is the whole point of a
recipe being a *theme* rather than a sealed configuration.

`banking` (not a recipe but a mode) = `minimalBank` motion + hard caps from §4 and
the layer restrictions in architecture §9.

---

## 11. Perf implications of the motion spec

- Only `_ambient` runs when idle; `_transition`/`_burst` are stopped once settled.
- After a terminal state's burst completes, `_ambient` is stopped → 0 % CPU idle.
- `pause()` stops all three tickers.
- Shake (`N1`) and glitch (`N3`) are pure offset math — no extra paint passes.
- `blurredFrost` is the only style that requires a widget-level `BackdropFilter`
  pass; documented as the expensive option with a `blurSigma: 0` fast path.
