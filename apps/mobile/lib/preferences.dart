import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'design.dart';
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

int compareEvents(
  WagzEvent a,
  WagzEvent b,
  DiscoveryProfile profile,
  bool forYou,
) {
  if (forYou) {
    final score = recommendation(
      b,
      profile,
    ).score.compareTo(recommendation(a, profile).score);
    if (score != 0) return score;
  }
  final date = zagrebDate(a.startsAt).compareTo(zagrebDate(b.startsAt));
  return date != 0 ? date : a.title.compareTo(b.title);
}

Future<DiscoveryProfile?> showPreferences(
  BuildContext context,
  DiscoveryProfile profile,
) => showModalBottomSheet<DiscoveryProfile>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => _PreferencesSheet(profile: profile),
);

class _PreferencesSheet extends StatefulWidget {
  const _PreferencesSheet({required this.profile});
  final DiscoveryProfile profile;
  @override
  State<_PreferencesSheet> createState() => _PreferencesSheetState();
}

class _PreferencesSheetState extends State<_PreferencesSheet> {
  late String audience = widget.profile.audience;
  late Set<String> interests = widget.profile.interests.toSet();
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Tvoj radar.',
                style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900),
              ),
            ),
            IconButton(
              tooltip: 'Zatvori',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Odaberi što želiš istaknuti. Svi događaji ostaju dostupni. '
          'Odabir se sprema samo na ovom uređaju.',
          style: TextStyle(height: 1.5, color: muted),
        ),
        const SizedBox(height: 24),
        const Eyebrow('ZA KOGA TRAŽIŠ PLAN?'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: audienceNames.entries
              .map(
                (entry) => ChoiceChip(
                  label: Text(entry.value),
                  selected: audience == entry.key,
                  onSelected: (_) => setState(() => audience = entry.key),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 24),
        const Eyebrow('TVOJI INTERESI · NEOBAVEZNO'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: categoryNames.entries
              .map(
                (entry) => FilterChip(
                  label: Text(entry.value),
                  selected: interests.contains(entry.key),
                  onSelected: (selected) => setState(
                    () => selected
                        ? interests.add(entry.key)
                        : interests.remove(entry.key),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(
              context,
              DiscoveryProfile(
                audience: audience,
                interests: interests.toList(),
              ),
            ),
            child: const Text('Spremi moj odabir'),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: () => setState(() {
              audience = 'all';
              interests.clear();
            }),
            child: const Text('Poništi odabir'),
          ),
        ),
      ],
    ),
  );
}
