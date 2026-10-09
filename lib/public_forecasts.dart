import 'dart:convert';

import 'package:latlong2/latlong.dart';

import 'data.dart';

/// Public, key-free model feeds. Map positions are model cells, not gauges.
extension PublicForecasts on SyriApi {
  Future<FeedResult<List<Event>>> skyForCities(
    List<City> places, {
    int hoursAhead = 0,
  }) async {
    Future<FeedResult<List<Event>>> batch(List<City> group) async {
      final response = await fetch(
        'sky_v1_${group.map((e) => e.name).join('_')}',
        'https://api.open-meteo.com/v1/forecast?latitude=${group.map((e) => e.lat).join(',')}&longitude=${group.map((e) => e.lon).join(',')}&hourly=cloud_cover,visibility,wind_speed_10m,wind_direction_10m,wind_gusts_10m&timezone=auto&forecast_hours=12',
        const Duration(minutes: 30),
      );
      final decoded = jsonDecode(response.value);
      final rows = decoded is List ? decoded : [decoded];
      final events = <Event>[];
      for (var i = 0; i < group.length && i < rows.length; i++) {
        final row = rows[i];
        if (row is! Map) continue;
        final hourly = row['hourly'];
        if (hourly is! Map) continue;
        num? at(String key) {
          final values = hourly[key];
          if (values is! List || hoursAhead >= values.length) return null;
          return values[hoursAhead] as num?;
        }

        final cloud = at('cloud_cover');
        final visibility = at('visibility');
        final wind = at('wind_speed_10m');
        final gust = at('wind_gusts_10m');
        final direction = at('wind_direction_10m');
        if (cloud == null || visibility == null || wind == null) continue;
        final timeValues = hourly['time'];
        final localTime = timeValues is List && hoursAhead < timeValues.length
            ? timeValues[hoursAhead].toString()
            : '';
        final fog = visibility < 1000;
        final place = group[i];
        events.add(
          Event(
            id: 'sky-${place.name}',
            title: '${fog ? 'Mjegull' : 'Re dhe erë'} · ${place.name}',
            description:
                'Vranësira: ${cloud.round()}%\nDukshmëria: ${(visibility / 1000).toStringAsFixed(1)} km\nEra: ${wind.toStringAsFixed(1)} km/h${direction == null ? '' : ' · ${direction.round()}°'}${gust == null ? '' : '\nShkulmet: ${gust.toStringAsFixed(1)} km/h'}\nOra lokale e parashikimit: $localTime\nParashikim modelor nga Open-Meteo; jo matje në terren.',
            source: 'Open-Meteo',
            url: 'https://open-meteo.com/en/docs',
            kind: 'sky-conditions',
            point: place.point,
            approximate: true,
          ),
        );
      }
      return FeedResult(events, response.fetched, response.stale);
    }

    final groups = <List<City>>[
      for (var i = 0; i < places.length; i += 12)
        places.skip(i).take(12).toList(),
    ];
    final settled = await Future.wait(
      groups.map((group) async {
        try {
          return await batch(group);
        } catch (_) {
          return null;
        }
      }),
    );
    if (settled.every((item) => item == null)) {
      throw StateError('Sky forecast unavailable');
    }
    return FeedResult(
      [
        for (final item in settled)
          if (item != null) ...item.value,
      ],
      DateTime.now(),
      settled.any((item) => item == null || item.stale),
    );
  }

