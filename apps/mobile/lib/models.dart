import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

const categoryNames = {
  'music': 'Glazba',
  'nightlife': 'Noćni život',
  'dance': 'Ples',
  'workshop': 'Radionica',
  'theatre': 'Kazalište',
  'culture': 'Kultura',
  'sport': 'Sport',
  'community': 'Zajednica',
  'other': 'Ostalo',
};
const audienceNames = {
  'all': 'Svi',
  'students': 'Studenti',
  'adults': 'Odrasli',
  'seniors': 'Stariji',
};

class EventEvidence {
  const EventEvidence(this.name, this.url);
  final String name;
  final String url;
  factory EventEvidence.fromJson(Map<String, dynamic> json) =>
      EventEvidence(json['sourceName'] as String, json['url'] as String);
}

class DiscoveryReason {
  const DiscoveryReason(this.reason, this.sourceUrl, {this.audience});
  final String reason;
  final String sourceUrl;
  final String? audience;
}

class EventDiscovery {
  const EventDiscovery({
    this.audiences = const [],
    this.audienceEvidence = const [],
    this.prominenceLabel,
    this.prominenceEvidence,
    this.free = false,
  });
  final List<String> audiences;
  final List<DiscoveryReason> audienceEvidence;
  final String? prominenceLabel;
  final DiscoveryReason? prominenceEvidence;
  final bool free;

  factory EventDiscovery.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const EventDiscovery();
    final prominence = json['prominence'] as Map<String, dynamic>?;
    return EventDiscovery(
      audiences: (json['audiences'] as List? ?? []).cast<String>(),
      audienceEvidence: (json['audienceEvidence'] as List? ?? [])
          .map(
            (value) => DiscoveryReason(
              value['reason'] as String,
              value['sourceUrl'] as String,
              audience: value['audience'] as String,
            ),
          )
          .toList(),
      prominenceLabel: prominence?['label'] as String?,
      prominenceEvidence: prominence == null
          ? null
          : DiscoveryReason(
              prominence['reason'] as String,
              prominence['sourceUrl'] as String,
            ),
      free: json['free'] == true,
    );
  }
}

class WagzEvent {
  const WagzEvent({
    required this.id,
    required this.title,
    required this.startsAt,
    this.description = '',
    this.endsAt,
    this.venue,
    this.address,
    this.city = 'Osijek',
    this.category = 'other',
    this.price,
    this.status = 'scheduled',
    this.sources = const [],
    this.discovery = const EventDiscovery(),
  });
  final String id, title, description, startsAt, city, category, status;
  final String? endsAt, venue, address, price;
  final List<EventEvidence> sources;
  final EventDiscovery discovery;

  factory WagzEvent.fromJson(Map<String, dynamic> json) => WagzEvent(
    id: json['id'] as String,
    title: json['title'] as String,
    description: json['description'] as String? ?? '',
    startsAt: json['startsAt'] as String,
    endsAt: json['endsAt'] as String?,
    venue: json['venue'] as String?,
    address: json['address'] as String?,
    city: json['city'] as String? ?? 'Osijek',
    category: json['category'] as String? ?? 'other',
    price: json['price'] as String?,
    status: json['status'] as String? ?? 'scheduled',
    sources: (json['sources'] as List? ?? [])
        .map((source) => EventEvidence.fromJson(source as Map<String, dynamic>))
        .toList(),
    discovery: EventDiscovery.fromJson(
      json['discovery'] as Map<String, dynamic>?,
    ),
  );
}

class PublicFeed {
  const PublicFeed({
    required this.events,
    required this.now,
    this.lastCheckedAt,
  });
  final List<WagzEvent> events;
  final String now;
  final String? lastCheckedAt;
  factory PublicFeed.fromJson(Map<String, dynamic> json) => PublicFeed(
    events: (json['events'] as List)
        .map((value) => WagzEvent.fromJson(value as Map<String, dynamic>))
        .toList(),
    now: json['meta']['now'] as String,
    lastCheckedAt: json['meta']['lastCheckedAt'] as String?,
  );
}

enum DateFilter { all, today, weekend, week }

const dateFilterNames = {
  DateFilter.all: 'Sve',
  DateFilter.today: 'Danas',
  DateFilter.weekend: 'Ovaj vikend',
  DateFilter.week: 'Ovaj tjedan',
};

DateTime zagrebDate(String value) {
  final date = DateTime.parse(value);
  final location = tz.getLocation('Europe/Zagreb');
  return value.length == 10
      ? tz.TZDateTime(location, date.year, date.month, date.day)
      : tz.TZDateTime.from(date, location);
}

DateTime dayOnly(String value) {
  final date = zagrebDate(value);
  return DateTime.utc(date.year, date.month, date.day);
}

String formatDate(String value, [String pattern = 'd. MMMM']) =>
    DateFormat(pattern, 'hr').format(zagrebDate(value));

String formatTime(String value) =>
    value.length == 10 ? 'Vrijeme nije navedeno' : formatDate(value, 'HH:mm');

bool inDateFilter(WagzEvent event, DateFilter filter, String now) {
  if (filter == DateFilter.all) return true;
  final today = dayOnly(now);
  var start = today;
  var end = today;
  if (filter == DateFilter.week) {
    end = today.add(Duration(days: DateTime.sunday - today.weekday));
  } else if (filter == DateFilter.weekend) {
    start = today.add(Duration(days: DateTime.friday - today.weekday));
    end = start.add(const Duration(days: 2));
  }
  return !dayOnly(event.startsAt).isAfter(end) &&
      !dayOnly(event.endsAt ?? event.startsAt).isBefore(start);
}

String normalize(String value) {
  var result = value.toLowerCase();
  const accents = {'č': 'c', 'ć': 'c', 'š': 's', 'ž': 'z', 'đ': 'd'};
  accents.forEach((from, to) => result = result.replaceAll(from, to));
  return result;
}

Uri? safeLink(String? value) {
  if (value == null) return null;
  final uri = Uri.tryParse(value);
  return uri != null &&
          ['http', 'https'].contains(uri.scheme) &&
          uri.host.isNotEmpty &&
          !uri.host.endsWith('.invalid') &&
          uri.userInfo.isEmpty
      ? uri
      : null;
}
