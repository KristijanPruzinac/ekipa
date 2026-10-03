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

/// Only an explicit audience cue changes order. Every event remains available.
/// Legacy category interests and prominence never affect this ordering.
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
      audienceMatch:
          event.status == 'scheduled' &&
          audience != 'all' &&
          event.discovery.audienceEvidence.any(
            (evidence) => evidence.audience == audience,
          ),
    );
  }).toList();
  ranked.sort((a, b) {
    if (a.audienceMatch != b.audienceMatch) return a.audienceMatch ? -1 : 1;
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
