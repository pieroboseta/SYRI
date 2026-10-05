import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';

class City {
  final String name, country;
  final double lat, lon;
  final List<String> aliases;
  const City(this.name, this.country, this.lat, this.lon, this.aliases);
  LatLng get point => LatLng(lat, lon);
}

const cities = [
  City('Shkodër', 'Shqipëri', 42.0683, 19.5126, [
    'shkoder',
    'shkodra',
    'shkodres',
  ]),
  City('Tiranë', 'Shqipëri', 41.3275, 19.8187, ['tirane', 'tirana', 'tiranes']),
  City('Durrës', 'Shqipëri', 41.3231, 19.4414, [
    'durres',
    'durresi',
    'durresit',
  ]),
  City('Vlorë', 'Shqipëri', 40.4661, 19.4914, ['vlore', 'vlora', 'vlores']),
  City('Lezhë', 'Shqipëri', 41.7836, 19.6436, ['lezhe', 'lezha', 'lezhes']),
  City('Kukës', 'Shqipëri', 42.0769, 20.4219, ['kukes', 'kukesi', 'kukesit']),
  City('Elbasan', 'Shqipëri', 41.1125, 20.0822, [
    'elbasan',
    'elbasani',
    'elbasanit',
  ]),
  City('Fier', 'Shqipëri', 40.7239, 19.5561, ['fier', 'fieri', 'fierit']),
  City('Berat', 'Shqipëri', 40.7058, 19.9522, ['berat', 'berati', 'beratit']),
  City('Korçë', 'Shqipëri', 40.6186, 20.7808, ['korce', 'korca', 'korces']),
  City('Gjirokastër', 'Shqipëri', 40.0758, 20.1389, [
    'gjirokaster',
    'gjirokastra',
    'gjirokastres',
  ]),
  City('Sarandë', 'Shqipëri', 39.8756, 20.0053, [
    'sarande',
    'saranda',
    'sarandes',
  ]),
  City('Pogradec', 'Shqipëri', 40.9025, 20.6525, [
    'pogradec',
    'pogradeci',
    'pogradecit',
  ]),
  City('Prishtinë', 'Kosovë', 42.6629, 21.1655, [
    'prishtine',
    'prishtina',
    'prishtines',
  ]),
  City('Prizren', 'Kosovë', 42.2139, 20.7397, [
    'prizren',
    'prizreni',
    'prizrenit',
  ]),
  City('Pejë', 'Kosovë', 42.6593, 20.2887, ['peje', 'peja', 'pejes']),
  City('Gjakovë', 'Kosovë', 42.3803, 20.4308, [
    'gjakove',
    'gjakova',
    'gjakoves',
  ]),
  City('Gjilan', 'Kosovë', 42.4635, 21.4694, ['gjilan', 'gjilani', 'gjilanit']),
  City('Ferizaj', 'Kosovë', 42.3702, 21.1483, [
    'ferizaj',
    'ferizaji',
    'ferizajt',
  ]),
  City('Mitrovicë', 'Kosovë', 42.8914, 20.865, [
    'mitrovice',
    'mitrovica',
    'mitrovices',
  ]),
  City('Koplik', 'Shqipëri', 42.2136, 19.4364, [
    'koplik',
    'kopliku',
    'malesi e madhe',
  ]),
  City('Pukë', 'Shqipëri', 42.0444, 19.8997, ['puke', 'puka', 'pukes']),
  City('Rrëshen', 'Shqipëri', 41.7675, 19.8756, [
    'rreshen',
    'rresheni',
    'mirdite',
  ]),
  City('Krujë', 'Shqipëri', 41.5092, 19.7928, ['kruje', 'kruja', 'krujes']),
  City('Kamëz', 'Shqipëri', 41.3817, 19.7603, ['kamez', 'kamza', 'kamzes']),
  City('Kavajë', 'Shqipëri', 41.1856, 19.5569, ['kavaje', 'kavaja', 'kavajes']),
  City('Lushnjë', 'Shqipëri', 40.9419, 19.7050, [
    'lushnje',
    'lushnja',
    'lushnjes',
  ]),
  City('Divjakë', 'Shqipëri', 40.9967, 19.5294, [
    'divjake',
    'divjaka',
    'divjakes',
  ]),
  City('Gramsh', 'Shqipëri', 40.8697, 20.1844, [
    'gramsh',
    'gramshi',
    'gramshit',
  ]),
  City('Librazhd', 'Shqipëri', 41.1790, 20.3150, [
    'librazhd',
    'librazhdi',
    'librazhdit',
  ]),
  City('Prrenjas', 'Shqipëri', 41.0667, 20.5450, [
    'prrenjas',
    'prrenjasi',
    'prrenjasit',
  ]),
  City('Peshkopi', 'Shqipëri', 41.6850, 20.4289, [
    'peshkopi',
    'peshkopia',
    'diber',
  ]),
  City('Burrel', 'Shqipëri', 41.6103, 20.0089, ['burrel', 'burreli', 'mat']),
  City('Bulqizë', 'Shqipëri', 41.4917, 20.2219, [
    'bulqize',
    'bulqiza',
    'bulqizes',
  ]),
  City('Tepelenë', 'Shqipëri', 40.2958, 20.0192, [
    'tepelene',
    'tepelena',
    'tepelenes',
  ]),
  City('Përmet', 'Shqipëri', 40.2336, 20.3517, [
    'permet',
    'permeti',
    'permetit',
  ]),
  City('Himarë', 'Shqipëri', 40.1017, 19.7447, ['himare', 'himara', 'himares']),
  City('Deçan', 'Kosovë', 42.5400, 20.2883, ['decan', 'decani', 'decanit']),
  City('Rahovec', 'Kosovë', 42.3994, 20.6547, [
    'rahovec',
    'rahoveci',
    'orahovac',
  ]),
  City('Suharekë', 'Kosovë', 42.3586, 20.8250, [
    'suhareke',
    'suhareka',
    'therande',
  ]),
  City('Vushtrri', 'Kosovë', 42.8231, 20.9675, [
    'vushtrri',
    'vushtrria',
    'vucitrn',
  ]),
  City('Podujevë', 'Kosovë', 42.9106, 21.1931, [
    'podujeve',
    'podujeva',
    'besiane',
  ]),
  City('Lipjan', 'Kosovë', 42.5217, 21.1258, ['lipjan', 'lipjani', 'lipljan']),
  City('Kaçanik', 'Kosovë', 42.2319, 21.2594, ['kacanik', 'kacaniku']),
  City('Drenas', 'Kosovë', 42.6283, 20.8939, ['drenas', 'drenasi', 'gllogoc']),
  City('Klinë', 'Kosovë', 42.6217, 20.5778, ['kline', 'klina', 'klines']),
  City('Tetovë', 'Maqedonia e Veriut', 42.0103, 20.9714, [
    'tetove',
    'tetova',
    'tetovo',
  ]),
  City('Gostivar', 'Maqedonia e Veriut', 41.7960, 20.9082, [
    'gostivar',
    'gostivari',
  ]),
  City('Strugë', 'Maqedonia e Veriut', 41.1775, 20.6783, ['struge', 'struga']),
  City('Dibër e Madhe', 'Maqedonia e Veriut', 41.5244, 20.5242, [
    'diber e madhe',
    'diber maqedoni',
    'debar',
  ]),
  City('Kërçovë', 'Maqedonia e Veriut', 41.5127, 20.9589, [
    'kercove',
    'kercova',
    'kicevo',
  ]),
  City('Shkup', 'Maqedonia e Veriut', 41.9981, 21.4254, [
    'shkup',
    'shkupi',
    'skopje',
    'cair',
  ]),
  City('Kumanovë', 'Maqedonia e Veriut', 42.1322, 21.7144, [
    'kumanove',
    'kumanova',
    'kumanovo',
  ]),
  City('Ulqin', 'Mali i Zi', 41.9294, 19.2244, ['ulqin', 'ulqini', 'ulcinj']),
  City('Tuz', 'Mali i Zi', 42.3656, 19.3314, [
    'tuz',
    'tuzi',
    'tuzi municipality',
  ]),
  City('Tivar', 'Mali i Zi', 42.0931, 19.1003, [
    'tivar',
    'tivari',
    'bar montenegro',
  ]),
  City('Budva', 'Mali i Zi', 42.2864, 18.8400, ['budva', 'budve']),
  City('Podgoricë', 'Mali i Zi', 42.4304, 19.2594, ['podgorica', 'podgorice']),
  City('Kotor', 'Mali i Zi', 42.4247, 18.7712, ['kotor', 'kotorri']),
  City('Guci', 'Mali i Zi', 42.5619, 19.8339, ['guci', 'gucia', 'gusinje']),
  City('Plavë', 'Mali i Zi', 42.5969, 19.9456, [
    'plave',
    'plava',
    'plav montenegro',
  ]),
];
String normalize(String v) =>
    v.toLowerCase().replaceAll('ë', 'e').replaceAll('ç', 'c');

String countryCodeFor(City city) => switch (city.country) {
  'Kosovë' => 'XK',
  'Maqedonia e Veriut' => 'MK',
  'Mali i Zi' => 'ME',
  _ => 'AL',
};

String shqipStatus(Object? raw) {
  final value = raw?.toString().trim() ?? '';
  if (value.isEmpty) return '—';
  final key = normalize(value);
  const exact = {
    'under control': 'Nën kontroll',
    'contained': 'I kufizuar',
    'active': 'Aktiv',
    'extinguished': 'I shuar',
    'out': 'I shuar',
    'monitoring': 'Në monitorim',
    'low': 'I ulët',
    'moderate': 'Mesatar',
    'medium': 'Mesatar',
    'high': 'I lartë',
    'very high': 'Shumë i lartë',
    'extreme': 'Ekstrem',
    'green': 'I ulët',
    'orange': 'I lartë',
    'red': 'Shumë i lartë',
    'unknown': 'I panjohur',
    'no data': 'Pa të dhëna',
  };
  if (exact.containsKey(key)) return exact[key]!;
  var translated = value;
  const phrases = {
    'Under control': 'Nën kontroll',
    'Low': 'I ulët',
    'Moderate': 'Mesatar',
    'Medium': 'Mesatar',
    'High': 'I lartë',
    'Very high': 'Shumë i lartë',
    'Extreme': 'Ekstrem',
    'Unknown': 'I panjohur',
  };
  for (final item in phrases.entries) {
    translated = translated.replaceAll(item.key, item.value);
  }
  return translated;
}

String shqipFlightStatus(Object? raw) {
  final value = raw?.toString().trim() ?? '';
  if (value.isEmpty) return 'Pa status';
  return switch (normalize(value)) {
    'on time' => 'Në orar',
    'scheduled' => 'I planifikuar',
    'landed' => 'Ka mbërritur',
    'departed' => 'Është nisur',
    'boarding' => 'Hipja në avion',
    'gate open' => 'Porta është hapur',
    'gate closed' => 'Porta është mbyllur',
    'delayed' => 'Me vonesë',
    'cancelled' || 'canceled' => 'I anuluar',
    'diverted' => 'Devijuar',
    'early' => 'Më herët',
    _ => value,
  };
}

bool placeInsightMatches(
  String placeTitle,
  String placeDescription,
  String pageTitle,
  String extract,
) {
  final wanted = normalize(placeTitle);
  final candidate = normalize('$pageTitle $extract');
  final words = wanted
      .split(RegExp(r'[^a-z0-9]+'))
      .where(
        (word) =>
            word.length >= 3 &&
            !const {
              'dhe',
              'nga',
              'per',
              'the',
              'albania',
              'kosovo',
            }.contains(word),
      )
      .toSet();
  if (words.isEmpty) return false;
  final matching = words.where(candidate.contains).length;
  final needed = words.length == 1 ? 1 : (words.length * .6).ceil();
  if (matching < needed) return false;

  final context = normalize(placeDescription);
  final isPolitical = RegExp(
    r'prime minister|president|politician|political party|kryeminist|president|deputet',
  ).hasMatch(candidate);
  final expectsPolitics = RegExp(
    r'prime minister|president|kryeminist|politikan|deputet',
  ).hasMatch('$wanted $context');
  return !isPolitical || expectsPolitics;
}

City? matchCity(String title) {
  final words = normalize(title).split(RegExp(r'[^a-z]+')).toSet();
  final m = cities.where((c) => c.aliases.any(words.contains)).toList();
  return m.length == 1 ? m.single : null;
}

String dateLabel(DateTime time) {
  final t = time.toLocal();
  return '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}.${t.year} · ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class SearchPlace {
  final String name, country;
  final LatLng point;
  const SearchPlace(this.name, this.country, this.point);
  City get asCity =>
      City(name, country, point.latitude, point.longitude, [normalize(name)]);
}

class Event {
  final String id, title, description, source, url, kind;
  final String? summary;
  final LatLng? point;
  final DateTime? time;
  final bool approximate;
  final double? heading, speedKnots;
  final List<LatLng>? geometry;
  const Event({
    required this.id,
    required this.title,
    required this.description,
    required this.source,
    required this.url,
    required this.kind,
    this.summary,
    this.point,
    this.time,
    this.approximate = false,
    this.heading,
    this.speedKnots,
    this.geometry,
  });

  /// A user-facing statement of what the timestamp and marker represent.
  String get dataMode {
    if (kind == 'planes') return 'LIVE';
    if (const {
      'quakes',
      'fire',
      'storm',
      'flood',
      'volcano',
      'hazards',
      'internet-outage',
      'river-level',
      'airport-arrival',
      'airport-departure',
    }.contains(kind)) {
      return 'AFËR KOHËS REALE';
    }
    if (const {
      'news',
      'roadwork',
      'traffic-jam',
      'power-outage',
      'water-outage',
      'health-alert',
      'food-alert',
      'port-alert',
      'hydrology-alert',
      'civic-alert',
    }.contains(kind)) {
      return 'RAPORTIM';
    }
    if (const {'cameras', 'ships', 'energy-grid', 'geoportal'}.contains(kind)) {
      return 'LIDHJE E JASHTME';
    }
    return 'TË DHËNA PUBLIKE';
  }

  String get tone {
    if (kind != 'news') return 'neutral';
    final t = normalize(title);
    const bad = [
      'aksident',
      'arrest',
      'vrit',
      'vra',
      'plagos',
      'zjarr',
      'vjedh',
      'krim',
      'dhun',
      'rrezik',
      'permbyt',
      'humb jet',
      'godit',
      'te shtena',
      'tragjedi',
    ];
    const good = [
      'shpeton',
      'shpetohet',
      'ndihmon',
      'hapet',
      'perfundo',
      'fiton',
      'sukses',
      'investim',
      'rritet',
      'miratohet',
      'zgjidhet',
      'rikthehet',
      'restaurohet',
    ];
    if (bad.any(t.contains)) return 'bad';
    if (good.any(t.contains)) return 'good';
    return 'neutral';
  }

  String get newsType {
    final t = normalize(title);
    if ([
      'aksident',
      'perplasje',
      'automjet',
      'makine',
      'humb kontrollin',
    ].any(t.contains)) {
      return 'crash';
    }
    final nonWeaponFatalIncident = [
      'shperth',
      'shemb',
      'helmim',
      'asfiksi',
      'mbytet',
      'mbytje',
      'elektrokut',
      'aksident ne pune',
    ].any(t.contains);
    final deathMention = [
      'vdes',
      'vdekur',
      'humb jeten',
      'humbi jeten',
      'nderron jete',
      'vrit',
      'vra',
    ].any(t.contains);
    if (nonWeaponFatalIncident && deathMention) return 'death';
    if ([
      'arme',
      'pistolete',
      'pushke',
      'kallashnikov',
      'plumb',
      'qellon',
      'te shtena',
      'thike',
      'dhun',
      'sulm fizik',
      'rrah',
      'vrit',
      'vra',
    ].any(t.contains)) {
      return 'violence';
    }
    if (deathMention) return 'death';
    if ([
      'plagos',
      'arrest',
      'krim',
      'vjedh',
      'droge',
      'mashtrim',
      'kontraband',
    ].any(t.contains)) {
      return 'crime';
    }
    if (['zjarr', 'djegie'].any(t.contains)) return 'fire';
    if (['stuhi', 'permbyt', 'reshje', 'bore', 'termet'].any(t.contains)) {
      return 'weather';
    }
    if (tone == 'good') return 'good';
    return 'major';
  }

  String get cameraType {
    if (kind != 'cameras') return '';
    final text = normalize('$title $description $source');
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      return 'youtube';
    }
    if (text.contains('kufi') ||
        text.contains('border') ||
        text.contains('vermic')) {
      return 'border';
    }
    if (text.contains('ski') ||
        text.contains('nature') ||
        text.contains('natyre') ||
        text.contains('brezovic') ||
        text.contains('batllav') ||
        text.contains('brod, dragash')) {
      return 'nature';
    }
    if (source == 'Bashkia Tiranë' || text.contains('traffic')) {
      return 'traffic';
    }
    return 'city';
  }

  bool get important {
    if (kind != 'news') return true;
    final t = normalize(title);
    const terms = [
      'aksident',
      'perplasje',
      'vrit',
      'vra',
      'plagos',
      'arrest',
      'krim',
      'vjedh',
      'arme',
      'droge',
      'dhun',
      'te shtena',
      'zjarr',
      'shperthim',
      'permbyt',
      'stuhi',
      'termet',
      'emergjenc',
      'evaku',
      'humb jet',
      'vdekje',
      'proteste',
      'zgjedhje',
      'qeveri',
      'parlament',
      'minister',
      'kryeminister',
      'president',
      'gjykate',
      'prokurori',
      'operacion',
      'shpeton',
      'shpetohet',
      'fiton',
      'rekord',
      'medalje',
      'investim madhor',
      'hapet',
      'inaugurohet',
    ];
    return terms.any(t.contains);
  }

  LatLng get displayPoint {
    if (point == null ||
        kind != 'planes' ||
        heading == null ||
        speedKnots == null ||
        time == null) {
      return point!;
    }
    final sec =
        DateTime.now().difference(time!).inMilliseconds.clamp(0, 45000) / 1000;
    return const Distance().offset(
      point!,
      speedKnots! * 0.514444 * sec,
      heading!,
    );
  }
}

