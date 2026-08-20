import 'dart:math' as math;

import 'package:ekipa_ui/src/tokens/colors.dart';
import 'package:ekipa_ui/src/tokens/spacing.dart';
import 'package:ekipa_ui/src/tokens/typography.dart';
import 'package:flutter/widgets.dart';

/// The group's mark: one symbol in one colour, drawn.
///
/// **Intention — this is the object the product has to carry.** Four people who
/// have never met arrive within a few minutes of each other at a café. The
/// thirty seconds before anyone speaks is the whole risk of the evening, and
/// the sigil is what removes it: you hold up your phone, or you say *"we're the
/// red circle"*, and the problem is solved in one sentence in either language.
///
/// **Why it is drawn rather than an emoji or an icon font.** An emoji is
/// whatever the platform's font decided a circle looks like this year, and it
/// is different on the phone next to yours — on the one screen where two phones
/// must agree, that is disqualifying. An icon font would be a dependency and a
/// second visual language inside a design system that deliberately has neither.
/// Twenty-four paths is a morning's work and it never changes underneath us.
///
/// The catalogue is the database's (`0007_v3_sigils.sql`), including the
/// Croatian labels with the adjective declined per symbol. This widget renders
/// codes; it does not own the set.
class Sigil extends StatelessWidget {
  /// Draws [symbol] in [colour], both as the codes the server sends.
  const Sigil({
    required this.symbol,
    required this.colour,
    this.size = 64,
    this.label,
    super.key,
  });

  /// A code from the sigil catalogue, e.g. `circle`.
  final String symbol;

  /// A colour code from the catalogue: red, orange, yellow, green, blue,
  /// purple.
  final String colour;

  /// The drawn size, in logical pixels.
  final double size;

  /// The sayable name, rendered beneath. `null` renders the mark alone.
  ///
  /// Passing the server's label rather than composing one here is deliberate:
  /// "crveni krug" and "crvena zvijezda" decline differently, and a client that
  /// concatenated them would be wrong on most of the set.
  final String? label;

  /// The six sigil hues.
  ///
  /// **Why these live here and not in `ZarColors`.** A token is a *role* —
  /// ember means "the one thing that is the point". These are not roles; they
  /// are six mutually distinguishable values that arrive from a database
  /// column, and a person says one of them out loud. Four are the palette's own
  /// accents; yellow and purple are added for this set alone, tuned against the
  /// same ground so the twenty-four marks read as one family.
  static const Map<String, Color> palette = {
    'red': Color(0xFFE5715F),
    'orange': Color(0xFFFF6B3F),
    'yellow': Color(0xFFE9B44C),
    'green': Color(0xFF63D3A2),
    'blue': Color(0xFF8FD4FF),
    'purple': Color(0xFFB79BE8),
  };

  @override
  Widget build(BuildContext context) {
    final ink = palette[colour] ?? ZarColors.ink;
    final mark = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SigilPainter(symbol: symbol, ink: ink),
      ),
    );
    final text = label;
    if (text == null) return mark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(height: ZarSpace.xs),
        Text(
          text,
          textAlign: TextAlign.center,
          style: ZarType.label.copyWith(color: ink),
        ),
      ],
    );
  }
}

class _SigilPainter extends CustomPainter {
  _SigilPainter({required this.symbol, required this.ink});

