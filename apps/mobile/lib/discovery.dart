import 'models.dart';

enum DiscoveryTheme { goOut, dance, workshop, culture, joinIn }

const discoveryThemes = {
  DiscoveryTheme.goOut: 'Glazba i izlasci',
  DiscoveryTheme.dance: 'Ples',
  DiscoveryTheme.workshop: 'Radionice',
  DiscoveryTheme.culture: 'Pozornica i kultura',
  DiscoveryTheme.joinIn: 'Pokret i druženje',
};

DiscoveryTheme? themeForCategory(String category) => switch (category) {
  'music' || 'nightlife' => DiscoveryTheme.goOut,
  'dance' => DiscoveryTheme.dance,
  'workshop' => DiscoveryTheme.workshop,
  'theatre' || 'culture' => DiscoveryTheme.culture,
  'sport' || 'community' => DiscoveryTheme.joinIn,
  _ => null,
};

String _categoryText(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[čć]'), 'c')
    .replaceAll('š', 's')
    .replaceAll('ž', 'z')
    .replaceAll('đ', 'd');

final _programmeTitle = RegExp(
  r'\b(?:koncert[a-z]*|festival[a-z]*|predstav[a-z]*|izlozb[a-z]*|sajam[a-z]*|konferenc[a-z]*|vecer[a-z]*|plesnjak[a-z]*|dan(?:i)? otvorenih vrata|otvoren[ai] dan)\b',
);

bool isWorkshopTitle(String title) {
  final value = _categoryText(title);
  final workshop = RegExp(
    r'\b(?:radionic[a-z]*|workshop[a-z]*)\b',
  ).firstMatch(value);
  if (workshop == null) return false;
  final programme = _programmeTitle.firstMatch(value);
  return programme == null || workshop.start < programme.start;
}

bool isWorkshopEvent(WagzEvent event) =>
    isWorkshopTitle(event.title) ||
    (!_programmeTitle.hasMatch(_categoryText(event.title)) &&
        RegExp(
          r'^(?:(?:ovo je|dogadaj je|program je|rijec je o)\s+)?(?:(?:plesna|plesnoj|kreativna|edukativna|besplatna|otvorena|jednodnevna)\s+)*(?:radionica|radionici|workshop)\b',
        ).hasMatch(_categoryText(event.description.trim())));

String eventCategoryLabel(WagzEvent event) =>
    event.category == 'dance' && isWorkshopEvent(event)
    ? 'Ples · Radionica'
    : categoryNames[event.category] ?? 'Ostalo';

class RankedEvent {
  const RankedEvent({required this.event, required this.index});
  final WagzEvent event;
  final int index;
}

/// Every event stays chronological. Legacy audience arguments are ignored.
List<RankedEvent> rankForAudience(
  List<WagzEvent> events, {
  String audience = 'all',
  String? now,
}) {
  final ranked = events.indexed
      .map((entry) => RankedEvent(event: entry.$2, index: entry.$1))
      .toList();
  ranked.sort((a, b) {
    final date = _compareDates(a.event.startsAt, b.event.startsAt);
    return date != 0 ? date : a.index.compareTo(b.index);
  });
  return ranked;
}

/// Audience mentions require a safe, matching source and a nonblank reason.
List<DiscoveryReason> sourceAudienceEvidence(WagzEvent event) => [
  for (final audience in ['students', 'adults', 'seniors'])
    ...event.discovery.audienceEvidence
        .where(
          (item) =>
              item.audience == audience &&
              item.reason.trim().isNotEmpty &&
              safeLink(item.sourceUrl) != null &&
              event.sources.any((source) => source.url == item.sourceUrl),
        )
        .take(1),
];

List<String> sourceAudienceLabels(WagzEvent event) => sourceAudienceEvidence(
  event,
).map((item) => audienceNames[item.audience]!).toList();

int _compareDates(String a, String b) {
  final day = dayOnly(a).compareTo(dayOnly(b));
  if (day != 0) return day;
  if ((a.length == 10) != (b.length == 10)) return a.length == 10 ? -1 : 1;
  return zagrebDate(a).compareTo(zagrebDate(b));
}

String? knownEnd(WagzEvent event) {
  final end = event.endsAt;
  if (end == null || DateTime.tryParse(end) == null) return null;
  return (end.length == 10 || event.startsAt.length == 10
          ? !dayOnly(end).isBefore(dayOnly(event.startsAt))
          : DateTime.parse(end).isAfter(DateTime.parse(event.startsAt)))
      ? end
      : null;
}

String? durationLabel(WagzEvent event) {
  final end = knownEnd(event);
  if (end == null || end.length == 10 || event.startsAt.length == 10) {
    return null;
  }
  final minutes =
      (DateTime.parse(
                end,
              ).difference(DateTime.parse(event.startsAt)).inMilliseconds /
              60000)
          .round();
  final days = minutes ~/ 1440,
      hours = (minutes % 1440) ~/ 60,
      rest = minutes % 60;
  final parts = [
    if (days > 0) '$days d',
    if (hours > 0) '$hours h',
    if (rest > 0) '$rest min',
  ];
  return parts.isEmpty ? '< 1 min' : parts.join(' ');
}

bool isOngoing(WagzEvent event, String now) {
  final end = knownEnd(event);
  if (end == null || event.status != 'scheduled') return false;
  final started = event.startsAt.length == 10
      ? dayOnly(event.startsAt).isBefore(dayOnly(now))
      : !DateTime.parse(event.startsAt).isAfter(DateTime.parse(now));
  return started &&
      (end.length == 10
          ? !dayOnly(now).isAfter(dayOnly(end))
          : DateTime.parse(now).isBefore(DateTime.parse(end)));
}

String eventDurationText(WagzEvent event, [String? now]) {
  final end = knownEnd(event);
  if (end == null) return 'Kraj nije naveden';
  final date = formatDate(end, 'd.M.');
  final time = end.length > 10 ? formatTime(end) : null;
  if (now != null && isOngoing(event, now)) {
    return time != null && dayOnly(now) == dayOnly(end)
        ? 'Danas do $time'
        : 'Traje do $date${time == null ? '' : ' · $time'}';
  }
  final exact = durationLabel(event);
  if (exact != null && dayOnly(event.startsAt) == dayOnly(end)) {
    return 'Traje $exact';
  }
  if (event.startsAt.length == 10 && end.length == 10) {
    final days = dayOnly(end).difference(dayOnly(event.startsAt)).inDays + 1;
    return days == 1
        ? 'Isti dan · sat završetka nije naveden'
        : 'Traje $days dana';
  }
  return 'Traje do $date${time == null ? '' : ' · $time'}';
}

class TimelineMoment {
  const TimelineMoment(this.event, this.value, this.ending);
  final WagzEvent event;
  final String value;
  final bool ending;
}

class TimelineRange {
  const TimelineRange(this.event, this.start, this.end, this.lane);
  final WagzEvent event;
  final int start, end, lane;
}

class EventTimelineData {
  const EventTimelineData(this.moments, this.ranges);
  final List<TimelineMoment> moments;
  final List<TimelineRange> ranges;
}

EventTimelineData timelineFor(List<WagzEvent> events) {
  final moments = [
    for (final event in events) ...[
      TimelineMoment(event, event.startsAt, false),
      if (knownEnd(event) != null)
        TimelineMoment(event, knownEnd(event)!, true),
    ],
  ];
  // Keep equivalent timestamps stable, as in the web client.
  final ordered = moments.indexed.toList()
    ..sort((a, b) {
      final day = dayOnly(a.$2.value).compareTo(dayOnly(b.$2.value));
      if (day != 0) return day;
      double position(TimelineMoment item) => item.value.length == 10
          ? (item.ending ? double.infinity : double.negativeInfinity)
          : DateTime.parse(item.value).millisecondsSinceEpoch.toDouble();
      final time = position(a.$2).compareTo(position(b.$2));
      if (time != 0) return time;
      if (a.$2.ending != b.$2.ending) return a.$2.ending ? 1 : -1;
      return a.$1.compareTo(b.$1);
    });
  final sorted = ordered.map((row) => row.$2).toList();
  final ranges = <TimelineRange>[];
  final occupied = <int>[];
  for (var start = 0; start < sorted.length; start++) {
    final moment = sorted[start];
    if (moment.ending || knownEnd(moment.event) == null) continue;
    final end = sorted.indexWhere(
      (item) => item.event.id == moment.event.id && item.ending,
    );
    var lane = occupied.indexWhere((until) => until < start);
    if (lane == -1) {
      lane = occupied.length;
      occupied.add(end);
    } else {
      occupied[lane] = end;
    }
    ranges.add(TimelineRange(moment.event, start, end, lane));
  }
  return EventTimelineData(sorted, ranges);
}