class FeedResult<T> {
  final T value;
  final DateTime fetched;
  final bool stale;
  const FeedResult(this.value, this.fetched, this.stale);
}

class WeatherHour {
  final DateTime time;
  final double temperature, rain;
  final int rainChance;
  final String symbol;
  const WeatherHour(
    this.time,
    this.temperature,
    this.rain,
    this.rainChance,
    this.symbol,
  );
}

class WeatherDay {
  final DateTime date, sunrise, sunset;
  final double minimum, maximum;
  final int rainChance;
  final String symbol;
  const WeatherDay(
    this.date,
    this.sunrise,
    this.sunset,
    this.minimum,
    this.maximum,
    this.rainChance,
    this.symbol,
  );
}

class Weather {
  final double temperature, wind, rain;
  final int rainChance;
  final String symbol;
  final DateTime time, sunrise, sunset;
  final List<WeatherHour> hours;
  final List<WeatherDay> days;
  const Weather(
    this.temperature,
    this.wind,
    this.rain,
    this.rainChance,
    this.symbol,
    this.time,
    this.sunrise,
    this.sunset,
    this.hours,
    this.days,
  );
  String get label => symbol.contains('thunder')
      ? 'Stuhi e parashikuar'
      : symbol.contains('snow')
      ? 'Borë'
      : symbol.contains('sleet')
      ? 'Reshje të përziera'
      : symbol.contains('rain')
      ? 'Shi'
      : symbol.contains('cloud')
      ? 'Vranësira'
      : symbol.contains('fog')
      ? 'Mjegull'
      : 'Kthjellët';
  bool get rainAhead =>
      hours.any((h) => h.rain > 0 || h.symbol.contains('rain'));
  bool get thunderAhead => hours.any((h) => h.symbol.contains('thunder'));
  bool get hailAhead => hours.any((h) => h.symbol.contains('hail'));
}

class AircraftRoute {
  final String airline,
      originName,
      originCode,
      destinationName,
      destinationCode;
  const AircraftRoute(
    this.airline,
    this.originName,
    this.originCode,
    this.destinationName,
    this.destinationCode,
  );
}

class RadarLayer {
  final String tileUrl;
  final DateTime time;
  const RadarLayer(this.tileUrl, this.time);
}

class AirQuality {
  final double europeanAqi, pm25, pm10, uv, dust;
  final double? olivePollen, grassPollen;
  final DateTime time;
  const AirQuality(
    this.europeanAqi,
    this.pm25,
    this.pm10,
    this.uv,
    this.dust,
    this.olivePollen,
    this.grassPollen,
    this.time,
  );

  String get label => europeanAqi <= 20
      ? 'Ajër i mirë'
      : europeanAqi <= 40
      ? 'Ajër i pranueshëm'
      : europeanAqi <= 60
      ? 'Ajër mesatar'
      : europeanAqi <= 80
      ? 'Ajër i dobët'
      : europeanAqi <= 100
      ? 'Ajër shumë i dobët'
      : 'Ajër jashtëzakonisht i dobët';
}

List<AirQuality?> parseAirQualityBatch(String body, DateTime fetched) {
  final decoded = jsonDecode(body);
  final rows = decoded is List ? decoded : [decoded];
  return rows.map<AirQuality?>((row) {
    if (row is! Map || row['current'] is! Map) return null;
    final current = row['current'] as Map;
    double? number(String key) => (current[key] as num?)?.toDouble();
    final aqi = number('european_aqi');
    if (aqi == null) return null;
    return AirQuality(
      aqi,
      number('pm2_5') ?? 0,
      number('pm10') ?? 0,
      number('uv_index') ?? 0,
      number('dust') ?? 0,
      number('olive_pollen'),
      number('grass_pollen'),
      DateTime.tryParse(current['time']?.toString() ?? '') ?? fetched,
    );
  }).toList();
}

class PlaceInsight {
  final String? summary, sourceUrl, language;
  final List<String> activities;
  const PlaceInsight({
    this.summary,
    this.sourceUrl,
    this.language,
    required this.activities,
  });
}

class MarineWeather {
  final double waveHeight, wavePeriod, seaTemperature, currentSpeed;
  final DateTime time;
  const MarineWeather(
    this.waveHeight,
    this.wavePeriod,
    this.seaTemperature,
    this.currentSpeed,
    this.time,
  );
}

List<Event> parseMontenegroBathingWater(
  String body, {
  required int year,
  required String round,
}) {
  final root = jsonDecode(body) as Map<String, dynamic>;
  final rows = (root['mjerenja'] as List?) ?? const [];
  final events = <Event>[];
  for (final raw in rows) {
    if (raw is! Map) continue;
    final row = Map<String, dynamic>.from(raw);
    final rawGeometry = row['geometrija']?.toString() ?? '';
    final coordinateText = RegExp(
      r'POLYGON\s*\(\((.*?)\)\)',
      dotAll: true,
    ).firstMatch(rawGeometry)?.group(1);
    if (coordinateText == null) continue;
    final geometry = <LatLng>[];
    for (final pair in coordinateText.split(',')) {
      final parts = pair.trim().split(RegExp(r'\s+'));
      if (parts.length < 2) continue;
      final longitude = double.tryParse(parts[0]);
      final latitude = double.tryParse(parts[1]);
      if (latitude != null && longitude != null) {
        geometry.add(LatLng(latitude, longitude));
      }
    }
    if (geometry.length < 3) continue;
    final grade = int.tryParse('${row['tezina']}') ?? 0;
    final status =
        const {
          1: 'E shkëlqyer',
          2: 'E mirë',
          3: 'E mjaftueshme',
          4: 'E dobët',
          0: 'Pa mostër',
        }[grade] ??
        'Pa mostër';
    final beach = (row['naziv'] ?? row['plaza'] ?? 'Plazh').toString().trim();
    final municipality = (row['opstina'] ?? 'Mali i Zi').toString().trim();
    final sampled = (row['vrijemeUzorkovanja'] ?? '').toString().trim();
    final dateMatch = RegExp(
      r'^(\d{2})\.(\d{2})\.(\d{4})\.?(?:\s+(\d{2}):(\d{2}))?',
    ).firstMatch(sampled);
    final sampleTime = dateMatch == null
        ? null
        : DateTime.tryParse(
            '${dateMatch.group(3)}-${dateMatch.group(2)}-${dateMatch.group(1)}T${dateMatch.group(4) ?? '00'}:${dateMatch.group(5) ?? '00'}:00',
          );
    final center = LatLng(
      geometry.map((p) => p.latitude).reduce((a, b) => a + b) / geometry.length,
      geometry.map((p) => p.longitude).reduce((a, b) => a + b) /
          geometry.length,
    );
    events.add(
      Event(
        id: 'morsko-water-$year-$round-${row['id']}',
        title: '$beach · $status',
        description:
            'Cilësia e ujit: $status\nPlazhi: $beach\nBashkia: $municipality\nMostra: ${sampled.isEmpty ? 'nuk është marrë' : sampled}\nVlerësim sezonal, jo matje në kohë reale.',
        source: 'JP Morsko dobro · Mali i Zi',
        url: 'https://monitoring.morskodobro.me/?lang=en_US',
        kind: 'water',
        point: center,
        time: sampleTime,
        geometry: geometry,
      ),
    );
  }
  return events;
}

