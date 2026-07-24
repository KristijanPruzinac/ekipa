import 'package:flutter/material.dart';

/// Hand-drawn line icons, one per activity — replacing emoji entirely.
/// Consistent stroke weight, drawn on a 24x24 canvas so they scale cleanly.
class ActivityIcon extends StatelessWidget {
  const ActivityIcon(this.slug, {super.key, this.size = 24, this.color});

  final String slug;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? IconTheme.of(context).color ?? Colors.white;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ActivityPainter(slug: slug, color: resolvedColor),
      ),
    );
  }
}

class _ActivityPainter extends CustomPainter {
  _ActivityPainter({required this.slug, required this.color});

  final String slug;
  final Color color;

  Paint get _stroke => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.7
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint get _fill => Paint()..color = color;

  @override
  void paint(Canvas canvas, Size size) {
    // All paths authored on a 24x24 grid; scale to the actual size.
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);

    switch (slug) {
      case 'walk':
        canvas.drawCircle(const Offset(13, 4.5), 1.6, _fill);
        _path(canvas, [
          [10, 8], [12, 10], [11, 14], [8, 17],
        ]);
        _path(canvas, [
          [12, 10], [15, 11], [17, 15],
        ]);
        _path(canvas, [
          [9, 17], [7, 21],
        ]);
        _path(canvas, [
          [14, 15], [16, 20],
        ]);
        break;

      case 'boardgames':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3.5, 3.5, 17, 17),
            const Radius.circular(4),
          ),
          _stroke,
        );
        for (final p in [
          [8.3, 8.3], [15.7, 8.3], [8.3, 15.7], [15.7, 15.7], [12.0, 12.0],
        ]) {
          canvas.drawCircle(Offset(p[0], p[1]), 1, _fill);
        }
        break;

      case 'hike':
        _path(canvas, [
          [4, 19], [10, 6], [13, 12], [15, 9], [20, 19],
        ], close: false);
        canvas.drawCircle(const Offset(9.5, 4.5), 1.6, _fill);
        break;

      case 'bouldering':
        _path(canvas, [
          [3, 20], [7, 11], [10, 15], [12, 9], [16, 12], [21, 20],
        ]);
        for (final p in [
          [6.0, 9.0], [12.0, 7.0], [17.0, 11.0],
        ]) {
          canvas.drawCircle(Offset(p[0], p[1]), 1, _fill);
        }
        break;

      case 'coffee_quiet':
        canvas.drawPath(
          Path()
            ..moveTo(5, 9)
            ..lineTo(16, 9)
            ..lineTo(16, 15)
            ..arcToPoint(const Offset(9, 19), radius: const Radius.circular(4))
            ..lineTo(5, 9)
            ..close(),
          _stroke,
        );
        canvas.drawArc(const Rect.fromLTWH(16, 10, 4, 6), -1.2, 2.4, false, _stroke);
        _path(canvas, [
          [8, 5], [8, 6.5], [7, 7.5],
        ], close: false);
        _path(canvas, [
          [12, 5], [12, 6.5], [11, 7.5],
        ], close: false);
        break;

      case 'photography':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, 7, 18, 13),
            const Radius.circular(3),
          ),
          _stroke,
        );
        canvas.drawCircle(const Offset(12, 13.5), 3.6, _stroke);
        _path(canvas, [
          [9, 7], [10.3, 4.6], [13.7, 4.6], [15, 7],
        ], close: false);
        break;

      case 'cowork_hobby':
        _path(canvas, [
          [12, 4], [13.6, 7.3], [17, 8], [14.4, 10.3],
          [15, 14], [12, 12.2], [9, 14], [9.6, 10.3],
          [7, 8], [10.4, 7.3],
        ]);
        break;

      case 'cooking':
        canvas.drawPath(
          Path()
            ..moveTo(4, 12)
            ..lineTo(20, 12)
            ..arcToPoint(const Offset(4, 12), radius: const Radius.circular(8)),
          _stroke,
        );
        _path(canvas, [
          [8, 12], [8, 7],
        ], close: false);
        _path(canvas, [
          [12, 12], [12, 5],
        ], close: false);
        _path(canvas, [
          [16, 12], [16, 7],
        ], close: false);
        break;

      case 'cinema':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3.5, 5, 17, 14),
            const Radius.circular(2.5),
          ),
          _stroke,
        );
        _path(canvas, [
          [8, 5], [8, 19],
        ], close: false);
        _path(canvas, [
          [16, 5], [16, 19],
        ], close: false);
        _path(canvas, [
          [3.5, 9.5], [7.5, 9.5],
        ], close: false);
        _path(canvas, [
          [16.5, 9.5], [20.5, 9.5],
        ], close: false);
        _path(canvas, [
          [3.5, 14.5], [7.5, 14.5],
        ], close: false);
        _path(canvas, [
          [16.5, 14.5], [20.5, 14.5],
        ], close: false);
        break;

      case 'reading':
        _path(canvas, [
          [12, 6], [12, 19],
        ], close: false);
        canvas.drawPath(
          Path()
            ..moveTo(12, 6)
            ..cubicTo(10, 4.5, 7, 4, 4, 5)
            ..lineTo(4, 18)
            ..cubicTo(7, 17, 10, 17.5, 12, 19)
            ..cubicTo(14, 17.5, 17, 17, 20, 18)
            ..lineTo(20, 5)
            ..cubicTo(17, 4, 14, 4.5, 12, 6)
            ..close(),
          _stroke,
        );
        break;

      default:
        canvas.drawCircle(const Offset(12, 12), 8, _stroke);
    }

    canvas.restore();
  }

  void _path(Canvas canvas, List<List<double>> points, {bool close = false}) {
    final path = Path()..moveTo(points.first[0], points.first[1]);
    for (final p in points.skip(1)) {
      path.lineTo(p[0], p[1]);
    }
    if (close) path.close();
    canvas.drawPath(path, _stroke);
  }

  @override
  bool shouldRepaint(covariant _ActivityPainter oldDelegate) =>
      oldDelegate.slug != slug || oldDelegate.color != color;
}
