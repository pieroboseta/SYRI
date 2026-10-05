import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import 'data.dart';

const minMapZoom = 5.0;
const maxMapZoom = 18.0;
const markerDotUntilZoom = 6.25;

int mapZoomPercent(double zoom) =>
    ((zoom - minMapZoom) / (maxMapZoom - minMapZoom) * 100)
        .clamp(0, 100)
        .round();

bool showAirPill(double zoom) => mapZoomPercent(zoom) >= 30;

/// The first few regional zoom steps grow the symbol quickly enough to stay
/// legible; the final steps ease into its normal street-map size.
double markerScaleForZoom(double zoom) {
  final progress = ((zoom - markerDotUntilZoom) / (11 - markerDotUntilZoom))
      .clamp(0.0, 1.0);
  return .23 + .77 * (1 - math.pow(1 - progress, 7));
}

/// Dense reference layers use smaller symbols until street zoom. News and
/// alerts retain their prominence at every zoom level.
double markerScaleForKind(String kind, double zoom) {
  final base = markerScaleForZoom(zoom);
  if (const {
    'health',
    'police',
    'fire_station',
    'services',
    'pharmacy',
    'aed',
    'parking',
    'charging',
    'transit',
    'water',
    'drinking-water',
    'biodiversity-flora',
    'biodiversity-fauna',
    'protected',
    'environment',
    'places',
  }.contains(kind)) {
    return base * (.65 + .35 * ((zoom - 10) / 4).clamp(0.0, 1.0));
  }
  return base;
}

/// Shared-location reports use a smaller footprint while staying centered on
/// their real map point. The scale catches up to ordinary markers on street maps.
double coincidentMarkerScale(double zoom) =>
    markerScaleForZoom(zoom) * (.74 + .26 * ((zoom - 7) / 7).clamp(0.0, 1.0));

double coincidentMarkerSpacing(double zoom) =>
    (34 * coincidentMarkerScale(zoom)).clamp(22.0, 34.0);

/// News stays easy to recognize and tap when nearby reports share a city.
double newsMarkerScale(double zoom, {bool compact = false}) =>
    (compact ? coincidentMarkerScale(zoom) : markerScaleForZoom(zoom)) * 1.10;

double newsMarkerSpacing(double zoom) =>
    22 + 26 * ((zoom - 7.2) / 3.8).clamp(0.0, 1.0);

/// TV logos need a phone-sized tap target even when the regional map is open.
double tvMarkerScale(double zoom) =>
    (.82 + .23 * ((zoom - 7) / 5).clamp(0.0, 1.0));

double tvMarkerSpacing(double zoom) =>
    (52 * tvMarkerScale(zoom) + 6).clamp(48.0, 61.0);

/// The main map category is used for layout, not for deciding what to cluster.
String markerCategory(Event event) => switch (event.kind) {
  'news' => 'news',
  'quakes' ||
  'fire' ||
  'storm' ||
  'flood' ||
  'volcano' ||
  'hazards' ||
  'cems' ||
  'health-alert' ||
  'food-alert' ||
  'hydrology-alert' => 'alerts',
  'frost' || 'hail' || 'drought' || 'heat' || 'wind' => 'weather',
  'health' ||
  'police' ||
  'fire_station' ||
  'services' ||
  'pharmacy' ||
  'aed' ||
  'parking' ||
  'charging' ||
  'utilities' ||
  'power-outage' ||
  'water-outage' ||
  'civic-alert' ||
  'energy-grid' ||
  'internet-outage' => 'services',
  'environment' || 'river-level' => 'environment',
  'population' ||
  'protected' ||
  'geoportal' ||
  'biodiversity-flora' ||
  'biodiversity-fauna' => 'territory',
  'ships' || 'water' || 'drinking-water' || 'port-alert' || 'marine' => 'sea',
  'planes' ||
  'airport-arrival' ||
  'airport-departure' ||
  'traffic-jam' ||
  'speed-camera' ||
  'police-alert' ||
  'transit' ||
  'roadwork' ||
  'borders' => 'transport',
  'cameras' => 'cameras',
  'tv' => 'tv',
  _ => event.kind,
};

