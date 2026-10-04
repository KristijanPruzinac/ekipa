import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'design.dart';
import 'discovery.dart';
import 'models.dart';

/// One calendar cell; times are never invented. Mirrors shared/day-strip.ts.
class DayCell {
  const DayCell(this.kind, this.weekday, this.date, this.time, [this.hidden]);
  final String kind; // single | start | mid | end | gap | open
  final String weekday, date;
  final String? time;
  final int? hidden;
}

const maxVisibleDays = 5;
const _short = ['pon', 'uto', 'sri', 'čet', 'pet', 'sub', 'ned'];
const _long = [
  'ponedjeljak',
  'utorak',
  'srijeda',
  'četvrtak',
  'petak',
  'subota',
  'nedjelja',
];

DayCell _cell(String kind, DateTime day, String? time, [bool long = false]) =>
    DayCell(
      kind,
      (long ? _long : _short)[day.weekday - 1],
      '${day.day}.${day.month}.',
      time,
    );

List<DayCell> dayStrip(WagzEvent event) {
  final startDay = dayOnly(event.startsAt);
  final startTime = event.startsAt.length == 10
      ? null
      : formatDate(event.startsAt, 'HH:mm');
  final end = knownEnd(event);
  if (end == null) {
    if (startTime == null) return [_cell('single', startDay, null, true)];
    return [
      _cell('start', startDay, startTime),
      const DayCell('open', 'kraj', '?', null),
    ];
  }
  final endDay = dayOnly(end);
  final endTime = end.length == 10 ? null : formatDate(end, 'HH:mm');
  if (endDay == startDay) {
    final time = startTime != null && endTime != null
        ? '$startTime–$endTime'
        : startTime ?? (endTime != null ? 'do $endTime' : null);
    return [_cell('single', startDay, time, true)];
  }
  final span = endDay.difference(startDay).inDays + 1;
  // Daily hours are printed once under the ticket; the day stubs carry dates only.
  final daily = event.dailyHours != null;
  final first = _cell('start', startDay, daily ? null : startTime);
  final last = _cell('end', endDay, daily ? null : endTime);
  if (span > maxVisibleDays) {
    return [first, DayCell('gap', '', '', null, span - 2), last];
  }
  return [
    first,
    for (var index = 1; index < span - 1; index++)
      _cell('mid', startDay.add(Duration(days: index)), null),
    last,
  ];
}

/// One ticket stub: a big line and a small line. Mirrors shared/day-strip.ts `ticket`.
class Stub {
  const Stub(this.tone, this.big, this.small);
  final String tone; // main | mid | open
  final String? big;
  final String small;
}

({List<Stub> stubs, String? daily}) ticket(WagzEvent event) {
  final cells = dayStrip(event);
  final daily = cells.length > 1 ? event.dailyHours?.text : null;
  final stubs = [
    for (final cell in cells)
      if (cell.kind == 'gap')
        Stub('mid', '+${cell.hidden}', 'dana')
      else if (cell.kind == 'open')
        const Stub('open', '?', 'kraj')
      else if (cell.kind == 'mid')
        Stub('mid', daily != null ? '${cell.date.split('.').first}.' : null, cell.weekday)
      else if (cell.time != null)
        Stub('main', cell.time, '${cell.weekday} ${cell.date}')
      else
        Stub('main', cell.date, cell.weekday),
  ];
  return (stubs: stubs, daily: daily);
}

/// Plain-language reading of the ticket for screen readers. Mirrors `ticketLabel`.
String ticketLabel(WagzEvent event) {
  final cells = dayStrip(event).where((c) => c.kind != 'mid' && c.kind != 'gap').toList();
  final daily = event.dailyHours?.text;
  String long(String short) {
    final i = _short.indexOf(short);
    return i < 0 ? short : _long[i];
  }

  String stop(String text) => text.endsWith('.') ? text : '$text.';
  String at(DayCell c) => '${long(c.weekday)} ${c.date}${c.time != null ? ' u ${c.time}' : ''}';
  if (cells.length == 1) {
    final only = cells.first;
    return only.time != null ? '${only.weekday} ${only.date}, ${only.time}.' : '${only.weekday} ${only.date}';
  }
  final last = cells.last;
  final end = last.kind == 'open' ? 'Kraj nije naveden.' : stop('Kraj: ${at(last)}');
  return '${stop('Početak: ${at(cells.first)}')} $end${daily != null ? ' Svaki dan $daily.' : ''}';
}

/// Train-ticket strip: one stub per day, dashed perforation with a half-round notch.
class DayStripView extends StatelessWidget {
  const DayStripView({super.key, required this.event});
  final WagzEvent event;

  @override
  Widget build(BuildContext context) {
    final result = ticket(event);
    final stubs = result.stubs;
    final height = MediaQuery.textScalerOf(context).scale(66).clamp(66.0, 92.0);
    return Semantics(
      label: ticketLabel(event),
      excludeSemantics: true,
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: Row(
            key: const ValueKey('day-strip'),
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < stubs.length; index++)
                stubs[index].tone == 'mid'
                    ? SizedBox(
                        width: 52,
                        child: _StubBox(
                          stub: stubs[index],
                          first: index == 0,
                          last: index == stubs.length - 1,
                        ),
                      )
                    : Flexible(
                        child: _StubBox(
                          stub: stubs[index],
                          first: index == 0,
                          last: index == stubs.length - 1,
                        ),
                      ),
            ],
          ),
        ),
        if (result.daily != null) ...[
          const SizedBox(height: 6),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 7,
            children: [
              const Text('svaki dan', style: TextStyle(fontSize: 14, color: muted)),
              Text(
                result.daily!,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  height: 1.1,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ],
      ),
    );
  }
}