  final String symbol;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    // Everything below is authored in a 100×100 box and scaled once, so a sigil
    // at 32 and the same sigil at 120 are the same drawing.
    final scale = size.width / 100;
    canvas
      ..save()
      ..scale(scale);

    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final fill = Paint()
      ..color = ink
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    switch (symbol) {
      // ── Geometry ──────────────────────────────────────────────────────────
      case 'circle':
        canvas.drawCircle(const Offset(50, 50), 36, stroke);
      case 'square':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(16, 16, 68, 68),
            const Radius.circular(8),
          ),
          stroke,
        );
      case 'triangle':
        canvas.drawPath(_polygon([(50, 14), (86, 80), (14, 80)]), stroke);
      case 'diamond':
        canvas.drawPath(
          _polygon([(50, 12), (86, 50), (50, 88), (14, 50)]),
          stroke,
        );
      case 'star':
        canvas.drawPath(
          _star(centre: const Offset(50, 52), outer: 38, inner: 16),
          stroke,
        );
      case 'heart':
        canvas.drawPath(_heart(), stroke);

      // ── Sky and weather ───────────────────────────────────────────────────
      case 'sun':
        canvas.drawCircle(const Offset(50, 50), 20, stroke);
        for (var i = 0; i < 8; i++) {
          final angle = i * math.pi / 4;
          canvas.drawLine(
            Offset(50 + math.cos(angle) * 31, 50 + math.sin(angle) * 31),
            Offset(50 + math.cos(angle) * 42, 50 + math.sin(angle) * 42),
            stroke,
          );
        }
      case 'moon':
        canvas.drawPath(
          Path.combine(
            PathOperation.difference,
            Path()..addOval(
              Rect.fromCircle(center: const Offset(50, 50), radius: 36),
            ),
            Path()..addOval(
              Rect.fromCircle(center: const Offset(70, 38), radius: 34),
            ),
          ),
          fill,
        );
      case 'cloud':
        canvas.drawPath(
          Path()
            ..moveTo(28, 70)
            ..cubicTo(12, 70, 12, 48, 30, 47)
            ..cubicTo(32, 28, 62, 24, 68, 44)
            ..cubicTo(86, 42, 90, 70, 72, 70)
            ..close(),
          stroke,
        );
      case 'bolt':
        canvas.drawPath(
          _polygon([
            (58, 10),
            (30, 54),
            (48, 54),
            (42, 90),
            (72, 44),
            (52, 44),
          ]),
          stroke,
        );
      case 'drop':
        canvas.drawPath(
          Path()
            ..moveTo(50, 12)
            ..cubicTo(76, 42, 84, 56, 84, 64)
            ..arcToPoint(
              const Offset(16, 64),
              radius: const Radius.circular(34),
            )
            ..cubicTo(16, 56, 24, 42, 50, 12)
            ..close(),
          stroke,
        );
      case 'wave':
        for (var row = 0; row < 3; row++) {
          final y = 34.0 + row * 17;
          canvas.drawPath(
            Path()
              ..moveTo(14, y)
              ..cubicTo(26, y - 12, 38, y + 12, 50, y)
              ..cubicTo(62, y - 12, 74, y + 12, 86, y),
            stroke,
          );
        }

      // ── Growing things ────────────────────────────────────────────────────
      case 'leaf':
        canvas.drawPath(
          Path()
            ..moveTo(20, 80)
            ..cubicTo(20, 34, 46, 18, 82, 18)
            ..cubicTo(82, 56, 60, 80, 20, 80)
            ..close(),
          stroke,
        );
        canvas.drawLine(const Offset(26, 76), const Offset(70, 32), stroke);
      case 'flower':
        for (var i = 0; i < 5; i++) {
          final angle = -math.pi / 2 + i * 2 * math.pi / 5;
          canvas.drawCircle(
            Offset(50 + math.cos(angle) * 22, 50 + math.sin(angle) * 22),
            15,
            stroke,
          );
        }
      case 'tree':
        canvas.drawPath(_polygon([(50, 12), (78, 56), (22, 56)]), stroke);
        canvas.drawPath(_polygon([(50, 36), (84, 76), (16, 76)]), stroke);
        canvas.drawLine(const Offset(50, 76), const Offset(50, 90), stroke);
      case 'mountain':
        canvas.drawPath(
          Path()
            ..moveTo(10, 80)
            ..lineTo(36, 34)
            ..lineTo(54, 62)
            ..lineTo(66, 46)
            ..lineTo(90, 80)
            ..close(),
          stroke,
        );
      case 'feather':
        canvas.drawPath(
          Path()
            ..moveTo(78, 18)
            ..cubicTo(78, 58, 54, 78, 26, 80)
            ..cubicTo(26, 42, 46, 20, 78, 18)
            ..close(),
          stroke,
        );
        canvas.drawLine(const Offset(74, 22), const Offset(20, 86), stroke);
      case 'shell':
        canvas.drawPath(
          Path()
            ..moveTo(14, 76)
            ..arcToPoint(
              const Offset(86, 76),
              radius: const Radius.circular(40),
            )
            ..close(),
          stroke,
        );
        for (final x in [36.0, 50.0, 64.0]) {
          canvas.drawLine(const Offset(50, 76), Offset(x, 30), stroke);
        }

      // ── Objects ───────────────────────────────────────────────────────────
      case 'key':
        canvas.drawCircle(const Offset(32, 34), 17, stroke);
        canvas.drawLine(const Offset(43, 47), const Offset(84, 88), stroke);
        canvas.drawLine(const Offset(66, 70), const Offset(56, 80), stroke);
        canvas.drawLine(const Offset(76, 80), const Offset(66, 90), stroke);
      case 'anchor':
        canvas.drawCircle(const Offset(50, 20), 9, stroke);
        canvas.drawLine(const Offset(50, 30), const Offset(50, 86), stroke);
        canvas.drawLine(const Offset(30, 44), const Offset(70, 44), stroke);
        canvas.drawPath(
          Path()
            ..moveTo(18, 60)
            ..cubicTo(18, 86, 38, 88, 50, 86)
            ..cubicTo(62, 88, 82, 86, 82, 60),
          stroke,
        );
      case 'bell':
        canvas.drawPath(
          Path()
            ..moveTo(24, 72)
            ..cubicTo(24, 40, 32, 24, 50, 22)
            ..cubicTo(68, 24, 76, 40, 76, 72)
            ..close(),
          stroke,
        );
        canvas.drawLine(const Offset(42, 84), const Offset(58, 84), stroke);
      case 'arrow':
        canvas.drawLine(const Offset(50, 86), const Offset(50, 18), stroke);
        canvas.drawPath(
          Path()
            ..moveTo(26, 40)
            ..lineTo(50, 16)
            ..lineTo(74, 40),
          stroke,
        );
      case 'flame':
        canvas.drawPath(
          Path()
            ..moveTo(50, 12)
            ..cubicTo(74, 36, 82, 52, 82, 62)
            ..arcToPoint(
              const Offset(18, 62),
              radius: const Radius.circular(32),
            )
            ..cubicTo(18, 46, 34, 42, 40, 26)
            ..cubicTo(46, 34, 50, 12, 50, 12)
            ..close(),
          stroke,
        );
      case 'bird':
        canvas.drawPath(
          Path()
            ..moveTo(12, 58)
            ..cubicTo(28, 32, 42, 34, 50, 52)
            ..cubicTo(58, 34, 72, 32, 88, 58),
          stroke,
        );
        canvas.drawPath(
          Path()
            ..moveTo(28, 46)
            ..cubicTo(40, 60, 60, 60, 72, 46),
          stroke,
        );

      default:
        // An unknown code is a newer catalogue against an older build. Draw the
        // ring and let the label carry it, rather than showing nothing at the
        // one moment the mark is needed.
        canvas.drawCircle(const Offset(50, 50), 34, stroke);
    }

    canvas.restore();
  }

  Path _polygon(List<(double, double)> points) {
    final path = Path()..moveTo(points.first.$1, points.first.$2);
    for (final (x, y) in points.skip(1)) {
      path.lineTo(x, y);
    }
    return path..close();
  }

  Path _star({
    required Offset centre,
    required double outer,
    required double inner,
  }) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? outer : inner;
      final angle = -math.pi / 2 + i * math.pi / 5;
      final point =
          centre + Offset(math.cos(angle) * radius, math.sin(angle) * radius);
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  Path _heart() => Path()
    ..moveTo(50, 84)
    ..cubicTo(4, 56, 16, 18, 50, 36)
    ..cubicTo(84, 18, 96, 56, 50, 84)
    ..close();

  @override
  bool shouldRepaint(_SigilPainter old) =>
      old.symbol != symbol || old.ink != ink;
}
