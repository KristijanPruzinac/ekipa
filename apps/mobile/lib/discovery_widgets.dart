import 'package:flutter/material.dart';
import 'design.dart';
import 'discovery.dart';
import 'models.dart';

Color themeColor(DiscoveryTheme? theme) => switch (theme) {
  DiscoveryTheme.goOut => const Color(0xff674587),
  DiscoveryTheme.dance => const Color(0xff983d55),
  DiscoveryTheme.workshop => const Color(0xff356087),
  DiscoveryTheme.film => const Color(0xff3e596b),
  DiscoveryTheme.literature => const Color(0xff725622),
  DiscoveryTheme.culture => const Color(0xff914a2b),
  DiscoveryTheme.joinIn => const Color(0xff286d62),
  null => muted,
};

Color eventPaper(WagzEvent event) => switch (themeForCategory(event.category)) {
  DiscoveryTheme.goOut => const Color(0xffe8ddf3),
  DiscoveryTheme.dance => const Color(0xfff5dce1),
  DiscoveryTheme.workshop => const Color(0xffdce7f5),
  DiscoveryTheme.film => const Color(0xffdce8ec),
  DiscoveryTheme.literature => const Color(0xffefe5ca),
  DiscoveryTheme.culture => const Color(0xfff3dfd0),
  DiscoveryTheme.joinIn => const Color(0xffd9ebe2),
  null => const Color(0xffe9e7df),
};

/// A category illustration, never an audience assumption or another filter.
class EventMotif extends StatelessWidget {
  const EventMotif({super.key, required this.theme, this.compact = false});
  final DiscoveryTheme? theme;
  final bool compact;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: compact ? 62 : 112,
      height: compact ? 44 : 76,
      child: CustomPaint(painter: _MotifPainter(theme)),
    ),
  );
}

