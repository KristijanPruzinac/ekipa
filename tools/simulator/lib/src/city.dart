import 'package:ekipa_core/ekipa_core.dart';

/// The synthetic city: where the clusters are, and when the slots are.
///
/// **Why geography is modelled at all.** The cheapest simulation puts everyone
/// in one cluster, and it is the one that cannot see the failure mode this
/// product is most exposed to at launch: a city thin enough that the
/// group-wide cluster intersection, not the ring draw, is what decides who
/// meets. With four districts five kilometres apart and a four-kilometre travel
/// radius, an agent who lives at a district centre reaches one cluster and an
/// agent who lives between two reaches two — which is the real shape of Osijek
/// and the reason `noSharedCluster` shows up in the funnel at all.
final class SimCity {
  /// Builds a city. The defaults are Osijek-shaped: four districts around a
  /// centre, three evenings a week, three start times an evening.
  const SimCity({
    this.id = const CityId('sim-osijek'),
    this.centre = const GeoPoint(latitude: 45.5550, longitude: 18.6955),
    this.districtOffsetMetres = 5000,
    this.eveningDays = const [3, 4, 5],
    this.startHours = const [16, 17, 19],
    this.startMinutes = const [0, 30, 0],
  });

  /// The city id every person and slot carries.
  final CityId id;

  /// The middle of the city.
  final GeoPoint centre;

  /// How far the outer districts sit from [centre].
  final double districtOffsetMetres;

  /// Weekday numbers (`DateTime.thursday` is 4) offset from the week's Monday.
  final List<int> eveningDays;

  /// Start hours of the three slots in an evening.
  final List<int> startHours;

  /// Start minutes matching [startHours], so 17:30 is expressible.
  final List<int> startMinutes;

  static const _metresPerDegreeLatitude = 111320.0;

  /// The four districts, in a fixed order so a replay names them identically.
  List<(ClusterId, GeoPoint)> get districts {
    final dLat = districtOffsetMetres / _metresPerDegreeLatitude;
    final dLon = dLat / 0.7; // cos(45.5°), rounded; the city is not a sphere.
    return [
      (const ClusterId('centre'), centre),
      (
        const ClusterId('north'),
        GeoPoint(
          latitude: centre.latitude + dLat,
          longitude: centre.longitude,
        ),
      ),
      (
        const ClusterId('south'),
        GeoPoint(
          latitude: centre.latitude - dLat,
          longitude: centre.longitude,
        ),
      ),
      (
        const ClusterId('east'),
        GeoPoint(
          latitude: centre.latitude,
          longitude: centre.longitude + dLon,
        ),
      ),
    ];
  }

  /// Which districts somebody living at [home] can reach.
  ///
  /// Always non-empty: an agent who can reach nothing would be filtered by
  /// `MustReachSomewhere` every week forever, which is a real product state but
  /// a useless simulation state — it is churn with extra steps.
  Set<ClusterId> reachableFrom(GeoPoint home, int maxTravelMetres) {
    final reachable = <ClusterId>{};
    var nearest = districts.first.$1;
    var nearestDistance = double.infinity;
    for (final (cluster, at) in districts) {
      final distance = home.distanceTo(at);
      if (distance <= maxTravelMetres) reachable.add(cluster);
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = cluster;
      }
    }
    return reachable.isEmpty ? {nearest} : reachable;
  }

  /// The slots of week [week], counted from [firstMonday].
  List<Slot> slotsOfWeek(int week, DateTime firstMonday) => [
    for (final day in eveningDays)
      for (var i = 0; i < startHours.length; i++)
        Slot(
          id: SlotId('w$week-d$day-s$i'),
          cityId: id,
          startsAt: firstMonday
              .add(Duration(days: week * 7 + day))
              .add(Duration(hours: startHours[i], minutes: startMinutes[i])),
          endsAt: firstMonday
              .add(Duration(days: week * 7 + day))
              .add(
                Duration(
                  hours: startHours[i],
                  minutes: startMinutes[i] + 90,
                ),
              ),
        ),
  ];

  /// How many slots a week offers.
  int get slotsPerWeek => eveningDays.length * startHours.length;
}
