import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:syri/data.dart';
import 'package:syri/map_markers.dart';

Event marker(String id, String kind, LatLng point, {String? title}) => Event(
  id: id,
  title: title ?? id,
  description: id,
  source: 'Test',
  url: 'https://example.com/$id',
  kind: kind,
  point: point,
);

void main() {
  test('icons grow with zoom and dense reference layers remain compact', () {
    final twenty = minMapZoom + (maxMapZoom - minMapZoom) * .20;
    expect(mapZoomPercent(twenty), 20);
    expect(markerScaleForZoom(twenty), greaterThan(.88));
    expect(markerScaleForKind('news', 11), 1);
    expect(markerScaleForKind('parking', 11), lessThan(1));
    expect(markerScaleForKind('parking', 14), 1);
  });

  test('AQI changes from dot to readable pill at 30 percent zoom', () {
    expect(showAirPill(8.7), isFalse);
    expect(showAirPill(8.9), isTrue);
  });

  test('only identical subcategories group, regardless of input order', () {
    const center = LatLng(42.068, 19.512);
    final events = [
      marker('one', 'health-alert', center),
      marker('two', 'food-alert', center),
      marker('three', 'quakes', center),
      marker('four', 'health-alert', center),
    ];
    for (final zoom in [6.0, 11.0, 16.0, 18.0]) {
      final groups = groupMapMarkers(events, zoom);
      final reversed = groupMapMarkers(events.reversed.toList(), zoom);
      expect(groups, hasLength(3));
      expect(
        {for (final group in groups) group.subcategory: group.events.length},
        {'health-alert': 2, 'food-alert': 1, 'quakes': 1},
      );
      expect(
        {for (final group in reversed) group.subcategory: group.anchor},
        {for (final group in groups) group.subcategory: group.anchor},
      );
      expect(groups.every((group) => group.anchor == center), isTrue);
    }
  });

  test('large shared locations retain one accurate tap target', () {
    const center = LatLng(42.068, 19.512);
    final group = groupMapMarkers([
      for (var i = 0; i < 59; i++) marker('service-$i', 'pharmacy', center),
    ], 18).single;
    expect(group.events, hasLength(59));
    expect(group.anchor, center);
  });

  test('sea forecast and ship stay separately tappable at one port', () {
    const port = LatLng(41.8, 19.6);
    final groups = groupMapMarkers([
      marker('forecast', 'marine', port),
      marker('ship', 'ships', port),
      marker('water', 'water', port),
    ], 13.4);
    expect(groups, hasLength(3));
    final positions = layoutCoincidentMarkers(groups, 13.4);
    expect(positions, hasLength(3));
    expect(positions.values.toSet(), hasLength(3));
    expect(groups.every((group) => group.anchor == port), isTrue);
  });

  test(
    'different types at one city point get only bounded display offsets',
    () {
      const center = LatLng(42.068, 19.512);
      final groups = groupMapMarkers([
        marker('fire', 'fire', center),
        marker('quake', 'quakes', center),
        marker('health', 'health-alert', center),
      ], 11);
      final displayed = layoutCoincidentMarkers(groups, 11);
      expect(displayed, hasLength(3));
      expect(displayed.values.toSet(), hasLength(3));
      expect(groups.every((group) => group.anchor == center), isTrue);
      // Offsets are screen-size tap adjustments, not fabricated remote places.
      for (final point in displayed.values) {
        expect((point.latitude - center.latitude).abs(), lessThan(.05));
        expect((point.longitude - center.longitude).abs(), lessThan(.05));
      }
      expect(layoutCoincidentMarkers(groups, 9), hasLength(3));
      expect(layoutCoincidentMarkers(groups, markerDotUntilZoom - .1), isEmpty);
    },
  );

  test('nearby news and alerts stay side by side at regional zoom', () {
    const center = LatLng(41.33, 19.82);
    final groups = groupMapMarkers([
      marker('fire', 'fire', center),
      marker('crash', 'news', center, title: 'Aksident në qytet'),
      marker('crime', 'news', center, title: 'Arrestohet një person'),
    ], 8.8);
    final positions = layoutCoincidentMarkers(groups, 8.8);
    expect(positions, hasLength(3));
    expect(positions.values.toSet(), hasLength(3));
    expect(groups.every((group) => group.anchor == center), isTrue);
  });

  test('regional reports stay tightly attached to their actual city', () {
    const shkoder = LatLng(42.068, 19.512);
    final sameCity = groupMapMarkers([
      marker('crime', 'news', shkoder, title: 'Arrestim në Shkodër'),
      marker('alert', 'fire', shkoder),
    ], 7.2);
    final positions = layoutCoincidentMarkers(sameCity, 7.2);
    expect(positions, hasLength(2));
    for (final point in positions.values) {
      expect((point.longitude - shkoder.longitude).abs(), lessThan(.11));
      expect((point.latitude - shkoder.latitude).abs(), lessThan(.11));
    }
    expect(coincidentMarkerScale(7.2), lessThan(markerScaleForZoom(7.2)));

    final differentPlaces = groupMapMarkers([
      marker('shkoder', 'news', shkoder),
      marker('koplik', 'fire', const LatLng(42.068, 19.612)),
    ], 7.2);
    expect(layoutCoincidentMarkers(differentPlaces, 7.2), isEmpty);

    final distantNews = groupMapMarkers([
      marker('shkoder-news', 'news', shkoder),
      marker('lezhe-news', 'news', const LatLng(41.78, 19.64)),
    ], 7.2);
    expect(distantNews, hasLength(2));
  });

  test(
    'news markers gain a modest visual boost without losing map accuracy',
    () {
      expect(newsMarkerScale(9), greaterThan(markerScaleForZoom(9)));
      expect(newsMarkerSpacing(7.2), lessThan(newsMarkerSpacing(11)));
      expect(newsMarkerSpacing(7.2), lessThanOrEqualTo(22));
    },
  );

  test('news types, services and water grades keep separate icons', () {
    const center = LatLng(42.068, 19.512);
    final groups = groupMapMarkers([
      marker('crime', 'news', center, title: 'Arrestohet për drogë'),
      marker('crash', 'news', center, title: 'Aksident në Shkodër'),
      marker('crash-2', 'news', center, title: 'Përplasje makinash'),
      marker('pharmacy', 'pharmacy', center),
      marker('parking', 'parking', center),
      marker('excellent', 'water', center, title: 'Plazh · E shkëlqyer'),
      marker('poor', 'water', center, title: 'Plazh · E dobët'),
    ], 10);
    expect(groups, hasLength(6));
    expect(
      groups.singleWhere((g) => g.subcategory == 'news:crash').events,
      hasLength(2),
    );
    expect(
      groups.where((g) => g.subcategory.startsWith('water:')),
      hasLength(2),
    );
    expect(groups.every((g) => g.anchor == center), isTrue);
  });

  test(
    'nearby points split at street zoom; moving planes stay independent',
    () {
      const center = LatLng(42.068, 19.512);
      const nearby = LatLng(42.068, 19.514);
      final events = [
        marker('one', 'health-alert', center),
        marker('two', 'health-alert', nearby),
      ];
      expect(groupMapMarkers(events, 11), hasLength(1));
      expect(groupMapMarkers(events, 18), hasLength(2));
      expect(
        groupMapMarkers([
          marker('plane-a', 'planes', center),
          marker('plane-b', 'planes', center),
        ], 11),
        hasLength(2),
      );
      final regionalPlanes = groupMapMarkers([
        marker('plane-a', 'planes', center),
        marker('plane-b', 'planes', center),
      ], 7);
      expect(regionalPlanes, hasLength(2));
      expect(regionalPlanes.every((group) => group.events.length == 1), isTrue);
    },
  );
}