class _StubBox extends StatelessWidget {
  const _StubBox({required this.stub, required this.first, required this.last});
  final Stub stub;
  final bool first, last;

  @override
  Widget build(BuildContext context) {
    final mid = stub.tone == 'mid', open = stub.tone == 'open';
    final tint = mid ? const Color(0xff444441) : open ? muted : ink;
    return CustomPaint(
      painter: _StubPainter(first: first, last: last, tone: stub.tone),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: mid ? 4 : 14),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (stub.big != null)
                  Text(
                    stub.big!,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: mid ? 20 : 27,
                      fontWeight: FontWeight.w500,
                      height: 1,
                      letterSpacing: -0.3,
                      color: tint,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.only(top: stub.big == null ? 0 : (mid ? 2 : 4)),
                  child: Text(
                    stub.small,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: mid ? 14 : 13,
                      color: mid ? tint : muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StubPainter extends CustomPainter {
  _StubPainter({required this.first, required this.last, required this.tone});
  final bool first, last;
  final String tone;
  static const radius = 7.0, stroke = 1.0, notch = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height, half = stroke / 2;
    final rl = first ? radius : 0.0, rr = last ? radius : 0.0;
    final shape = RRect.fromRectAndCorners(
      Rect.fromLTWH(0, half, w, h - stroke),
      topLeft: Radius.circular(rl),
      bottomLeft: Radius.circular(rl),
      topRight: Radius.circular(rr),
      bottomRight: Radius.circular(rr),
    );
    if (tone != 'open') {
      canvas.drawRRect(
        shape,
        Paint()..color = tone == 'mid' ? const Color(0xffecebe4) : Colors.white,
      );
    }
    final pen = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final top = half, bottom = h - half, left = first ? half : 0.0;
    final right = last ? w - half : w;
    final outline = Path()..moveTo(left + rl, top)..lineTo(right - rr, top);
    if (last) {
      outline
        ..arcToPoint(Offset(right, top + rr), radius: const Radius.circular(radius))
        ..lineTo(right, bottom - rr)
        ..arcToPoint(Offset(right - rr, bottom), radius: const Radius.circular(radius));
    } else {
      outline.moveTo(right, bottom);
    }
    outline.lineTo(left + rl, bottom);
    if (first) {
      outline
        ..arcToPoint(Offset(left, bottom - rl), radius: const Radius.circular(radius))
        ..lineTo(left, top + rl)
        ..arcToPoint(Offset(left + rl, top), radius: const Radius.circular(radius));
    }
    if (tone == 'open') {
      _dashed(canvas, outline, pen);
    } else {
      canvas.drawPath(outline, pen);
    }
    if (!first) {
      final cy = h / 2;
      _dashed(canvas, Path()..moveTo(0, top)..lineTo(0, cy - notch), pen);
      _dashed(canvas, Path()..moveTo(0, cy + notch)..lineTo(0, bottom), pen);
      final bite = Path()
        ..moveTo(0, cy - notch)
        ..arcToPoint(Offset(0, cy + notch), radius: const Radius.circular(notch));
      canvas.drawPath(bite, Paint()..color = paper);
      canvas.drawPath(bite, pen);
    }
  }

  void _dashed(Canvas canvas, Path path, Paint pen) {
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 6) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 3, metric.length)), pen);
      }
    }
  }

  @override
  bool shouldRepaint(_StubPainter old) =>
      old.first != first || old.last != last || old.tone != tone;
}

/// Minimal static map: light CARTO tiles with the lime pin; tapping opens the maps app.
class EventMapView extends StatelessWidget {
  const EventMapView({super.key, required this.event});
  final WagzEvent event;
  static const zoom = 16, tile = 256.0;

  @override
  Widget build(BuildContext context) {
    final location = event.location;
    if (location == null) return const SizedBox.shrink();
    final scale = math.pow(2, zoom).toDouble();
    final x = (location.lon + 180) / 360 * scale;
    final latRad = location.lat * math.pi / 180;
    final y =
        (1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
        2 *
        scale;
    final tileX = x.floor(), tileY = y.floor();
    final offsetX = (x - tileX) * tile, offsetY = (y - tileY) * tile;
    final maps =
        'https://www.google.com/maps/search/?api=1&query=${location.lat},${location.lon}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            button: true,
            label: 'Otvori ${event.venue ?? 'lokaciju'} u kartama',
            child: GestureDetector(
              key: const ValueKey('event-map'),
              onTap: () => openSource(context, maps),
              child: Container(
                height: 180,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xffececea),
                  border: Border.all(color: ink, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: LayoutBuilder(
                  builder: (context, box) => Stack(
                    children: [
                      for (var dy = -1; dy <= 1; dy++)
                        for (var dx = -2; dx <= 2; dx++)
                          Positioned(
                            left: box.maxWidth / 2 - offsetX + dx * tile,
                            top: box.maxHeight / 2 - offsetY + dy * tile,
                            width: tile,
                            height: tile,
                            child: Image.network(
                              'https://${'abcd'[(tileX + dx + tileY + dy + 4) % 4]}.basemaps.cartocdn.com/light_all/$zoom/${tileX + dx}/${tileY + dy}.png',
                              errorBuilder: (context, error, stack) => const SizedBox.shrink(),
                            ),
                          ),
                      Positioned(
                        left: box.maxWidth / 2 - 21,
                        top: box.maxHeight / 2 - 21,
                        child: Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0x59dfff00),
                          ),
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: lime,
                              border: Border.all(color: ink, width: 3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 4,
            children: [
              GestureDetector(
                onTap: () => openSource(context, maps),
                child: const Text(
                  'Otvori u kartama',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              const Text(
                '© OpenStreetMap · CARTO',
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
