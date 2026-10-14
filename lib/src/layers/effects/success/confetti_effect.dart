import 'dart:math' as math;
import 'dart:ui' show Canvas, Color, Offset, Rect, Size;

import '../../../animation/scan_fx_frame.dart';
import '../../../theme/scan_fx_tunables.dart';
import '../scan_effect_layer.dart';

/// A short burst of paper from the locked frame.
///
/// The liveliest success style, and the one style banking mode must never use:
/// see [QrScanFxTheme.bankingBlue].
///
/// ### Why this style allocates nothing while it runs
///
/// Confetti is the one effect here that is naturally per-particle, and a
/// per-particle [Rect] would allocate on every frame of the burst. Instead the
/// particle table is generated **once** at construction and every particle is
/// drawn by transforming the canvas around a single shared unit square. Position,
/// size, rotation and the paper "flip" are all canvas transform state, so the
/// only per-particle work is a handful of doubles.
///
/// The table is deterministic (fixed seed and a fixed capacity), which keeps
/// golden tests stable. [ScanSuccessOptions.particleCount] selects how many of
/// the [capacity] particles are used.
class ConfettiEffect extends ScanSuccessEffect {
  /// Creates the style.
  ConfettiEffect() {
    _particles = _generate();
  }

  /// The number of particles generated at construction.
  ///
  /// [ScanSuccessOptions.particleCount] is clamped to this, so a theme cannot ask
  /// for a table that does not exist.
  static const int capacity = 48;

  /// Fraction of the burst a particle lives for, after its own [delay].
  static const double _life = 0.82;

  /// Downward acceleration, as a fraction of the quad's shortest side per unit
  /// of particle time.
  static const double _gravity = 1.05;

  /// The single square every particle is drawn from.
  static final Rect _unitSquare =
      Rect.fromCenter(center: Offset.zero, width: 1, height: 1);

  late final List<_Particle> _particles;

  @override
  void paint(Canvas canvas, Size size, ScanFxFrame frame) {
    final burst = successBurst(frame);
    if (burst < 0) return;

    final side = frame.quad.shortestSide;
    if (side <= 1) return;
    final center = frame.quad.center;

    final count = frame.theme.success.particleCount.clamp(0, capacity);
    if (count == 0) return;

    // Two base colours computed once per frame rather than per particle.
    final base = frame.stateColor;
    final bright = ScanFxPalette.mix(base, const Color(0xFFFFFFFF), 0.55);

    for (var i = 0; i < count; i++) {
      final p = _particles[i];

      // Under reduce-motion the burst is frozen at its own steady state: a
      // settled scatter, held rather than animated.
      final t = frame.reduceMotion ? 0.45 : (burst - p.delay) / _life;
      if (t <= 0 || t >= 1) continue;

      final alpha = (frame.reduceMotion ? 0.5 : 1 - t * t * t) *
          frame.intensity *
          frame.reveal;
      if (alpha <= 0.01) continue;

      // Ballistic position plus a gentle sinusoid, so the scatter looks like
      // paper rather than like a fountain of identical dots.
      final drift = math.sin(t * math.pi * 2 + p.phase) * 0.05;
      final x = center.dx + (p.ox + (p.vx + drift) * t) * side;
      final y = center.dy + (p.oy + p.vy * t + 0.5 * _gravity * t * t) * side;

      // The flip: the paper turns edge-on and shows its face again.
      final flip = 0.35 + 0.65 * math.cos(t * math.pi * 4 + p.phase).abs();

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.angle + p.spin * t);
      canvas.scale(p.width * side * flip, p.height * side);
      cache.fill
        ..color = ScanFxPalette.fade(p.mix > 0.5 ? bright : base, alpha)
        ..maskFilter = null;
      canvas.drawRect(_unitSquare, cache.fill);
      canvas.restore();
    }
  }

  /// Builds the deterministic particle table.
  static List<_Particle> _generate() {
    final random = math.Random(0x51F0);
    return List<_Particle>.generate(capacity, (index) {
      // Roughly every other particle flies up-left, so the burst reads as a
      // spread rather than as a beam.
      final angle = -math.pi * (0.55 + 0.9 * random.nextDouble());
      final speed = 0.25 + 0.65 * random.nextDouble();
      return _Particle(
        ox: (random.nextDouble() - 0.5) * 0.5,
        oy: (random.nextDouble() - 0.5) * 0.5,
        vx: math.cos(angle) * speed,
        vy: math.sin(angle) * speed,
        width: 0.022 + 0.028 * random.nextDouble(),
        height: 0.03 + 0.04 * random.nextDouble(),
        angle: random.nextDouble() * math.pi * 2,
        spin: (random.nextDouble() - 0.5) * 14,
        phase: random.nextDouble() * math.pi * 2,
        delay: random.nextDouble() * 0.16,
        mix: random.nextDouble(),
      );
    });
  }
}

/// One precomputed confetti particle.
///
/// Every field is a *fraction* of the frame's shortest side, so a burst scales
/// with the target and needs no rebuild when the frame is resized.
class _Particle {
  const _Particle({
    required this.ox,
    required this.oy,
    required this.vx,
    required this.vy,
    required this.width,
    required this.height,
    required this.angle,
    required this.spin,
    required this.phase,
    required this.delay,
    required this.mix,
  });

  /// Launch offset from the frame centre.
  final double ox;
  final double oy;

  /// Velocity, per unit of particle time.
  final double vx;
  final double vy;

  /// Size of the paper.
  final double width;
  final double height;

  /// Starting rotation, and how far it turns over the particle's life.
  final double angle;
  final double spin;

  /// Phase offset for the drift and the flip.
  final double phase;

  /// Fraction of the burst before this particle launches.
  final double delay;

  /// `0..1`; above `0.5` the particle takes the brighter tint.
  final double mix;
}
