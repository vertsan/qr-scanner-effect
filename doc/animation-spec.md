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
| `refreshGuard` | 500 ms | min spacing between semantics announcements |

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
| T7 | `any → reset` | 300 ms | `easeInOutCubic` | current quad → default area, tint → base, alpha → scan baseline |

`detected` is transient by default (`autoLock: true`) so T2 and T3 read as one
continuous "lock-on" to the eye: a spring morph followed by a soft bracket
convergence. With `autoLock: false`, `detected` holds indefinitely.

### 4.1 `locked → success` (T4)

| Effect | Start | Duration | Curve | Detail |
|---|---|---|---|---|
| `checkMorph` | 0 ms | 420 ms | `easeOutCubic` | path morph ✓; stroke via `PathMetric.trim` 0→1, 380 ms `easeInOutSine` |
| `glowFlash` | 0 ms | 400 ms | `easeOutQuint` | glow 0.7 → 1.5 → 0.5 (peak at t=0.22) |
| `cornersFlash` | 0 ms | 300 ms ×2 | `easeInOutSine` | corners alpha 1→0.15→1 twice |
| `colorWash` | 60 ms | 520 ms | `easeInOutCubic` | success color alpha 0→0.35→0 |
| `rippleBurst` | 80 ms | 620 ms | `easeOutQuart` | 2 waves, stagger 160 ms, start r = 0.35·minSide |
| `confettiMini` | 120 ms | 900 ms | gravity + `easeOutCubic` | 12 pieces, 1.6× frame size spread, rotation ±540° |

Total timeline 900 ms, then the final visual (tinted frame + check) **holds** until
`reset()`.

### 4.2 `* → error` (T5)

| Effect | Start | Duration | Curve | Detail |
|---|---|---|---|---|
| `shake` | 0 ms | 420 ms | damped sine, f=14 Hz, ζ=0.28 | x offset amplitude 10 px, y 0 |
| `redPulse` | 0 ms | 600 ms | `easeInOutSine` | 2 pulses, frame tint → error color @ 0.45 |
| `fadeBlink` | 0 ms | 240 ms ×2 | `easeInOutSine` | frame alpha 1→0.4→1 |
| `crossMorph` | 60 ms | 360 ms | `easeOutCubic` | ✕ stroke draw-in (`PathMetric`, 340 ms) |

### 4.3 `* → invalid` (T6, banking-grade calm)

| Effect | Start | Duration | Curve | Detail |
|---|---|---|---|---|
| `invalidTint` | 0 ms | 240 ms | `easeInOutCubic` | frame → neutral amber/blue, **no shake** |
| `fadeBlink` | 0 ms | 200 ms ×1 | `easeInOutSine` | single soft blink |
| message slot | 80 ms | 220 ms | `easeOutCubic` | slide-up 10 px + fade in |

Banking rule: never shake, never flash red-on-white, never exceed 400 ms.

---

## 5. Spring values

Flutter `SpringDescription(mass, stiffness, damping)`; `ζ = damping / (2·√(k·m))`.

| ID | Name | mass | stiffness `k` | damping `c` | ζ | Settle | Overshoot | Used by |
|---|---|---|---|---|---|---|---|---|
| **S1** | `reticleLock` | 1 | 180 | 19.32 | 0.72 | ~480 ms | ≈ 4 % | T2 `springSnap`, `appleVision` |
| S2 | `reticleLockCalm` | 1 | 220 | 29.66 | 1.00 | ~340 ms | 0 % | banking lock, `minimalBank` |
| S3 | `successSnap` | 1 | 240 | 22.00 | 0.71 | ~380 ms | ≈ 4.5 % | success frame settle |
| S4 | `zoomIn` | 1 | 200 | 16.97 | 0.60 | ~420 ms | ≈ 9 % | `lock.zoomIn` scale |
| S5 | `ringContract` | 1 | 260 | 25.80 | 0.80 | ~360 ms | ≈ 1.5 % | `lock.ringContract` radius |
| S6 | `bracketCollapse` | 1 | 300 | 24.25 | 0.70 | ~300 ms | ≈ 5 % | `lock.bracketCollapse` inset |
| S7 | `pulseLock` | 1 | 320 | 30.00 | 0.84 | ~280 ms | ≈ 2 % | **P1** lock pulse scale |
| S8 | `glitchLock` | 1 | 420 | 21.00 | 0.51 | ~520 ms | ≈ 18 % | `lock.glitchLock` (intentionally bouncy) |

