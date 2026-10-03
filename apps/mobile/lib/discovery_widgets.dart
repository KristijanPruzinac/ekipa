import 'package:flutter/material.dart';
import 'design.dart';
import 'discovery.dart';
import 'models.dart';

Color themeColor(DiscoveryTheme? theme) => switch (theme) {
  DiscoveryTheme.goOut => const Color(0xff8672b7),
  DiscoveryTheme.culture => const Color(0xffc87652),
  DiscoveryTheme.joinIn => const Color(0xff568773),
  null => muted,
};

Color eventPaper(WagzEvent event) => switch (themeForCategory(event.category)) {
  DiscoveryTheme.goOut => const Color(0xffe9e1f0),
  DiscoveryTheme.culture => const Color(0xfff2e4d4),
  DiscoveryTheme.joinIn => const Color(0xffdeeadc),
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

class AudienceSelector extends StatelessWidget {
  const AudienceSelector({
    super.key,
    required this.audience,
    required this.onChanged,
  });
  final String audience;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final largeText = MediaQuery.textScalerOf(context).scale(13) > 18;
      final columns = largeText && constraints.maxWidth < 500 ? 2 : 4;
      return Wrap(
        spacing: 6,
        runSpacing: 6,
        children: audienceNames.entries.map((entry) {
          final selected = audience == entry.key;
          return SizedBox(
            width: (constraints.maxWidth - (columns - 1) * 6) / columns,
            child: Semantics(
              selected: selected,
              button: true,
              child: Material(
                color: selected ? ink : paper,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(color: ink),
                  borderRadius: BorderRadius.circular(4),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  key: ValueKey('audience-${entry.key}'),
                  onTap: () => onChanged(entry.key),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 3,
                        vertical: 13,
                      ),
                      child: Text(
                        entry.value,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected ? lime : ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );
    },
  );
}

class EventTimeline extends StatefulWidget {
  const EventTimeline({super.key, required this.events, required this.onOpen});
  final List<WagzEvent> events;
  final ValueChanged<WagzEvent> onOpen;

  @override
  State<EventTimeline> createState() => _EventTimelineState();
}

class _EventTimelineState extends State<EventTimeline> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) {
    final ordered = rankForAudience(widget.events);
    final visible = expanded ? ordered : ordered.take(3);
    return Container(
      key: const ValueKey('event-timeline'),
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      decoration: BoxDecoration(
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Grad, po danima.',
            style: TextStyle(
              fontFamily: 'Space Grotesk',
              fontWeight: FontWeight.w800,
              fontSize: 23,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Kratki pregled · uvijek po datumu',
            style: TextStyle(fontSize: 12, color: muted),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final entry in const {
                DiscoveryTheme.goOut: 'Izlasci',
                DiscoveryTheme.culture: 'Kultura',
                DiscoveryTheme.joinIn: 'Druženje',
              }.entries)
                _Legend(label: entry.value, color: themeColor(entry.key)),
              if (widget.events.any(
                (event) => themeForCategory(event.category) == null,
              ))
                const _Legend(label: 'Ostalo', color: muted),
            ],
          ),
          const SizedBox(height: 12),
          for (final row in visible)
            _TimelineStation(
              event: row.event,
              onTap: () => widget.onOpen(row.event),
            ),
          if (ordered.length > 3)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('timeline-expand'),
                onPressed: () => setState(() => expanded = !expanded),
                icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                label: Text(
                  expanded ? 'Prikaži manje' : 'Cijela vremenska crta',
                ),
              ),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.circle, size: 7, color: color),
      const SizedBox(width: 5),
      Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
      ),
    ],
  );
}

class _TimelineStation extends StatelessWidget {
  const _TimelineStation({required this.event, required this.onTap});
  final WagzEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      key: ValueKey('timeline-event-${event.id}'),
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 68,
              child: CustomPaint(
                painter: _RailsPainter(themeForCategory(event.category)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 11, 0, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${formatDate(event.startsAt, 'EEE, d. M.')} · ${formatTime(event.startsAt)}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: muted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      event.status == 'scheduled'
                          ? categoryNames[event.category] ?? 'Ostalo'
                          : event.status == 'cancelled'
                          ? 'OTKAZANO'
                          : 'ODGOĐENO',
                      style: TextStyle(
                        fontSize: 10,
                        color: event.status == 'scheduled'
                            ? muted
                            : const Color(0xff9b3022),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RailsPainter extends CustomPainter {
  const _RailsPainter(this.theme);
  final DiscoveryTheme? theme;

  @override
  void paint(Canvas canvas, Size size) {
    const positions = [8.0, 24.0, 40.0];
    for (var index = 0; index < 3; index++) {
      canvas.drawLine(
        Offset(positions[index], 0),
        Offset(positions[index], size.height),
        Paint()
          ..color = themeColor(
            DiscoveryTheme.values[index],
          ).withValues(alpha: 0.5)
          ..strokeWidth = 2,
      );
    }
    final x = theme == null ? 57.0 : positions[theme!.index];
    final y = size.height / 2;
    canvas.drawLine(
      Offset(x, y),
      Offset(64, y),
      Paint()
        ..color = themeColor(theme)
        ..strokeWidth = 1,
    );
    canvas.drawCircle(Offset(x, y), 5, Paint()..color = paper);
    canvas.drawCircle(
      Offset(x, y),
      5,
      Paint()
        ..color = themeColor(theme)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _RailsPainter oldDelegate) =>
      oldDelegate.theme != theme;
}