class SyriApi {
  final http.Client client;
  bool offline = false;
  SyriApi({http.Client? client}) : client = client ?? http.Client();
  Future<FeedResult<String>> fetch(
    String key,
    String url,
    Duration ttl, {
    bool allowHtml = false,
    bool forceRefresh = false,
    Map<String, String>? formBody,
    Duration requestTimeout = const Duration(seconds: 20),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final safe = key.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final old = prefs.getString('data_$safe');
    final stamp = DateTime.tryParse(prefs.getString('time_$safe') ?? '');
    if (offline) {
      if (old != null && stamp != null) return FeedResult(old, stamp, true);
      throw StateError('No cached data available while offline');
    }
    if (!forceRefresh &&
        old != null &&
        stamp != null &&
        DateTime.now().difference(stamp) < ttl) {
      return FeedResult(old, stamp, false);
    }
    try {
      final response =
          await (formBody == null
                  ? client.get(
                      Uri.parse(url),
                      headers: {
                        'User-Agent': 'SYRI/0.2 public-data map',
                        'Accept': allowHtml
                            ? 'text/html, application/xhtml+xml, application/xml;q=0.9, */*;q=0.8'
                            : 'application/json, application/rss+xml, application/xml, text/xml',
                      },
                    )
                  : client.post(
                      Uri.parse(url),
                      body: formBody,
                      headers: {
                        'User-Agent': 'SYRI/0.2 public-data map',
                        'Accept': 'application/json',
                      },
                    ))
              .timeout(requestTimeout);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final body = utf8.decode(response.bodyBytes);
      if (!allowHtml &&
          (body.trimLeft().startsWith('<!DOCTYPE html') ||
              body.trimLeft().startsWith('<html'))) {
        throw Exception('HTML');
      }
      final now = DateTime.now();
      await prefs.setString('data_$safe', body);
      await prefs.setString('time_$safe', now.toIso8601String());
      return FeedResult(body, now, false);
    } catch (_) {
      if (old != null && stamp != null) return FeedResult(old, stamp, true);
      rethrow;
    }
  }

  Future<FeedResult<Weather>> weather(
    City city, {
    bool forceRefresh = false,
  }) async {
    final r = await fetch(
      'weather_v2_${city.lat}_${city.lon}',
      'https://api.open-meteo.com/v1/forecast?latitude=${city.lat}&longitude=${city.lon}&current=temperature_2m,wind_speed_10m,precipitation,weather_code&hourly=temperature_2m,precipitation,precipitation_probability,weather_code&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset&timezone=auto&forecast_days=7',
      const Duration(minutes: 10),
      forceRefresh: forceRefresh,
    );
    final json = jsonDecode(r.value) as Map<String, dynamic>;
    final current = json['current'] as Map<String, dynamic>;
    final hourly = json['hourly'] as Map<String, dynamic>;
    final daily = json['daily'] as Map<String, dynamic>;
    String symbolFor(num raw) {
      final code = raw.round();
      if (code >= 95) {
        return code == 96 || code == 99 ? 'thunder_hail' : 'thunder';
      }
      if (code >= 71 && code <= 77) return 'snow';
      if (code == 66 || code == 67) return 'sleet';
      if ((code >= 51 && code <= 65) || (code >= 80 && code <= 82)) {
        return 'rain';
      }
      if (code == 45 || code == 48) return 'fog';
      if (code >= 1 && code <= 3) return 'cloud';
      return 'clear';
    }

    final now = DateTime.now();
    final times = (hourly['time'] as List).cast<String>();
    final upcoming = <WeatherHour>[];
    for (var i = 0; i < times.length && upcoming.length < 24; i++) {
      final time = DateTime.parse(times[i]);
      if (time.isBefore(now.subtract(const Duration(hours: 1)))) continue;
      upcoming.add(
        WeatherHour(
          time,
          (hourly['temperature_2m'][i] as num).toDouble(),
          (hourly['precipitation'][i] as num).toDouble(),
          (hourly['precipitation_probability'][i] as num?)?.round() ?? 0,
          symbolFor(hourly['weather_code'][i] as num),
        ),
      );
    }
    final days = <WeatherDay>[];
    final dates = (daily['time'] as List).cast<String>();
    for (var i = 0; i < dates.length && days.length < 6; i++) {
      days.add(
        WeatherDay(
          DateTime.parse(dates[i]),
          DateTime.parse(daily['sunrise'][i]),
          DateTime.parse(daily['sunset'][i]),
          (daily['temperature_2m_min'][i] as num).toDouble(),
          (daily['temperature_2m_max'][i] as num).toDouble(),
          (daily['precipitation_probability_max'][i] as num?)?.round() ?? 0,
          symbolFor(daily['weather_code'][i] as num),
        ),
      );
    }
    final currentTime = DateTime.parse(current['time'].toString());
    final currentChance = upcoming
        .take(3)
        .fold<int>(0, (highest, hour) => math.max(highest, hour.rainChance));
    var currentRain = (current['precipitation'] as num).toDouble();
    var currentSymbol = symbolFor(current['weather_code'] as num);
    try {
      final met = await fetch(
        'met_weather_${city.lat}_${city.lon}',
        'https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=${city.lat}&lon=${city.lon}',
        const Duration(minutes: 10),
        forceRefresh: forceRefresh,
      );
      final series =
          (jsonDecode(met.value)['properties']?['timeseries'] ?? []) as List;
      if (series.isNotEmpty) {
        final next = series.first['data']?['next_1_hours'];
        final metRain =
            (next?['details']?['precipitation_amount'] as num?)?.toDouble() ??
            0;
        final metSymbol =
            next?['summary']?['symbol_code']?.toString().toLowerCase() ?? '';
        currentRain = math.max(currentRain, metRain);
        if (metSymbol.contains('thunder')) {
          currentSymbol = 'thunder';
        } else if (metSymbol.contains('snow')) {
          currentSymbol = 'snow';
        } else if (metSymbol.contains('sleet')) {
          currentSymbol = 'sleet';
        } else if (metRain >= .05 || metSymbol.contains('rain')) {
          currentSymbol = 'rain';
        }
      }
    } catch (_) {
      // Open-Meteo remains available when the corroborating source is offline.
    }
    if (currentRain >= .05 &&
        !currentSymbol.contains('thunder') &&
        !currentSymbol.contains('snow')) {
      currentSymbol = 'rain';
    }
    return FeedResult(
      Weather(
        (current['temperature_2m'] as num).toDouble(),
        (current['wind_speed_10m'] as num).toDouble(),
        currentRain,
        currentChance,
        currentSymbol,
        currentTime,
        days.first.sunrise,
        days.first.sunset,
        upcoming,
        days,
      ),
      r.fetched,
      r.stale,
    );
  }

  Future<FeedResult<AirQuality>> airQuality(City city) async {
    final r = await fetch(
      'air_${city.lat}_${city.lon}',
      'https://air-quality-api.open-meteo.com/v1/air-quality?latitude=${city.lat}&longitude=${city.lon}&current=european_aqi,pm2_5,pm10,dust,uv_index,olive_pollen,grass_pollen&timezone=auto',
      const Duration(minutes: 30),
    );
    final parsed = parseAirQualityBatch(r.value, r.fetched).first;
    if (parsed == null) throw const FormatException('Air quality unavailable');
    return FeedResult(parsed, r.fetched, r.stale);
  }

  Future<Map<String, FeedResult<AirQuality>>> airQualityForCities(
    List<City> selectedCities,
  ) async {
    final readings = <String, FeedResult<AirQuality>>{};
    for (var start = 0; start < selectedCities.length; start += 20) {
      final group = selectedCities.skip(start).take(20).toList();
      final latitudes = group.map((city) => city.lat).join(',');
      final longitudes = group.map((city) => city.lon).join(',');
      try {
        final response = await fetch(
          'air_cities_${group.map((city) => city.name).join('_')}',
          'https://air-quality-api.open-meteo.com/v1/air-quality?latitude=$latitudes&longitude=$longitudes&current=european_aqi,pm2_5,pm10,dust,uv_index,olive_pollen,grass_pollen&timezone=auto',
          const Duration(minutes: 30),
        );
        final parsed = parseAirQualityBatch(response.value, response.fetched);
        for (
          var index = 0;
          index < group.length && index < parsed.length;
          index++
        ) {
          final reading = parsed[index];
          if (reading != null) {
            readings[group[index].name] = FeedResult(
              reading,
              response.fetched,
              response.stale,
            );
          }
        }
      } catch (_) {
        // Keep other batches visible if one request fails.
      }
    }
    return readings;
  }

  Future<PlaceInsight> placeInsight(Event event) async {
    final searchable = 'intitle:"${event.title}" Albania Kosovo';
    Map<String, dynamic>? page;
    String? language;
    for (final lang in const ['sq', 'en']) {
      try {
        final r = await fetch(
          'wiki_${lang}_${normalize(event.title)}',
          'https://$lang.wikipedia.org/w/api.php?action=query&generator=search&gsrsearch=${Uri.encodeQueryComponent(searchable)}&gsrlimit=5&prop=extracts%7Cinfo&exintro=1&explaintext=1&inprop=url&format=json&origin=*',
          const Duration(days: 30),
        );
        final pages = jsonDecode(r.value)['query']?['pages'];
        if (pages is Map && pages.isNotEmpty) {
          for (final raw in pages.values) {
            final candidate = Map<String, dynamic>.from(raw as Map);
            if (placeInsightMatches(
              event.title,
              event.description,
              candidate['title']?.toString() ?? '',
              candidate['extract']?.toString() ?? '',
            )) {
              page = candidate;
              language = lang;
              break;
            }
          }
          if (page != null) break;
        }
      } catch (_) {
        // The activity suggestions below remain useful without Wikipedia.
      }
    }
    final text = normalize('${event.title} ${event.description}');
    final activities = <String>{};
    if (text.contains('shpell') || text.contains('cave')) {
      activities.addAll([
        'Ecje dhe eksplorim',
        'Fotografi',
        'Gjeologji dhe natyrë',
      ]);
    } else if (text.contains('museum') || text.contains('muze')) {
      activities.addAll(['Histori dhe kulturë', 'Vizitë muzeale', 'Fotografi']);
    } else if (text.contains('viewpoint') || text.contains('panoram')) {
      activities.addAll(['Pamje panoramike', 'Fotografi', 'Ecje']);
    } else if (text.contains('camp')) {
      activities.addAll(['Kamping', 'Ecje', 'Natyrë']);
    } else if (text.contains('protected') || text.contains('mbrojtur')) {
      activities.addAll([
        'Ecje në natyrë',
        'Vëzhgim i biodiversitetit',
        'Fotografi',
      ]);
    } else {
      activities.addAll(['Vizitë kulturore', 'Fotografi', 'Eksplorim i zonës']);
    }
    activities.add('Kontrollo aksesin dhe orarin para nisjes');
    final extract = page?['extract']?.toString().trim();
    return PlaceInsight(
      summary: extract?.isNotEmpty == true ? extract : null,
      sourceUrl: page?['fullurl']?.toString(),
      language: language,
      activities: activities.toList(),
    );
  }

  Future<FeedResult<MarineWeather>> marine(City city) async {
    final r = await fetch(
      'marine_${city.lat}_${city.lon}',
      'https://marine-api.open-meteo.com/v1/marine?latitude=${city.lat}&longitude=${city.lon}&current=wave_height,wave_period,sea_surface_temperature,ocean_current_velocity&cell_selection=sea&timezone=auto',
      const Duration(minutes: 45),
    );
    final current = jsonDecode(r.value)['current'] as Map<String, dynamic>;
    double number(String key) => (current[key] as num?)?.toDouble() ?? 0;
    return FeedResult(
      MarineWeather(
        number('wave_height'),
        number('wave_period'),
        number('sea_surface_temperature'),
        number('ocean_current_velocity'),
        DateTime.tryParse(current['time']?.toString() ?? '') ?? r.fetched,
      ),
      r.fetched,
      r.stale,
    );
  }

  Future<FeedResult<List<Event>>> earthquakes() async {
    final start = DateTime.now()
        .toUtc()
        .subtract(const Duration(days: 7))
        .toIso8601String()
        .substring(0, 19);
    final r = await fetch(
      'quakes',
      'https://www.seismicportal.eu/fdsnws/event/1/query?format=json&limit=150&minlatitude=39&maxlatitude=44&minlongitude=18&maxlongitude=23.1&starttime=$start',
      const Duration(minutes: 5),
    );
    final events = (jsonDecode(r.value)['features'] as List).map((row) {
      final p = row['properties'];
      return Event(
        id: row['id'],
        title: 'M ${p['mag']} · Tërmet',
        description:
            'Zona: ${p['flynn_region']}\nThellësia: ${p['depth']} km\nMagnituda: ${p['mag']}\nTë dhënat mund të rishikohen nga EMSC.',
        source: 'EMSC',
        url:
            'https://www.emsc-csem.org/Earthquake_information/earthquake.php?id=${p['source_id']}',
        kind: 'quakes',
        point: LatLng(
          (p['lat'] as num).toDouble(),
          (p['lon'] as num).toDouble(),
        ),
        time: DateTime.parse(p['time']),
      );
    }).toList();
    return FeedResult(events, r.fetched, r.stale);
  }

  Future<FeedResult<List<Event>>> aircraft(City city) async {
    final r = await fetch(
      'planes_${city.name}',
      'https://api.adsb.lol/v2/point/${city.lat}/${city.lon}/100',
      const Duration(seconds: 15),
    );
    final rows = (jsonDecode(r.value)['ac'] ?? []) as List;
    final events = rows
        .where(
          (p) =>
              p['lat'] != null &&
              p['lon'] != null &&
              ((p['seen_pos'] ?? 9999) as num) < 120,
        )
        .map((p) {
          final seconds = ((p['seen_pos'] ?? 0) as num).round();
          final call = (p['flight'] ?? p['r'] ?? p['hex']).toString().trim();
          final direction = p['track'] ?? p['true_heading'];
          return Event(
            id: p['hex'].toString(),
            title: call.isEmpty ? p['hex'].toString() : call,
            description:
                'Emri/operatori: ${p['ownOp'] ?? 'i panjohur'}\nModeli: ${p['desc'] ?? p['t'] ?? 'i panjohur'}\nRegjistrimi: ${p['r'] ?? 'i panjohur'}\nLartësia: ${p['alt_baro'] ?? '—'} ft\nShpejtësia: ${p['gs'] ?? '—'} kn\nDrejtimi: ${direction ?? '—'}°\nPozicioni vjen nga marrës publikë ADS-B dhe mund të ketë boshllëqe.',
            source: 'ADSB.lol',
            url: 'https://globe.adsb.lol/?icao=${p['hex']}',
            kind: 'planes',
            point: LatLng(
              (p['lat'] as num).toDouble(),
              (p['lon'] as num).toDouble(),
            ),
            time: r.fetched.subtract(Duration(seconds: seconds)),
            heading: direction is num ? direction.toDouble() : null,
            speedKnots: p['gs'] is num ? (p['gs'] as num).toDouble() : null,
          );
        })
        .toList();
    return FeedResult(events, r.fetched, r.stale);
  }

  Future<FeedResult<AircraftRoute>> aircraftRoute(String callsign) async {
    final clean = callsign.trim().replaceAll(' ', '');
    if (clean.isEmpty) throw const FormatException('Pa kod fluturimi');
    final r = await fetch(
      'route_$clean',
      'https://api.adsbdb.com/v0/callsign/${Uri.encodeComponent(clean)}',
      const Duration(hours: 12),
    );
    final route = jsonDecode(r.value)['response']['flightroute'];
    final airline = route['airline'];
    final origin = route['origin'];
    final destination = route['destination'];
    return FeedResult(
      AircraftRoute(
        airline?['name']?.toString() ?? 'i panjohur',
        origin?['name']?.toString() ?? 'i panjohur',
        origin?['iata_code']?.toString() ??
            origin?['icao_code']?.toString() ??
            '—',
        destination?['name']?.toString() ?? 'i panjohur',
        destination?['iata_code']?.toString() ??
            destination?['icao_code']?.toString() ??
            '—',
      ),
      r.fetched,
      r.stale,
    );
  }

  Future<FeedResult<List<Event>>> activeFires() async {
    final fm = await fetch(
      'firemap_active_balkans',
      'https://geo.firemap.live/geoserver/ows?service=WFS&version=1.0.0&request=GetFeature&typeName=FireDB%3Amodis_ba_pt_7day&outputFormat=application%2Fjson&bbox=18,38.5,23.1,44.5,EPSG:4326',
      const Duration(minutes: 10),
    );
    final events = <Event>[];
    final fireRows = (jsonDecode(fm.value)['features'] ?? []) as List;
    for (final row in fireRows) {
      final coordinates = row['geometry']?['coordinates'];
      if (coordinates is! List || coordinates.length < 2) continue;
      final lon = (coordinates[0] as num).toDouble();
      final lat = (coordinates[1] as num).toDouble();
      final p = row['properties'] as Map<String, dynamic>;
      final hours = (p['lastupdate_hours'] as num?)?.round();
      final updated = hours == null
          ? DateTime.tryParse(p['datetimenow']?.toString() ?? '')
          : DateTime.now().toUtc().subtract(Duration(hours: hours));
      final status = normalize(p['fire_status']?.toString() ?? '');
      final age = updated == null
          ? null
          : DateTime.now().toUtc().difference(updated.toUtc());
      if (age == null ||
          age.isNegative ||
          age > const Duration(hours: 24) ||
          status.contains('extinguish') ||
          status.contains('shuar') ||
          status.contains('contained') ||
          status.contains('fikur')) {
        continue;
      }
      events.add(
        Event(
          id: 'firemap-${row['id']}',
          title: p['fire_name']?.toString().trim().isNotEmpty == true
              ? p['fire_name'].toString().trim()
              : 'Vatër termike e zbuluar',
          description:
              'Statusi: ${shqipStatus(p['fire_status'] ?? 'zbulim satelitor')}\nSipërfaqja: ${p['size_ha'] ?? '—'} ha\nZbulime satelitore në 24 orë: ${p['heatsigsatellite_returns_24hrs'] ?? '—'}\nRreziku meteorologjik: ${shqipStatus(p['fwi_daily'])}\nNdezja e mundshme: ${p['ignition_date'] ?? '—'}\nNjë pikë termike nuk është gjithmonë zjarr i konfirmuar.',
          source: 'FireMap.live · NASA FIRMS',
          url: 'https://firemap.live/?lng=$lon&lat=$lat&zoom=11',
          kind: 'fire',
          point: LatLng(lat, lon),
          time: updated,
        ),
      );
    }
    return FeedResult(events, fm.fetched, fm.stale);
  }

  Future<FeedResult<List<Event>>> hazards() async {
    final to = DateTime.now().toUtc(),
        from = to.subtract(const Duration(days: 90));
    String d(DateTime x) => x.toIso8601String().substring(0, 10);
    final url =
        'https://www.gdacs.org/gdacsapi/api/events/geteventlist/SEARCH?eventlist=FL%3BWF%3BTC%3BVO&fromdate=${d(from)}&todate=${d(to)}&alertlevel=green%3Borange%3Bred';
    final events = <Event>[];
    var fetched = DateTime.now();
    var stale = false;
    const kinds = {'WF': 'fire', 'TC': 'storm', 'FL': 'flood', 'VO': 'volcano'};
    try {
      final r = await fetch('gdacs_hazards', url, const Duration(minutes: 30));
      fetched = r.fetched;
      stale = r.stale;
      final rows = (jsonDecode(r.value)['features'] ?? []) as List;
      for (final row in rows) {
        final c = row['geometry']?['coordinates'];
        if (c is! List || c.length < 2) continue;
        final lon = (c[0] as num).toDouble(), lat = (c[1] as num).toDouble();
        if (lat < 38.5 || lat > 44.5 || lon < 18 || lon > 23.1) continue;
        final p = row['properties'];
        final type = p['eventtype'].toString();
        final start = DateTime.tryParse(p['fromdate']?.toString() ?? '');
        if (type == 'WF' &&
            (start == null ||
                DateTime.now().toUtc().difference(start.toUtc()) >
                    const Duration(hours: 24))) {
          continue;
        }
        final report = p['url'] is Map ? p['url']['report'] : '';
        final severity = shqipStatus(
          p['severitydata']?['severitytext'] ?? 'Pa hollësi',
        );
        events.add(
          Event(
            id: 'GDACS-${p['eventid']}',
            title: p['name'] ?? p['description'] ?? 'Ngjarje natyrore',
            description:
                'Lloji: ${const {'WF': 'zjarr pyjor', 'TC': 'ciklon/stuhi', 'FL': 'përmbytje', 'VO': 'vullkan'}[type] ?? type}\nNiveli: ${shqipStatus(p['alertlevel'])}\nAshpërsia: $severity\nVendi: ${p['country'] ?? 'rajoni'}\nStatusi dhe pozicioni vijnë nga GDACS.',
            source: 'GDACS',
            url: report?.toString() ?? 'https://www.gdacs.org/',
            kind: kinds[type] ?? 'hazards',
            point: LatLng(lat, lon),
            time: start,
          ),
        );
      }
    } catch (_) {}
    try {
      final ak = await news('AKMC', 'https://akmc.gov.al/feed/');
      for (final e in ak.value.where((x) {
        final t = normalize(x.title);
        return [
          'zjarr',
          'permbyt',
          'stuhi',
          'emergjenc',
          'reshje',
        ].any(t.contains);
      })) {
        if (normalize(e.title).contains('zjarr')) {
          final age = e.time == null
              ? null
              : DateTime.now().toUtc().difference(e.time!.toUtc());
          final text = normalize('${e.title} ${e.description}');
          if (age == null ||
              age.isNegative ||
              age > const Duration(hours: 24) ||
              text.contains('shuar') ||
              text.contains('fikur')) {
            continue;
          }
        }
        final c = matchCity(e.title);
        if (c != null) {
          events.add(
            Event(
              id: 'akmc-${e.id}',
              title: e.title,
              description: 'Raportim i Agjencisë Kombëtare të Mbrojtjes Civile.\nPika është qendra e qytetit të përmendur.\nLexoni njoftimin origjinal për udhëzimet e plota.',
              source: 'AKMC',
              url: e.url,
              kind: normalize(e.title).contains('zjarr')
                  ? 'fire'
                  : normalize(e.title).contains('stuhi')
                  ? 'storm'
                  : normalize(e.title).contains('permbyt')
                  ? 'flood'
                  : 'hazards',
              point: c.point,
              time: e.time,
              approximate: true,
            ),
          );
        }
      }
    } catch (_) {}
    return FeedResult(events, fetched, stale);
  }

  Future<FeedResult<RadarLayer>> radar() async {
    final r = await fetch(
      'rainviewer_frames',
      'https://api.rainviewer.com/public/weather-maps.json',
      const Duration(minutes: 5),
    );
    final json = jsonDecode(r.value) as Map<String, dynamic>;
    final frames = (json['radar']?['past'] ?? []) as List;
    if (frames.isEmpty) throw const FormatException('Pa radar');
    final frame = frames.last;
    return FeedResult(
      RadarLayer(
        '${json['host']}${frame['path']}/256/{z}/{x}/{y}/2/1_1.png',
        DateTime.fromMillisecondsSinceEpoch(
          (frame['time'] as num).round() * 1000,
          isUtc: true,
        ),
      ),
      r.fetched,
      r.stale,
    );
  }

  Future<FeedResult<List<Event>>> cameras() async {
    final events = <Event>[
      const Event(
        id: 'cam-vlora-live',
        title: 'Vlorë · gjiri dhe Lungomare live',
        description: 'Lloji: transmetim publik 24/7\nPamja: gjiri, Lungomare, porti dhe Sazani\nKamera: PTZ 4K\nHapet te faqja zyrtare e transmetimit.',
        source: 'Vlora LIVE',
        url: 'https://vlora.live/',
        kind: 'cameras',
        point: LatLng(40.446, 19.493),
        approximate: true,
      ),
      const Event(
        id: 'cam-durres-skyline',
        title: 'Durrës · plazhi live',
        description: 'Lloji: kamera publike live\nPamja: plazhi dhe bregdeti i Durrësit\nPlatforma: SkylineWebcams\nHapet te faqja origjinale e kamerës.',
        source: 'SkylineWebcams',
        url: 'https://www.skylinewebcams.com/en/webcam/albania/durres/durres/durres-beach.html',
        kind: 'cameras',
        point: LatLng(41.306, 19.493),
        approximate: true,
      ),
      const Event(
        id: 'cam-bestrove-skyline',
        title: 'Bestrovë · panoramë mbi Vlorë live',
        description: 'Lloji: kamera publike live\nPamja: panorama nga Kisha e Shën Todorit\nPlatforma: SkylineWebcams\nHapet te faqja origjinale e kamerës.',
        source: 'SkylineWebcams',
        url: 'https://www.skylinewebcams.com/en/webcam/albania/valona/valona/bestrove.html',
        kind: 'cameras',
        point: LatLng(40.493, 19.486),
        approximate: true,
      ),
      const Event(
        id: 'cam-border-kufiri-live',
        title: 'Kamera live të kufijve të Ballkanit',
        description: 'Lloji: kamera publike kufitare\nMbulimi: Kosovë, Ballkan dhe Evropë\nHapet katalogu i transmetimeve origjinale sipas pikës kufitare.',
        source: 'Kufiri.LIVE',
        url: 'https://kufiri.live/',
        kind: 'cameras',
        point: LatLng(42.946, 21.274),
        approximate: true,
      ),
      const Event(
        id: 'cam-me-bozaj',
        title: 'Bozhaj · kamera zyrtare kufitare',
        description: 'Pika: Bozhaj – Hani i Hotit\nPamja: hyrja dhe dalja në kufirin Mal i Zi–Shqipëri\nBurimi: Ministria e Brendshme e Malit të Zi\nHapet faqja zyrtare me video të përditësuara. Pamja nuk është matje e kohës së pritjes.',
        source: 'Ministria e Brendshme · Mali i Zi',
        url: 'http://kamere.mup.gov.me/kamere.php?kamere=Bozaj&lang=en',
        kind: 'cameras',
        point: LatLng(42.32966, 19.41883),
      ),
      const Event(
        id: 'cam-me-sukobin',
        title: 'Sukobinë · kamera zyrtare kufitare',
        description: 'Pika: Sukobinë – Muriqan\nPamja: hyrja dhe dalja në kufirin Mal i Zi–Shqipëri\nBurimi: Ministria e Brendshme e Malit të Zi\nHapet faqja zyrtare me video të përditësuara. Pamja nuk është matje e kohës së pritjes.',
        source: 'Ministria e Brendshme · Mali i Zi',
        url: 'http://kamere.mup.gov.me/kamere.php?kamere=Sukobin&lang=en',
        kind: 'cameras',
        point: LatLng(42.01637, 19.37055),
      ),
      const Event(
        id: 'cam-mk-official-roads',
        title: 'Kamerat zyrtare rrugore · Maqedonia e Veriut',
        description: 'Burimi: Ndërmarrja Publike për Rrugët Shtetërore\nPamja: hartë me kamera në rrugët shtetërore\nHapet harta zyrtare në shqip. Shenja këtu tregon hyrjen te katalogu, jo vendin e një kamere të vetme.',
        source: 'Ndërmarrja Publike për Rrugët Shtetërore',
        url: 'https://roads.org.mk/sq/rrjeti-rrugor/kamerat-mbikeqyrese/',
        kind: 'cameras',
        point: LatLng(41.9981, 21.4254),
        approximate: true,
      ),
      const Event(
        id: 'cam-mk-popova-sapka',
        title: 'Kodra e Diellit · kamera panoramike',
        description: 'Zona: Kodra e Diellit, Tetovë\nPamja: kushtet në qendrën malore\nHapet te transmetuesi origjinal; disponueshmëria mund të ndryshojë.',
        source: 'SkylineWebcams',
        url: 'https://www.skylinewebcams.com/en/webcam/north-macedonia/polog/tetovo/popova-sapka.html',
        kind: 'cameras',
        point: LatLng(42.0168, 20.8844),
        approximate: true,
      ),
      const Event(
        id: 'cam-mk-ohrid-lake',
        title: 'Ohër · Liqeni i Ohrit live',
        description: 'Zona: Ohër, Maqedonia e Veriut\nPamja: Liqeni i Ohrit\nPlatforma: SkylineWebcams\nHapet te faqja origjinale e kamerës; pamja mund të mos jetë gjithmonë e disponueshme.',
        source: 'SkylineWebcams',
        url: 'https://www.skylinewebcams.com/en/webcam/north-macedonia/southwestern/ohrid/lake.html',
        kind: 'cameras',
        point: LatLng(41.117, 20.802),
        approximate: true,
      ),
    ];
    var fetched = DateTime.now();
    var stale = false;

    for (final country in const [
      (slug: 'albania', name: 'Shqipëri', pages: 1),
      (slug: 'kosovo', name: 'Kosovë', pages: 2),
      (slug: 'north-macedonia', name: 'Maqedonia e Veriut', pages: 1),
      (slug: 'montenegro', name: 'Mali i Zi', pages: 1),
    ]) {
      for (var page = 1; page <= country.pages; page++) {
        try {
          final result = await fetch(
            'opencctv_${country.slug}_$page',
            'https://opencctv.org/cameras/${country.slug}${page == 1 ? '' : '?page=$page'}',
            const Duration(minutes: 30),
            allowHtml: true,
          );
          stale = stale || result.stale;
          events.addAll(
            parseOpenCctvCameras(
              result.value,
              country: country.name,
              fetched: result.fetched,
            ),
          );
        } catch (_) {
          // Other country catalogs and official links remain available.
        }
      }
    }
    try {
      final result = await fetch(
        'gjirafa_slow_tv',
        'https://video-swp.gjirafa.com/slow-tv-2-2',
        const Duration(minutes: 10),
        allowHtml: true,
      );
      stale = stale || result.stale;
      final links = RegExp(
        r'href=([^\s>]+)[^>]*title="(SlowTV[^"]+)"',
        caseSensitive: false,
      ).allMatches(result.value);
      LatLng pointFor(String title) {
        final value = normalize(title);
        if (value.contains('brezovic')) return const LatLng(42.178, 21.035);
        if (value.contains('batllav')) return const LatLng(42.818, 21.325);
        if (value.contains('brod')) return const LatLng(41.992, 20.706);
        if (value.contains('decan')) return const LatLng(42.540, 20.288);
        if (value.contains('ferizaj')) return const LatLng(42.370, 21.148);
        if (value.contains('fushe kosov')) return const LatLng(42.637, 21.096);
        if (value.contains('gjilan')) return const LatLng(42.463, 21.469);
        if (value.contains('gjakov')) return const LatLng(42.380, 20.431);
        if (value.contains('prizren')) return const LatLng(42.214, 20.740);
        if (value.contains('vermic')) return const LatLng(42.163, 20.559);
        return const LatLng(42.663, 21.166);
      }

      for (final link in links) {
        final path = link.group(1)!;
        final title = _cleanArticleText(link.group(2)!);
        if (path.isEmpty || title.isEmpty) continue;
        events.add(
          Event(
            id: 'gjirafa-${normalize(path)}',
            title: title,
            description: 'Lloji: transmetim publik live\nPlatforma: GjirafaVideo SlowTV\nZona është vendosur sipas emrit të transmetimit. Hapet faqja origjinale e kamerës.',
            source: 'GjirafaVideo · SlowTV',
            url: 'https://video-swp.gjirafa.com$path',
            kind: 'cameras',
            point: pointFor(title),
            time: result.fetched,
            approximate: true,
          ),
        );
      }
    } catch (_) {
      // The other verified public camera catalogs remain available.
    }
    final unique = <String>{};
    events.removeWhere((event) => !unique.add(event.id));
    return FeedResult(events, fetched, stale);
  }

  static List<Event> parseOpenCctvCameras(
    String html, {
    required String country,
    required DateTime fetched,
  }) {
    final events = <Event>[];
    final scripts = RegExp(
      r'<script[^>]+type="application/ld\+json"[^>]*>([\s\S]*?)</script>',
      caseSensitive: false,
    ).allMatches(html);
    for (final script in scripts) {
      try {
        final decoded = jsonDecode(script.group(1)!) as Map<String, dynamic>;
        if (decoded['@type'] != 'ItemList') continue;
        for (final entry in (decoded['itemListElement'] as List? ?? const [])) {
          if (entry is! Map) continue;
          final item = entry['item'];
          if (item is! Map) continue;
          final location = item['contentLocation'];
          if (location is! Map) continue;
          final geo = location['geo'];
          if (geo is! Map) continue;
          final lat = (geo['latitude'] as num?)?.toDouble();
          final lon = (geo['longitude'] as num?)?.toDouble();
          final path = '${item['url'] ?? ''}';
          if (lat == null || lon == null || path.isEmpty) continue;
          // Country pages sometimes contain cameras across a nearby border.
          final inCountry = switch (country) {
            'Shqipëri' =>
              lat >= 39.6 &&
                  lat <= 42.7 &&
                  lon >= 19.2 &&
                  lon <= 21.1 &&
                  !(lat < 39.9 && lon < 19.9),
            'Kosovë' =>
              lat >= 41.8 && lat <= 43.3 && lon >= 20.0 && lon <= 21.9,
            'Maqedonia e Veriut' =>
              lat >= 40.8 && lat <= 42.4 && lon >= 20.4 && lon <= 23.1,
            'Mali i Zi' =>
              lat >= 41.7 && lat <= 43.6 && lon >= 18.4 && lon <= 20.4,
            _ => false,
          };
          if (!inCountry) continue;
          final url = path.startsWith('https://opencctv.org/')
              ? path
              : path.startsWith('/')
              ? 'https://opencctv.org$path'
              : '';
          if (url.isEmpty) continue;
          events.add(
            Event(
              id: 'opencctv-${Uri.parse(url).pathSegments.last}',
              title: '${item['name'] ?? 'Kamera publike'}',
              description:
                  'Lloji: kamera publike e kataloguar\nVendi: $country\nZona: ${location['name'] ?? country}\nKoordinata: ${lat.toStringAsFixed(5)}, ${lon.toStringAsFixed(5)}\nHapet te faqja e kamerës; burimi tregon nëse pamja është aktualisht e disponueshme.',
              source: 'OpenCCTV · katalog publik',
              url: url,
              kind: 'cameras',
              point: LatLng(lat, lon),
              time: fetched,
            ),
          );
        }
      } catch (_) {
        // Ignore malformed metadata and keep other camera listings.
      }
    }
    return events;
  }

  List<Event> ships() => const [
    Event(
      id: 'ships-durres',
      title: 'Anije pranë Portit të Durrësit',
      description: 'Shërbimi: harta zyrtare detare\nPozicionet e anijeve hapen te burimi.',
      source: 'Albanian Marine Traffic',
      url: 'https://vesselsdata.gov.al/',
      kind: 'ships',
      point: LatLng(41.3034, 19.4576),
      approximate: true,
    ),
    Event(
      id: 'ships-vlore',
      title: 'Anije pranë Portit të Vlorës',
      description: 'Shërbimi: harta zyrtare detare\nPozicionet e anijeve hapen te burimi.',
      source: 'Albanian Marine Traffic',
      url: 'https://vesselsdata.gov.al/',
      kind: 'ships',
      point: LatLng(40.4515, 19.4837),
      approximate: true,
    ),
    Event(
      id: 'ships-shengjin',
      title: 'Anije pranë Portit të Shëngjinit',
      description: 'Shërbimi: harta zyrtare detare\nPozicionet e anijeve hapen te burimi.',
      source: 'Albanian Marine Traffic',
      url: 'https://vesselsdata.gov.al/',
      kind: 'ships',
      point: LatLng(41.8085, 19.5930),
      approximate: true,
    ),
    Event(
      id: 'ships-sarande',
      title: 'Anije pranë Portit të Sarandës',
      description: 'Shërbimi: harta zyrtare detare\nPozicionet e anijeve hapen te burimi.',
      source: 'Albanian Marine Traffic',
      url: 'https://vesselsdata.gov.al/',
      kind: 'ships',
      point: LatLng(39.8690, 20.0040),
      approximate: true,
    ),
    Event(
      id: 'ships-bar-me',
      title: 'Porti i Tivarit (Bar)',
      description: 'Port tregtar dhe pasagjerësh në Malin e Zi. Kontrollo njoftimet dhe shërbimet në faqen zyrtare; kjo pikë nuk gjurmon anije live.',
      source: 'Luka Bar',
      url: 'https://lukabar.me/en/',
      kind: 'ships',
      point: LatLng(42.0813, 19.0853),
      approximate: true,
    ),
    Event(
      id: 'ships-kotor-me',
      title: 'Porti i Kotorrit',
      description: 'Port pasagjerësh në Gjirin e Kotorrit. Orari dhe njoftimet kontrollohen te autoriteti përkatës; kjo pikë nuk gjurmon anije live.',
      source: 'Ministria e Detarisë · Mali i Zi',
      url:
          'https://www.gov.me/mpo/direktorat-za-pomorsku-i-unutrasnju-plovidbu',
      kind: 'ships',
      point: LatLng(42.4247, 18.7701),
      approximate: true,
    ),
    Event(
      id: 'ships-ferry-kamenari-me',
      title: 'Trageti Kamenari–Lepetane',
      description: 'Lidhje trageti në Gjirin e Kotorrit. Biletat dhe informacioni i linjës hapen te operatori; kjo pikë nuk është pozicion live i tragetit.',
      source: 'Trajekt Kamenari–Lepetane',
      url: 'https://trajekt.me/',
      kind: 'ships',
      point: LatLng(42.4605, 18.6749),
      approximate: true,
    ),
  ];

  List<Event> regionalProtectedAreas(Set<String> countries) => [
    for (final entry
        in const <
          ({
            String country,
            String id,
            String name,
            double lat,
            double lon,
            String source,
            String url,
          })
        >[
          (
            country: 'Kosovë',
            id: 'sharri-xk',
            name: 'Parku Kombëtar Sharri',
            lat: 42.185,
            lon: 20.965,
            source: 'AMMK · Kosovë',
            url: 'https://ammk-rks.net/assets/cms/uploads/files/Publikime-raporte//Raporti_Natyra_Eng.pdf',
          ),
          (
            country: 'Kosovë',
            id: 'bjeshket-xk',
            name: 'Parku Kombëtar Bjeshkët e Nemuna',
            lat: 42.665,
            lon: 20.180,
            source: 'AMMK · Kosovë',
            url: 'https://ammk-rks.net/assets/cms/uploads/files/Publikime-raporte//Raporti_Natyra_Eng.pdf',
          ),
          (
            country: 'Maqedonia e Veriut',
            id: 'shar-mk',
            name: 'Parku Kombëtar Mali Sharr',
            lat: 42.045,
            lon: 20.785,
            source: 'MMJPH · Maqedonia e Veriut',
            url: 'https://www.moepp.gov.mk/mk-MK/odnosi-so-javnost/novosti/xodza-i-vo-2026-obezbedivme-sredstva-za-nacionalnite-parkovi-koi-se-klucen-stolb-vo-zastitata-na-prirodnoto-nasledstvo',
          ),
          (
            country: 'Maqedonia e Veriut',
            id: 'mavrovo-mk',
            name: 'Parku Kombëtar Mavrovë',
            lat: 41.700,
            lon: 20.660,
            source: 'MMJPH · Maqedonia e Veriut',
            url: 'https://www.moepp.gov.mk/mk-MK/odnosi-so-javnost/novosti/xodza-i-vo-2026-obezbedivme-sredstva-za-nacionalnite-parkovi-koi-se-klucen-stolb-vo-zastitata-na-prirodnoto-nasledstvo',
          ),
          (
            country: 'Maqedonia e Veriut',
            id: 'galicica-mk',
            name: 'Parku Kombëtar Galiçicë',
            lat: 40.967,
            lon: 20.846,
            source: 'MMJPH · Maqedonia e Veriut',
            url: 'https://www.moepp.gov.mk/mk-MK/odnosi-so-javnost/novosti/xodza-i-vo-2026-obezbedivme-sredstva-za-nacionalnite-parkovi-koi-se-klucen-stolb-vo-zastitata-na-prirodnoto-nasledstvo',
          ),
          (
            country: 'Maqedonia e Veriut',
            id: 'pelister-mk',
            name: 'Parku Kombëtar Pelister',
            lat: 41.003,
            lon: 21.176,
            source: 'MMJPH · Maqedonia e Veriut',
            url: 'https://www.moepp.gov.mk/mk-MK/odnosi-so-javnost/novosti/xodza-i-vo-2026-obezbedivme-sredstva-za-nacionalnite-parkovi-koi-se-klucen-stolb-vo-zastitata-na-prirodnoto-nasledstvo',
          ),
          (
            country: 'Mali i Zi',
            id: 'durmitor-me',
            name: 'Parku Kombëtar Durmitor',
            lat: 43.110,
            lon: 19.000,
            source: 'Nacionalni parkovi Crne Gore',
            url: 'https://nparkovi.me/edukativni-kutak',
          ),
          (
            country: 'Mali i Zi',
            id: 'biogradska-me',
            name: 'Parku Kombëtar Biogradska Gora',
            lat: 42.900,
            lon: 19.602,
            source: 'Nacionalni parkovi Crne Gore',
            url: 'https://nparkovi.me/edukativni-kutak',
          ),
          (
            country: 'Mali i Zi',
            id: 'lovcen-me',
            name: 'Parku Kombëtar Lovćen',
            lat: 42.398,
            lon: 18.842,
            source: 'Nacionalni parkovi Crne Gore',
            url: 'https://nparkovi.me/edukativni-kutak',
          ),
          (
            country: 'Mali i Zi',
            id: 'skadar-me',
            name: 'Parku Kombëtar Liqeni i Shkodrës',
            lat: 42.307,
            lon: 19.172,
            source: 'Nacionalni parkovi Crne Gore',
            url: 'https://nparkovi.me/edukativni-kutak',
          ),
          (
            country: 'Mali i Zi',
            id: 'prokletije-me',
            name: 'Parku Kombëtar Bjeshkët e Nemuna',
            lat: 42.532,
            lon: 19.770,
            source: 'Nacionalni parkovi Crne Gore',
            url: 'https://nparkovi.me/edukativni-kutak',
          ),
        ])
      if (countries.contains(entry.country))
        Event(
          id: 'protected-${entry.id}',
          title: entry.name,
          description:
              'Vendi: ${entry.country}\nLloji: park kombëtar\nShenja tregon afërsisht qendrën e parkut, jo kufirin zyrtar. Hap burimin për hollësi.',
          source: entry.source,
          url: entry.url,
          kind: 'protected',
          point: LatLng(entry.lat, entry.lon),
          approximate: true,
        ),
  ];

  Future<FeedResult<List<Event>>> montenegroBathingWater() async {
    final year = DateTime.now().year;
    final rounds = await fetch(
      'morsko_calendar_$year',
      'https://monitoring.morskodobro.me/javna/getCalendarData',
      const Duration(hours: 12),
      formBody: {'godina': '$year'},
    );
    final calendar = jsonDecode(rounds.value) as Map<String, dynamic>;
    final choices = (calendar['data'] as List?) ?? const [];
    final latest = choices.cast<Map<String, dynamic>>().where(
      (item) =>
          int.tryParse('${item['id']}') != null &&
          int.parse('${item['id']}') > 0,
    );
    if (latest.isEmpty) return FeedResult([], rounds.fetched, rounds.stale);
    final round = '${latest.first['id']}';
    final r = await fetch(
      'morsko_map_${year}_$round',
      'https://monitoring.morskodobro.me/javna/crtajMapu',
      const Duration(hours: 12),
      formBody: {'godina': '$year', 'rb': round, 'opstina': '0', 'q': ''},
    );
    return FeedResult(
      parseMontenegroBathingWater(r.value, year: year, round: round),
      r.fetched,
      rounds.stale || r.stale,
    );
  }

  Future<FeedResult<List<Event>>> borderCrossings() async {
    final r = await fetch(
      'kosovo_border_flow',
      'https://mpb.rks-gov.net/?culture=sq-al',
      const Duration(minutes: 3),
      allowHtml: true,
    );
    const points = <String, LatLng>{
      'bernjak': LatLng(42.959, 20.474),
      'dheu i bardhe': LatLng(42.552, 21.588),
      'glloboqice': LatLng(42.160, 21.166),
      'hani i elezit': LatLng(42.150, 21.296),
      'jarinje': LatLng(43.155, 20.704),
      'kulle': LatLng(42.665, 20.169),
      'merdare': LatLng(42.946, 21.274),
      'mucibabe': LatLng(42.489, 21.735),
      'mutivode': LatLng(42.821, 21.478),
      'qafe e morines': LatLng(42.479, 20.286),
      'qafe e prushit': LatLng(42.356, 20.331),
      'stanciq': LatLng(42.516, 21.700),
      'vermice': LatLng(42.163, 20.559),
    };
    final table = RegExp(
      r'<table id="fluksi-tabela"[\s\S]*?</table>',
      caseSensitive: false,
    ).firstMatch(r.value)?.group(0);
    if (table == null) throw const FormatException('Pa tabelën e kufirit');
    final events = <Event>[];
    for (final row in RegExp(
      r'<tr[^>]*>([\s\S]*?)</tr>',
      caseSensitive: false,
    ).allMatches(table)) {
      final cells = RegExp(r'<td[^>]*>([\s\S]*?)</td>', caseSensitive: false)
          .allMatches(row.group(1)!)
          .map((m) => _cleanArticleText(m.group(1)!))
          .toList();
      if (cells.length < 9) continue;
      final name = cells.first;
      final point = points[normalize(name)];
      if (point == null) continue;
      int waitMinutes(String value) =>
          RegExp(r'\d+')
              .allMatches(value)
              .map((match) => int.tryParse(match.group(0)!) ?? 0)
              .fold(0, math.max);
      final longestWait = [
        cells[1],
        cells[2],
        cells[5],
        cells[6],
      ].map(waitMinutes).fold(0, math.max);
      final longestQueue = [
        cells[3],
        cells[4],
        cells[7],
        cells[8],
      ].map(waitMinutes).fold(0, math.max);
      if (longestWait <= 5 && longestQueue == 0) continue;
      final status = longestWait >= 30 || longestQueue >= 500
          ? 'Vonesë e madhe'
          : 'Ka pritje';
      String queueLabel(int metres) => metres >= 1000
          ? '${(metres / 1000).toStringAsFixed(1)} km'
          : '$metres m';
      final headline = <String>[
        if (longestWait > 0) '$longestWait min',
        if (longestQueue > 0) queueLabel(longestQueue),
      ].join(' · ');
      final facts = <String>[
        'Gjendja: $status',
        if (longestWait > 0) 'Pritja më e gjatë: $longestWait minuta',
        if (longestQueue > 0) 'Radha më e gjatë: ${queueLabel(longestQueue)}',
        if (waitMinutes(cells[1]) > 0) 'Automjete në hyrje: ${cells[1]} minuta',
        if (waitMinutes(cells[2]) > 0) 'Automjete në dalje: ${cells[2]} minuta',
        if (waitMinutes(cells[5]) > 0) 'Kamionë në hyrje: ${cells[5]} minuta',
        if (waitMinutes(cells[6]) > 0) 'Kamionë në dalje: ${cells[6]} minuta',
        'Përditësuar: ${dateLabel(r.fetched)}',
      ];
      events.add(
        Event(
          id: 'border-${normalize(name)}',
          title: '$name · $headline',
          description: facts.join('\n'),
          source: 'MPB Kosovë · QKMK',
          url: 'https://mpb.rks-gov.net/?culture=sq-al',
          kind: 'borders',
          point: point,
          time: r.fetched,
        ),
      );
    }
    return FeedResult(events, r.fetched, r.stale);
  }

  /// Published lake assessments share the bathing-water layer and legend.
  /// Kosovo has no regular published bathing-water classification yet.
  List<Event> inlandBathingWater(Set<String> countries) {
    const macedoniaReport =
        'https://iph.mk/Upload/Editor_Upload/%D0%98%D0%B7%D0%B2%D0%B5%D1%88%D1%82%D0%B0%D1%98%20%D0%B7%D0%B0%20%D0%BA%D0%B2%D0%B0%D0%BB%D0%B8%D1%82%D0%B5%D1%82%20%D0%BD%D0%B0%20%D0%BF%D1%80%D0%B8%D1%80%D0%BE%D0%B4%D0%BD%D0%B8%20%D0%B5%D0%B7%D0%B5%D1%80%D0%B0,%20%D1%81%D0%B5%D0%B7%D0%BE%D0%BD%D0%B0%20%D0%BD%D0%B0%20%D0%BA%D0%B0%D0%BF%D0%B5%D1%9A%D0%B5%202025_FINAL_21_7_2025.pdf';
    const kosovoReport =
        'https://mmphi.rks-gov.net/MMPHIFolder/OtherDocuments/SHQIP_Raporti_SWMI_9-Mars-2026.pdf';
    final events = <Event>[];
    if (countries.contains('Maqedonia e Veriut')) {
      events.add(
        Event(
          id: 'ohrid-water-2026',
          title: 'Liqeni i Ohrit · Matje të ndryshme',
          description: 'Cilësia e ujit: ndryshon sipas plazhit\nLiqeni: Ohër\nMostrat: qershor 2026, 11 vende matjeje\nRezultati: 8 vende klasa I, 2 vende klasa II dhe plazhi Grashnicë klasa III. Sipas komunës, larja lejohet në klasat I dhe II. Kjo pikë shënon liqenin afërsisht, jo çdo plazh veçmas.',
          source: 'Komuna e Ohrit · Qendra e Shëndetit Publik',
          url: 'https://ohrid.gov.mk/%D0%B2%D0%BE%D0%B4%D0%B0%D1%82%D0%B0-%D0%B2%D0%BE-%D0%BE%D1%85%D1%80%D0%B8%D0%B4%D1%81%D0%BA%D0%BE%D1%82%D0%BE-%D0%B5%D0%B7%D0%B5%D1%80%D0%BE-%D0%B5-%D0%B1%D0%B5%D0%B7%D0%B1%D0%B5%D0%B4%D0%BD%D0%B0/',
          kind: 'water',
          point: LatLng(41.112, 20.797),
          time: DateTime(2026, 6, 25),
          approximate: true,
        ),
      );
      for (final item in const [
        ('Liqeni i Prespës', 40.981, 21.071, 'E shkëlqyer', '13.06.2025'),
        ('Liqeni i Dojranit', 41.186, 22.722, 'E mirë', '20.06.2025'),
      ]) {
        events.add(
          Event(
            id: 'iph-lake-${item.$1}',
            title: '${item.$1} · ${item.$4}',
            description:
                'Cilësia e ujit: ${item.$4}\nLiqeni: ${item.$1}\nMostra: ${item.$5}\nVlerësim i një pike monitorimi në raportin zyrtar 2025; pozicioni në hartë është i përafërt. Nuk është matje e sotme dhe nuk përshkruan të gjithë liqenin.',
            source: 'Instituti i Shëndetit Publik · Maqedonia e Veriut',
            url: macedoniaReport,
            kind: 'water',
            point: LatLng(item.$2, item.$3),
            time: DateTime(2025, 6, item.$5 == '20.06.2025' ? 20 : 13),
            approximate: true,
          ),
        );
      }
    }
    if (countries.contains('Kosovë')) {
      for (final item in const [
        ('Liqeni i Badovcit', 42.623, 21.316),
        ('Liqeni i Radoniqit', 42.491, 20.416),
        ('Liqeni i Ujmanit', 42.963, 20.568),
      ]) {
        events.add(
          Event(
            id: 'kosovo-lake-${item.$1}',
            title: '${item.$1} · Pa matje publike',
            description:
                'Cilësia e ujit: pa klasifikim të verifikuar për larje\nLiqeni: ${item.$1}\nMostra: nuk ka rezultat sistematik publik. Raporti qeveritar i marsit 2026 thotë se Kosova nuk ka regjistër të ujërave të larjes dhe monitorimi mikrobiologjik është i parregullt. Pika shënon liqenin, jo një stacion matjeje. Mos e interpreto ngjyrën gri si vlerësim sigurie.',
            source: 'MMPHI · Raporti i ujërave 2026',
            url: kosovoReport,
            kind: 'water',
            point: LatLng(item.$2, item.$3),
            approximate: true,
          ),
        );
      }
    }
    return events;
  }

  Future<FeedResult<List<Event>>> kosovoRiverLevels() async {
    final r = await fetch(
      'ihmk_kosovo_river_levels_v1',
      'https://ihmk-rks.net/?page=1%2C41',
      const Duration(minutes: 30),
      allowHtml: true,
    );
    return FeedResult(parseKosovoRiverLevels(r.value), r.fetched, r.stale);
  }

  static List<Event> parseKosovoRiverLevels(String html, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final events = <Event>[];
    final tables = RegExp(
      r'<table[^>]*class="dsp"[^>]*>(.*?)</table>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(html);
    for (final table in tables) {
      final block = table.group(1)!;
      final coordinates = RegExp(
        r'maps/place/(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)',
        caseSensitive: false,
      ).firstMatch(block);
      final stationMatch = RegExp(
        r'alt="location"\s*/?>([^<]+)</a>',
        caseSensitive: false,
      ).firstMatch(block);
      final cells =
          RegExp(
                r'<td[^>]*class="center"[^>]*>(.*?)</td>',
                caseSensitive: false,
                dotAll: true,
              )
              .allMatches(block)
              .map((match) => _cleanArticleText(match.group(1)!))
              .toList();
      if (coordinates == null || stationMatch == null || cells.length < 12) {
        continue;
      }
      final row = cells.sublist(cells.length - 6);
      final river = row[0].trim();
      final level = _numberFromText(row[2]);
      final change = _numberFromText(row[3]);
      final measured = _parseIhmkDate(row[5]);
      if (level == null || measured == null) continue;
      final age = reference.difference(measured);
      if (age.isNegative && age.inHours.abs() > 6) continue;
      if (age > const Duration(hours: 72)) continue;
      final station = _cleanArticleText(stationMatch.group(1)!);
      final trend = change == null || change.abs() < .01
          ? 'i qëndrueshëm'
          : change > 0
          ? 'në rritje'
          : 'në ulje';
      final changeLabel = change == null
          ? 'e papublikuar'
          : '${change > 0 ? '+' : ''}${change.toStringAsFixed(2)} cm';
      events.add(
        Event(
          id: 'ihmk-${normalize(station)}-${measured.millisecondsSinceEpoch}',
          title:
              '${river.isEmpty ? station : river} · ${level.toStringAsFixed(1)} cm',
          description:
              'Stacioni: $station\nLumi: ${river.isEmpty ? 'i papërcaktuar' : river}\nNiveli: ${level.toStringAsFixed(2)} cm\nNdryshimi: $changeLabel\nTendenca: $trend\nMatja: ${dateLabel(measured)}\nRifreskimi i deklaruar: çdo 4 orë\nBurimi: Instituti Hidrometeorologjik i Kosovës',
          summary: 'Niveli është $trend krahasuar me matjen paraprake.',
          source: 'IHMK Kosovë',
          url: 'https://ihmk-rks.net/?page=1%2C41',
          kind: 'river-level',
          point: LatLng(
            double.parse(coordinates.group(1)!),
            double.parse(coordinates.group(2)!),
          ),
          time: measured,
        ),
      );
    }
    events.sort((a, b) => b.time!.compareTo(a.time!));
    return events.take(40).toList();
  }

  Future<FeedResult<List<Event>>> tiranaAirportFlights() async {
    final r = await fetch(
      'tirana_airport_flights_v1',
      'https://tirana-airport.com/en',
      const Duration(minutes: 5),
      allowHtml: true,
    );
    return FeedResult(
      parseTiranaAirportFlights(r.value, fetched: r.fetched),
      r.fetched,
      r.stale,
    );
  }

  List<Event> regionalAirports(Set<String> countries) => [
    for (final airport
        in const <(String, String, String, String, double, double, String)>[
          (
            'Shqipëri',
            'TIA',
            'Aeroporti Ndërkombëtar i Tiranës',
            'Aeroporti i Tiranës',
            41.4147,
            19.7206,
            'https://tirana-airport.com/en',
          ),
          (
            'Kosovë',
            'PRN',
            'Aeroporti Ndërkombëtar i Prishtinës',
            'Limak Kosovo',
            42.5728,
            21.0358,
            'https://www.limakkosovo.aero/',
          ),
          (
            'Maqedonia e Veriut',
            'SKP',
            'Aeroporti Ndërkombëtar i Shkupit',
            'TAV Macedonia',
            41.9616,
            21.6214,
            'https://skp.airports.com.mk/en-EN/flights',
          ),
          (
            'Maqedonia e Veriut',
            'OHD',
            'Aeroporti i Ohrit',
            'TAV Macedonia',
            41.18,
            20.7423,
            'https://ohd.airports.com.mk/en-EN/flights',
          ),
          (
            'Mali i Zi',
            'TGD',
            'Aeroporti i Podgoricës',
            'Aerodromi Crne Gore',
            42.3594,
            19.2519,
            'https://montenegroairports.com/en/aerodrom-podgorica/',
          ),
          (
            'Mali i Zi',
            'TIV',
            'Aeroporti i Tivatit',
            'Aerodromi Crne Gore',
            42.4047,
            18.7233,
            'https://montenegroairports.com/en/tivat-airport/',
          ),
        ])
      if (countries.contains(airport.$1))
        Event(
          id: 'airport-directory-${airport.$2.toLowerCase()}',
          title: '${airport.$3} · ${airport.$2}',
          description:
              'Vendi: ${airport.$1}\nKodi IATA: ${airport.$2}\nOrari dhe statusi i fluturimeve shihen në faqen zyrtare. Kjo pikë shënon aeroportin, jo një fluturim live.',
          source: airport.$4,
          url: airport.$7,
          kind: 'airport-info',
          point: LatLng(airport.$5, airport.$6),
          approximate: true,
        ),
  ];

  static List<Event> parseTiranaAirportFlights(
    String html, {
    required DateTime fetched,
  }) {
    const airport = LatLng(41.4147, 19.7206);
    final arrivalStart = html.indexOf('<ul id="arrival-container">');
    final departureStart = html.indexOf('<ul id="departure-container">');
    if (arrivalStart < 0 || departureStart <= arrivalStart) return const [];
    final departureEnd = html.indexOf(
      'serach-flights-container-home',
      departureStart,
    );
    final events = <Event>[];

    void parseSection(String section, {required bool arrival}) {
      final flights = RegExp(
        r'<a\s+href="([^"]*/flight/[^"]+)"[^>]*>\s*<ul>(.*?)</ul>\s*</a>',
        caseSensitive: false,
        dotAll: true,
      ).allMatches(section);
      for (final flight in flights.take(6)) {
        final cells =
            RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true)
                .allMatches(flight.group(2)!)
                .map((match) => _cleanArticleText(match.group(1)!))
                .where((value) => value.isNotEmpty)
                .take(5)
                .toList();
        if (cells.length < 5) continue;
        final hour = cells[0];
        final place = cells[1];
        final airline = cells[2];
        final flightNumber = cells[3];
        final status = shqipFlightStatus(cells[4]);
        final relativeUrl = flight.group(1)!;
        events.add(
          Event(
            id: 'tia-${arrival ? 'arrival' : 'departure'}-$relativeUrl',
            title: '${arrival ? 'Mbërritje' : 'Nisje'} $flightNumber · $place',
            description:
                'Ora e planifikuar: $hour\nGjendja: $status\n${arrival ? 'Nga' : 'Për'}: $place\nKompania: $airline\nFluturimi: $flightNumber\nAeroporti: Tiranë · Nënë Tereza\nLloji: ${arrival ? 'mbërritje' : 'nisje'}\nKontrolluar: ${dateLabel(fetched)}',
            summary: '$flightNumber · $status · ora $hour',
            source: 'Aeroporti i Tiranës',
            url: relativeUrl.startsWith('http')
                ? relativeUrl
                : 'https://tirana-airport.com$relativeUrl',
            kind: arrival ? 'airport-arrival' : 'airport-departure',
            point: airport,
            time: fetched,
          ),
        );
      }
    }

    parseSection(html.substring(arrivalStart, departureStart), arrival: true);
    parseSection(
      html.substring(
        departureStart,
        departureEnd > departureStart ? departureEnd : html.length,
      ),
      arrival: false,
    );
    return events;
  }

  static double? _numberFromText(String value) {
    final match = RegExp(r'-?\d+(?:[.,]\d+)?').firstMatch(value);
    return match == null
        ? null
        : double.tryParse(match.group(0)!.replaceAll(',', '.'));
  }

  static DateTime? _parseIhmkDate(String value) {
    final match = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})\s+(\d{1,2}):(\d{2})$')
        .firstMatch(value.trim());
    if (match == null) return null;
    return DateTime(
      int.parse(match.group(3)!),
      int.parse(match.group(2)!),
      int.parse(match.group(1)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
    );
  }

