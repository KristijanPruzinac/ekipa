import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// The ambient background: quiet, isolated dots in the dark, a few of them
/// warmly finding each other. This is the product thesis as a picture —
/// coordination failure, then a little light.
class ConstellationField extends StatefulWidget {
  const ConstellationField({
    super.key,
    this.dotCount = 60,
    this.warmPairCount = 3,
  });

  final int dotCount;
  final int warmPairCount;

  @override
  State<ConstellationField> createState() => _ConstellationFieldState();
}

class _ConstellationFieldState extends State<ConstellationField>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  )..repeat();

  late final List<_Dot> _dots;
  late final List<(int, int)> _pairs;

  @override
  void initState() {
    super.initState();
    final rnd = Random(7);
    _dots = List.generate(widget.dotCount, (i) {
      return _Dot(
        dx: rnd.nextDouble(),
        dy: rnd.nextDouble() * 0.85 + 0.05,
        r: 1 + rnd.nextDouble() * 1.3,
        phase: rnd.nextDouble() * pi * 2,
        warm: false,
      );
    });
    _pairs = [];
    for (var i = 0; i < widget.warmPairCount; i++) {
      final a = rnd.nextInt(_dots.length);
      var b = rnd.nextInt(_dots.length);
      while (b == a) {
        b = rnd.nextInt(_dots.length);
      }
      _dots[a] = _dots[a].copyWith(warm: true);
      _dots[b] = _dots[b].copyWith(warm: true);
      _pairs.add((a, b));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = reduceMotion ? 0.0 : _controller.value * pi * 2;
          return CustomPaint(
            painter: _FieldPainter(dots: _dots, pairs: _pairs, t: t, colors: c),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _Dot {
  const _Dot({
    required this.dx,
    required this.dy,
    required this.r,
    required this.phase,
    required this.warm,
  });

  final double dx, dy, r, phase;
  final bool warm;

  _Dot copyWith({bool? warm}) =>
      _Dot(dx: dx, dy: dy, r: r, phase: phase, warm: warm ?? this.warm);
}

class _FieldPainter extends CustomPainter {
  _FieldPainter({
    required this.dots,
    required this.pairs,
    required this.t,
    required this.colors,
  });

  final List<_Dot> dots;
  final List<(int, int)> pairs;
  final double t;
  final EkipaColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    // Warm connecting threads first, so dots sit on top.
    for (final (ai, bi) in pairs) {
      final a = dots[ai];
      final b = dots[bi];
      final p1 = Offset(a.dx * size.width, a.dy * size.height);
      final p2 = Offset(b.dx * size.width, b.dy * size.height);
      final glow = 0.3 + 0.25 * sin(t + ai);
      final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2 - 30);
      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, p2.dx, p2.dy);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = ui.Gradient.linear(
          p1,
          p2,
          [
            colors.ember.withValues(alpha: glow),
            colors.mossGlow.withValues(alpha: glow),
          ],
        );
      canvas.drawPath(path, paint);
    }

    for (final d in dots) {
      final center = Offset(d.dx * size.width, d.dy * size.height);
      final flicker = 0.5 + 0.5 * sin(t * 1.6 + d.phase);
      final paint = Paint();
      if (d.warm) {
        paint.color = colors.ember.withValues(alpha: 0.65 + 0.3 * flicker);
        canvas.drawCircle(
          center,
          d.r + 3,
          Paint()
            ..color = colors.ember.withValues(alpha: 0.18 * flicker)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      } else {
        paint.color = colors.mossGlow.withValues(alpha: 0.16 + 0.14 * flicker);
      }
      canvas.drawCircle(center, d.r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FieldPainter oldDelegate) => oldDelegate.t != t;
}
