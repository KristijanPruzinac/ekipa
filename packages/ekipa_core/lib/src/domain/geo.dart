import 'dart:math' as math;

import 'package:meta/meta.dart';

/// A point on the earth, in degrees.
///
/// **Intention.** Two different things in this system are points — a person's
/// home anchor and a venue's location — and exactly one of them is a secret.
/// Giving them a shared type with no formatting, no `toString` that prints
/// coordinates in full, and no JSON encoder keeps the anchor from leaking
/// through the easiest route: a log line somebody added while debugging
/// something else (rule 5 of 11_SECURITY.md §8).
@immutable
final class GeoPoint {
  /// A point at [latitude], [longitude], in degrees.
  const GeoPoint({required this.latitude, required this.longitude});

  /// Degrees north, `[-90, 90]`.
  final double latitude;

  /// Degrees east, `[-180, 180]`.
  final double longitude;

  /// Great-circle distance to [other], in metres.
  ///
  /// Haversine on a spherical earth. The error against the WGS-84 ellipsoid is
  /// about 0.5%, which at the scale this is used for — "is this person twenty
  /// minutes from that café" — is roughly a metre. Reaching for a geodesic
  /// library to remove it would be precision the decision cannot use, paid for
  /// with a dependency (SC-2).
  double distanceTo(GeoPoint other) {
    const earthRadiusMetres = 6371000.0;
    final dLat = _radians(other.latitude - latitude);
    final dLon = _radians(other.longitude - longitude);
    final lat1 = _radians(latitude);
    final lat2 = _radians(other.latitude);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadiusMetres * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  /// Snapped to a grid of [metres], which is how an anchor is stored.
  ///
  /// **Intention.** The product needs "roughly twenty minutes away". It does
  /// not need an address, and holding one is a liability against T2 — the
  /// stalker — that buys nothing. Snapping happens before the value is written,
  /// so the precise point never exists in the database to be leaked.
  GeoPoint snappedTo(double metres) {
    const metresPerDegreeLatitude = 111320.0;
    final latStep = metres / metresPerDegreeLatitude;
    final snappedLatitude = (latitude / latStep).roundToDouble() * latStep;

    // The longitude step is derived from the **snapped** latitude, not from the
    // original one. Deriving it from the original would give two points a few
    // metres apart very slightly different step sizes, so they would land on
    // very slightly different longitudes — and the grid would not be a grid.
    // Two neighbours would then hold distinguishable anchors, which is the one
    // thing snapping exists to prevent.
    final lonStep =
        metres /
        (metresPerDegreeLatitude *
            math.cos(_radians(snappedLatitude)).abs().clamp(0.01, 1));

    return GeoPoint(
      latitude: snappedLatitude,
      longitude: (longitude / lonStep).roundToDouble() * lonStep,
    );
  }

  static double _radians(double degrees) => degrees * math.pi / 180;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GeoPoint &&
          other.latitude == latitude &&
          other.longitude == longitude);

  @override
  int get hashCode => Object.hash(GeoPoint, latitude, longitude);

  /// Deliberately coarse.
  ///
  /// A `toString` that printed the coordinates would put a home anchor into
  /// every stack trace, every `print` somebody added while debugging, and every
  /// crash report. The type that holds the most dangerous value in the system
  /// should be the least chatty one.
  @override
  String toString() => 'GeoPoint(…)';
}