  Future<FeedResult<List<Event>>> roadAlerts() async {
    final r = await news('ARRSH', 'https://www.arrsh.gov.al/feed/');
    final events = <Event>[];
    final cutoff = DateTime.now().subtract(const Duration(hours: 48));
    for (final item in r.value) {
      if (item.time == null || item.time!.isBefore(cutoff)) continue;
      final place = matchCity('${item.title} ${item.summary ?? ''}');
      if (place == null) continue;
      events.add(
        Event(
          id: 'road-${item.id}',
          title: item.title,
          description:
              'Zona: ${place.name}\nNjoftim për gjendjen, punimet ose kufizimet e rrugës.\nKontrolloni burimin për orarin dhe devijimin e plotë.',
          summary: item.summary,
          source: 'ARRSH',
          url: item.url,
          kind: 'roadwork',
          point: place.point,
          time: item.time,
          approximate: true,
        ),
      );
    }
    return FeedResult(events, r.fetched, r.stale);
  }

  Future<FeedResult<List<Event>>> utilityAlerts(City city) async {
    final code = countryCodeFor(city);
    final query = Uri.encodeQueryComponent(
      '"${city.name}" (OSHEE OR KEDS OR EVN OR CEDIS OR ujësjellës OR KRU OR vodovod) (ndërprerje OR "pa energji" OR "pa ujë" OR defekt OR prekid) when:2d',
    );
    final r = await fetch(
      'utility_alerts_${city.name}_$code',
      'https://news.google.com/rss/search?q=$query&hl=sq&gl=$code&ceid=$code:sq',
      const Duration(minutes: 10),
    );
    final cutoff = DateTime.now().subtract(const Duration(hours: 48));
    final alerts =
        parseNews(
              r.value,
              'Google News',
              fallbackPoint: city.point,
              fallbackPlace: city.name,
            )
            .where((item) {
              if (item.time == null || item.time!.isBefore(cutoff)) {
                return false;
              }
              final text = normalize('${item.title} ${item.summary ?? ''}');
              final hasUtility = const [
                'oshee',
                'keds',
                'evn',
                'cedis',
                'ujesjelles',
                'ujesjellesi',
                'kru ',
              ].any(text.contains);
              final hasInterruption = const [
                'nderprer',
                'pa energji',
                'pa uje',
                'mungese uji',
                'defekt',
                'stakim',
                'prekid',
              ].any(text.contains);
              return hasUtility && hasInterruption;
            })
            .take(12);
    return FeedResult(
      alerts.map((item) {
        final text = normalize('${item.title} ${item.summary ?? ''}');
        final water =
            text.contains('ujesjelles') ||
            text.contains('pa uje') ||
            text.contains('mungese uji') ||
            text.contains('kru ');
        return Event(
          id: 'utility-${item.id}',
          title: item.title,
          description:
              'Shërbimi: ${water ? 'ujësjellës/kanalizime' : 'energji elektrike'}\nZona: ${city.name}\nPublikuar: ${dateLabel(item.time!)}\nBurimi: ${item.source}\nPika tregon qendrën e zonës së përmendur. Hapni njoftimin për rrugët dhe orarin e saktë.',
          summary: item.summary,
          source: item.source,
          url: item.url,
          kind: water ? 'water-outage' : 'power-outage',
          point: item.point,
          time: item.time,
          approximate: true,
        );
      }).toList(),
      r.fetched,
      r.stale,
    );
  }

