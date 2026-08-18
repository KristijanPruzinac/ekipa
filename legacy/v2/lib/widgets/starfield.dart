import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// The living sky. A transparent overlay meant to sit on top of the
/// photographic dusk background: quiet stars of varying brightness that
/// breathe, a few warm threads finding each other (the product thesis as a
/// picture), and — the new life — shooting stars that streak and leave a
/// warm trail that fades away over a couple of seconds.
///
/// Amber here is intentional: the arrival sky is part of the warm "you're in"
/// moment, one of the two worlds ember is allowed to live in.
class Starfield extends StatefulWidget {
  const Starfield({
    super.key,
    this.starCount = 90,
    this.warmPairCount = 3,
    this.shootingStars = true,
  });

  final int starCount;
  final int warmPairCount;
  final bool shootingStars;

  @override
  State<Starfield> createState() => _StarfieldState();
}

class _StarfieldState extends State<Starfield>
    with SingleTickerProviderStateMixin {
  // Frame ticker that advances at exactly 1.0 per real second, so the
  // painter can read `_ticker.value` as elapsed seconds. A very long period
  // means it effectively never resets during a session.
  late final AnimationController _ticker = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
    upperBound: double.infinity,
  )..repeat(min: 0, max: 100000, period: const Duration(seconds: 100000));

  late final List<_Star> _stars;
  late final List<(int, int)> _pairs;
  late final List<_Streak> _streaks;

  static const _loop = 22.0; // seconds; the shooting-star schedule repeats.

  @override
  void initState() {
    super.initState();
    final rnd = Random(11);
    _stars = List.generate(widget.starCount, (i) {
      final warm = false;
      return _Star(
        dx: rnd.nextDouble(),
        // Concentrated in the top half of the sky, not spread edge-to-edge —
        // the band fades out (see _topFade) rather than stopping sharply.
        dy: rnd.nextDouble() * 0.48 + 0.02,
        r: 0.9 + rnd.nextDouble() * 2.1,
        phase: rnd.nextDouble() * pi * 2,
        speed: 0.6 + rnd.nextDouble() * 1.4,
        baseBright: 0.32 + rnd.nextDouble() * 0.58,
        warm: warm,
        glow: rnd.nextDouble() < 0.26, // more halos now that stars read bigger
      );
    });

    _pairs = [];
    for (var i = 0; i < widget.warmPairCount; i++) {
      final a = rnd.nextInt(_stars.length);
      var b = rnd.nextInt(_stars.length);
      while (b == a) {
        b = rnd.nextInt(_stars.length);
      }
      _stars[a] = _stars[a].copyWith(warm: true, glow: true);
      _stars[b] = _stars[b].copyWith(warm: true, glow: true);
      _pairs.add((a, b));
    }

    // Precompute a deterministic schedule of shooting stars across one loop.
    _streaks = List.generate(5, (i) {
      final startX = rnd.nextDouble() * 0.7 + 0.1;
      final startY = rnd.nextDouble() * 0.35 + 0.03;
      final angle = (rnd.nextDouble() * 0.5 + 0.55) * pi; // down-ish, leftward
      final len = 0.18 + rnd.nextDouble() * 0.16;
      final travel = 0.9 + rnd.nextDouble() * 0.5;
      final t0 = (i / 5) * _loop + rnd.nextDouble() * 1.6;
      return _Streak(
        startX: startX,
        startY: startY,
        angle: angle,
        length: len,
        travel: travel, // seconds the head takes to cross
        fade: 0.7, // seconds the whole streak fades after arriving
        t0: t0,
      );
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _ticker,
          builder: (context, _) {
            final t = reduceMotion ? 0.0 : _ticker.value;
            return CustomPaint(
              painter: _SkyPainter(
                stars: _stars,
                pairs: _pairs,
                streaks: widget.shootingStars && !reduceMotion ? _streaks : const [],
                t: t,
                loop: _loop,
                colors: c,
              ),
              size: Size.infinite,
            );
          },
        ),
      ),
    );
  }
}

class _Star {
  const _Star({
    required this.dx,
    required this.dy,
    required this.r,
    required this.phase,
    required this.speed,
    required this.baseBright,
    required this.warm,
    required this.glow,
  });

  final double dx, dy, r, phase, speed, baseBright;
  final bool warm, glow;