class _MotifPainter extends CustomPainter {
  const _MotifPainter(this.theme);
  final DiscoveryTheme? theme;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 112, size.height / 76);
    final pen = Paint()
      ..color = themeColor(theme)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = themeColor(theme).withValues(alpha: 0.13);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 112, 76),
        const Radius.circular(3),
      ),
      fill,
    );
    switch (theme) {
      case DiscoveryTheme.goOut:
        canvas.drawCircle(const Offset(43, 38), 27, pen);
        canvas.drawCircle(const Offset(43, 38), 18, pen);
        canvas.drawCircle(const Offset(43, 38), 5, pen);
        canvas.drawPath(
          Path()
            ..moveTo(80, 16)
            ..lineTo(80, 48)
            ..lineTo(96, 60),
          pen,
        );
        canvas.drawLine(const Offset(73, 16), const Offset(93, 16), pen);
      case DiscoveryTheme.dance:
        // Hanging mirror ball and reflected light, matching the web illustration.
        canvas.drawLine(const Offset(77, 2), const Offset(77, 13), pen);
        canvas.drawCircle(
          const Offset(77, 40),
          27,
          Paint()..color = pen.color.withValues(alpha: 0.04),
        );
        canvas.drawCircle(const Offset(77, 40), 27, pen);
        canvas.drawPath(
          Path()
            ..moveTo(63.5, 28)
            ..quadraticBezierTo(70.25, 30.25, 77, 30.25)
            ..lineTo(77, 45.25)
            ..quadraticBezierTo(68, 45.25, 61.25, 43)
            ..quadraticBezierTo(61.25, 34.75, 63.5, 28)
            ..close()
            ..moveTo(77, 45.25)
            ..quadraticBezierTo(86, 45.25, 92.75, 43)
            ..quadraticBezierTo(92, 52.75, 87.5, 61)
            ..quadraticBezierTo(82.25, 63.25, 77, 63.25)
            ..close(),
          fill,
        );
        final gridPen = Paint()
          ..color = pen.color.withValues(alpha: 0.8)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;
        canvas.drawPath(
          Path()
            ..moveTo(77, 13)
            ..cubicTo(56.75, 25.75, 56.75, 54.25, 77, 67)
            ..moveTo(77, 13)
            ..cubicTo(97.25, 25.75, 97.25, 54.25, 77, 67)
            ..moveTo(77, 13)
            ..lineTo(77, 67)
            ..moveTo(56, 23.5)
            ..quadraticBezierTo(77, 35.5, 98, 23.5)
            ..moveTo(50, 40)
            ..quadraticBezierTo(77, 50.5, 104, 40)
            ..moveTo(56.75, 57.25)
            ..quadraticBezierTo(77, 68.5, 97.25, 57.25),
          gridPen,
        );
        final sparkle = Path()
          ..moveTo(21, 19)
          ..quadraticBezierTo(24, 34, 39, 38)
          ..quadraticBezierTo(24, 41, 21, 57)
          ..quadraticBezierTo(18, 41, 3, 38)
          ..quadraticBezierTo(18, 34, 21, 19)
          ..close();
        canvas.drawPath(
          sparkle,
          Paint()..color = pen.color.withValues(alpha: 0.06),
        );
        canvas.drawPath(sparkle, pen);
        canvas.drawPath(
          Path()
            ..moveTo(42, 9)
            ..lineTo(42, 19)
            ..moveTo(37, 14)
            ..lineTo(47, 14)
            ..moveTo(105, 64)
            ..lineTo(105, 72)
            ..moveTo(101, 68)
            ..lineTo(109, 68),
          pen,
        );
        pen.color = pen.color.withValues(alpha: 0.5);
        canvas.drawPath(
          Path()
            ..moveTo(39, 64)
            ..lineTo(44, 62)
            ..moveTo(106, 18)
            ..lineTo(109, 20),
          pen,
        );
      case DiscoveryTheme.workshop:
        canvas.drawPath(
          Path()
            ..moveTo(10, 43)
            ..lineTo(25, 13)
            ..lineTo(32, 17)
            ..lineTo(17, 47)
            ..lineTo(7, 53)
            ..close()
            ..moveTo(22, 19)
            ..lineTo(29, 23)
            ..moveTo(10, 43)
            ..lineTo(17, 47),
          pen,
        );
        canvas.drawCircle(const Offset(33, 61), 7, pen);
        canvas.drawCircle(const Offset(51, 64), 7, pen);
        canvas.drawPath(
          Path()
            ..moveTo(36, 55)
            ..lineTo(53, 26)
            ..lineTo(49, 57)
            ..moveTo(45, 58)
            ..lineTo(29, 27)
            ..lineTo(44, 44),
          pen,
        );
        canvas.drawCircle(
          const Offset(44, 48),
          1.5,
          Paint()..color = pen.color,
        );
        canvas.drawPath(
          Path()
            ..moveTo(67, 13)
            ..lineTo(89, 10)
            ..lineTo(101, 20)
            ..lineTo(105, 56)
            ..lineTo(73, 61)
            ..close()
            ..moveTo(89, 10)
            ..lineTo(91, 23)
            ..lineTo(101, 20)
            ..moveTo(77, 34)
            ..lineTo(95, 31)
            ..moveTo(78, 44)
            ..lineTo(91, 42),
          pen,
        );
      case DiscoveryTheme.film:
        canvas.drawCircle(const Offset(76, 35), 26, pen);
        canvas.drawCircle(const Offset(76, 35), 3, pen);
        for (final point in [
          const Offset(76, 18),
          const Offset(93, 35),
          const Offset(76, 52),
          const Offset(59, 35),
        ]) {
          canvas.drawCircle(point, 6, pen);
        }
        canvas.drawPath(
          Path()
            ..moveTo(76, 61)
            ..lineTo(97, 61)
            ..quadraticBezierTo(106, 61, 106, 52),
          pen,
        );
        canvas.drawPath(
          Path()
            ..moveTo(7, 31)
            ..lineTo(39, 23)
            ..lineTo(42, 34)
            ..lineTo(10, 42)
            ..close()
            ..moveTo(10, 42)
            ..lineTo(42, 42)
            ..lineTo(42, 65)
            ..lineTo(10, 65)
            ..close()
            ..moveTo(17, 30)
            ..lineTo(24, 39)
            ..moveTo(30, 26)
            ..lineTo(37, 35)
            ..moveTo(18, 50)
            ..lineTo(34, 50)
            ..moveTo(18, 57)
            ..lineTo(29, 57),
          pen,
        );
      case DiscoveryTheme.literature:
        canvas.drawPath(
          Path()
            ..moveTo(43, 21)
            ..quadraticBezierTo(58, 13, 73, 21)
            ..quadraticBezierTo(88, 13, 103, 21)
            ..lineTo(103, 65)
            ..quadraticBezierTo(88, 57, 73, 65)
            ..quadraticBezierTo(58, 57, 43, 65)
            ..close()
            ..moveTo(73, 21)
            ..lineTo(73, 65),
          pen,
        );
        for (final y in [32.0, 42.0, 52.0]) {
          canvas.drawPath(
            Path()
              ..moveTo(49, y)
              ..quadraticBezierTo(58, y - 3, 66, y)
              ..moveTo(80, y)
              ..quadraticBezierTo(89, y - 3, 97, y),
            pen,
          );
        }
        canvas.drawPath(
          Path()
            ..moveTo(8, 28)
            ..lineTo(31, 28)
            ..lineTo(31, 39)
            ..lineTo(8, 39)
            ..close()
            ..moveTo(5, 40)
            ..lineTo(34, 40)
            ..lineTo(34, 51)
            ..lineTo(5, 51)
            ..close()
            ..moveTo(10, 52)
            ..lineTo(33, 52)
            ..lineTo(33, 63)
            ..lineTo(10, 63)
            ..close(),
          pen,
        );
      case DiscoveryTheme.culture:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(16, 13, 80, 50),
            const Radius.circular(3),
          ),
          pen,
        );
        canvas.drawPath(
          Path()
            ..moveTo(19, 16)
            ..lineTo(44, 16)
            ..quadraticBezierTo(43, 41, 19, 51)
            ..close(),
          pen,
        );
        canvas.drawPath(
          Path()
            ..moveTo(93, 16)
            ..lineTo(68, 16)
            ..quadraticBezierTo(69, 41, 93, 51)
            ..close(),
          pen,
        );
        canvas.drawLine(const Offset(12, 64), const Offset(100, 64), pen);
      case DiscoveryTheme.joinIn:
        canvas.drawPath(
          Path()
            ..moveTo(18, 57)
            ..cubicTo(18, 22, 67, 68, 70, 29)
            ..quadraticBezierTo(71, 15, 94, 15),
          pen,
        );
        for (final point in [
          const Offset(18, 57),
          const Offset(55, 47),
          const Offset(94, 15),
        ]) {
          canvas.drawCircle(point, 5, Paint()..color = themeColor(theme));
        }
        canvas.drawCircle(const Offset(42, 19), 7, pen);
        canvas.drawArc(
          const Rect.fromLTWH(31, 29, 22, 21),
          3.14,
          3.14,
          false,
          pen,
        );
      case null:
        canvas.drawCircle(const Offset(56, 38), 22, pen);
        canvas.drawLine(const Offset(56, 25), const Offset(56, 51), pen);
        canvas.drawLine(const Offset(43, 38), const Offset(69, 38), pen);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MotifPainter oldDelegate) =>
      oldDelegate.theme != theme;
}