  Future<FeedResult<List<Event>>> trafficCongestion(City city) async {
    final code = countryCodeFor(city);
    final query = Uri.encodeQueryComponent(
      '"${city.name}" ("trafik i rënduar" OR kolonë OR bllokim OR "radhë kilometrike") when:1d',
    );
    final r = await fetch(
      'traffic_reports_${city.name}_$code',
      'https://news.google.com/rss/search?q=$query&hl=sq&gl=$code&ceid=$code:sq',
      const Duration(minutes: 5),
    );
    final cutoff = DateTime.now().subtract(const Duration(hours: 12));
    final reports =
        parseNews(
              r.value,
              'Google News',
              fallbackPoint: city.point,
              fallbackPlace: city.name,
            )
            .where((item) {
              final text = normalize('${item.title} ${item.summary ?? ''}');
              final explicit = const [
                'trafik i renduar',
                'trafik te renduar',
                'kolone',
                'kolona',
                'bllokim',
                'radhe kilometrike',
                'vonesa ne trafik',
                'qarkullim i renduar',
              ].any(text.contains);
              return explicit &&
                  item.time != null &&
                  item.time!.isAfter(cutoff);
            })
            .take(8);
    return FeedResult(
      reports
          .map(
            (item) => Event(
              id: 'traffic-${item.id}',
              title: item.title,
              description:
                  'Gjendja: trafik i rënduar i raportuar\nZona: ${city.name}\nRaportuar: ${dateLabel(item.time!)}\nBurimi: ${item.source}\nPozicioni është i përafërt; trekëndëshi shfaqet vetëm për raportime të 12 orëve të fundit që përmendin qartë kolonë, bllokim ose trafik të rënduar.',
              summary: item.summary,
              source: item.source,
              url: item.url,
              kind: 'traffic-jam',
              point: item.point,
              time: item.time,
              approximate: true,
            ),
          )
          .toList(),
      r.fetched,
      r.stale,
    );
  }

