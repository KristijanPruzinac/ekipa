import 'dart:math' as math;

import 'package:ekipa_core/ekipa_core.dart';
import 'package:ekipa_ui/src/tokens/colors.dart';
import 'package:ekipa_ui/src/tokens/spacing.dart';
import 'package:ekipa_ui/src/tokens/typography.dart';
import 'package:flutter/widgets.dart';

/// A city, drawn in Zar's colours, with a place marked on it.
///
/// **Intention — the map has one job: get four people to one spot.** So it
/// carries the least it can. No labels, no points of interest, no zoom, no pan,
/// no other pins. Streets and water for orientation, one marker for the place,
/// and — when we know it — one for where the person set out from, with the line
/// between them. Everything a general-purpose map adds is a thing to look at
/// instead of the one thing.
///
/// **Why it is a painter and not a map widget.** See
/// `tools/cartography/build_basemap.py`: raster tiles arrive in somebody else's
/// colours over a network at the worst possible moment, and the two commercial
/// SDKs need a billing account this project has decided not to have. Drawing it
/// ourselves costs a build step per city and buys a map that works with the
/// radio off, matches the theme exactly, and has no per-view price.
///
/// **The anchor is never drawn for anyone but its owner.** `05_PLACES.md §2`: a
/// home anchor is matching input, never display. This widget takes one point
/// and it is the viewer's own.
class MapSurface extends StatelessWidget {
  /// Draws [basemap], marking [meetingPoint].
  const MapSurface({
    required this.basemap,
    required this.meetingPoint,
    this.anchor,
    this.height = 260,
    this.zoom = 1,
    super.key,
  });

  /// The city geometry.
  final Basemap basemap;

  /// Where the group converges.
  final GeoPoint meetingPoint;

  /// Where the viewer sets out from, if they gave us one. Theirs alone.
  final GeoPoint? anchor;

  /// How tall the surface is.
  final double height;

