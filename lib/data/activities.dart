/// The activity catalog. Deliberately shoulder-to-shoulder and parallel:
/// activities that remove the conversational spotlight. "Just talk" is the
/// hardest format for this population and is intentionally absent.
class Activity {
  const Activity({required this.slug, required this.label, required this.emoji, this.seed = false});

  final String slug;
  final String label;
  final String emoji;

  /// Cheapest to organize + most silence-tolerant seed the first cohorts.
  final bool seed;
}

const List<Activity> kActivities = [
  Activity(slug: 'walk', label: 'Walking', emoji: '🌿', seed: true),
  Activity(slug: 'boardgames', label: 'Board games', emoji: '🎲', seed: true),
  Activity(slug: 'hike', label: 'Hiking', emoji: '⛰️'),
  Activity(slug: 'bouldering', label: 'Bouldering', emoji: '🧗'),
  Activity(slug: 'coffee_quiet', label: 'Quiet coffee', emoji: '🍵'),
  Activity(slug: 'photography', label: 'Photo walks', emoji: '📷'),
  Activity(slug: 'cowork_hobby', label: 'Hobby co-working', emoji: '🎨'),
  Activity(slug: 'cooking', label: 'Cooking', emoji: '🍲'),
  Activity(slug: 'cinema', label: 'Cinema', emoji: '🎬'),
  Activity(slug: 'reading', label: 'Reading together', emoji: '📖'),
];