class EventTimeline extends StatefulWidget {
  const EventTimeline({
    super.key,
    required this.events,
    required this.onOpen,
    this.now,
  });
  final List<WagzEvent> events;
  final ValueChanged<WagzEvent> onOpen;
  final String? now;

  @override
  State<EventTimeline> createState() => _EventTimelineState();
}

class _EventTimelineState extends State<EventTimeline> {
  bool expanded = false;
  bool chartOpen = false;

  @override
  Widget build(BuildContext context) {
    final ordered = rankForAudience(widget.events);
    final visible = (expanded ? ordered : ordered.take(3))
        .map((row) => row.event)
        .toList();
    final timeline = timelineFor(visible);
    final lanes = timeline.ranges.fold<int>(
      1,
      (count, range) => range.lane + 1 > count ? range.lane + 1 : count,
    );
    return Container(
      key: const ValueKey('event-timeline'),
      padding: chartOpen
          ? const EdgeInsets.fromLTRB(12, 20, 12, 8)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xffe9edde),
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (chartOpen) ...[
            const Eyebrow('RITAM GRADA'),
            const SizedBox(height: 8),
            Text(
              'Sve ima svoj trenutak.',
              style: TextStyle(
                fontFamily: 'Space Grotesk',
                fontWeight: FontWeight.w800,
                fontSize: chartOpen ? 25 : 20,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Početak, kraj i sve između.',
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ],
          SizedBox(
            width: double.infinity,
            child: Semantics(
              expanded: chartOpen,
              child: TextButton(
                key: const ValueKey('timeline-toggle'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 10,
                  ),
                  alignment: Alignment.centerLeft,
                ),
                onPressed: () => setState(() {
                  chartOpen = !chartOpen;
                  expanded = false;
                }),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            chartOpen
                                ? 'Zatvori vremensku crtu'
                                : 'Otvori vremensku crtu',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (!chartOpen) ...[
                            const SizedBox(height: 3),
                            const Text(
                              'Datumi i trajanja na jednom mjestu.',
                              style: TextStyle(
                                fontSize: 11,
                                color: muted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(chartOpen ? Icons.remove : Icons.add, size: 20),
                  ],
                ),
              ),
            ),
          ),
          if (chartOpen) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (final entry
                    in const {
                      DiscoveryTheme.goOut: 'Izlasci',
                      DiscoveryTheme.dance: 'Ples',
                      DiscoveryTheme.workshop: 'Radionice',
                      DiscoveryTheme.film: 'Film',
                      DiscoveryTheme.literature: 'Književnost',
                      DiscoveryTheme.culture: 'Kultura',
                      DiscoveryTheme.joinIn: 'Druženje',
                    }.entries.where(
                      (entry) => visible.any(
                        (event) =>
                            themeForCategory(event.category) == entry.key,
                      ),
                    ))
                  _Legend(label: entry.value, color: themeColor(entry.key)),
              ],
            ),
            const SizedBox(height: 12),
            const Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _Legend(label: 'Početak', color: ink),
                _Legend(label: 'Kraj', color: ink, hollow: true),
              ],
            ),
            const SizedBox(height: 7),
            const Text(
              'Luk spaja početak i kraj. Razmaci nisu mjerilo trajanja.',
              style: TextStyle(fontSize: 11, height: 1.5, color: muted),
            ),
            const SizedBox(height: 14),
            for (var index = 0; index < timeline.moments.length; index++)
              _TimelineStation(
                timeline: timeline,
                index: index,
                lanes: lanes,
                now: widget.now,
                onTap: () => widget.onOpen(timeline.moments[index].event),
              ),
            if (ordered.length > 3)
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  key: const ValueKey('timeline-expand'),
                  onPressed: () => setState(() => expanded = !expanded),
                  icon: Icon(expanded ? Icons.remove : Icons.add),
                  label: Text(
                    expanded ? 'Prikaži manje' : 'Cijela vremenska crta',
                  ),
                ),
              )
            else
              const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.label,
    required this.color,
    this.hollow = false,
  });
  final String label;
  final Color color;
  final bool hollow;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        hollow ? Icons.radio_button_unchecked : Icons.circle,
        size: 8,
        color: color,
      ),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );
}

