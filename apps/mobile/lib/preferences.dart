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
  const Recommendation(this.score, this.personal, this.reasons, [this.kind]);
  final int score;
  final bool personal;
  final List<String> reasons;
  final String? kind;
}

const audienceDescriptions = {
  'all': 'Svi događaji, po datumu.',
  'students':
      'Prvo studentski programi, povoljniji izlasci, glazba i radionice.',
  'adults':
      'Prvo programi za odrasle, kazalište, koncerti i događaji za druženje.',
  'seniors':
      'Prvo programi za starije, izložbe, kazalište i koncertni ciklusi.',
};

// Editorial suggestions from published facts, kept in sync with shared/discovery.ts.
const _audienceWeights = {
  'students': {
    'music': 2,
    'nightlife': 3,
    'theatre': 1,
    'culture': 1,
    'sport': 1,
    'community': 2,
    'other': 0,
  },
  'adults': {
    'music': 2,
    'nightlife': 1,
    'theatre': 3,
    'culture': 2,
    'sport': 2,
    'community': 2,
    'other': 0,
  },
  'seniors': {
    'music': 1,
    'nightlife': 0,
    'theatre': 3,
    'culture': 3,
    'sport': 1,
    'community': 2,
    'other': 0,
  },
};

Recommendation recommendation(WagzEvent event, DiscoveryProfile profile) {
  if (event.status != 'scheduled' ||
      !_audienceWeights.containsKey(profile.audience)) {
    return const Recommendation(0, false, []);
  }
  final reasons = <String>[];
  var score = 0;
  String? kind;
  final audience = profile.audience;
  final audienceMatches = event.discovery.audienceEvidence.where(
    (evidence) => evidence.audience == profile.audience,
  );
  if (profile.audience != 'all' && audienceMatches.isNotEmpty) {
    score += 100;
    kind = 'source';
    reasons.add(audienceMatches.first.reason);
  }
  final title = event.title.toLowerCase();
  if (RegExp(r'radionic|karijer|predavanj|kviz').hasMatch(title)) {
    score += {'students': 4, 'adults': 3, 'seniors': 1}[audience]!;
    reasons.add('Radionica, predavanje ili susret za učenje i razmjenu.');
  } else if (RegExp(r'izložb|književ|knjig').hasMatch(title)) {
    score += {'students': 1, 'adults': 2, 'seniors': 3}[audience]!;
    reasons.add('Izložbeni ili književni program u najavi.');
  } else if (event.category == 'music' &&
      RegExp(
        r'jazz|orkest|orekstar|simfon|zbor|ciklus|klasič',
      ).hasMatch(title)) {
    score += {'students': 1, 'adults': 2, 'seniors': 4}[audience]!;
    reasons.add('Jazz, orkestar, zbor ili koncertni ciklus u najavi.');
  }
  if (event.discovery.free ||
      RegExp(
        r'^(besplatno|besplatan ulaz|ulaz slobodan|slobodan ulaz|0\s*€)[.!\s]*$',
        caseSensitive: false,
      ).hasMatch(event.price?.trim() ?? '')) {
    score += audience == 'students' ? 3 : 1;
    reasons.add('Besplatan ulaz naveden je u najavi.');
  }
  final categoryScore = _audienceWeights[audience]![event.category] ?? 0;
  score += categoryScore;
  if (categoryScore > 0) {
    reasons.add(
      'Vrsta programa: ${(categoryNames[event.category] ?? 'Ostalo').toLowerCase()}.',
    );
  }
  if (kind == null && score > 0) kind = 'suggestion';
  return Recommendation(score, score >= 3, reasons, kind);
}
