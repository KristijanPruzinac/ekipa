import 'package:ekipa_core/ekipa_core.dart';
import 'package:simulator/src/agent.dart';
import 'package:simulator/src/behaviour.dart';
import 'package:simulator/src/city.dart';

/// Samples agents.
///
/// **Every draw comes from an injected [RandomSource].** The simulator's whole
/// claim is that a metric table is reproducible from a seed; a single
/// `Random()` anywhere in here would make a surprising run unreproducible, and
/// an unreproducible surprise is an anecdote.
final class Population {
  /// Builds a sampler for one city and one behaviour model.
  const Population({required this.city, required this.behaviour});

  /// The city agents are sampled into.
  final SimCity city;

  /// The model their traits are sampled from.
  final Behaviour behaviour;

  /// Samples [count] agents joining in [week], numbered from [startIndex].
  List<Agent> sample(
    int count,
    int week,
    int startIndex,
    RandomSource random,
  ) => [
    for (var i = 0; i < count; i++)
      _one(startIndex + i, week, random.fork('agent:${startIndex + i}')),
  ];

  Agent _one(int index, int week, RandomSource random) {
    // Home anchors cluster around districts rather than filling a box: people
    // live in neighbourhoods, and a uniform scatter would give almost everybody
    // the same two reachable clusters and quietly delete the geography.
    final districts = city.districts;
    final home = _jitter(
      districts[random.nextInt(districts.length)].$2,
      1800,
      random,
    );
    final gender = _gender(random.nextDouble());
    return Agent(
      id: PersonId('p$index'),
      gender: gender,
      homeAnchor: home,
      reachableClusters: city.reachableFrom(home, 4000),
      availability: _band(
        behaviour.availabilityMean,
        behaviour.availabilitySpread,
        random,
      ),
      reliability: _band(
        behaviour.reliabilityMean,
        behaviour.reliabilitySpread,
        random,
      ),
      warmth: _band(behaviour.warmthMean, behaviour.warmthSpread, random),
      openness: _band(
        behaviour.opennessMean,
        behaviour.opennessSpread,
        random,
      ),
      patienceWeeks:
          behaviour.patienceMean -
          behaviour.patienceSpread +
          random.nextInt(behaviour.patienceSpread * 2 + 1),
      joinedWeek: week,
    );
  }

  Gender _gender(double roll) {
    var cumulative = 0.0;
    for (final entry in behaviour.genderMix.entries) {
      cumulative += entry.value;
      if (roll < cumulative) return Gender(entry.key);
    }
    return Gender(behaviour.genderMix.keys.last);
  }

  static double _band(double mean, double spread, RandomSource random) =>
      (mean - spread + random.nextDouble() * spread * 2).clamp(0.0, 1.0);

  static GeoPoint _jitter(GeoPoint at, double metres, RandomSource random) {
    final dLat = (random.nextDouble() * 2 - 1) * metres / 111320;
    final dLon = (random.nextDouble() * 2 - 1) * metres / (111320 * 0.7);
    return GeoPoint(
      latitude: at.latitude + dLat,
      longitude: at.longitude + dLon,
    );
  }
}