class _TimelineStation extends StatelessWidget {
  const _TimelineStation({
    required this.timeline,
    required this.index,
    required this.lanes,
    required this.onTap,
    this.now,
  });
  final EventTimelineData timeline;
  final int index, lanes;
  final String? now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final moment = timeline.moments[index];
    final event = moment.event;
    final ending = moment.ending;
    final end = knownEnd(event);
    final duration = durationLabel(event);
    final color = themeColor(themeForCategory(event.category));
    final dateWidth = 43 * MediaQuery.textScalerOf(context).scale(11) / 11;
    final station = CustomPaint(
      painter: _SpinePainter(timeline, index, dateWidth + 11),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: SizedBox(
                width: dateWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatDate(moment.value, 'EEE').toUpperCase(),
                      key: ValueKey(
                        'timeline-weekday-${ending ? 'end' : 'event'}-${event.id}',
                      ),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatDate(moment.value, 'd. M.'),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      moment.value.length == 10
                          ? 'sat nije naveden'
                          : formatTime(moment.value),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 10,
                        color: muted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 29 + lanes * 7),
            if (!ending)
              Expanded(
                child: Material(
                  color: paper,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(7),
                    side: const BorderSide(color: Color(0xffcfd5c4)),
                  ),
                  child: InkWell(
                    key: ValueKey('timeline-event-${event.id}'),
                    borderRadius: BorderRadius.circular(7),
                    onTap: onTap,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 70),
                      child: Padding(
                        padding: const EdgeInsets.all(11),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (now != null && isOngoing(event, now!)) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 3,
                                ),
                                color: const Color(0xffe1ecc8),
                                child: const Text(
                                  'U TIJEKU',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Color(0xff425124),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                            ],
                            Text(
                              event.title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              eventCategoryLabel(event),
                              style: TextStyle(fontSize: 11, color: color),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              end == null
                                  ? 'Kraj nije naveden'
                                  : '↳ ${duration ?? '${formatDate(event.startsAt, 'd. M.')} – ${formatDate(end, 'd. M.')}'}',
                              style: TextStyle(
                                fontSize: end == null ? 10 : 12,
                                color: end == null ? muted : ink,
                                fontWeight: end == null
                                    ? FontWeight.normal
                                    : FontWeight.w700,
                              ),
                            ),
                            if (event.status != 'scheduled') ...[
                              const SizedBox(height: 4),
                              Text(
                                event.status == 'cancelled'
                                    ? 'Otkazano'
                                    : 'Odgođeno',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xff9b3022),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                            const SizedBox(height: 5),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Detalji',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    size: 14,
                                    color: color,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return ending
        ? Semantics(
            key: ValueKey('timeline-end-${event.id}'),
            container: true,
            label: 'Završetak: ${event.title}.',
            child: station,
          )
        : Semantics(
            button: true,
            label: eventActionLabel(event, now),
            onTap: onTap,
            excludeSemantics: true,
            child: station,
          );
  }
}

/// One neutral spine and event-specific ranges. Every bend ends at a real endpoint.
class _SpinePainter extends CustomPainter {
  const _SpinePainter(this.timeline, this.index, this.spine);
  final EventTimelineData timeline;
  final int index;
  final double spine;
  @override
  void paint(Canvas canvas, Size size) {
    final x = spine;
    const y = 24.0;
    canvas.drawLine(
      Offset(x, index == 0 ? y : 0),
      Offset(x, size.height),
      Paint()
        ..color = const Color(0xff7e8873)
        ..strokeWidth = 1,
    );
    for (final range in timeline.ranges) {
      if (index < range.start || index > range.end) continue;
      final branch = x + 12 + range.lane * 7;
      final pen = Paint()
        ..color = themeColor(
          themeForCategory(range.event.category),
        ).withValues(alpha: range.event.status == 'scheduled' ? 1 : 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      final path = Path();
      if (index == range.start) {
        path.moveTo(x, y);
        path.lineTo(branch - 6, y);
        path.quadraticBezierTo(branch, y, branch, y + 6);
        path.lineTo(branch, size.height);
      } else if (index == range.end) {
        path.moveTo(branch, 0);
        path.lineTo(branch, y - 6);
        path.quadraticBezierTo(branch, y, branch - 6, y);
        path.lineTo(x, y);
      } else {
        path.moveTo(branch, 0);
        path.lineTo(branch, size.height);
      }
      canvas.drawPath(path, pen);
    }
    final moment = timeline.moments[index];
    final color = themeColor(themeForCategory(moment.event.category));
    canvas.drawCircle(
      Offset(x, y),
      moment.ending ? 4 : 5,
      Paint()
        ..color = moment.ending || moment.event.status != 'scheduled'
            ? const Color(0xffe9edde)
            : color,
    );
    canvas.drawCircle(
      Offset(x, y),
      moment.ending ? 4 : 5,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(covariant _SpinePainter oldDelegate) => true;
}

/// Ongoing programs stay reachable without filling the upcoming card feed.
class OngoingEvents extends StatefulWidget {
  const OngoingEvents({
    super.key,
    required this.events,
    required this.onOpen,
    required this.now,
  });
  final String now;
  final List<WagzEvent> events;
  final ValueChanged<WagzEvent> onOpen;
  @override
  State<OngoingEvents> createState() => _OngoingEventsState();
}

class _OngoingEventsState extends State<OngoingEvents> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('ongoing-events'),
    decoration: BoxDecoration(
      color: const Color(0xffe9edde),
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(6),
    ),
    padding: const EdgeInsets.fromLTRB(14, 16, 14, 5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          label: 'U tijeku: ${widget.events.length} događaja',
          child: Row(
            children: [
              const Icon(Icons.circle, color: Color(0xff728400), size: 7),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'U tijeku',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${widget.events.length}',
                style: const TextStyle(fontSize: 12, color: muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Još stigneš. Točne termine provjeri u najavi.',
          style: TextStyle(fontSize: 11, color: muted, height: 1.5),
        ),
        for (final event in expanded ? widget.events : widget.events.take(2))
          Semantics(
            button: true,
            label: eventActionLabel(event, widget.now),
            onTap: () => widget.onOpen(event),
            excludeSemantics: true,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: ValueKey('ongoing-event-${event.id}'),
                onTap: () => widget.onOpen(event),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 7,
                        color: themeColor(themeForCategory(event.category)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${eventDurationText(event, widget.now)}${event.endsAt!.length > 10 ? '' : ' · završni sat nije naveden'}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: muted,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.north_east, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (widget.events.length > 2)
          SizedBox(
            width: double.infinity,
            child: Semantics(
              expanded: expanded,
              child: TextButton(
                key: const ValueKey('ongoing-expand'),
                onPressed: () => setState(() => expanded = !expanded),
                child: Text(
                  expanded
                      ? 'Sažmi događaje u tijeku'
                      : 'Prikaži sve u tijeku (${widget.events.length})',
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