/// A count marker must represent one kind of information and one icon.
/// News and a few map layers choose their icons from the event content, so
/// their keys need to follow the same distinction as the visible symbol.
String markerSubcategory(Event event) {
  if (event.kind == 'tv') return 'tv:${event.id}';
  if (event.kind == 'news') return 'news:${event.newsType}';
  if (event.kind == 'places') {
    final text = normalize('${event.title} ${event.description}');
    final type = text.contains('shpell') || text.contains('cave')
        ? 'cave'
        : text.contains('muze')
        ? 'museum'
        : text.contains('keshtjell') || text.contains('castle')
        ? 'castle'
        : text.contains('arkeolog') || text.contains('histor')
        ? 'history'
        : text.contains('kamp')
        ? 'camp'
        : text.contains('panoram')
        ? 'panorama'
        : 'hiking';
    return 'places:$type';
  }
  if (event.kind == 'environment') {
    final text = normalize('${event.title} ${event.description}');
    final type = text.contains('ajrit') || text.contains('aqi')
        ? 'air'
        : text.contains('mbetje') || text.contains('depozitim')
        ? 'waste'
        : text.contains('burim') || text.contains('ujerash')
        ? 'water'
        : text.contains('rezervat') || text.contains('mbrojtur')
        ? 'protected'
        : 'recycling';
    return 'environment:$type';
  }
  if (event.kind == 'water') {
    // Different bathing-water grades have different map colors and must not
    // be represented by a misleading single-color count marker.
    final title = normalize(event.title);
    final grade = title.contains('shkelqyer')
        ? 'excellent'
        : title.contains('e mire')
        ? 'good'
        : title.contains('mjaftueshme')
        ? 'sufficient'
        : title.contains('e dobet')
        ? 'poor'
        : 'unclassified';
    return 'water:$grade';
  }
  return event.kind;
}

/// A count marker stays on a real observation point. Tapping it lists members.
class MapMarkerGroup {
  final LatLng anchor;
  final String category;
  final String subcategory;
  final List<Event> events;

  MapMarkerGroup(this.anchor, Event first)
    : category = markerCategory(first),
      subcategory = markerSubcategory(first),
      events = [first];
}

({double x, double y}) _project(LatLng point, double zoom) {
  final scale = 256 * math.pow(2, zoom);
  final latitude = point.latitude.clamp(-85.0511, 85.0511);
  final radians = latitude * math.pi / 180;
  return (
    x: (point.longitude + 180) / 360 * scale,
    y:
        (1 - math.log(math.tan(math.pi / 4 + radians / 2)) / math.pi) /
        2 *
        scale,
  );
}

LatLng _unproject(double x, double y, double zoom) {
  final scale = 256 * math.pow(2, zoom);
  return LatLng(
    (2 * math.atan(math.exp(math.pi * (1 - 2 * y / scale))) - math.pi / 2) *
        180 /
        math.pi,
    x / scale * 360 - 180,
  );
}

/// High-priority reports need distinct, tappable symbols even at regional
/// zoom. Their visual layout is screen-space only; group anchors stay real.
Map<MapMarkerGroup, LatLng> layoutCoincidentMarkers(
  List<MapMarkerGroup> groups,
  double zoom,
) {
  if (zoom < markerDotUntilZoom) return {};
  final positions = <MapMarkerGroup, LatLng>{};
  final important =
      groups
          .where(
            (group) =>
                group.category == 'news' ||
                group.category == 'alerts' ||
                group.category == 'sea' ||
                group.category == 'tv',
          )
          .toList()
        ..sort((a, b) {
          final latitude = a.anchor.latitude.compareTo(b.anchor.latitude);
          if (latitude != 0) return latitude;
          final longitude = a.anchor.longitude.compareTo(b.anchor.longitude);
          return longitude != 0
              ? longitude
              : a.subcategory.compareTo(b.subcategory);
        });
  final clusters = <List<MapMarkerGroup>>[];
  for (final group in important) {
    final point = _project(group.anchor, zoom);
    List<MapMarkerGroup>? cluster;
    for (final candidate in clusters) {
      final first = _project(candidate.first.anchor, zoom);
      if (math.sqrt(
            math.pow(first.x - point.x, 2) + math.pow(first.y - point.y, 2),
          ) <=
          (zoom < 10 ? 5 : 12)) {
        cluster = candidate;
        break;
      }
    }
    if (cluster == null) {
      clusters.add([group]);
    } else {
      cluster.add(group);
    }
  }
  for (final cluster in clusters) {
    if (cluster.length < 2) continue;
    cluster.sort((a, b) => a.subcategory.compareTo(b.subcategory));
    final points = cluster.map((group) => _project(group.anchor, zoom));
    final centerX =
        points.map((point) => point.x).reduce((a, b) => a + b) / cluster.length;
    final centerY =
        points.map((point) => point.y).reduce((a, b) => a + b) / cluster.length;
    final columns = math.min(3, cluster.length);
    final rows = (cluster.length / columns).ceil();
    // Keep a compact grid directly around its real point. A large screen-space
    // gap becomes kilometres of apparent displacement at regional zoom.
    final spacing = cluster.any((group) => group.category == 'tv')
        ? tvMarkerSpacing(zoom)
        : cluster.any((group) => group.category == 'news')
        ? newsMarkerSpacing(zoom)
        : coincidentMarkerSpacing(zoom);
    for (var i = 0; i < cluster.length; i++) {
      positions[cluster[i]] = _unproject(
        centerX + ((i % columns) - (columns - 1) / 2) * spacing,
        centerY + ((i ~/ columns) - (rows - 1) / 2) * spacing,
        zoom,
      );
    }
  }
  final byPoint = <(int, int), List<MapMarkerGroup>>{};
  for (final group in groups) {
    if (group.category == 'news' ||
        group.category == 'alerts' ||
        group.category == 'sea' ||
        group.category == 'tv') {
      continue;
    }
    byPoint
        .putIfAbsent((
          (group.anchor.latitude * 100000).round(),
          (group.anchor.longitude * 100000).round(),
        ), () => [])
        .add(group);
  }
  for (final collocated in byPoint.values) {
    if (collocated.length < 2) continue;
    collocated.sort((a, b) => a.subcategory.compareTo(b.subcategory));
    final columns = math.sqrt(collocated.length).ceil();
    final rows = (collocated.length / columns).ceil();
    final base = _project(collocated.first.anchor, zoom);
    final spacing = coincidentMarkerSpacing(zoom);
    for (var i = 0; i < collocated.length; i++) {
      final dx = ((i % columns) - (columns - 1) / 2) * spacing;
      final dy = ((i ~/ columns) - (rows - 1) / 2) * spacing;
      // Preserve geographic credibility even if an unusually large number
      // of sources use a single generic city coordinate.
      positions[collocated[i]] = _unproject(
        base.x + dx.clamp(-45.0, 45.0),
        base.y + dy.clamp(-45.0, 45.0),
        zoom,
      );
    }
  }
  return positions;
}

