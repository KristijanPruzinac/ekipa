import 'dart:typed_data';

import 'package:ekipa_core/src/domain/geo.dart';
import 'package:ekipa_core/src/foundation/result.dart';
import 'package:meta/meta.dart';

/// What a shape in a basemap is, in paint order.
///
/// The order is the file's, not the painter's: water sits under green sits
/// under roads because that is how the bytes arrive. A painter that had to know
/// the order would be a second place the answer lives, and the two would drift
/// the first time a layer was added.
enum BasemapLayerKind {
  /// Rivers and lakes. In Osijek this is almost entirely the Drava.
  water,

  /// Parks, pitches, grass.
  green,

  /// Motorway through secondary — the roads a person names when giving
  /// directions.
  roadMajor,

  /// Tertiary, residential, unclassified.
  roadMinor,

  /// Pedestrian ways and footpaths. Drawn thinnest, and drawn last among the
  /// roads, because on the walk to a meeting point they are the useful ones.
  path,

  /// Railway.
  rail;

  /// Decodes the wire value, or `null` for a kind this build does not know.
  ///
  /// Unknown kinds are skipped rather than refused: a newer asset shipped to an
  /// older build should lose a layer, not the map.
  static BasemapLayerKind? fromWire(int value) =>
      value >= 0 && value < values.length ? values[value] : null;
}

/// One layer's geometry.
@immutable
final class BasemapLayer {
  /// Describes a layer.
  const BasemapLayer({required this.kind, required this.shapes});

  /// What these shapes are.
  final BasemapLayerKind kind;

  /// Each shape is an interleaved `x, y` run in the `0…65535` unit square, with
  /// `y` growing southward so it matches screen space without a flip.
  ///
  /// **Why quantised 16-bit rather than doubles.** A city centre is a few
  /// kilometres across, so one unit here is about six centimetres — far below
  /// what a phone can draw and far below OSM's own accuracy. Doubles would
  /// quadruple the asset for precision nobody can see.
  final List<Uint16List> shapes;
}

/// A city's geometry, drawn by us, in our colours.
///
/// **Intention — the map is an asset, not a service.** See
/// `tools/cartography/build_basemap.py` for the three options considered and
/// why shipping the geometry is the only one that survives no-company /
/// no-paid-infrastructure. The consequence worth stating here: the reveal
/// screen renders with the radio off, at the exact moment somebody is walking
/// somewhere and their signal is worst.
///
/// Data: © OpenStreetMap contributors, ODbL. The attribution is rendered on the
/// map surface itself — a licence honoured in a settings page is a licence
/// nobody sees.
@immutable
final class Basemap {
  /// Describes a decoded basemap.
  const Basemap({
    required this.southWest,
    required this.northEast,
    required this.layers,
  });

  /// The bottom-left corner of the covered area.
  final GeoPoint southWest;

  /// The top-right corner.
  final GeoPoint northEast;

  /// The layers, in paint order.
  final List<BasemapLayer> layers;

  static const List<int> _magic = [
    0x45,
    0x4B,
    0x4D,
    0x41,
    0x50,
    0x31,
  ]; // EKMAP1

  /// Reads the binary produced by `tools/cartography/build_basemap.py`.
  ///
  /// Returns an [Err] rather than throwing, because the caller is a widget: a
  /// corrupt asset should cost the map, not the screen the map is on.
  static Result<Basemap, String> decode(Uint8List bytes) {
    if (bytes.length < 6 + 32 + 2) return const Err('basemap: too short');
    for (var i = 0; i < _magic.length; i++) {
      if (bytes[i] != _magic[i]) return const Err('basemap: bad magic');
    }
    final data = ByteData.sublistView(bytes);
    var offset = _magic.length;

    final minLat = data.getFloat64(offset, Endian.little);
    final minLon = data.getFloat64(offset + 8, Endian.little);
    final maxLat = data.getFloat64(offset + 16, Endian.little);
    final maxLon = data.getFloat64(offset + 24, Endian.little);
    offset += 32;

    final layerCount = data.getUint16(offset, Endian.little);
    offset += 2;

    final layers = <BasemapLayer>[];
    for (var l = 0; l < layerCount; l++) {
      if (offset + 5 > bytes.length) {
        return const Err('basemap: truncated layer');
      }
      final kind = BasemapLayerKind.fromWire(data.getUint8(offset));
      final shapeCount = data.getUint32(offset + 1, Endian.little);
      offset += 5;

      final shapes = <Uint16List>[];
      for (var s = 0; s < shapeCount; s++) {
        if (offset + 2 > bytes.length) {
          return const Err('basemap: truncated shape');
        }
        final points = data.getUint16(offset, Endian.little);
        offset += 2;
        final span = points * 4;
        if (offset + span > bytes.length) {
          return const Err('basemap: shape runs past the end');
        }
        // A view, not a copy: the whole point of the quantised format is that
        // decoding is free and the bytes are painted where they landed.
        final run = Uint16List(points * 2);
        for (var p = 0; p < points * 2; p++) {
          run[p] = data.getUint16(offset + p * 2, Endian.little);
        }
        shapes.add(run);
        offset += span;
      }
      if (kind != null && shapes.isNotEmpty) {
        layers.add(
          BasemapLayer(kind: kind, shapes: List.unmodifiable(shapes)),
        );
      }
    }

    return Ok(
      Basemap(
        southWest: GeoPoint(latitude: minLat, longitude: minLon),
        northEast: GeoPoint(latitude: maxLat, longitude: maxLon),
        layers: List.unmodifiable(layers),
      ),
    );
  }

  /// Where [point] sits in the unit square, `y` growing southward.
  ///
  /// Returns values outside `0…1` for a point off the map rather than clamping
  /// — a pin clamped to the edge claims a place it is not, and on a screen
  /// whose whole job is "walk here" that is the one lie that matters.
  ({double x, double y}) unit(GeoPoint point) => (
    x:
        (point.longitude - southWest.longitude) /
        (northEast.longitude - southWest.longitude),
    y:
        (northEast.latitude - point.latitude) /
        (northEast.latitude - southWest.latitude),
  );

  /// Whether [point] is inside the covered area.
  bool covers(GeoPoint point) {
    final position = unit(point);
    return position.x >= 0 &&
        position.x <= 1 &&
        position.y >= 0 &&
        position.y <= 1;
  }
}