  /// How far to zoom in around the framed content. `1` frames the whole city.
  final double zoom;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: ZarRadius.allLg,
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _BasemapPainter(
              basemap: basemap,
              meetingPoint: meetingPoint,
              anchor: anchor,
              zoom: zoom,
            ),
            isComplex: true,
          ),
          Positioned(
            right: ZarSpace.sm,
            bottom: ZarSpace.xs,
            child: Text(
              '© OpenStreetMap',
              style: ZarType.caption.copyWith(
                color: ZarColors.inkFaint,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _BasemapPainter extends CustomPainter {
  _BasemapPainter({
    required this.basemap,
    required this.meetingPoint,
    required this.anchor,
    required this.zoom,
  });

  final Basemap basemap;
  final GeoPoint meetingPoint;
  final GeoPoint? anchor;
  final double zoom;

  // Layer styling. Kept here rather than in tokens because these are the only
  // place they are used and a token nobody shares is a token that pretends to
  // be a system.
  //
  // **These are brighter than they first were, and that was a real defect.**
  // The first pass drew minor roads at `#262F34` on a `#1A2023` ground — a
  // little over 1.2:1. It looked correct in the palette and rendered as an
  // almost-blank rectangle with a pin floating in it. A map nobody can read is
  // worse than no map, because it still takes the space and it still implies
  // the app knows where you are going.
  static const Map<BasemapLayerKind, (Color, double)> _style = {
    BasemapLayerKind.water: (Color(0xFF1B333B), 0),
    BasemapLayerKind.green: (Color(0xFF1B2C24), 0),
    BasemapLayerKind.roadMajor: (Color(0xFF56666D), 2.2),
    BasemapLayerKind.roadMinor: (Color(0xFF394750), 1.3),
    BasemapLayerKind.path: (Color(0xFF2E3940), 0.9),
    BasemapLayerKind.rail: (Color(0xFF333E44), 1),
  };

  /// Metres per degree of latitude. Longitude is this times `cos(latitude)`.
  static const double _metresPerDegree = 111320;

  /// The closest the map will ever frame, in metres across.
  ///
  /// Without a floor, an anchor a hundred metres from the meeting point frames
  /// a hundred metres — two dots at opposite edges of a rectangle with three
  /// streets in it, which tells a person nothing about which way to walk.
  static const double _minimumSpan = 400;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = ZarColors.surface);
    if (size.width <= 0 || size.height <= 0) return;

    // ── Framing, in metres ───────────────────────────────────────────────────
    //
    // **The unit square is not square, and neither is the canvas.** Osijek's
    // extract is about 4.3 km across and 2.8 km tall, drawn into a box that is
    // wider than it is tall by a different ratio again. Mapping unit → pixels
    // directly, as the first version did, multiplies those two distortions
    // together: streets that cross at right angles come out sheared, and the
    // dashed line to the anchor points somewhere the person should not walk.
    // So everything below happens in metres, and one scale is used for both
    // axes.
    final midLat =
        (basemap.southWest.latitude + basemap.northEast.latitude) / 2;
    final extractWidth =
        (basemap.northEast.longitude - basemap.southWest.longitude) *
        _metresPerDegree *
        math.cos(midLat * math.pi / 180);
    final extractHeight =
        (basemap.northEast.latitude - basemap.southWest.latitude) *
        _metresPerDegree;
    if (extractWidth <= 0 || extractHeight <= 0) return;

    final focus = basemap.unit(meetingPoint);
    final from = anchor == null ? null : basemap.unit(anchor!);
    final focusX = focus.x * extractWidth;
    final focusY = focus.y * extractHeight;

    double centreX;
    double centreY;
    double spanX;
    double spanY;

    if (from != null) {
      // **With an anchor, frame both points — do not zoom on one of them.**
      // The question this screen answers is "where is it from here", and an
      // anchor cropped off the edge answers the other half of it with a line
      // running off the frame, which reads as a rendering fault.
      final startX = from.x * extractWidth;
      final startY = from.y * extractHeight;
      centreX = (focusX + startX) / 2;
      centreY = (focusY + startY) / 2;
      // A third again, so neither marker sits against an edge.
      spanX = math.max((focusX - startX).abs() * 1.45, _minimumSpan);
      spanY = math.max((focusY - startY).abs() * 1.45, _minimumSpan);
    } else {
      centreX = focusX;
      centreY = focusY;
      spanX = math.max(extractWidth / math.max(zoom, 0.0001), _minimumSpan);
      spanY = math.max(extractHeight / math.max(zoom, 0.0001), _minimumSpan);
    }

    // Contain, never cover: the scale that shows *at least* the requested
    // window in both directions. Cover would fill the box by cropping, and the
    // thing it would crop is one of the two points the framing exists for.
    final scale = math.min(size.width / spanX, size.height / spanY);

    Offset place(double ux, double uy) => Offset(
      size.width / 2 + (ux * extractWidth - centreX) * scale,
      size.height / 2 + (uy * extractHeight - centreY) * scale,
    );

    // How far in we are compared with the whole extract, for stroke weights. A
    // hairline that stays a hairline when you zoom three streets across looks
    // like a diagram of a city rather than a city.
    final wide = math.min(
      size.width / extractWidth,
      size.height / extractHeight,
    );
    final weight = (scale / wide).clamp(1.0, 3.2);

    canvas
      ..save()
      ..clipRect(Offset.zero & size);

    for (final layer in basemap.layers) {
      final (colour, stroke) = _style[layer.kind]!;
      final filled = stroke == 0;
      final paint = Paint()
        ..color = colour
        ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = stroke * weight
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true;

      final path = Path();
      for (final shape in layer.shapes) {
        final count = shape.length ~/ 2;
        if (count < 2) continue;
        for (var i = 0; i < count; i++) {
          final point = place(shape[i * 2] / 0xFFFF, shape[i * 2 + 1] / 0xFFFF);
          i == 0
              ? path.moveTo(point.dx, point.dy)
              : path.lineTo(point.dx, point.dy);
        }
        if (filled) path.close();
      }
      canvas.drawPath(path, paint);
    }

    final target = place(focus.x, focus.y);

    if (from != null) {
      final start = place(from.x, from.y);
      // A straight line, deliberately. A routed line would be a promise about
      // the walk that we have not checked, and being wrong about a route is
      // worse than being silent about one.
      _dashed(canvas, start, target);
      canvas
        ..drawCircle(start, 5, Paint()..color = ZarColors.inkFaint)
        ..drawCircle(
          start,
          5,
          Paint()
            ..color = ZarColors.surface
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
    }

    // The marker. Ember, because this is the one thing on the screen that is
    // the point, and ember is reserved for exactly that.
    canvas
      ..drawCircle(target, 26, Paint()..color = ZarColors.emberWash)
      ..drawCircle(
        target,
        13,
        Paint()
          ..color = ZarColors.ember.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      )
      ..drawCircle(target, 7, Paint()..color = ZarColors.ember)
      ..drawCircle(
        target,
        7,
        Paint()
          ..color = ZarColors.ground
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      )
      ..restore();
  }

  void _dashed(Canvas canvas, Offset a, Offset b) {
    final paint = Paint()
      ..color = ZarColors.inkFaint.withValues(alpha: 0.55)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    const dash = 6.0;
    const gap = 5.0;
    final total = (b - a).distance;
    if (total == 0) return;
    final step = (b - a) / total;
    for (var travelled = 0.0; travelled < total; travelled += dash + gap) {
      final end = math.min(travelled + dash, total);
      canvas.drawLine(a + step * travelled, a + step * end, paint);
    }
  }

  @override
  bool shouldRepaint(_BasemapPainter old) =>
      old.basemap != basemap ||
      old.meetingPoint != meetingPoint ||
      old.anchor != anchor ||
      old.zoom != zoom;
}