  Future<FeedResult<List<Event>>> speedCameras(City city) async {
    final query =
        '''[out:json][timeout:25];(nwr(around:90000,${city.lat},${city.lon})[highway=speed_camera];nwr(around:90000,${city.lat},${city.lon})[enforcement=maxspeed];);out center meta 300;''';
    FeedResult<String>? response;
    Object? lastError;
    for (final endpoint in const [
      'https://overpass-api.de/api/interpreter',
      'https://overpass.kumi.systems/api/interpreter',
      'https://overpass.private.coffee/api/interpreter',
    ]) {
      try {
        response = await fetch(
          'speed_cameras_${city.name}',
          '$endpoint?data=${Uri.encodeQueryComponent(query)}',
          const Duration(days: 7),
        );
        break;
      } catch (error) {
        lastError = error;
      }
    }
    if (response == null) {
      throw lastError ?? Exception('Burimi Overpass nuk u arrit.');
    }
    final r = response;
    final rows = (jsonDecode(r.value)['elements'] ?? []) as List;
    final events = <Event>[];
    for (final row in rows) {
      final lat = (row['lat'] ?? row['center']?['lat']) as num?;
      final lon = (row['lon'] ?? row['center']?['lon']) as num?;
      if (lat == null || lon == null) continue;
      final tags = (row['tags'] ?? {}) as Map<String, dynamic>;
      final limit = tags['maxspeed']?.toString().trim();
      final direction = tags['direction']?.toString().trim();
      final operatorName = tags['operator']?.toString().trim();
      final road = tags['addr:street']?.toString().trim();
      final title = tags['name']?.toString().trim();
      events.add(
        Event(
          id: 'speed-camera-${row['type']}-${row['id']}',
          title: title?.isNotEmpty == true
              ? title!
              : road?.isNotEmpty == true
              ? 'Kamerë shpejtësie · $road'
              : 'Kamerë fikse shpejtësie',
          description: [
            'Lloji: kamerë fikse e hartëzuar',
            if (limit?.isNotEmpty == true) 'Kufiri i shpejtësisë: $limit km/h',
            if (direction?.isNotEmpty == true) 'Drejtimi: $direction',
            if (operatorName?.isNotEmpty == true) 'Operatori: $operatorName',
            if (road?.isNotEmpty == true) 'Rruga: $road',
            'Burimi: kontribuesit e OpenStreetMap',
            'Pika tregon një instalim fiks të hartëzuar; verifikoni sinjalistikën në rrugë.',
          ].join('\n'),
          source: 'OpenStreetMap · Overpass',
          url: 'https://www.openstreetmap.org/${row['type']}/${row['id']}',
          kind: 'speed-camera',
          point: LatLng(lat.toDouble(), lon.toDouble()),
          time: DateTime.tryParse(row['timestamp']?.toString() ?? ''),
        ),
      );
    }
    return FeedResult(events, r.fetched, r.stale);
  }

  Future<FeedResult<List<Event>>> officialRoadSafetyNotices(City city) async {
    if (city.country != 'Shqipëri' && city.country != 'Kosovë') {
      return _recentPublicAlerts(
        city: city,
        key: 'official_road_safety',
        query:
            '"${city.name}" (${city.country}) (polici OR policija OR police OR radar OR bllokim OR blokada OR aksident) when:1d',
        kind: 'police-alert',
        description: 'Lloji: njoftim publik për sigurinë rrugore',
        maximumAge: const Duration(hours: 24),
        requiredTerms: const [
          'polic',
          'radar',
          'bllok',
          'blokad',
          'aksident',
          'soobrak',
        ],
      );
    }
    final kosovo = normalize(city.country).contains('kosov');
    final r = await news(
      kosovo ? 'Policia e Kosovës' : 'Policia e Shtetit',
      kosovo
          ? 'https://www.kosovopolice.com/feed/'
          : 'https://asp.gov.al/feed/',
    );
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final items = r.value
        .where((item) {
          if (item.time == null || item.time!.isBefore(cutoff)) {
            return false;
          }
          final text = normalize('${item.title} ${item.summary ?? ''}');
          final matched = matchCity('${item.title} ${item.summary ?? ''}');
          final relevantPlace = matched == null
              ? text.contains(normalize(city.name))
              : normalize(matched.name) == normalize(city.name);
          return relevantPlace &&
              const [
                'kontroll policor',
                'kontrolle policore',
                'policia rrugore',
                'radar',
                'bllokim rruge',
                'kufizim qarkullimi',
                'devijim',
              ].any(text.contains);
        })
        .take(12);
    return FeedResult(
      items
          .map(
            (item) => Event(
              id: 'official-road-safety-${item.id}',
              title: item.title,
              description:
                  'Lloji: njoftim zyrtar për sigurinë rrugore\nZona: ${city.name}\nPublikuar: ${dateLabel(item.time!)}\nPozicioni është i përafërt dhe nuk tregon vendndodhjen e një automjeti policie. Hapni burimin për rrugën dhe orarin e saktë.',
              summary: item.summary,
              source: item.source,
              url: item.url,
              kind: 'police-alert',
              point: item.point ?? city.point,
              time: item.time,
              approximate: true,
            ),
          )
          .toList(),
      r.fetched,
      r.stale,
    );
  }

  Future<FeedResult<List<Event>>> _recentPublicAlerts({
    required City city,
    required String key,
    required String query,
    required String kind,
    required String description,
    required Duration maximumAge,
    required List<String> requiredTerms,
  }) async {
    final code = countryCodeFor(city);
    final encoded = Uri.encodeQueryComponent(query);
    final r = await fetch(
      '${key}_${city.name}_$code',
      'https://news.google.com/rss/search?q=$encoded&hl=sq&gl=$code&ceid=$code:sq',
      const Duration(minutes: 15),
    );
    final cutoff = DateTime.now().subtract(maximumAge);
    final items =
        parseNews(
              r.value,
              'Google News',
              fallbackPoint: city.point,
              fallbackPlace: city.name,
            )
            .where((item) {
              if (item.time == null || item.time!.isBefore(cutoff)) {
                return false;
              }
              final text = normalize('${item.title} ${item.summary ?? ''}');
              return requiredTerms.any(text.contains);
            })
            .take(12);
    return FeedResult(
      items
          .map(
            (item) => Event(
              id: '$kind-${item.id}',
              title: item.title,
              description:
                  '$description\nZona e shfaqjes: ${city.name}\nPublikuar: ${dateLabel(item.time!)}\nBurimi: ${item.source}\nPika është e përafërt; kontrolloni njoftimin origjinal për zonën dhe udhëzimet e plota.',
              summary: item.summary,
              source: item.source,
              url: item.url,
              kind: kind,
              point: item.point,
              time: item.time,
              approximate: true,
            ),
          )
          .toList(),
      r.fetched,
      r.stale,
    );
  }

  Future<FeedResult<List<Event>>> healthAlerts(City city) =>
      _recentPublicAlerts(
        city: city,
        key: 'health_alerts',
        query: '(ISHP OR "Ministria e Shëndetësisë" OR IKSHPK) (alarm OR epidemiologjik OR virus OR epidemi OR helmim OR "rrezik shëndetësor") when:7d',
        kind: 'health-alert',
        description: 'Lloji: njoftim për shëndetin publik',
        maximumAge: const Duration(days: 7),
        requiredTerms: const [
          'alarm',
          'epidemi',
          'virus',
          'helmim',
          'rrezik shendetesor',
          'infeksion',
        ],
      );

  Future<FeedResult<List<Event>>> foodAlerts(City city) => _recentPublicAlerts(
    city: city,
    key: 'food_alerts',
    query: '(AKU OR AUVK OR RASFF) (alarm OR terheqje OR rrezik OR kontaminim OR produkt) when:7d',
    kind: 'food-alert',
    description: 'Lloji: alarm për sigurinë ushqimore ose produktin',
    maximumAge: const Duration(days: 7),
    requiredTerms: const ['alarm', 'terheq', 'rrezik', 'kontamin', 'produkt'],
  );

  Future<FeedResult<List<Event>>> portAlerts(City city) => _recentPublicAlerts(
    city: city,
    key: 'port_alerts',
    query:
        '"${city.name}" (port OR kapiteneri OR traget OR lundrim) (pezullim OR ndalim OR anulim OR vonesë OR stuhi) when:2d',
    kind: 'port-alert',
    description: 'Lloji: kufizim lundrimi, porti ose trageti',
    maximumAge: const Duration(hours: 48),
    requiredTerms: const [
      'pezull',
      'ndalim',
      'anulim',
      'vonese',
      'stuhi',
      'mbyll',
    ],
  );

  Future<FeedResult<List<Event>>> hydrologyAlerts(City city) =>
      _recentPublicAlerts(
        city: city,
        key: 'hydrology_alerts',
        query: '(KESH OR AMBU OR IGJEO OR IGJEUM) (prurje OR nivel OR përmbytje OR shkarkim OR rezervuar) when:2d',
        kind: 'hydrology-alert',
        description: 'Lloji: njoftim hidrologjik për lumenj ose rezervuarë',
        maximumAge: const Duration(hours: 48),
        requiredTerms: const [
          'prurje',
          'nivel',
          'permbyt',
          'shkarkim',
          'rezervuar',
        ],
      );

  Future<FeedResult<List<Event>>> civicAlerts(City city) => _recentPublicAlerts(
    city: city,
    key: 'civic_alerts',
    query:
        '"${city.name}" (bashkia OR komuna OR policia) (evakuim OR "mbyllje rruge" OR "rrugë e mbyllur" OR "shkollat mbyllen" OR emergjencë) when:2d',
    kind: 'civic-alert',
    description: 'Lloji: njoftim civil që ndikon shërbimet ose lëvizjen',
    maximumAge: const Duration(hours: 48),
    requiredTerms: const [
      'evaku',
      'mbyllje rruge',
      'rruge e mbyllur',
      'shkollat mbyllen',
      'emergjenc',
    ],
  );

  Future<FeedResult<List<Event>>> agricultureAlerts(City city) async {
    final r = await fetch(
      'agriculture_${city.lat}_${city.lon}',
      'https://api.open-meteo.com/v1/forecast?latitude=${city.lat}&longitude=${city.lon}&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,wind_gusts_10m_max,et0_fao_evapotranspiration&hourly=soil_moisture_0_to_1cm&timezone=auto&forecast_days=3',
      const Duration(minutes: 30),
    );
    final data = jsonDecode(r.value) as Map<String, dynamic>;
    final daily = data['daily'] as Map<String, dynamic>;
    final hourly = data['hourly'] as Map<String, dynamic>;
    double dailyValue(String key) {
      final values = daily[key] as List?;
      return values == null || values.isEmpty
          ? 0
          : (values.first as num?)?.toDouble() ?? 0;
    }

    final minimum = dailyValue('temperature_2m_min');
    final maximum = dailyValue('temperature_2m_max');
    final precipitation = dailyValue('precipitation_sum');
    final gust = dailyValue('wind_gusts_10m_max');
    final evapotranspiration = dailyValue('et0_fao_evapotranspiration');
    final soilValues = (hourly['soil_moisture_0_to_1cm'] as List? ?? const [])
        .whereType<num>()
        .take(24)
        .map((value) => value.toDouble())
        .toList();
    final soil = soilValues.isEmpty
        ? 0.0
        : soilValues.reduce((a, b) => a + b) / soilValues.length;
    final codes = daily['weather_code'] as List? ?? const [];
    final weatherCode = codes.isEmpty ? 0 : (codes.first as num).round();
    final dates = daily['time'] as List? ?? const [];
    final day = dates.isEmpty ? 'sot' : dates.first;
    final events = <Event>[];
    void add(String kind, String title, String details) => events.add(
      Event(
        id: 'agriculture-$kind-${city.name}-$day',
        title: '$title · ${city.name}',
        description:
            '$details\nTemperatura: ${minimum.toStringAsFixed(1)}–${maximum.toStringAsFixed(1)}°C\nReshje: ${precipitation.toStringAsFixed(1)} mm\nLagështia e tokës: ${soil.toStringAsFixed(2)} m³/m³\nErë maksimale: ${gust.toStringAsFixed(0)} km/h\nBurimi: Open-Meteo',
        source: 'Open-Meteo Agriculture',
        url: 'https://open-meteo.com/en/docs',
        kind: kind,
        point: city.point,
        time: r.fetched,
        approximate: true,
      ),
    );
    add(
      'agriculture-info',
      'Kushtet bujqësore',
      'Përmbledhje e kushteve të sotme për tokën, kulturat dhe punët në terren.',
    );
    if (minimum <= 2) {
      add(
        'frost',
        'Rrezik ngrice',
        'Minimumi i parashikuar mund të dëmtojë bimët e ndjeshme.',
      );
    }
    if (maximum >= 36) {
      add(
        'heat',
        'Vapë e fortë',
        'Temperatura e lartë rrit stresin për bimët dhe kafshët.',
      );
    }
    if (gust >= 60) {
      add(
        'wind',
        'Erë e fortë',
        'Rafalet mund të dëmtojnë sera, pemë dhe kultura.',
      );
    }
    if (weatherCode == 96 || weatherCode == 99) {
      add(
        'hail',
        'Rrezik breshëri',
        'Kodi i motit parashikon stuhi me mundësi breshëri.',
      );
    }
    if (soil > 0 &&
        soil < .15 &&
        precipitation < 1 &&
        evapotranspiration >= 3) {
      add(
        'drought',
        'Tokë e thatë',
        'Lagështia sipërfaqësore është e ulët dhe avullimi i pritshëm është i lartë.',
      );
    }
    return FeedResult(events, r.fetched, r.stale);
  }

  Future<FeedResult<List<Event>>> nearbyServices(City city) async {
    final query =
        '''[out:json][timeout:20];(
node(around:18000,${city.lat},${city.lon})[amenity~"hospital|clinic|pharmacy|police|fire_station|charging_station|parking|drinking_water|toilets"];
way(around:18000,${city.lat},${city.lon})[amenity~"hospital|clinic|pharmacy|police|fire_station|charging_station|parking"];
node(around:18000,${city.lat},${city.lon})[emergency=defibrillator];
);out center 140;''';
    return _overpassEvents(
      'services_${city.name}',
      query,
      city,
      defaultKind: 'services',
    );
  }