  Future<FeedResult<List<Event>>> riverForecasts(Set<String> countries) async {
    // Representative points near major waterways. Their model grid cell may
    // differ from a named river; the UI deliberately avoids claiming a gauge.
    const sites = <(String, String, double, double)>[
      ('Shkodër', 'Shqipëri', 42.05, 19.51),
      ('Berat', 'Shqipëri', 40.675, 19.985),
      ('Prizren', 'Kosovë', 42.245, 20.69),
      ('Gjakovë', 'Kosovë', 42.395, 20.49),
      ('Podgoricë', 'Mali i Zi', 42.44, 19.235),
      ('Nikshiq', 'Mali i Zi', 42.78, 18.94),
      ('Shkup', 'Maqedonia e Veriut', 41.975, 21.49),
      ('Tetovë', 'Maqedonia e Veriut', 42.035, 21.02),
    ];
    final selected = sites
        .where((site) => countries.contains(site.$2))
        .toList();
    if (selected.isEmpty) return FeedResult(const [], DateTime.now(), false);
    final response = await fetch(
      'flood_v1_${selected.map((e) => e.$1).join('_')}',
      'https://flood-api.open-meteo.com/v1/flood?latitude=${selected.map((e) => e.$3).join(',')}&longitude=${selected.map((e) => e.$4).join(',')}&daily=river_discharge&forecast_days=7',
      const Duration(hours: 6),
    );
    final decoded = jsonDecode(response.value);
    final rows = decoded is List ? decoded : [decoded];
    final events = <Event>[];
    for (var i = 0; i < selected.length && i < rows.length; i++) {
      final row = rows[i];
      if (row is! Map || row['daily'] is! Map) continue;
      final daily = row['daily'] as Map;
      final values = daily['river_discharge'];
      final dates = daily['time'];
      if (values is! List || dates is! List || values.isEmpty) continue;
      final lines = <String>[];
      for (var day = 0; day < values.length && day < dates.length; day++) {
        final value = values[day];
        if (value is num && value.isFinite) {
          lines.add('${dates[day]}: ${value.toStringAsFixed(1)} m³/s');
        }
      }
      if (lines.isEmpty) continue;
      final site = selected[i];
      events.add(
        Event(
          id: 'river-forecast-${site.$1}',
          title: 'Prurje pranë ${site.$1}',
          description:
              '${lines.join('\n')}\n\nParashikim 7-ditor GloFAS/Open-Meteo për qelizën modelore pranë qytetit, jo matje e lumit apo alarm zyrtar. Rrjeti rreth 5 km mund të përfaqësojë një rrjedhë tjetër afër pikës.',
          source: 'GloFAS / Open-Meteo',
          url: 'https://open-meteo.com/en/docs/flood-api',
          kind: 'river-forecast',
          point: LatLng(
            (row['latitude'] as num?)?.toDouble() ?? site.$3,
            (row['longitude'] as num?)?.toDouble() ?? site.$4,
          ),
          approximate: true,
        ),
      );
    }
    return FeedResult(events, response.fetched, response.stale);
  }

  Future<FeedResult<List<Event>>> solarActivity() async {
    final response = await fetch(
      'noaa_scales_v1',
      'https://services.swpc.noaa.gov/products/noaa-scales.json',
      const Duration(minutes: 30),
    );
    final decoded = jsonDecode(response.value);
    if (decoded is! Map) throw const FormatException('Invalid NOAA scales');
    String describe(dynamic row) {
      if (row is! Map) return '';
      return ['G', 'R', 'S']
          .map((key) {
            final scale = row[key] is Map
                ? row[key]['Scale']?.toString()
                : null;
            return scale == null ? '' : '$key$scale';
          })
          .where((part) => part.isNotEmpty)
          .join(' · ');
    }

    final observed = describe(decoded['0']);
    final outlook = [
      for (var i = 1; i <= 3; i++) 'Dita $i: ${describe(decoded['$i'])}',
    ];
    final current = decoded['0'];
    final serious =
        current is Map &&
        ['G', 'R', 'S'].any((key) {
          final value = current[key] is Map
              ? int.tryParse(current[key]['Scale']?.toString() ?? '') ?? 0
              : 0;
          return key == 'G' ? value >= 2 : value >= 3;
        });
    return FeedResult(
      [
        Event(
          id: 'solar-activity',
          title: serious
              ? 'Aktivitet diellor i shtuar'
              : 'Aktiviteti diellor · $observed',
          description:
              'Gjendja e vëzhguar globale: $observed\n${outlook.join('\n')}\n\nG = stuhi gjeomagnetike, R = ndërprerje radioje, S = rrezatim diellor. Parashikimi është global; nuk nënkupton ndikim të konfirmuar në katër vendet e hartës.',
          source: 'NOAA SWPC',
          url: 'https://www.swpc.noaa.gov/noaa-scales-explanation',
          kind: 'solar-activity',
        ),
      ],
      response.fetched,
      response.stale,
    );
  }
}
