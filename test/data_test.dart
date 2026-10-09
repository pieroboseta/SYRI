import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syri/data.dart';

void main() {
  test('offline fetch serves saved data without making a request', () async {
    SharedPreferences.setMockInitialValues({});
    var requests = 0;
    final api = SyriApi(
      client: MockClient((_) async {
        requests++;
        return http.Response('{"value":1}', 200);
      }),
    );
    final online = await api.fetch(
      'offline_sample',
      'https://example.test/data',
      Duration.zero,
    );
    expect(online.value, '{"value":1}');
    api.offline = true;
    final saved = await api.fetch(
      'offline_sample',
      'https://example.test/data',
      Duration.zero,
    );
    expect(saved.value, online.value);
    expect(saved.stale, isTrue);
    expect(requests, 1);
    await expectLater(
      api.fetch('never_seen', 'https://example.test/other', Duration.zero),
      throwsStateError,
    );
    api.client.close();
  });

  test(
    'non-Albanian buses use mapped stops and recover from a failed server',
    () async {
      SharedPreferences.setMockInitialValues({});
      var requests = 0;
      final api = SyriApi(
        client: MockClient((request) async {
          requests++;
          final query = request.url.queryParameters['data'] ?? '';
          expect(query, contains('amenity=bus_station'));
          if (requests == 1) return http.Response('Unavailable', 503);
          return http.Response(
            jsonEncode({
              'elements': [
                {
                  'type': 'node',
                  'id': 1,
                  'lat': 42.431,
                  'lon': 19.260,
                  'tags': {'highway': 'bus_stop', 'name': 'Centar'},
                },
                {
                  'type': 'way',
                  'id': 2,
                  'center': {'lat': 42.432, 'lon': 19.261},
                  'tags': {
                    'amenity': 'bus_station',
                    'name': 'Autobuska stanica',
                  },
                },
              ],
            }),
            200,
          );
        }),
      );
      final city = cities.firstWhere((item) => item.name == 'Podgoricë');
      final result = await api.transit(city);
      expect(requests, 2);
      expect(result.value, hasLength(2));
      expect(result.value.every((event) => event.kind == 'transit'), isTrue);
      expect(result.value.every((event) => event.point != null), isTrue);
      expect(
        result.value.any((event) => event.id.startsWith('etransport-')),
        isFalse,
      );
    },
  );

  test(
    'batched air readings stay matched to cities and preserve missing pollen',
    () async {
      SharedPreferences.setMockInitialValues({});
      var requests = 0;
      final api = SyriApi(
        client: MockClient((request) async {
          requests++;
          expect(request.url.queryParameters['latitude'], '42.0683,41.3275');
          return http.Response(
            jsonEncode([
              {
                'current': {
                  'time': '2026-09-29T12:00',
                  'european_aqi': 25,
                  'olive_pollen': null,
                  'grass_pollen': null,
                },
              },
              {
                'current': {
                  'time': '2026-09-29T12:00',
                  'european_aqi': 57,
                  'olive_pollen': 2.5,
                  'grass_pollen': 0,
                },
              },
            ]),
            200,
          );
        }),
      );
      final readings = await api.airQualityForCities(cities.take(2).toList());
      expect(requests, 1);
      expect(readings['Shkodër']?.value.europeanAqi, 25);
      expect(readings['Shkodër']?.value.olivePollen, isNull);
      expect(readings['Tiranë']?.value.europeanAqi, 57);
      expect(readings['Tiranë']?.value.olivePollen, 2.5);
    },
  );

  test('one failed air batch does not hide other cities', () async {
    SharedPreferences.setMockInitialValues({});
    final selected = cities.take(13).toList();
    final api = SyriApi(
      client: MockClient((request) async {
        final latitudes = request.url.queryParameters['latitude']!.split(',');
        if (latitudes.length == 12) return http.Response('unavailable', 503);
        return http.Response(
          jsonEncode({
            'current': {'time': '2026-09-29T12:00', 'european_aqi': 31},
          }),
          200,
        );
      }),
    );
    final readings = await api.airQualityForCities(selected);
    expect(readings.length, 1);
    expect(readings[selected.last.name]?.value.europeanAqi, 31);
  });

  test('inland bathing water keeps measured and unmeasured lakes distinct', () {
    final events = SyriApi().inlandBathingWater({
      'Kosovë',
      'Maqedonia e Veriut',
    });
    expect(events, hasLength(6));
    expect(
      events.where((event) => event.title.contains('Pa matje publike')),
      hasLength(3),
    );
    expect(events.where((event) => event.time != null), hasLength(3));
    expect(events.every((event) => event.approximate), isTrue);
  });
  test(
    'regional parks and maritime points cover Montenegro and neighbours',
    () {
      final api = SyriApi();
      final parks = api.regionalProtectedAreas({
        'Kosovë',
        'Maqedonia e Veriut',
        'Mali i Zi',
      });
      expect(parks.where((e) => e.id.endsWith('-xk')), hasLength(2));
      expect(parks.where((e) => e.id.endsWith('-mk')), hasLength(4));
      expect(parks.where((e) => e.id.endsWith('-me')), hasLength(5));
      expect(
        parks.every((e) => e.approximate && e.url.startsWith('https:')),
        isTrue,
      );
      expect(api.ships().where((e) => e.id.endsWith('-me')), hasLength(3));
    },
  );

  test('Montenegro bathing water parses grade, sample and shoreline', () {
    final events = parseMontenegroBathingWater(
      jsonEncode({
        'mjerenja': [
          {
            'id': 62,
            'naziv': 'Rose',
            'opstina': 'Herceg Novi',
            'tezina': 1,
            'vrijemeUzorkovanja': '01.09.2026. 08:40',
            'geometrija': 'POLYGON ((18.5561 42.4283, 18.557 42.4283, 18.557 42.429, 18.5561 42.4283))',
          },
        ],
      }),
      year: 2026,
      round: '8',
    );
    expect(events, hasLength(1));
    expect(events.single.title, contains('E shkëlqyer'));
    expect(events.single.description, contains('01.09.2026. 08:40'));
    expect(events.single.geometry, hasLength(4));
    expect(events.single.point!.latitude, closeTo(42.428475, 0.001));
  });

  test('Montenegro bathing water requests latest official round', () async {
    SharedPreferences.setMockInitialValues({});
    final requests = <http.Request>[];
    final api = SyriApi(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('getCalendarData')) {
          return http.Response(
            jsonEncode({
              'data': [
                {'id': 8, 'tekst': '8 (31.08.2026. - 03.09.2026.)'},
                {'id': 7, 'tekst': '7'},
              ],
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'mjerenja': [
              {
                'id': 12,
                'naziv': 'Budva',
                'opstina': 'Budva',
                'tezina': 4,
                'vrijemeUzorkovanja': '02.09.2026. 10:00',
                'geometrija':
                    'POLYGON ((18.8 42.2, 18.81 42.2, 18.81 42.21, 18.8 42.2))',
              },
            ],
          }),
          200,
        );
      }),
    );
    final result = await api.montenegroBathingWater();
    expect(result.value.single.title, contains('E dobët'));
    expect(requests, hasLength(2));
    expect(requests.every((request) => request.method == 'POST'), isTrue);
    expect(requests.last.bodyFields['rb'], '8');
  });

  test('GBIF observations retain country, taxon and original source', () async {
    SharedPreferences.setMockInitialValues({});
    final requested = <String>{};
    final api = SyriApi(
      client: MockClient((request) async {
        final country = request.url.queryParameters['country']!;
        final taxon = request.url.queryParameters['taxonKey']!;
        requested.add('$country:$taxon');
        return http.Response(
          jsonEncode({
            'results': [
              {
                'key': '$country$taxon'.hashCode.abs(),
                'scientificName': 'Test species',
                'kingdom': taxon == '6' ? 'Plantae' : 'Animalia',
                'decimalLatitude': 42.0,
                'decimalLongitude': 20.0,
                'eventDate': '2025-06-01',
              },
            ],
          }),
          200,
        );
      }),
    );
    final records = await api.biodiversityObservations({
      'Shqipëri',
      'Kosovë',
      'Maqedonia e Veriut',
      'Mali i Zi',
    }, requestPause: Duration.zero);
    expect(requested, {
      'AL:6',
      'AL:1',
      'XK:6',
      'XK:1',
      'MK:6',
      'MK:1',
      'ME:6',
      'ME:1',
    });
    expect(records.value, hasLength(8));
    expect(
      records.value.where((e) => e.kind == 'biodiversity-flora'),
      hasLength(4),
    );
    expect(records.value.every((e) => e.url.contains('/occurrence/')), isTrue);
    expect(
      records.value.every((e) => e.description.contains('jo vendndodhje live')),
      isTrue,
    );
  });

  test('camera catalog maps four countries and rejects misplaced entries', () {
    String listing(String lat, String lon, String path) =>
        '''
      <script type="application/ld+json">{"@type":"ItemList",
      "itemListElement":[{"item":{"name":"Kamera në qendër",
      "url":"$path","contentLocation":{"name":"Qendër",
      "geo":{"latitude":$lat,"longitude":$lon}}}}]}</script>''';
    final cases = [
      ('Shqipëri', '41.3', '19.8', '/cameras/albania/tirana/1'),
      ('Kosovë', '42.6', '21.1', '/cameras/kosovo/prishtina/2'),
      (
        'Maqedonia e Veriut',
        '42.0',
        '20.9',
        '/cameras/north-macedonia/tetovo/3',
      ),
      ('Mali i Zi', '42.4', '19.3', '/cameras/montenegro/tuzi/4'),
    ];
    for (final (country, lat, lon, path) in cases) {
      final events = SyriApi.parseOpenCctvCameras(
        listing(lat, lon, path),
        country: country,
        fetched: DateTime(2026, 9, 22),
      );
      expect(events, hasLength(1), reason: country);
      expect(events.single.description, contains(country));
      expect(events.single.url, 'https://opencctv.org$path');
    }
    expect(
      SyriApi.parseOpenCctvCameras(
        listing('39.7', '19.6', '/cameras/albania/corfu/5'),
        country: 'Shqipëri',
        fetched: DateTime(2026, 9, 22),
      ),
      isEmpty,
    );
  });

  test(
    'parses fixed speed cameras from the public Overpass response',
    () async {
      SharedPreferences.setMockInitialValues({});
      final api = SyriApi(
        client: MockClient(
          (_) async => http.Response(
            '''{"elements":[{"type":"node","id":42,"lat":41.32,"lon":19.81,"timestamp":"2026-09-13T10:00:00Z","tags":{"highway":"speed_camera","maxspeed":"60","direction":"90","operator":"Policia Rrugore"}}]}''',
            200,
          ),
        ),
      );

      final result = await api.speedCameras(cities.first);
      expect(result.value, hasLength(1));
      expect(result.value.single.kind, 'speed-camera');
      expect(result.value.single.description, contains('60 km/h'));
      expect(result.value.single.description, contains('Policia Rrugore'));
      expect(result.value.single.url, contains('/node/42'));
    },
  );

  test('keeps only fresh location-matched official road notices', () async {
    SharedPreferences.setMockInitialValues({});
    const rss = '''<?xml version="1.0"?><rss version="2.0"><channel>
      <item><title>Tiranë/Policia Rrugore njofton kufizim qarkullimi</title>
      <link>https://asp.gov.al/njoftim</link>
      <pubDate>Wed, 10 Sep 2099 12:00:00 +0200</pubDate>
      <description>Devijim i përkohshëm në Tiranë.</description></item>
      <item><title>Vlorë/Policia Rrugore njofton radar</title>
      <link>https://asp.gov.al/vlore</link>
      <pubDate>Wed, 10 Sep 2099 12:00:00 +0200</pubDate></item>
      </channel></rss>''';
    final api = SyriApi(
      client: MockClient(
        (_) async => http.Response.bytes(utf8.encode(rss), 200),
      ),
    );
    final tirana = cities.firstWhere((item) => item.name == 'Tiranë');

    final result = await api.officialRoadSafetyNotices(tirana);
    expect(result.value, hasLength(1));
    expect(result.value.single.kind, 'police-alert');
    expect(result.value.single.title, contains('Tiranë'));
    expect(result.value.single.approximate, isTrue);
  });

  test('public alert statuses are translated to Albanian', () {
    expect(shqipStatus('Under control'), 'Nën kontroll');
    expect(shqipStatus('Low'), 'I ulët');
    expect(shqipStatus('Very high'), 'Shumë i lartë');
  });

  test('airport flight statuses are translated to Albanian', () {
    expect(shqipFlightStatus('On Time'), 'Në orar');
    expect(shqipFlightStatus('Delayed'), 'Me vonesë');
    expect(shqipFlightStatus('Gate closed'), 'Porta është mbyllur');
  });

  test(
    'Kosovo river parser keeps recent measurements and exact coordinates',
    () {
      const html = '''<table class="dsp"><tr><th>Stacioni:
      <a href="http://www.google.com/maps/place/42.1943,20.7739/@x">
      <img alt="location" />Prizren</a></th></tr>
      <tr><td class="center">Lumi</td><td class="center">Kuota</td>
      <td class="center">Niveli</td><td class="center">Ndryshimi</td>
      <td class="center">Tendenca</td><td class="center">Data</td></tr>
      <tr><td class="center">Bistrica e Prizrenit</td><td class="center"></td>
      <td class="center">35.30 cm</td><td class="center">0.50 cm</td>
      <td class="center"><img src="tUp.png"/></td>
      <td class="center">13.09.2026 09:00</td></tr></table>''';
      final events = SyriApi.parseKosovoRiverLevels(
        html,
        now: DateTime(2026, 9, 13, 10),
      );
      expect(events, hasLength(1));
      expect(events.single.title, contains('35.3 cm'));
      expect(events.single.description, contains('në rritje'));
      expect(events.single.point!.latitude, closeTo(42.1943, .00001));
      expect(events.single.dataMode, 'AFËR KOHËS REALE');
    },
  );

  test('Tirana airport parser separates arrivals and departures', () {
    const html = '''<ul id="arrival-container"><li><a href="/en/flight/1"><ul>
      <li>12:45</li><li>Barcelona (ES)</li><li>Vueling</li>
      <li>VY 8580</li><li>Landed</li></ul></a></li></ul>
      <ul id="departure-container"><li><a href="/en/flight/2"><ul>
      <li>13:00</li><li>Pisa (IT)</li><li>Ryanair</li>
      <li>FR 8391</li><li>Boarding</li></ul></a></li></ul>
      <div class="serach-flights-container-home"></div>''';
    final events = SyriApi.parseTiranaAirportFlights(
      html,
      fetched: DateTime(2026, 9, 13, 11),
    );
    expect(events, hasLength(2));
    expect(events.first.kind, 'airport-arrival');
    expect(events.first.description, contains('Ka mbërritur'));
    expect(events.last.kind, 'airport-departure');
    expect(events.last.description, contains('Hipja në avion'));
  });
  test('matches Albanian city names without diacritics', () {
    expect(matchCity('Aksident në Shkoder')?.name, 'Shkodër');
    expect(matchCity('Ngjarje në Prishtinë')?.name, 'Prishtinë');
    expect(matchCity('Lajme nga rajoni'), isNull);
  });

  test('RSS parser preserves source links and marks city as approximate', () {
    const xml = '''<?xml version="1.0"?><rss version="2.0"><channel><item>
      <title>Raportim nga Shkodër</title>
      <link>https://example.com/lajmi</link>
      <pubDate>Wed, 10 Sep 2026 12:00:00 +0200</pubDate>
    </item></channel></rss>''';
    final events = SyriApi.parseNews(xml, 'Burimi');
    expect(events, hasLength(1));
    expect(events.single.point, isNotNull);
    expect(events.single.approximate, isTrue);
    expect(events.single.url, 'https://example.com/lajmi');
  });

  test('RSS parser reads Google News GMT date and time', () {
    const xml = '''<?xml version="1.0"?><rss version="2.0"><channel><item>
      <title>Aksident në Tiranë</title><link>https://example.com/crash</link>
      <pubDate>Thu, 11 Sep 2026 08:42:15 GMT</pubDate>
    </item></channel></rss>''';
    final event = SyriApi.parseNews(xml, 'Burimi').single;
    expect(event.time, DateTime.utc(2026, 9, 11, 8, 42, 15));
    expect(event.important, isTrue);
    expect(event.newsType, 'crash');
  });

  test('RSS parser extracts a clean, short article summary', () {
    const xml = '''<?xml version="1.0"?><rss version="2.0"><channel><item>
      <title>Ngjarje e rëndësishme në Tiranë</title>
      <link>https://example.com/ngjarja</link>
      <description><![CDATA[<p>Autoritetet dhanë hollësi të reja për ngjarjen
      dhe njoftuan masat që po merren në zonë.</p>]]></description>
    </item></channel></rss>''';
    final event = SyriApi.parseNews(xml, 'Burimi').single;
    expect(event.summary, contains('Autoritetet dhanë hollësi'));
    expect(event.summary, isNot(contains('<p>')));
  });

  test('news icons distinguish armed violence from other deaths', () {
    const base = Event(
      id: '1',
      title: 'Një person u vra nga shpërthimi në banesë',
      description: '',
      source: 'Burimi',
      url: 'https://example.com/1',
      kind: 'news',
    );
    const armed = Event(
      id: '2',
      title: 'Të shtëna me armë, një person u vra',
      description: '',
      source: 'Burimi',
      url: 'https://example.com/2',
      kind: 'news',
    );
    expect(base.newsType, 'death');
    expect(armed.newsType, 'violence');
  });

  test('place summaries reject unrelated political pages', () {
    expect(
      placeInsightMatches(
        'Ura e Mesit',
        'Lloji: bridge; historic: yes',
        'Prime Minister of Albania',
        'The prime minister is the head of government of Albania.',
      ),
      isFalse,
    );
    expect(
      placeInsightMatches(
        'Ura e Mesit',
        'Lloji: bridge; historic: yes',
        'Ura e Mesit',
        'Ura e Mesit is an Ottoman bridge near Shkodër.',
      ),
      isTrue,
    );
  });

  test('camera links are separated by their public source and purpose', () {
    const youtube = Event(
      id: 'yt',
      title: 'Shkodër live',
      description: '',
      source: 'YouTube',
      url: 'https://www.youtube.com/watch?v=abc',
      kind: 'cameras',
    );
    const traffic = Event(
      id: 'tirana',
      title: 'Sheshi Kombinat',
      description: 'Kamera trafiku',
      source: 'Bashkia Tiranë',
      url: 'https://tirana.al/kamera-trafiku',
      kind: 'cameras',
    );
    expect(youtube.cameraType, 'youtube');
    expect(traffic.cameraType, 'traffic');
  });

  test('data modes do not present external links as live measurements', () {
    const plane = Event(
      id: 'plane',
      title: 'Fluturim',
      description: '',
      source: 'ADSB',
      url: 'https://example.com/plane',
      kind: 'planes',
    );
    const energy = Event(
      id: 'energy',
      title: 'Portali energjetik',
      description: '',
      source: 'OST',
      url: 'https://example.com/energy',
      kind: 'energy-grid',
    );
    expect(plane.dataMode, 'LIVE');
    expect(energy.dataMode, 'LIDHJE E JASHTME');
  });

  test('energy portal cards do not invent a live observation time', () {
    final cards = SyriApi().energyGrid().value;
    expect(cards, hasLength(2));
    expect(cards.every((event) => event.time == null), isTrue);
    expect(
      cards.every((event) => event.dataMode == 'LIDHJE E JASHTME'),
      isTrue,
    );
  });
}