  Future<FeedResult<List<Event>>> nearbyPlaces(City city) async {
    final box =
        '${city.lat - .26},${city.lon - .33},${city.lat + .26},${city.lon + .33}';
    final query =
        '''[out:json][timeout:20];(
nwr($box)[tourism~"museum|attraction|viewpoint|camp_site|information"];
node($box)[natural=cave_entrance];
nwr($box)[historic][name];
);out center 160;''';
    return _overpassEvents(
      'places_${city.name}',
      query,
      city,
      defaultKind: 'places',
    );
  }

  Future<FeedResult<List<Event>>> protectedAreas(City city) async {
    final box =
        '${city.lat - .42},${city.lon - .55},${city.lat + .42},${city.lon + .55}';
    final query =
        '''[out:json][timeout:20];(
nwr($box)[boundary=protected_area][name];
nwr($box)[leisure=nature_reserve][name];
);out center 120;''';
    return _overpassEvents(
      'protected_${city.name}',
      query,
      city,
      defaultKind: 'protected',
    );
  }

  Future<FeedResult<List<Event>>> biodiversityObservations(
    Set<String> countries, {
    Duration requestPause = const Duration(milliseconds: 200),
  }) async {
    const codes = <String, String>{
      'Shqipëri': 'AL',
      'Kosovë': 'XK',
      'Maqedonia e Veriut': 'MK',
      'Mali i Zi': 'ME',
    };
    final events = <Event>[];
    var fetched = DateTime.now();
    var stale = false;
    var requestIndex = 0;
    for (final country in countries) {
      final code = codes[country];
      if (code == null) continue;
      for (final (taxonKey, expectedKingdom) in const [
        (6, 'Plantae'),
        (1, 'Animalia'),
      ]) {
        if (requestIndex++ > 0 && requestPause > Duration.zero) {
          await Future.delayed(requestPause);
        }
        try {
          final result = await fetch(
            'gbif_biodiversity_${code}_${taxonKey}_v2',
            'https://api.gbif.org/v1/occurrence/search?country=$code&taxonKey=$taxonKey&hasCoordinate=true&occurrenceStatus=PRESENT&license=CC_BY_4_0&year=${DateTime.now().year - 6},${DateTime.now().year}&limit=16',
            const Duration(days: 7),
          );
          fetched = result.fetched;
          stale = stale || result.stale;
          final rows = (jsonDecode(result.value)['results'] ?? []) as List;
          for (final raw in rows) {
            if (raw is! Map<String, dynamic>) continue;
            final lat = raw['decimalLatitude'];
            final lon = raw['decimalLongitude'];
            final key = raw['key'];
            if (lat is! num || lon is! num || key == null) continue;
            final kingdom = raw['kingdom']?.toString() ?? '';
            if (kingdom != expectedKingdom) continue;
            final flora = kingdom == 'Plantae';
            final name = raw['scientificName']?.toString().trim() ?? '';
            if (name.isEmpty) continue;
            final observed = raw['eventDate']?.toString() ?? '';
            events.add(
              Event(
                id: 'gbif-$key',
                title: name,
                description:
                    'Vendi: $country\nGrupi: ${flora ? 'florë' : 'faunë'}\nRegjistruar: ${observed.isEmpty ? 'datë e papërcaktuar' : observed}\nKjo është pikë e një regjistrimi historik, jo vendndodhje live e një kafshe ose bime.\nLicenca: CC BY 4.0; hollësitë dhe autorët gjenden te burimi.',
                source: 'GBIF · të dhëna të hapura',
                url: 'https://www.gbif.org/occurrence/$key',
                kind: flora ? 'biodiversity-flora' : 'biodiversity-fauna',
                point: LatLng(lat.toDouble(), lon.toDouble()),
                time: DateTime.tryParse(observed),
              ),
            );
          }
        } catch (_) {
          stale = true;
        }
      }
    }
    if (events.isEmpty && countries.isNotEmpty) {
      throw StateError('Nuk u morën regjistrime nga GBIF.');
    }
    return FeedResult(events, fetched, stale);
  }

  Future<FeedResult<List<Event>>> nearbyEnvironment(City city) async {
    final localBox =
        '${city.lat - .17},${city.lon - .22},${city.lat + .17},${city.lon + .22}';
    final natureBox =
        '${city.lat - .32},${city.lon - .42},${city.lat + .32},${city.lon + .42}';
    final query =
        '''[out:json][timeout:20];(
node($localBox)[amenity~"recycling|drinking_water"];
node($localBox)[amenity=waste_disposal][name];
nwr($localBox)[man_made~"wastewater_plant|monitoring_station"];
nwr($localBox)[landuse=landfill];
nwr($natureBox)[leisure=nature_reserve];
node($localBox)[natural=spring];
);out center 180;''';
    final base = await _overpassEvents(
      'environment_${city.name}',
      query,
      city,
      defaultKind: 'environment',
    );
    final events = [...base.value];
    var stale = base.stale;
    try {
      final air = await airQuality(city);
      stale = stale || air.stale;
      events.insert(
        0,
        Event(
          id: 'environment-air-${normalize(city.name)}',
          title: '${air.value.label} · ${city.name}',
          description:
              'Indeksi evropian AQI: ${air.value.europeanAqi.round()}\nPM2.5: ${air.value.pm25.toStringAsFixed(1)} μg/m³\nPM10: ${air.value.pm10.toStringAsFixed(1)} μg/m³\nPluhur: ${air.value.dust.toStringAsFixed(1)} μg/m³\nIndeksi UV: ${air.value.uv.toStringAsFixed(1)}\nPërditësuar: ${dateLabel(air.value.time)}\nVlerat janë model rajonal dhe jo domosdoshmërisht sensor lokal.',
          source: 'Open-Meteo · CAMS',
          url: 'https://open-meteo.com/en/docs/air-quality-api',
          kind: 'environment',
          point: city.point,
          time: air.value.time,
          approximate: true,
        ),
      );
    } catch (_) {
      // Keep the mapped environmental infrastructure when AQI is unavailable.
    }
    return FeedResult(events, base.fetched, stale);
  }

  Future<FeedResult<List<Event>>> drinkingWater(City city) async {
    final box =
        '${city.lat - .17},${city.lon - .22},${city.lat + .17},${city.lon + .22}';
    final query =
        '''[out:json][timeout:20];(
node($box)[amenity=drinking_water];
node($box)[natural=spring][drinking_water=yes];
);out center 180;''';
    return _overpassEvents(
      'drinking_water_${city.name}',
      query,
      city,
      defaultKind: 'drinking-water',
    );
  }

  Future<FeedResult<List<Event>>> _overpassEvents(
    String key,
    String query,
    City city, {
    required String defaultKind,
    bool fallbackServers = false,
  }) async {
    FeedResult<String>? r;
    Object? lastError;
    final hosts = fallbackServers
        ? const [
            'https://overpass-api.de/api/interpreter',
            'https://overpass.kumi.systems/api/interpreter',
            'https://overpass.private.coffee/api/interpreter',
          ]
        : const ['https://overpass-api.de/api/interpreter'];
    for (final host in hosts) {
      try {
        final result = await fetch(
          key,
          '$host?data=${Uri.encodeQueryComponent(query)}',
          const Duration(hours: 12),
          forceRefresh: r?.stale == true,
          requestTimeout: fallbackServers
              ? const Duration(seconds: 8)
              : const Duration(seconds: 20),
        );
        r = result;
        if (!result.stale) break;
      } catch (error) {
        lastError = error;
      }
    }
    if (r == null) throw lastError ?? Exception('Overpass unavailable');
    final rows = (jsonDecode(r.value)['elements'] ?? []) as List;
    final events = <Event>[];
    for (final row in rows) {
      final tags = (row['tags'] ?? {}) as Map<String, dynamic>;
      final lat = (row['lat'] ?? row['center']?['lat']) as num?;
      final lon = (row['lon'] ?? row['center']?['lon']) as num?;
      if (lat == null || lon == null) continue;
      final amenity = tags['amenity']?.toString() ?? '';
      final tourism = tags['tourism']?.toString() ?? '';
      final kind = amenity == 'hospital' || amenity == 'clinic'
          ? 'health'
          : amenity == 'pharmacy'
          ? 'pharmacy'
          : amenity == 'police'
          ? 'police'
          : amenity == 'fire_station'
          ? 'fire_station'
          : amenity == 'charging_station'
          ? 'charging'
          : amenity == 'parking'
          ? 'parking'
          : tags['emergency'] == 'defibrillator'
          ? 'aed'
          : tourism.isNotEmpty
          ? 'places'
          : defaultKind == 'environment'
          ? 'environment'
          : defaultKind;
      final type = amenity.isNotEmpty
          ? amenity
          : tourism.isNotEmpty
          ? tourism
          : tags['highway'] == 'bus_stop'
          ? 'bus_stop'
          : tags['monitoring:air_quality'] == 'yes'
          ? 'air_monitoring'
          : tags['man_made']?.toString().isNotEmpty == true
          ? tags['man_made'].toString()
          : tags['landuse'] == 'landfill'
          ? 'landfill'
          : tags['leisure'] == 'nature_reserve'
          ? 'nature_reserve'
          : tags['natural'] == 'spring'
          ? 'spring'
          : tags['natural'] == 'cave_entrance'
          ? 'cave_entrance'
          : tags['historic']?.toString().isNotEmpty == true
          ? tags['historic'].toString()
          : tags['boundary'] == 'protected_area'
          ? 'protected_area'
          : tags['protect_class']?.toString() ?? 'zonë e mbrojtur';
      final name = tags['name:SQ'] ?? tags['name:sq'] ?? tags['name'];
      final recyclingMaterials = tags.entries
          .where(
            (entry) =>
                entry.key.startsWith('recycling:') && entry.value == 'yes',
          )
          .map(
            (entry) =>
                entry.key.substring('recycling:'.length).replaceAll('_', ' '),
          )
          .take(6)
          .join(', ');
      final facts = <String>[
        'Lloji: ${_serviceLabel(type)}',
        'Zona: ${city.name}',
        if (recyclingMaterials.isNotEmpty) 'Materialet: $recyclingMaterials',
        if (tags['recycling_type']?.toString().trim().isNotEmpty == true)
          'Forma e pikës: ${tags['recycling_type']}',
        if (tags['protect_class']?.toString().trim().isNotEmpty == true)
          'Klasa e mbrojtjes: ${tags['protect_class']}',
        if (tags['monitoring:air_quality'] == 'yes')
          'Monitorimi: cilësia e ajrit',
        if (tags['monitoring:water_quality'] == 'yes')
          'Monitorimi: cilësia e ujit',
        if (tags['drinking_water']?.toString().trim().isNotEmpty == true)
          'Ujë i pijshëm: ${tags['drinking_water'] == 'yes' ? 'po' : tags['drinking_water']}',
        if (tags['description']?.toString().trim().isNotEmpty == true)
          'Përshkrimi: ${tags['description']}',
        if (tags['opening_hours']?.toString().trim().isNotEmpty == true)
          'Orari: ${tags['opening_hours']}',
        if (tags['operator']?.toString().trim().isNotEmpty == true)
          'Operatori: ${tags['operator']}',
        if (tags['fee']?.toString().trim().isNotEmpty == true)
          'Pagesë: ${tags['fee']}',
        if (tags['access']?.toString().trim().isNotEmpty == true)
          'Aksesi: ${tags['access']}',
        if (tags['addr:street']?.toString().trim().isNotEmpty == true)
          'Adresa: ${tags['addr:street']}${tags['addr:housenumber'] == null ? '' : ' ${tags['addr:housenumber']}'}',
        if (tags['website']?.toString().trim().isNotEmpty == true)
          'Faqja: ${tags['website']}',
        'Të dhënat vijnë nga kontribuesit e OpenStreetMap; verifikoni hollësitë në burim.',
      ];
      events.add(
        Event(
          id: 'osm-${row['type']}-${row['id']}',
          title: name?.toString().trim().isNotEmpty == true
              ? name.toString()
              : _serviceLabel(type),
          description: facts.join('\n'),
          source: 'OpenStreetMap',
          url: 'https://www.openstreetmap.org/${row['type']}/${row['id']}',
          kind: kind,
          point: LatLng(lat.toDouble(), lon.toDouble()),
        ),
      );
    }
    return FeedResult(events, r.fetched, r.stale);
  }

  Future<FeedResult<List<Event>>> transit(City city) async {
    if (normalize(city.name) == 'tirane') {
      final r = await fetch(
        'tirana_transit_stops',
        'https://ckan.tirana.al/dataset/1424f2b9-96d8-406a-b1c6-9abbb473f9d2/resource/38432a57-3968-4ef0-830a-877e235c1fcd/download/linjat_e_autobus_ve_publik__dhe_stacionet.geojson.txt',
        const Duration(days: 7),
      );
      final rows = (jsonDecode(r.value)['features'] ?? []) as List;
      final events = <Event>[];
      final seen = <String>{};
      for (final row in rows) {
        final c = row['geometry']?['coordinates'];
        if (row['geometry']?['type'] != 'Point' || c is! List || c.length < 2) {
          continue;
        }
        final key = '${c[1].toStringAsFixed(5)},${c[0].toStringAsFixed(5)}';
        if (!seen.add(key) || events.length >= 140) continue;
        final p = row['properties'] ?? {};
        final name = p['RRUGA']?.toString().trim();
        events.add(
          Event(
            id: 'tirana-stop-$key',
            title: name?.isNotEmpty == true
                ? 'Stacion · $name'
                : 'Stacion autobusi',
            description: 'Transport: stacion urban\nQyteti: Tiranë\nPozicioni vjen nga të dhënat e hapura të Bashkisë Tiranë; nuk përmban mbërritje live.',
            source: 'Bashkia Tiranë · Open Data',
            url: 'https://ckan.tirana.al/tr/dataset/tranporti-publik-ne-tirane-i-gjeoreferencuar',
            kind: 'transit',
            point: LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
          ),
        );
      }
      events.insert(0, _eTransportEvent(city));
      return FeedResult(events, r.fetched, r.stale);
    }
    final query =
        '''[out:json][timeout:20];(
node(around:12000,${city.lat},${city.lon})[highway=bus_stop];
nwr(around:12000,${city.lat},${city.lon})[amenity=bus_station];
);out center 100;''';
    final base = await _overpassEvents(
      'transit_v2_${city.name}',
      query,
      city,
      defaultKind: 'transit',
      fallbackServers: true,
    );
    if (city.country != 'Shqipëri') return base;
    return FeedResult(
      [_eTransportEvent(city), ...base.value],
      base.fetched,
      base.stale,
    );
  }

  Event _eTransportEvent(City city) => Event(
    id: 'etransport-${normalize(city.name)}',
    title: 'Oraret ndërqytetëse · ${city.name}',
    description:
        'Shërbimi: transport ndërqytetës\nNisja: ${city.name}\nInformacioni: linja, operatorë dhe orare të planifikuara\nGjendja: hapet platforma zyrtare eTransport\nShënim: orari nuk paraqitet si mbërritje live në SYRI.',
    source: 'eTransport Shqipëri',
    url: 'https://www.etransport.al/',
    kind: 'transit',
    point: city.point,
    approximate: true,
  );

  Future<FeedResult<List<Event>>> copernicusEvents() async {
    final r = await fetch(
      'copernicus_activations',
      'https://rapidmapping.emergency.copernicus.eu/backend/dashboard-api/public-activations-info/?limit=250',
      const Duration(hours: 1),
    );
    final rows = (jsonDecode(r.value)['results'] ?? []) as List;
    final events = <Event>[];
    for (final row in rows) {
      final countries = ((row['countries'] ?? []) as List)
          .map((x) => normalize(x.toString()))
          .toList();
      if (!countries.any(
        (x) =>
            x.contains('alban') ||
            x.contains('kosov') ||
            x.contains('macedon') ||
            x.contains('montenegro'),
      )) {
        continue;
      }
      final pointMatch = RegExp(r'POINT \(([-0-9.]+) ([-0-9.]+)\)')
          .firstMatch(row['centroid']?.toString() ?? '');
      if (pointMatch == null) continue;
      events.add(
        Event(
          id: 'cems-${row['code']}',
          title: row['name']?.toString() ?? 'Hartë emergjence',
          description:
              'Kategoria: ${row['category'] ?? '—'}\nKodi: ${row['code']}\nZona të analizuara: ${row['n_aois'] ?? '—'}\nProdukte hartografike: ${row['n_products'] ?? '—'}\nStatusi: ${row['closed'] == true ? 'mbyllur' : 'aktiv'}',
          source: 'Copernicus EMS',
          url:
              'https://mapping.emergency.copernicus.eu/activations/${row['code']}',
          kind: 'cems',
          point: LatLng(
            double.parse(pointMatch.group(2)!),
            double.parse(pointMatch.group(1)!),
          ),
          time: DateTime.tryParse(row['eventTime']?.toString() ?? ''),
        ),
      );
    }
    return FeedResult(events, r.fetched, r.stale);
  }