List<MapMarkerGroup> groupMapMarkers(
  List<Event> events,
  double zoom, {
  bool clusterNearby = true,
}) {
  final buckets = <(String, int, int), List<Event>>{};
  for (final event in events) {
    final kind = event.kind;
    // Aircraft move continuously, so keep each at its own live position at
    // every zoom instead of turning nearby aircraft into a count marker.
    if (kind == 'planes') {
      final point = _project(event.displayPoint, zoom);
      buckets[('planes:${event.id}', point.x.round(), point.y.round())] = [
        event,
      ];
      continue;
    }
    final dense = const {
      'health',
      'police',
      'fire_station',
      'services',
      'pharmacy',
      'aed',
      'parking',
      'charging',
      'transit',
      'water',
      'drinking-water',
      'biodiversity-flora',
      'biodiversity-fauna',
      'protected',
      'environment',
      'places',
    }.contains(kind);
    final priority =
        markerCategory(event) == 'news' || markerCategory(event) == 'alerts';
    final size = !clusterNearby
        ? 1.5
        : priority
        ? (18 + (zoom - 7) * 2).clamp(14.0, 32.0)
        : dense
        ? (110 - (zoom - 9) * 13).clamp(42.0, 116.0)
        : (66 - (zoom - 9) * 4).clamp(38.0, 70.0);
    final point = _project(event.displayPoint, zoom);
    final key = (
      markerSubcategory(event),
      (point.x / size).floor(),
      (point.y / size).floor(),
    );
    buckets.putIfAbsent(key, () => []).add(event);
  }
  final groups = <MapMarkerGroup>[];
  for (final bucket in buckets.values) {
    bucket.sort((a, b) => a.id.compareTo(b.id));
    // A medoid keeps the symbol on an actual reported location, never in a
    // fabricated radial position or halfway across a bay.
    final points = bucket.map((event) => _project(event.displayPoint, zoom));
    final x =
        points.map((point) => point.x).reduce((a, b) => a + b) / bucket.length;
    final y =
        points.map((point) => point.y).reduce((a, b) => a + b) / bucket.length;
    final anchorEvent = bucket.reduce((best, event) {
      final bestPoint = _project(best.displayPoint, zoom);
      final eventPoint = _project(event.displayPoint, zoom);
      final bestDistance =
          math.pow(bestPoint.x - x, 2) + math.pow(bestPoint.y - y, 2);
      final eventDistance =
          math.pow(eventPoint.x - x, 2) + math.pow(eventPoint.y - y, 2);
      return eventDistance < bestDistance ? event : best;
    });
    final group = MapMarkerGroup(anchorEvent.displayPoint, anchorEvent);
    group.events.addAll(bucket.where((event) => event != anchorEvent));
    groups.add(group);
  }
  return groups;
}