  _Star copyWith({bool? warm, bool? glow}) => _Star(
        dx: dx,
        dy: dy,
        r: r,
        phase: phase,
        speed: speed,
        baseBright: baseBright,
        warm: warm ?? this.warm,
        glow: glow ?? this.glow,
      );
}

class _Streak {
  const _Streak({
    required this.startX,
    required this.startY,
    required this.angle,
    required this.length,
    required this.travel,
    required this.fade,
    required this.t0,
  });

  final double startX, startY, angle, length, travel, fade, t0;
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({
    required this.stars,
    required this.pairs,
    required this.streaks,
    required this.t,
    required this.loop,
    required this.colors,
  });

  final List<_Star> stars;
  final List<(int, int)> pairs;
  final List<_Streak> streaks;
  final double t;
  final double loop;
  final EkipaColors colors;

  /// Smooth taper so the top-half band blends into the photo below instead
  /// of stopping in a visible line: full strength until [_fadeStart], eased
  /// out to nothing by [_fadeEnd].
  static const _fadeStart = 0.30;
  static const _fadeEnd = 0.52;
  double _topFade(double dy) {
    if (dy <= _fadeStart) return 1.0;
    return (1 - (dy - _fadeStart) / (_fadeEnd - _fadeStart)).clamp(0.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Warm threads between the "connected" stars — bolder than a
    //    hairline so the constellation motif actually reads.
    for (final (ai, bi) in pairs) {
      final a = stars[ai];
      final b = stars[bi];
      final p1 = Offset(a.dx * size.width, a.dy * size.height);
      final p2 = Offset(b.dx * size.width, b.dy * size.height);
      final fade = _topFade((a.dy + b.dy) / 2);
      final glow = (0.26 + 0.16 * sin(t * 0.8 + ai)) * fade;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..shader = ui.Gradient.linear(p1, p2, [
          colors.ember.withValues(alpha: glow),
          colors.ember.withValues(alpha: glow * 0.35),
        ]);
      canvas.drawLine(p1, p2, paint);
    }

    // 2. Twinkling stars, faded toward the bottom of their band.
    for (final s in stars) {
      final center = Offset(s.dx * size.width, s.dy * size.height);
      final tw = 0.5 + 0.5 * sin(t * s.speed + s.phase);
      final bright = (s.baseBright + 0.35 * tw).clamp(0.0, 1.0) * _topFade(s.dy);
      final color = s.warm
          ? colors.ember.withValues(alpha: bright)
          : Colors.white.withValues(alpha: bright * 0.9);
      if (s.glow) {
        canvas.drawCircle(
          center,
          s.r + 2.5,
          Paint()
            ..color = color.withValues(alpha: bright * 0.25)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5),
        );
      }
      canvas.drawCircle(center, s.r, Paint()..color = color);
    }

    // 3. Shooting stars: a bright head crossing, trailing a warm gradient
    //    line that fades out after it lands.
    final tl = t % loop;
    for (final st in streaks) {
      final life = st.travel + st.fade;
      var local = tl - st.t0;
      if (local < 0) local += loop; // allow wrap-around near the seam
      if (local < 0 || local > life) continue;

      final dir = Offset(cos(st.angle), sin(st.angle));
      final travelDist = st.length * 2.6; // total path length (normalized-ish)
      final headProg = (local / st.travel).clamp(0.0, 1.0);
      final headN = Offset(
        st.startX + dir.dx * travelDist * headProg,
        st.startY + dir.dy * travelDist * headProg,
      );
      final tailN = Offset(
        headN.dx - dir.dx * st.length,
        headN.dy - dir.dy * st.length,
      );
      final head = Offset(headN.dx * size.width, headN.dy * size.height);
      final tail = Offset(tailN.dx * size.width, tailN.dy * size.height);

      // Opacity: ramp in quickly, hold, then fade after arrival.
      double op;
      if (local < 0.15) {
        op = local / 0.15;
      } else if (local <= st.travel) {
        op = 1.0;
      } else {
        op = (1 - (local - st.travel) / st.fade).clamp(0.0, 1.0);
      }

      final trail = Paint()
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.0
        ..shader = ui.Gradient.linear(head, tail, [
          colors.ember.withValues(alpha: 0.9 * op),
          colors.ember.withValues(alpha: 0.0),
        ]);
      canvas.drawLine(head, tail, trail);

      // Glowing head.
      canvas.drawCircle(
        head,
        2.2,
        Paint()
          ..color = Colors.white.withValues(alpha: op)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter oldDelegate) => oldDelegate.t != t;
}