  Future<FeedResult<List<Event>>> bathingWaterQuality() async {
    final r = await fetch(
      'eea_bathing_water_albania',
      "https://water.discomap.eea.europa.eu/arcgis/rest/services/BathingWater/BathingWater_Dyna_WM/MapServer/0/query?where=countryCode%3D%27AL%27&outFields=bathingWaterName,qualityStatus,longitude,latitude,bwWaterCategory&returnGeometry=true&outSR=4326&f=geojson",
      const Duration(days: 7),
    );
    final rows = (jsonDecode(r.value)['features'] ?? []) as List;
    String quality(String value) =>
        const {
          'Excellent': 'E shkëlqyer',
          'Good': 'E mirë',
          'Sufficient': 'E mjaftueshme',
          'Poor': 'E dobët',
          'Not classified': 'E paklasifikuar',
        }[value] ??
        value;
    final events = <Event>[];
    for (final row in rows) {
      final p = row['properties'] as Map<String, dynamic>;
      final c = row['geometry']?['coordinates'];
      if (c is! List || c.length < 2) continue;
      final status = quality(
        p['qualityStatus']?.toString() ?? 'E paklasifikuar',
      );
      final name = p['bathingWaterName']?.toString().trim() ?? 'Zonë larjeje';
      events.add(
        Event(
          id: 'eea-water-${row['id'] ?? '${c[1]}-${c[0]}'}',
          title: '$name · $status',
          description:
              'Cilësia e ujit: $status\nZona: $name\nLloji: ${p['bwWaterCategory'] == 'Coastal' ? 'ujë bregdetar' : 'ujë i brendshëm'}\nTreguesit: E. coli dhe enterokoket intestinale\nViti: klasifikimi 2025 i publikuar nga EEA\nKjo është pikë monitorimi, jo vlerësim i të gjithë bregdetit. Nuk është matje në kohë reale.',
          source: 'Agjencia Evropiane e Mjedisit · EEA',
          url: 'https://www.eea.europa.eu/en/analysis/maps-and-charts/state-of-bathing-waters-in-2025',
          kind: 'water',
          point: LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
          // EEA's annual grade has no single sample timestamp.
        ),
      );
    }
    return FeedResult(events, r.fetched, r.stale);
  }

  List<Event> environmentalMonitoring() => const [
    Event(
      id: 'water-velipoje',
      title: 'Monitorimi i ujit · Velipojë',
      description: 'Monitorim: ujë larës bregdetar\nFreskia: sezonale/vjetore\nShikoni burimin për klasifikimin dhe datën e mostrës.',
      source: 'AKM',
      url: 'https://akm.gov.al/bregdeti/',
      kind: 'water',
      point: LatLng(41.858, 19.421),
    ),
    Event(
      id: 'water-shengjin',
      title: 'Monitorimi i ujit · Shëngjin',
      description: 'Monitorim: ujë larës bregdetar\nFreskia: sezonale/vjetore',
      source: 'AKM',
      url: 'https://akm.gov.al/bregdeti/',
      kind: 'water',
      point: LatLng(41.810, 19.595),
    ),
    Event(
      id: 'water-durres',
      title: 'Monitorimi i ujit · Durrës',
      description: 'Monitorim: ujë larës bregdetar\nFreskia: sezonale/vjetore',
      source: 'AKM',
      url: 'https://akm.gov.al/bregdeti/',
      kind: 'water',
      point: LatLng(41.300, 19.493),
    ),
    Event(
      id: 'water-vlore',
      title: 'Monitorimi i ujit · Vlorë',
      description: 'Monitorim: ujë larës bregdetar\nFreskia: sezonale/vjetore',
      source: 'AKM',
      url: 'https://akm.gov.al/bregdeti/',
      kind: 'water',
      point: LatLng(40.435, 19.495),
    ),
    Event(
      id: 'water-himare',
      title: 'Monitorimi i ujit · Himarë',
      description: 'Monitorim: ujë larës bregdetar\nFreskia: sezonale/vjetore',
      source: 'AKM',
      url: 'https://akm.gov.al/bregdeti/',
      kind: 'water',
      point: LatLng(40.102, 19.745),
    ),
    Event(
      id: 'water-sarande',
      title: 'Monitorimi i ujit · Sarandë',
      description: 'Monitorim: ujë larës bregdetar\nFreskia: sezonale/vjetore',
      source: 'AKM',
      url: 'https://akm.gov.al/bregdeti/',
      kind: 'water',
      point: LatLng(39.869, 20.010),
    ),
    Event(
      id: 'lake-shkoder',
      title: 'Monitorimi · Liqeni i Shkodrës',
      description: 'Monitorim: cilësia e ujit të liqenit\nFreskia: periodike',
      source: 'AKM',
      url: 'https://akm.gov.al/liqene/',
      kind: 'water',
      point: LatLng(42.120, 19.397),
    ),
    Event(
      id: 'lake-ohrid',
      title: 'Monitorimi · Liqeni i Ohrit',
      description: 'Monitorim: cilësia e ujit të liqenit\nFreskia: periodike',
      source: 'AKM',
      url: 'https://akm.gov.al/liqene/',
      kind: 'water',
      point: LatLng(40.950, 20.670),
    ),
    Event(
      id: 'lake-prespa',
      title: 'Monitorimi · Liqeni i Prespës',
      description: 'Monitorim: cilësia e ujit të liqenit\nFreskia: periodike',
      source: 'AKM',
      url: 'https://akm.gov.al/liqene/',
      kind: 'water',
      point: LatLng(40.753, 20.944),
    ),
  ];

  List<Event> utilityLinks(City city) {
    final provider = switch (city.country) {
      'Kosovë' => (
        name: 'KEDS',
        url: 'https://www.keds-energy.com/shq/punime-ne-rrjet/njoftime-per-punime-ne-rrjet/',
      ),
      'Maqedonia e Veriut' => (
        name: 'EVN Maqedoni',
        url: 'https://www.evn.mk/',
      ),
      'Mali i Zi' => (name: 'CEDIS', url: 'https://cedis.me/'),
      _ => (name: 'OSHEE', url: 'https://oshee.al/'),
    };
    return [
      Event(
        id: 'power-${city.name}',
        title: 'Punime dhe ndërprerje energjie · ${city.name}',
        description:
            '${provider.name} publikon njoftimet për punimet ose ndërprerjet e planifikuara. Hapni burimin për zonën dhe orarin aktual.',
        source: provider.name,
        url: provider.url,
        kind: 'utilities',
        point: city.point,
        approximate: true,
      ),
    ];
  }

  FeedResult<List<Event>> energyGrid() => FeedResult(
    [
      Event(
        id: 'energy-grid-albania',
        title: 'Portali energjetik · Shqipëri',
        description: 'Lloji: lidhje te paneli publik i OST\nTë dhëna të publikuara: prodhimi dhe ngarkesa totale, frekuenca e rrjetit dhe shkëmbimet fizike me Kosovën, Malin e Zi dhe Greqinë.\nSYRI nuk i ka lexuar vlerat brenda aplikacionit; hapni burimin për matjet aktuale.',
        source: 'OST · Open Data',
        url: 'https://opendata.ost.al/',
        kind: 'energy-grid',
        point: const LatLng(41.3275, 19.8187),
        approximate: true,
      ),
      Event(
        id: 'energy-grid-kosovo',
        title: 'Portali energjetik · Kosovë',
        description: 'Lloji: lidhje te paneli publik i KOSTT\nTë dhëna të publikuara: prodhimi, parashikimi i ngarkesës dhe shkyçjet e njësive gjeneruese.\nSYRI nuk i ka lexuar vlerat brenda aplikacionit; hapni burimin për matjet aktuale.',
        source: 'KOSTT · Transparenca',
        url: 'https://kostt.com/Transparency/BasicMarketDataOnGeneration',
        kind: 'energy-grid',
        point: const LatLng(42.6629, 21.1655),
        approximate: true,
      ),
    ],
    DateTime.now(),
    false,
  );

  Future<FeedResult<List<Event>>> internetOutages() async {
    final until = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    final from = until - const Duration(hours: 48).inSeconds;
    final r = await fetch(
      'ioda_outages_al_xk_mk_me',
      'https://api.ioda.inetintel.cc.gatech.edu/v2/outages/alerts?entityType=country&entityCode=AL,XK,MK,ME&from=$from&until=$until&limit=100',
      const Duration(minutes: 10),
      forceRefresh: true,
    );
    final decoded = jsonDecode(r.value) as Map<String, dynamic>;
    final rows = decoded['data'] is List ? decoded['data'] as List : const [];
    final events = <Event>[];
    for (final raw in rows) {
      if (raw is! Map) continue;
      final row = Map<String, dynamic>.from(raw);
      final entity = row['entity'] is Map
          ? Map<String, dynamic>.from(row['entity'] as Map)
          : const <String, dynamic>{};
      final code = (entity['code'] ?? row['entityCode'] ?? '')
          .toString()
          .toUpperCase();
      if (!const {'AL', 'XK', 'MK', 'ME'}.contains(code)) continue;
      final startValue = row['start'] ?? row['startTime'] ?? row['from'];
      final startSeconds = startValue is num
          ? startValue.toInt()
          : int.tryParse(startValue?.toString() ?? '');
      final time = startSeconds == null
          ? r.fetched
          : DateTime.fromMillisecondsSinceEpoch(
              startSeconds * 1000,
              isUtc: true,
            );
      final source = (row['datasource'] ?? row['source'] ?? 'IODA').toString();
      final score = row['score'] ?? row['level'] ?? row['severity'];
      events.add(
        Event(
          id: 'ioda-${row['id'] ?? '$code-$startSeconds-$source'}',
          title:
              'Anomali e internetit · ${const {'AL': 'Shqipëri', 'XK': 'Kosovë', 'MK': 'Maqedonia e Veriut', 'ME': 'Mali i Zi'}[code]}',
          description:
              'Zbuluar nga: $source\nFillimi: ${dateLabel(time)}${score == null ? '' : '\nTreguesi: $score'}\nIODA zbulon anomali të lidhshmërisë; shkaku nuk është domosdoshmërisht i konfirmuar.',
          source: 'IODA · Georgia Tech',
          url: 'https://ioda.inetintel.cc.gatech.edu/country/$code',
          kind: 'internet-outage',
          point: const {
            'AL': LatLng(41.3275, 19.8187),
            'XK': LatLng(42.6629, 21.1655),
            'MK': LatLng(41.9981, 21.4254),
            'ME': LatLng(42.4304, 19.2594),
          }[code],
          time: time,
          approximate: true,
        ),
      );
    }
    return FeedResult(events, r.fetched, r.stale);
  }

  static String _serviceLabel(String type) =>
      const {
        'hospital': 'Spital',
        'clinic': 'Klinikë',
        'pharmacy': 'Farmaci',
        'police': 'Polici',
        'fire_station': 'Zjarrfikëse',
        'charging_station': 'Karikues elektrik',
        'parking': 'Parkim',
        'drinking_water': 'Ujë i pijshëm',
        'recycling': 'Pikë riciklimi',
        'waste_disposal': 'Pikë grumbullimi mbetjesh',
        'wastewater_plant': 'Impiant trajtimi ujërash',
        'air_monitoring': 'Monitorim i cilësisë së ajrit',
        'monitoring_station': 'Stacion monitorimi mjedisor',
        'landfill': 'Venddepozitim mbetjesh',
        'nature_reserve': 'Rezervat natyror',
        'spring': 'Burim natyror',
        'cave_entrance': 'Hyrje shpelle',
        'archaeological_site': 'Vend arkeologjik',
        'castle': 'Kështjellë',
        'ruins': 'Rrënoja historike',
        'monument': 'Monument',
        'memorial': 'Memorial',
        'protected_area': 'Zonë e mbrojtur',
        'toilets': 'Tualet publik',
        'museum': 'Muze',
        'attraction': 'Atraksion',
        'viewpoint': 'Pikë panoramike',
        'camp_site': 'Kamping',
        'information': 'Informacion turistik',
        'bus_stop': 'Stacion autobusi',
      }[type] ??
      type.replaceAll('_', ' ');

  Future<List<SearchPlace>> searchPlaces(String query) async {
    final q = query.trim();
    if (q.length < 2) return [];
    final r = await fetch(
      'place_${normalize(q)}',
      'https://nominatim.openstreetmap.org/search?format=jsonv2&limit=8&addressdetails=1&countrycodes=al,xk,mk,me&q=${Uri.encodeQueryComponent(q)}',
      const Duration(days: 7),
    );
    return (jsonDecode(r.value) as List).map((x) {
      final a = (x['address'] ?? {}) as Map;
      final name = (x['name'] ?? x['display_name'].toString().split(',').first)
          .toString();
      return SearchPlace(
        name,
        (a['country'] ?? 'Hapësira shqipfolëse').toString(),
        LatLng(double.parse(x['lat']), double.parse(x['lon'])),
      );
    }).toList();
  }

  Future<FeedResult<List<Event>>> localNews(City city) async {
    final code = countryCodeFor(city);
    final q = Uri.encodeQueryComponent('"${city.name}"');
    final r = await fetch(
      'local_${city.name}_$code',
      'https://news.google.com/rss/search?q=$q&hl=sq&gl=$code&ceid=$code:sq',
      const Duration(minutes: 15),
    );
    return FeedResult(
      parseNews(r.value, 'Google News', fallbackPlace: city.name),
      r.fetched,
      r.stale,
    );
  }

  Future<FeedResult<List<Event>>> worldNews() async {
    final r = await fetch(
      'world_news',
      'https://news.google.com/rss/headlines/section/topic/WORLD?hl=sq&gl=AL&ceid=AL:sq',
      const Duration(minutes: 15),
    );
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final items = parseNews(r.value, 'Google News')
        .where((event) => event.time != null && event.time!.isAfter(cutoff))
        .take(8)
        .toList();
    return FeedResult(items, r.fetched, r.stale);
  }

  Future<FeedResult<List<Event>>> news(
    String source,
    String url, {
    bool forceRefresh = false,
  }) async {
    final r = await fetch(
      'news_$source',
      url,
      const Duration(minutes: 15),
      forceRefresh: forceRefresh,
    );
    return FeedResult(parseNews(r.value, source), r.fetched, r.stale);
  }

  static List<Event> parseNews(
    String xml,
    String source, {
    LatLng? fallbackPoint,
    String? fallbackPlace,
  }) {
    final doc = XmlDocument.parse(xml);
    if (doc.findAllElements('rss').isEmpty) {
      throw const FormatException('Jo RSS');
    }
    final seen = <String>{};
    return doc
        .findAllElements('item')
        .map((item) {
          String get(String tag) =>
              item.getElement(tag)?.innerText.trim() ?? '';
          var title = get('title'), actualSource = source;
          if (source == 'Google News') {
            final s = get('source');
            if (s.isNotEmpty) actualSource = s;
            final suffix = ' - $actualSource';
            if (title.endsWith(suffix)) {
              title = title.substring(0, title.length - suffix.length);
            }
          }
          final matched = matchCity(title),
              point = matched?.point ?? fallbackPoint;
          final dateElements = item.descendantElements.where((element) {
            final name = element.name.local.toLowerCase();
            return const {
                  'pubdate',
                  'date',
                  'published',
                  'updated',
                }.contains(name) &&
                element.innerText.trim().isNotEmpty;
          });
          final raw = dateElements.isEmpty
              ? ''
              : dateElements.first.innerText.trim();
          final time = _parseFeedDate(raw);
          final descriptionText = _cleanArticleText(get('description'));
          final encodedElement = item.descendantElements.where(
            (element) => element.name.local.toLowerCase() == 'encoded',
          );
          final encodedText = encodedElement.isEmpty
              ? ''
              : _cleanArticleText(encodedElement.first.innerText);
          var summary = descriptionText.length >= 35
              ? descriptionText
              : encodedText;
          if (normalize(summary) == normalize(title)) summary = '';
          return Event(
            id: get('link'),
            title: title,
            description:
                'Botuesi: $actualSource\nZona: ${matched?.name ?? fallbackPlace ?? 'e papërcaktuar'}\nPika tregon qendrën e zonës, jo adresën e verifikuar.\nHapni artikullin origjinal për raportimin e plotë.',
            source: actualSource,
            url: get('link'),
            kind: 'news',
            summary: summary.isEmpty ? null : summary,
            point: point,
            time: time,
            approximate: point != null,
          );
        })
        .where(
          (e) =>
              e.title.isNotEmpty &&
              Uri.tryParse(e.url)?.scheme == 'https' &&
              seen.add(e.url),
        )
        .take(40)
        .toList();
  }

  static String _cleanArticleText(String value) {
    var text = value
        .replaceAll(
          RegExp(
            r'<(script|style)[^>]*>.*?</\1>',
            caseSensitive: false,
            dotAll: true,
          ),
          ' ',
        )
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&ndash;', '–')
        .replaceAll('&mdash;', '—')
        .replaceAll('&hellip;', '…');
    text = text.replaceAllMapped(RegExp(r'&#(x?[0-9a-fA-F]+);'), (match) {
      final raw = match.group(1)!;
      final code = raw.startsWith('x') || raw.startsWith('X')
          ? int.tryParse(raw.substring(1), radix: 16)
          : int.tryParse(raw);
      return code == null ? match.group(0)! : String.fromCharCode(code);
    });
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (text.length <= 420) return text;
    final shortened = text.substring(0, 420);
    final lastSpace = shortened.lastIndexOf(' ');
    return '${shortened.substring(0, lastSpace > 320 ? lastSpace : 420).trim()}…';
  }

  static DateTime? _parseFeedDate(String raw) {
    final iso = DateTime.tryParse(raw);
    if (iso != null) return iso;
    final cleaned = raw.replaceFirst(RegExp(r'^[A-Za-z]{3},\s*'), '');
    final m = RegExp(
      r'(\d{1,2}) ([A-Za-z]{3}) (\d{4}) (\d{2}):(\d{2})(?::(\d{2}))? (GMT|UTC|([+-])(\d{2})(\d{2}))',
    ).firstMatch(cleaned);
    if (m == null) return null;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = months.indexOf(m[2]!) + 1;
    if (month < 1) return null;
    final offset = m[7] == 'GMT' || m[7] == 'UTC'
        ? 0
        : (int.parse(m[9]!) * 60 + int.parse(m[10]!)) * (m[8] == '+' ? 1 : -1);
    return DateTime.utc(
      int.parse(m[3]!),
      month,
      int.parse(m[1]!),
      int.parse(m[4]!),
      int.parse(m[5]!),
      int.tryParse(m[6] ?? '') ?? 0,
    ).subtract(Duration(minutes: offset));
  }
}
