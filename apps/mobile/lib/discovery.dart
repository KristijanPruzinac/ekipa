import 'models.dart';
import 'preferences.dart';

enum DiscoveryTheme { goOut, culture, joinIn }

const discoveryThemes = {
  DiscoveryTheme.goOut: 'Glazba i izlasci',
  DiscoveryTheme.culture: 'Pozornica i kultura',
  DiscoveryTheme.joinIn: 'Pokret i druženje',
};

DiscoveryTheme? themeForCategory(String category) => switch (category) {
  'music' || 'nightlife' => DiscoveryTheme.goOut,
  'theatre' || 'culture' => DiscoveryTheme.culture,
  'sport' || 'community' => DiscoveryTheme.joinIn,
  _ => null,
};

class RankedEvent {
  const RankedEvent({
    required this.event,
    required this.index,
    required this.audienceMatch,
    required this.recommendation,
  });
  final WagzEvent event;
  final int index;
  final bool audienceMatch;
  final Recommendation recommendation;
}

/// Source audience evidence wins, followed by transparent factual recommendations.
/// All events stay available. Svi and the timeline remain chronological.
List<RankedEvent> rankForAudience(
  List<WagzEvent> events, {
  String audience = 'all',
}) {
  final ranked = events.indexed.map((entry) {
    final (index, event) = entry;
    return RankedEvent(
      event: event,
      index: index,
      recommendation: recommendation(
        event,
        DiscoveryProfile(audience: audience),
      ),
      audienceMatch: recommendation(
        event,
        DiscoveryProfile(audience: audience),
      ).personal,
    );
  }).toList();
  ranked.sort((a, b) {
    final score = b.recommendation.score.compareTo(a.recommendation.score);
    if (score != 0) return score;
    final date = _compareDates(a.event.startsAt, b.event.startsAt);
    return date != 0 ? date : a.index.compareTo(b.index);
  });
  return ranked;
}

int _compareDates(String a, String b) {
  final day = dayOnly(a).compareTo(dayOnly(b));
  if (day != 0) return day;
  if ((a.length == 10) != (b.length == 10)) return a.length == 10 ? -1 : 1;
  return zagrebDate(a).compareTo(zagrebDate(b));
}

/// Keep old saved profiles readable while using only the chosen audience.
DiscoveryProfile audienceProfile(DiscoveryProfile profile) =>
    DiscoveryProfile(audience: profile.audience);

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
