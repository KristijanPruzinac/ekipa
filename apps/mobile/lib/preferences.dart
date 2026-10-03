import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class DiscoveryProfile {
  const DiscoveryProfile({this.audience = 'all', this.interests = const []});
  final String audience;
  final List<String> interests;
  bool get isSet => audience != 'all' || interests.isNotEmpty;

  static DiscoveryProfile load(SharedPreferences preferences) {
    try {
      final json = jsonDecode(
        preferences.getString('wagz.discovery.v1') ?? '{}',
      );
      return DiscoveryProfile(
        audience: audienceNames.containsKey(json['audience'])
            ? json['audience'] as String
            : 'all',
        interests: (json['interests'] as List? ?? [])
            .whereType<String>()
            .where(categoryNames.containsKey)
            .toList(),
      );
    } catch (_) {
      return const DiscoveryProfile();
    }
  }

  Future<bool> save(SharedPreferences preferences) => preferences.setString(
    'wagz.discovery.v1',
    jsonEncode({'audience': audience, 'interests': interests}),
  );
}

class Recommendation {
  const Recommendation(this.score, this.personal, this.reasons);
  final int score;
  final bool personal;
  final List<String> reasons;
}

Recommendation recommendation(WagzEvent event, DiscoveryProfile profile) {
  if (event.status != 'scheduled') return const Recommendation(0, false, []);
  final reasons = <String>[];
  var score = 0;
  var personal = false;
  final audienceMatches = event.discovery.audienceEvidence.where(
    (evidence) => evidence.audience == profile.audience,
  );
  if (profile.audience != 'all' && audienceMatches.isNotEmpty) {
    score += 4;
    personal = true;
    reasons.add(audienceMatches.first.reason);
  }
  if (profile.interests.contains(event.category)) {
    score += 2;
    personal = true;
    reasons.add('Tvoj interes: ${categoryNames[event.category] ?? 'Ostalo'}.');
  }
  if (event.discovery.prominenceEvidence != null) {
    score += 1;
    reasons.add(event.discovery.prominenceEvidence!.reason);
  }
  return Recommendation(score, personal, reasons);
}