Non-spring motions:

| ID | Name | Shape |
|---|---|---|
| N1 | `errorShake` | `A·e^(−t/τ)·sin(2π·f·t)`, A=10 px, τ=120 ms, f=14 Hz, 420 ms |
| N2 | `confetti` | linear velocity + `g = 1400 px/s²`, landing at t=0.45 of the burst |
| N3 | `glitchJump` | 3 stepped offsets (6/0/−4 px) with 40 ms holds + 2 alpha dropouts |
| N4 | `resetReturn` | `easeInOutCubic`, 300 ms, quad lerp |

**P1 — lock pulse:** scale 1 → 1.06 → 1.0 via S7, plus an expanding ring from the
locked quad: r 0.5·minSide → 1.15·minSide, alpha 0.60 → 0, 400 ms `easeOutQuint`.

**Spring seeding rule:** every spring re-target is seeded from the *current* value
and *current* velocity. `ScanFxMotionValue.fromSpring(desc, initialValue, initialVelocity)`
then `animateWith(controller)`. This is what makes a mid-flight `lockOn()` during
`detected` feel continuous instead of snapping.

---

## 6. Easing catalog (`physics/scan_fx_curves.dart`)

`easeOutCubic`, `easeInCubic`, `easeInOutCubic`, `easeOutQuart`, `easeOutQuint`,
`easeInOutSine`, `easeOutExpo`, `easeOutCirc`, `easeOutBack(1.70158)`,
`anticipate(1.70158)`, `easeOutElastic(period: 0.3)`, `overshoot(amount)`,
`dampedSine(freq, damping)`, `smoothstep`, `steps(n, jump: hold)`.

All are implemented as `Curve` subclasses (or `Curve` adaptations of the existing
ones) with `transformInternal` overridden, no closures per call.

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
| `intensity` | 0..1 | scales alpha, glow amplitude, padding, particle count | no |
| `speedMultiplier` | 0.25..3 (clamped) | divides all durations; spring `dt` scaled | no — progress preserved, springs re-seeded |
| `glow` | 0..1 | blur sigma / shader intensity; `0` = no blur pass | no |
| `cornerRadius` | 0..0.5·minSide | path rebuild only when delta > 0.25 px | no |
| `beamThickness` | 1..24 px | gradient cache invalidated on change | no |
| `blurSigma` | 0..24 | backdrop only; `0` degrades `blurredFrost` → `solidDim` | no |

`speedMultiplier` implementation detail: `duration = base / multiplier`, and if the
controller is mid-flight we set `duration` then re-`forward()` from the current
`value` — visually continuous.

---

## 9. Reduce-motion mapping

When `MediaQuery.disableAnimations == true`:

| Full motion | Reduce motion |
|---|---|
| ambient loops (breathing/floating/shimmer/beam) | frozen at `t = 0.35`; beam drawn as a static soft bar |
| T1 (240 ms) | 120 ms fade |
| T2 spring morph | 120 ms `easeOutCubic` quad lerp, **no overshoot** |
| T3 pulse | removed |
| T4 success (900 ms) | 200 ms `colorWash` + static check mark |
| T5 error (620 ms) | 200 ms tint to error color, no shake/flash |
| T6 invalid (380 ms) | 200 ms tint + message fade |
| particles / confetti / glitch | not painted at all |

State changes are still announced to screen readers.

---

## 10. Motion presets (recipes)

| Recipe | Idle | Lock (spring) | Beam | Success | Feel |
|---|---|---|---|---|---|
| `appleVision` | breathing | S1 + pulseLock | softGradientBar | glowFlash + checkMorph | clean, dimensioned, calm |
| `cyberpunk` | shimmer | S1 + glitchLock | glowingLaser | confettiMini | loud, fast, neon |
| `minimalBank` | breathing (0.008) | S2 (critical) | softGradientBar | colorWash | quiet, trustworthy |
| `retroLaser` | still | S1 + scanlineSweepOver | doubleLaser | cornersFlash | CRT / arcade |
| `playfulPop` | floating | S3 + pulseLock | pulseRings | rippleBurst | soft, bouncy, toy-like |

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
