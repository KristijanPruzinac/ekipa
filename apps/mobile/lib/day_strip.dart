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
        ? '$startTime – $endTime'
        : startTime ?? (endTime != null ? 'do $endTime' : null);
    return [_cell('single', startDay, time, true)];
  }
  final span = endDay.difference(startDay).inDays + 1;
  final daily = event.dailyHours?.text;
  final first = _cell('start', startDay, daily ?? startTime);
  final last = _cell('end', endDay, daily ?? endTime);
  if (span > maxVisibleDays) {
    return [first, DayCell('gap', '', '', null, span - 2), last];
  }
  return [
    first,
    for (var index = 1; index < span - 1; index++)
      _cell('mid', startDay.add(Duration(days: index)), daily),
    last,
  ];
}

class DayStripView extends StatelessWidget {
  const DayStripView({super.key, required this.event});
  final WagzEvent event;

  @override
  Widget build(BuildContext context) {
    final cells = dayStrip(event);
    final daily = cells.length > 1 ? event.dailyHours?.text : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          key: const ValueKey('day-strip'),
          children: [
            for (var index = 0; index < cells.length; index++)
              Flexible(
                flex: cells.length == 1 ? 0 : 1,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: cells.length == 1 ? 190 : 86,
                    minWidth: cells.length == 1 ? 150 : 0,
                  ),
                  child: _DayBox(
                    cell: cells[index],
                    first: index == 0,
                    last: index == cells.length - 1,
                  ),
                ),
              ),
          ],
        ),
        if (daily != null) ...[
          const SizedBox(height: 8),
          Text(
            'Svaki dan $daily',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ],
    );
  }
}

class _DayBox extends StatelessWidget {
  const _DayBox({required this.cell, required this.first, required this.last});
  final DayCell cell;
  final bool first, last;

  @override
  Widget build(BuildContext context) {
    final edge = const {'start', 'end', 'single'}.contains(cell.kind);
    final dashed = cell.kind == 'open' || cell.kind == 'gap';
    final background = edge
        ? lime
        : cell.kind == 'mid' || cell.kind == 'gap'
        ? const Color(0xfff3ffb3)
        : Colors.transparent;
    final radius = BorderRadius.horizontal(
      left: Radius.circular(first ? 8 : 0),
      right: Radius.circular(last ? 8 : 0),
    );
    final missing = cell.time == null;
    Widget? chip;
    if (cell.kind == 'open') {
      chip = const Text(
        'nije naveden',
        style: TextStyle(fontSize: 11, color: muted),
      );
    } else if (cell.kind != 'mid' || cell.time != null) {
      chip = Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: missing ? null : ink,
          border: missing ? Border.all(color: ink) : null,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          cell.time ?? (cell.kind == 'single' ? 'vrijeme nije navedeno' : '—'),
          style: TextStyle(
            fontSize: 13,
            fontWeight: missing ? FontWeight.w400 : FontWeight.w700,
            color: missing ? ink : lime,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 6, 4, 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: radius,
        border: Border(
          top: BorderSide(color: edge || !dashed ? ink : muted, width: 1.5),
          bottom: BorderSide(color: edge || !dashed ? ink : muted, width: 1.5),
          left: BorderSide(color: edge || !dashed ? ink : muted, width: 1.5),
          right: last
              ? BorderSide(color: edge || !dashed ? ink : muted, width: 1.5)
              : BorderSide.none,
        ),
      ),
      child: cell.kind == 'gap'
          ? Center(
              heightFactor: 2.4,
              child: Text(
                '+ ${cell.hidden} dana',
                style: const TextStyle(fontSize: 12, color: muted),
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cell.weekday,
                  style: TextStyle(
                    fontSize: 11,
                    color: cell.kind == 'open' ? muted : ink,
                  ),
                ),
                Text(
                  cell.date,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: cell.kind == 'open' ? muted : ink,
                  ),
                ),
                if (chip != null) FittedBox(fit: BoxFit.scaleDown, child: chip),
              ],
            ),
    );
  }
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
