import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:workmanager/workmanager.dart';

import 'data.dart';
import 'map_markers.dart';
import 'background_notifications.dart';
import 'notification_payload.dart';
import 'event_dossier.dart';
import 'news_sources.dart';
import 'info_pages.dart';
import 'tv_channels.dart';
import 'welcome_overlay.dart';

const ink = Color(0xff0d2020);
const panel = Color(0xff183030);
const mint = Color(0xffc7f36a);
const donationAccent = Color(0xffff7385);
const muted = Color(0xff9fb2af);
const glassOpacity = .64;
const glassBlur = 12.0;
const donationUrl = 'https://buymeacoffee.com/pieroboseta';
const paypalDonationUrl = 'https://paypal.me/xsinerox';
const creatorLinkedInUrl = 'https://www.linkedin.com/in/pieroboseta';
const _syriPowerChannel = MethodChannel('al.syri.syri/power');

String protectedAreaLayerDefinitions(Set<String> activeCountries) {
  const codes = {
    'Shqipëri': 'AL',
    'Kosovë': 'XK',
    'Mali i Zi': 'ME',
    'Maqedonia e Veriut': 'MK',
  };
  final selected = [
    for (final entry in codes.entries)
      if (activeCountries.contains(entry.key)) "'${entry.value}'",
  ];
  final filter = selected.isEmpty
      ? '1=0'
      : 'cddaCountryCode IN (${selected.join(',')})';
  return jsonEncode({
    for (final layer in ['0', '1', '3', '4']) layer: filter,
  });
}

class PistolMarkerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 36, size.height / 36);
    final shape = ui.Path()
      ..moveTo(3, 10)
      ..lineTo(28, 10)
      ..quadraticBezierTo(32, 10, 32, 14)
      ..lineTo(32, 18)
      ..lineTo(22, 18)
      ..lineTo(20, 21)
      ..lineTo(17, 21)
      ..lineTo(17, 18)
      ..lineTo(15, 18)
      ..lineTo(12, 30)
      ..lineTo(6, 30)
      ..lineTo(9, 18)
      ..lineTo(3, 18)
      ..close();
    canvas.drawShadow(shape, Colors.black, 5, true);
    canvas.drawPath(shape, Paint()..color = Colors.redAccent);
    canvas.drawLine(
      const Offset(19, 13),
      const Offset(28, 13),
      Paint()
        ..color = ink.withValues(alpha: .75)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

BoxDecoration glassSurface(
  double radius, {
  Color? outline,
  List<BoxShadow>? shadows,
}) => BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      const Color(0xff263838).withValues(alpha: glassOpacity),
      ink.withValues(alpha: glassOpacity),
    ],
  ),
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: outline ?? Colors.white.withValues(alpha: .16)),
  boxShadow: shadows,
);

int cachedSourceBytes(SharedPreferences prefs) {
  var bytes = 0;
  for (final key in prefs.getKeys()) {
    if (!key.startsWith('data_') && !key.startsWith('time_')) continue;
    final value = prefs.getString(key);
    if (value != null) bytes += utf8.encode(value).length;
  }
  return bytes;
}

String formattedCacheSize(int bytes) {
  if (bytes == 0) return '0 MB';
  if (bytes < 10486) return '<0.01 MB';
  if (bytes < 1073741824) {
    return '${(bytes / 1048576).toStringAsFixed(2)} MB';
  }
  return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
}

Color bathingWaterColor(Event event) {
  final text = event.title.toLowerCase();
  if (text.contains('shkëlqyer')) return const Color(0xff96ccff);
  if (text.contains('e mirë')) return const Color(0xff81fb7f);
  if (text.contains('mjaftueshme')) return const Color(0xffffda00);
  if (text.contains('e dobët')) return const Color(0xfffa7f7f);
  return const Color(0xffababab);
}

const supportedNewsCountries = <String>[
  'Shqipëri',
  'Kosovë',
  'Maqedonia e Veriut',
  'Mali i Zi',
];

const cityPickerCountryOrder = <String>[
  'Shqipëri',
  'Kosovë',
  'Mali i Zi',
  'Maqedonia e Veriut',
];

List<City> orderedCitiesForPicker(
  Iterable<City> allCities,
  Set<String> favorites,
) {
  final ordered = [...allCities];
  ordered.sort((a, b) {
    final favoriteOrder =
        (favorites.contains(b.name) ? 1 : 0) -
        (favorites.contains(a.name) ? 1 : 0);
    if (favoriteOrder != 0) return favoriteOrder;
    final countryOrder = cityPickerCountryOrder
        .indexOf(a.country)
        .compareTo(cityPickerCountryOrder.indexOf(b.country));
    if (countryOrder != 0) return countryOrder;
    return normalize(a.name).compareTo(normalize(b.name));
  });
  return ordered;
}

const notificationAllowedKeys = <String>{
  'weather',
  'quakes',
  'hazard:fire',
  'hazard:storm',
  'hazard:flood',
  'hazard:volcano',
  'news:good',
  'news:major',
  'news:crash',
  'news:crime',
  'news:violence',
  'news:death',
  'news:fire',
  'news:weather',
};

bool isBriefingKind(String kind) => const {
  'news',
  'fire',
  'storm',
  'flood',
  'volcano',
  'quakes',
  'hazards',
  'cems',
  'power-outage',
  'water-outage',
  'health-alert',
  'food-alert',
  'civic-alert',
  'road-closure',
}.contains(kind);

bool isEventsFeedKind(String kind) => const {
  'news',
  'quakes',
  'fire',
  'storm',
  'flood',
  'volcano',
  'hazards',
  'cems',
  'frost',
  'hail',
  'drought',
  'heat',
  'wind',
  'power-outage',
  'water-outage',
  'internet-outage',
  'health-alert',
  'food-alert',
  'civic-alert',
  'hydrology-alert',
  'port-alert',
  'roadwork',
  'traffic-jam',
  'road-closure',
}.contains(kind);

String? newsCountry(Event event) {
  final cityMatch = matchCity(
    '${event.title} ${event.summary ?? ''} ${event.description}',
  );
  if (cityMatch != null) return cityMatch.country;
  final content = normalize('${event.title} ${event.summary ?? ''}');
  if (content.contains('kosov')) return 'Kosovë';
  if (content.contains('maqedoni') ||
      content.contains('north macedonia') ||
      content.contains('tetov') ||
      content.contains('gostivar')) {
    return 'Maqedonia e Veriut';
  }
  if (content.contains('mali i zi') ||
      content.contains('montenegro') ||
      content.contains('ulqin') ||
      content.contains('ulcinj')) {
    return 'Mali i Zi';
  }
  if (content.contains('shqiperi') || content.contains('albania')) {
    return 'Shqipëri';
  }
  return switch (event.source) {
    'KALLXO' || 'Telegrafi' || 'Reporteri' || 'Gazeta Express' => 'Kosovë',
    'Star Plus TV' || 'RTSH' || 'BalkanWeb' => 'Shqipëri',
    'Portalb' || 'Alsat' => 'Maqedonia e Veriut',
    'Koha Javore' || 'Ul-info' => 'Mali i Zi',
    _ => null,
  };
}

String? eventCountry(Event event) {
  if (event.kind == 'news') return newsCountry(event);
  final point = event.point;
  if (point == null) return null;
  City? nearest;
  var distance = double.infinity;
  for (final candidate in cities) {
    final current = const Distance().distance(candidate.point, point);
    if (current < distance) {
      distance = current;
      nearest = candidate;
    }
  }
  return nearest?.country;
}

const touristLanguageNames = <String, String>{'en': 'English'};

const touristCopy = <String, Map<String, String>>{
  'sq': {
    'nowSubtitle': 'Përmbledhja që ka rëndësi pranë teje',
    'openBriefing': 'Hap përmbledhjen',
    'currentSituation': 'Situata tani',
    'weatherUnavailable': 'Moti nuk është ngarkuar ende.',
    'rainChance': 'Mundësi shiu',
    'airQuality': 'Cilësia e ajrit',
    'nearbyUpdates': 'Përditësime pranë qytetit',
    'noUrgent': 'Nuk ka raportime të rëndësishme të fundit pranë qytetit.',
    'sourceReminder': 'Kontrollo gjithmonë burimin dhe orën e raportimit.',
    'shareBriefing': 'Ndaj përmbledhjen',
    'touristGuide': 'Udhëzuesi i turistit',
    'touristSubtitle': 'Informacion thelbësor për udhëtimin tënd',
    'emergency': 'Emergjencë',
    'emergencyBody': 'Telefono 112 për polici, ambulancë ose zjarrfikës.',
    'call112': 'Telefono 112',
    'location': 'Vendndodhja',
    'officialSources': 'Burimet origjinale hapen nga çdo raportim.',
    'shareCard': 'Shpërndaje',
    'source': 'Burimi',
    'updated': 'Përditësuar',
    'publicData': 'Informacion publik · verifiko burimin origjinal',
    'clear': 'Kthjellët',
    'cloudy': 'Vranësira',
    'rain': 'Shi',
    'thunder': 'Stuhi me bubullima',
    'snow': 'Borë',
  },
  'en': {
    'nowSubtitle': 'The information that matters near you',
    'openBriefing': 'Open briefing',
    'currentSituation': 'Current situation',
    'weatherUnavailable': 'Weather has not loaded yet.',
    'rainChance': 'Rain chance',
    'airQuality': 'Air quality',
    'nearbyUpdates': 'Updates near the city',
    'noUrgent': 'No recent important reports were found near the city.',
    'sourceReminder': 'Always check the original source and report time.',
    'shareBriefing': 'Share briefing',
    'touristGuide': 'Tourist guide',
    'touristSubtitle': 'Essential information for your trip',
    'emergency': 'Emergency',
    'emergencyBody': 'Call 112 for police, ambulance or fire services.',
    'call112': 'Call 112',
    'location': 'Location',
    'officialSources': 'Open the original source from every report.',
    'shareCard': 'Share',
    'source': 'Source',
    'updated': 'Updated',
    'publicData': 'Public information · verify the original source',
    'clear': 'Clear',
    'cloudy': 'Cloudy',
    'rain': 'Rain',
    'thunder': 'Thunderstorm',
    'snow': 'Snow',
  },
};

bool syriEnglish = false;
final ValueNotifier<bool> syriEnglishChanges = ValueNotifier(false);

void setSyriEnglish(bool value) {
  syriEnglish = value;
  syriEnglishChanges.value = value;
}

class SyriTranslation {
  static final _modelManager = OnDeviceTranslatorModelManager();
  static final _translator = OnDeviceTranslator(
    sourceLanguage: TranslateLanguage.albanian,
    targetLanguage: TranslateLanguage.english,
  );
  static final _albanianTranslator = OnDeviceTranslator(
    sourceLanguage: TranslateLanguage.english,
    targetLanguage: TranslateLanguage.albanian,
  );
  static final Map<String, Future<String>> _translations = {};
  static final Map<String, Future<String>> _albanianTranslations = {};
  static final _languageIdentifier = LanguageIdentifier(
    confidenceThreshold: .5,
  );
  static Future<bool>? _preparing;
  static bool ready = false;
  static Object? lastError;

  // ML Kit is used for live reports and longer descriptions. Short UI labels
  // are kept here because translation models can return them unchanged when
  // they have little context.
  static const Map<String, String> _knownTranslations = {
    'Lajme': 'News',
    'Alarme': 'Alerts',
    'Moti': 'Weather',
    'Shërbime': 'Services',
    'Mjedisi': 'Environment',
    'Territori': 'Territory',
    'Deti': 'Sea',
    'Transport': 'Transport',
    'Kamera': 'Cameras',
    'Kanale': 'Channels',
    'Cilësime': 'Settings',
    'Zgjidh qytetin': 'Choose a city',
    'Shqipëri': 'Albania',
    'Kosovë': 'Kosovo',
    'Maqedonia e Veriut': 'North Macedonia',
    'Mali i Zi': 'Montenegro',
    'Ngjarje': 'Events',
    'Harta': 'Map',
    'Të gjitha': 'All',
    'Bota': 'World',
    'Pranë qytetit': 'Near the city',
    'Të mira': 'Good news',
    'Të mëdha': 'Major events',
    'Aksidente': 'Accidents',
    'Krime': 'Crime',
    'Dhunë/armë': 'Violence/weapons',
    'Humbje jete': 'Loss of life',
    'Zjarre': 'Fires',
    'Mot i rrezikshëm': 'Severe weather',
    'Radar shiu': 'Rain radar',
    'Ajër/UV/polen': 'Air/UV/pollen',
    'Bujqësi': 'Agriculture',
    'Tërmete': 'Earthquakes',
    'Zjarre aktive': 'Active fires',
    'Stuhi': 'Storms',
    'Përmbytje': 'Floods',
    'Vullkane': 'Volcanoes',
    'Harta dëmi': 'Damage maps',
    'Shëndeti publik': 'Public health',
    'Siguria ushqimore': 'Food safety',
    'Lumenj/rezervuarë': 'Rivers/reservoirs',
    'Internet': 'Internet',
    'Rrëshqitje dheu': 'Landslides',
    'Avionë': 'Aircraft',
    'Avionë live': 'Live aircraft',
    'Aeroporte': 'Airports',
    'Trafik i rënduar': 'Heavy traffic',
    'Kamera shpejtësie': 'Speed cameras',
    'Njoftime policore': 'Police notices',
    'Autobusë': 'Buses',
    'Bllokime rrugësh': 'Road closures',
    'Pritje në kufi': 'Border waits',
    'Urgjencë/shëndet': 'Emergency/health',
    'Farmaci': 'Pharmacies',
    'Defibrilatorë': 'Defibrillators',
    'Parkim/karikim': 'Parking/charging',
    'Energji dhe ujë': 'Power and water',
    'Energjia live': 'Live power grid',
    'Njoftime civile': 'Civic notices',
    'Riciklim/mjedis': 'Recycling/environment',
    'Nivelet e lumenjve': 'River levels',
    'Cilësia e lumenjve': 'River quality',
    'Stacione ajri': 'Air stations',
    'Zona përmbytjeje': 'Flood zones',
    'Rrezik gjeologjik': 'Geological risk',
    'Popullsia 2023': '2023 population',
    'Zona të mbrojtura': 'Protected areas',
    'Flora dhe fauna': 'Flora and fauna',
    'Sateliti i ditës': 'Daily satellite',
    'Hartat zyrtare të rajonit': 'Official regional maps',
    'Gjendja e detit': 'Sea conditions',
    'Porte dhe tragete': 'Ports and ferries',
    'Anije/porte': 'Ships/ports',
    'Cilësia e plazheve': 'Beach-water quality',
    'Ujë i pijshëm': 'Drinking water',
    'Zgjidh kategoritë': 'Choose categories',
    'Zgjidh kategorinë': 'Choose a category',
    'Një kategori shfaqet në hartë. Përshtat nënkategoritë e saj më poshtë.':
        'One category appears on the map. Choose its subcategories below.',
    'Fshi të gjitha': 'Clear all',
    'Fshi të gjitha shtresat': 'Clear all layers',
    'Hiqi të gjitha': 'Clear All',
    'Çaktivizo këtë nënkategori': 'Turn off this subcategory',
    'Cilësime të hartës': 'Map settings',
    'Cilësimet': 'Settings',
    'Kontrollo çfarë shfaqet dhe sa shpesh rifreskohet.':
        'Control what appears and how often it refreshes.',
    'Njoftimet e personalizuara': 'Personalized notifications',
    'Burimet dhe kreditet': 'Sources and credits',
    'Shiko origjinën, licencat dhe lidhjet e të dhënave publike.':
        'View origins, licenses and public-data links.',
    'Gjendja e burimeve': 'Source status',
    'Burimet e ngarkuara po përgjigjen normalisht.':
        'Loaded sources are responding normally.',
    'Burimet nuk janë kontrolluar ende.': 'Sources have not been checked yet.',
    'Burimet e kontrolluara po përgjigjen normalisht.':
        'Checked sources are responding normally.',
    'PËRMBAJTJA DHE HARTA': 'CONTENT AND MAP',
    'Vetëm lajme të rëndësishme': 'Important news only',
    'Aksidente, krime, emergjenca dhe ngjarje të mëdha.':
        'Accidents, crime, emergencies and major events.',
    'Radar shiu në hartë': 'Rain radar on the map',
    'Shtresë RainViewer kur Moti është aktiv.':
        'RainViewer layer when Weather is active.',
    'Rifreskimi i avionëve': 'Aircraft refresh',
    'Lëvizja vizuale vazhdon çdo sekondë.':
        'Visual movement continues every second.',
    'Shfaq legjendat e hartës': 'Show map legends',
    'Grupo ikonat pranë njëra-tjetrës': 'Group nearby icons',
    'Ul mbingarkesën e hartës; numri tregon sa pika ka grupi.':
        'Reduces map clutter; the number shows how many points are grouped.',
    'Transparenca e satelitit': 'Satellite opacity',
    'Mosha maksimale e lajmeve': 'Maximum news age',
    'Lajmet më të vjetra hiqen automatikisht.':
        'Older news is removed automatically.',
    'Rrezja “Pranë qytetit”': '“Near the city” radius',
    'Rifresko kur hapet aplikacioni': 'Refresh when the app opens',
    'Kontrollon automatikisht burimet kur rikthehesh në SYRI.':
        'Automatically checks sources when you return to SYRI.',
    'Pastro të dhënat e ruajtura të burimeve': 'Clear saved source data',
    'Heq kopjet e burimeve dhe i shkarkon përsëri; cilësimet ruhen.':
        'Removes cached source data and downloads it again; settings are kept.',
    'SHËRBIME TË JASHTME': 'EXTERNAL SERVICES',
    'Trafiku': 'Traffic',
    'Transporti ndërqytetës': 'Intercity transport',
    'Kamerat': 'Cameras',
    'Anijet': 'Ships',
    'Privatësia & rreth aplikacionit': 'Privacy & about the app',
    'Aktivizo njoftimet': 'Enable notifications',
    'Vetëm njoftime të rëndësishme': 'Important notifications only',
    'Tingulli': 'Sound',
    'Orari i qetësisë': 'Quiet hours',
    'Dërgo njoftim prove': 'Send test notification',
    'Rifresko burimet aktive': 'Refresh active sources',
    'Mbyll': 'Close',
    'Ruaj': 'Save',
    'Rifresko': 'Refresh',
    'Lexo te burimi': 'Read at source',
    'Hap burimin ↗': 'Open source ↗',
    'Navigo te kjo pikë': 'Navigate to this point',
    'Kërko më shumë për këtë vend': 'Learn more about this place',
    'Lexo përmbledhjen e plotë': 'Read the full summary',
    'Ndiq avionin te ADSB.lol': 'Track aircraft on ADSB.lol',
    'Po kërkojmë informacion për vendin…':
        'Searching for information about this place…',
    'Po kërkojmë itinerarin…': 'Searching for the route…',
    'Parashikimi nuk është i disponueshëm.': 'The forecast is unavailable.',
    'Të dhënat e ajrit nuk janë ende të disponueshme.':
        'Air data is not available yet.',
    'Të dhënat detare nuk janë ende të disponueshme.':
        'Marine data is not available yet.',
    'Të dhënat bujqësore nuk janë ende të disponueshme.':
        'Agricultural data is not available yet.',
    'Hap hartën zyrtare ↗': 'Open official map ↗',
    'Hap hartën NASA LHASA': 'Open NASA LHASA map',
    'Hap Google Maps': 'Open Google Maps',
    'Hap Waze': 'Open Waze',
    'Një sy. Shumë burime.': 'One eye. Many sources.',
    'Informacion publik, me origjinë të qartë.':
        'Public information with a clear origin.',
    'TË DHËNA NË HARTË': 'MAP DATA',
  };

  static final Set<String> _protectedNames = {
    'SYRI',
    ...cities.map((city) => city.name),
    'OpenStreetMap',
    'Open-Meteo',
    'RainViewer',
    'ADSB.lol',
    'ADSBDB',
    'FireMap.live',
    'Google Maps',
    'Waze',
  };

  static String? knownTranslation(String value) {
    if (_protectedNames.contains(value.trim())) return value;
    if (touristCopy['en']!.containsValue(value) ||
        touristCopy['en']!.values.any((text) => text.toUpperCase() == value)) {
      return value;
    }
    return _knownTranslations[value];
  }

  static Future<bool> prepare() =>
      _preparing ??= _prepare().whenComplete(() => _preparing = null);

  static Future<bool> _prepare() async {
    if (ready) return true;
    try {
      final albanian = TranslateLanguage.albanian.bcpCode;
      final english = TranslateLanguage.english.bcpCode;
      if (!await _modelManager.isModelDownloaded(albanian)) {
        await _modelManager.downloadModel(albanian, isWifiRequired: false);
      }
      if (!await _modelManager.isModelDownloaded(english)) {
        await _modelManager.downloadModel(english, isWifiRequired: false);
      }
      ready = true;
      return true;
    } catch (error, stackTrace) {
      lastError = error;
      debugPrint('SYRI translation model error: $error\n$stackTrace');
      return false;
    }
  }

  // Feed headlines can arrive in English even when the app is in Albanian.
  // Require more than one English cue to avoid translating names and acronyms.
  static bool looksEnglish(String value) {
    if (value.trim().isEmpty) return false;
    if (RegExp(
      r'\b(food safety|public health|wildfire|earthquake|food recall|virus outbreak|fire alert|flood|flooding)\b',
      caseSensitive: false,
    ).hasMatch(value)) {
      return true;
    }
    final words = RegExp(
      r'\b(the|with|from|about|after|before|into|food|safety|warning|alert|health|fire|virus|outbreak|earthquake|reported|confirmed|recall|water|quality|police|arrested|injured|killed|people|official|near|today|yesterday)\b',
      caseSensitive: false,
    ).allMatches(value).length;
    return words >= 2;
  }

  static Future<String> translateToAlbanian(String value) {
    if (value.trim().isEmpty || _protectedNames.contains(value.trim())) {
      return Future.value(value);
    }
    return _albanianTranslations.putIfAbsent(value, () async {
      if (!looksEnglish(value)) {
        if (RegExp(
          r'\b(në|dhe|për|nga|është|kanë|këtë|njoftim|burimi|shfaqet|vendndodhje)\b',
          caseSensitive: false,
        ).hasMatch(value)) {
          return value;
        }
        try {
          if (await _languageIdentifier.identifyLanguage(value) != 'en') {
            return value;
          }
        } catch (_) {
          return value;
        }
      }
      if (!ready && !await prepare()) return value;
      try {
        return await _albanianTranslator.translateText(value);
      } catch (_) {
        return value;
      }
    });
  }

  static Future<String> translate(String value) {
    if (!ready || value.trim().isEmpty) return Future.value(value);
    final known = knownTranslation(value);
    if (known != null) return Future.value(known);
    return _translations.putIfAbsent(value, () async {
      try {
        var protectedInput = value;
        final protectedCities = <int, String>{};
        var cityIndex = 0;
        for (final city in cities) {
          if (value.contains(city.name)) {
            final token = '[[SYRICITY$cityIndex]]';
            protectedCities[cityIndex++] = city.name;
            protectedInput = protectedInput.replaceAll(city.name, token);
          }
        }
        var safe = await _translator.translateText(protectedInput);
        return restoreProtectedCities(safe, protectedCities);
      } catch (_) {
        return value;
      }
    });
  }

  static String restoreProtectedCities(String value, Map<int, String> names) {
    var restored = value;
    for (final entry in names.entries) {
      restored = restored.replaceAll(
        RegExp(
          r'\[?\[?\s*SYRICITY\s*' + entry.key.toString() + r'\s*\]?\]?',
          caseSensitive: false,
        ),
        entry.value,
      );
    }
    return restored;
  }
}

/// Translates every visible label and every dynamic report when English mode
/// is active. Albanian remains the source of truth and the startup language.
class AppText extends StatelessWidget {
  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextDirection? textDirection;
  final bool? softWrap;
  final TextOverflow? overflow;
  final int? maxLines;

  const AppText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.textDirection,
    this.softWrap,
    this.overflow,
    this.maxLines,
  });

  Widget _text(String value) => Text(
    value,
    style: style,
    textAlign: textAlign,
    textDirection: textDirection,
    softWrap: softWrap,
    overflow: overflow,
    maxLines: maxLines,
  );

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: syriEnglishChanges,
    builder: (_, english, _) {
      if (data.trim().isEmpty) {
        return _text(data);
      }
      if (!english) {
        if (data.length < 24 && !SyriTranslation.looksEnglish(data)) {
          return _text(data);
        }
        return FutureBuilder<String>(
          future: SyriTranslation.translateToAlbanian(data),
          initialData: data,
          builder: (_, snapshot) => _text(snapshot.data ?? data),
        );
      }
      final known = SyriTranslation.knownTranslation(data);
      if (known != null) return _text(known);
      if (!SyriTranslation.ready) return _text(data);
      return FutureBuilder<String>(
        future: SyriTranslation.translate(data),
        initialData: data,
        builder: (_, snapshot) => _text(snapshot.data ?? data),
      );
    },
  );
}

final syriNotifications = FlutterLocalNotificationsPlugin();
final pendingNotificationPayload = ValueNotifier<String?>(null);
bool notificationsInitialized = false;
final Completer<void> _workmanagerReady = Completer<void>();

Future<void> _configureBackgroundNotifications(bool enabled) async {
  if (Platform.isAndroid) await _workmanagerReady.future;
  await configureSyriBackgroundNotifications(enabled);
}

Future<void> initializeNotifications() async {
  if (notificationsInitialized) return;
  try {
    await syriNotifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('syri_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        pendingNotificationPayload.value = response.payload;
      },
    );
    notificationsInitialized = true;
    final launch = await syriNotifications.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      pendingNotificationPayload.value = launch?.notificationResponse?.payload;
    }
  } catch (_) {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Cache tiles reached through normal map use. Public OSM tiles must never
  // be downloaded in bulk to assemble an offline country map.
  BuiltInMapCachingProvider.getOrCreateInstance(maxCacheSize: 1_000_000_000);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const SyriApp());
  // Let Flutter draw the animated handoff before plugin setup can hold the
  // native (static) splash on screen. Pending notification payloads are
  // observed by SyriHome even when initialization completes afterward.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_initializeBackgroundServices());
  });
}

Future<void> _initializeBackgroundServices() async {
  unawaited(initializeNotifications());
  if (Platform.isAndroid) {
    try {
      await Workmanager().initialize(syriBackgroundDispatcher);
    } catch (_) {
      // Scheduling will report its own failure if the plugin is unavailable.
    } finally {
      if (!_workmanagerReady.isCompleted) _workmanagerReady.complete();
    }
  }
}

class SyriApp extends StatelessWidget {
  final bool loadData;
  const SyriApp({super.key, this.loadData = true});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SYRI',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: ink,
      colorScheme: ColorScheme.fromSeed(
        seedColor: mint,
        brightness: Brightness.dark,
        surface: ink,
        primary: mint,
      ),
      dividerColor: Colors.white12,
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: Colors.transparent,
        indicatorShape: const StadiumBorder(),
        height: 64,
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.pressed)
              ? mint.withValues(alpha: .14)
              : Colors.transparent,
        ),
      ),
    ),
    home: SyriHome(loadData: loadData),
  );
}

class LayerInfo {
  final String id, name, note;
  final IconData icon;
  final Color color;
  const LayerInfo(this.id, this.name, this.note, this.icon, this.color);
}

class MapCategory {
  final String id, name;
  final IconData icon;
  final Color color;
  const MapCategory(this.id, this.name, this.icon, this.color);

  String get englishName => switch (id) {
    'news' => 'News',
    'alerts' => 'Alerts',
    'weather' => 'Weather',
    'territory' => 'Territory',
    'sea' => 'Waters',
    'transport' => 'Transport',
    'cameras' => 'Cameras',
    'tv' => 'Channels',
    _ => name,
  };
}

const mapCategories = [
  MapCategory('news', 'Lajme', Icons.newspaper_outlined, Color(0xff91b5ff)),
  MapCategory(
    'alerts',
    'Alarme',
    Icons.warning_amber_rounded,
    Color(0xffff8178),
  ),
  MapCategory('weather', 'Moti', Icons.cloud_outlined, Color(0xff66d9ff)),
  MapCategory(
    'territory',
    'Territori',
    Icons.layers_outlined,
    Color(0xffffdc72),
  ),
  MapCategory('sea', 'Ujërat', Icons.water_outlined, Color(0xff52d9ff)),
  MapCategory('transport', 'Transport', Icons.commute, Color(0xffc7f36a)),
  MapCategory('cameras', 'Kamera', Icons.videocam_outlined, Color(0xffd7a6ff)),
  MapCategory('tv', 'Kanale', Icons.live_tv_rounded, Color(0xffffa967)),
];

const layerInfo = [
  LayerInfo(
    'news',
    'Lajme',
    'Tituj me qytet të përafërt',
    Icons.article_outlined,
    Color(0xff91b5ff),
  ),
  LayerInfo(
    'quakes',
    'Tërmete',
    'Rajoni · 7 ditë',
    Icons.vibration_rounded,
    Color(0xffffb66f),
  ),
  LayerInfo(
    'planes',
    'Avionë',
    'Live · lëvizje dhe rifreskim',
    Icons.flight,
    mint,
  ),
  LayerInfo(
    'hazards',
    'Natyra',
    'Zjarre, stuhi dhe përmbytje',
    Icons.local_fire_department_outlined,
    Color(0xffff8178),
  ),
  LayerInfo(
    'cameras',
    'Kamera',
    'Kamera publike të verifikuara',
    Icons.videocam_outlined,
    Color(0xffd7a6ff),
  ),
  LayerInfo(
    'ships',
    'Anije',
    'Portet dhe harta detare',
    Icons.directions_boat_outlined,
    Color(0xff66d9ff),
  ),
];

LayerInfo infoFor(String id) {
  if (id == 'tv') {
    return const LayerInfo(
      'tv',
      'Kanale',
      'Lidhje me televizionet origjinale',
      Icons.live_tv_rounded,
      Color(0xffffa967),
    );
  }
  if (id == 'marine') {
    return const LayerInfo(
      'marine',
      'Gjendja e detit',
      'Parashikim detar nga Open-Meteo',
      Icons.waves,
      Colors.cyanAccent,
    );
  }
  if (id == 'river-levels' || id == 'river-level') {
    return const LayerInfo(
      'river-levels',
      'Niveli i lumit',
      'Stacione IHMK · matje periodike',
      Icons.water_damage_outlined,
      Color(0xff55c9ff),
    );
  }
  if (id == 'airports' || id.startsWith('airport-')) {
    return LayerInfo(
      'airports',
      id == 'airport-arrival'
          ? 'Mbërritje'
          : id == 'airport-departure'
          ? 'Nisje'
          : 'Aeroporte',
      'Tabela zyrtare e fluturimeve',
      id == 'airport-arrival' ? Icons.flight_land : Icons.flight_takeoff,
      const Color(0xff8ed7ff),
    );
  }
  if (id == 'energy-grid') {
    return const LayerInfo(
      'energy-grid',
      'Energjia live',
      'OST dhe KOSTT',
      Icons.electric_bolt,
      Color(0xffffdf64),
    );
  }
  if (id == 'internet-outages' || id == 'internet-outage') {
    return const LayerInfo(
      'internet-outages',
      'Ndërprerje interneti',
      'Alarme IODA · 48 orë',
      Icons.wifi_off_rounded,
      Color(0xffff8c78),
    );
  }
  if (id == 'landslides') {
    return const LayerInfo(
      'landslides',
      'Rrëshqitje dheu',
      'NASA LHASA · afër kohës reale',
      Icons.landscape_outlined,
      Color(0xffffa55f),
    );
  }
  if (id == 'satellite') {
    return const LayerInfo(
      'satellite',
      'Sateliti i ditës',
      'NASA GIBS · pamje VIIRS',
      Icons.satellite_alt,
      Color(0xff9dd8ff),
    );
  }
  if (id == 'agriculture-info') {
    return const LayerInfo(
      'agriculture-info',
      'Kushtet bujqësore',
      'Tokë, reshje, erë dhe temperatura',
      Icons.agriculture_outlined,
      Color(0xffa9e85c),
    );
  }
  if (id == 'health-alerts') {
    return const LayerInfo(
      'health-alerts',
      'Shëndeti publik',
      'Alarme deri në 7 ditë',
      Icons.health_and_safety,
      Color(0xffff6f91),
    );
  }
  if (id == 'food-alerts') {
    return const LayerInfo(
      'food-alerts',
      'Siguria ushqimore',
      'Alarme deri në 7 ditë',
      Icons.no_food_rounded,
      Color(0xffffa24b),
    );
  }
  if (id == 'port-alerts') {
    return const LayerInfo(
      'port-alerts',
      'Porte dhe tragete',
      'Njoftime deri në 48 orë',
      Icons.anchor_rounded,
      Color(0xff52d9ff),
    );
  }
  if (id == 'hydrology-alerts') {
    return const LayerInfo(
      'hydrology-alerts',
      'Lumenj dhe rezervuarë',
      'Njoftime hidrologjike deri në 48 orë',
      Icons.water_damage_outlined,
      Color(0xff4f9dff),
    );
  }
  if (id == 'civic-alerts') {
    return const LayerInfo(
      'civic-alerts',
      'Njoftime civile',
      'Mbyllje, evakuime dhe ndërprerje deri në 48 orë',
      Icons.campaign_outlined,
      Color(0xffffd66e),
    );
  }
  if (id == 'agriculture') {
    return const LayerInfo(
      'agriculture',
      'Bujqësia',
      'Ngricë, vapë, erë, breshër dhe thatësi',
      Icons.agriculture_outlined,
      Color(0xffa9e85c),
    );
  }
  if (id == 'river-quality') {
    return const LayerInfo(
      'river-quality',
      'Cilësia e lumenjve',
      'Monitorimi zyrtar ASIG/AKM',
      Icons.water,
      Color(0xff55d8ff),
    );
  }
  if (id == 'air-stations') {
    return const LayerInfo(
      'air-stations',
      'Stacionet e ajrit',
      'Rrjeti zyrtar ASIG/AKM',
      Icons.sensors,
      Color(0xff58e0c2),
    );
  }
  if (id == 'flood-zones') {
    return const LayerInfo(
      'flood-zones',
      'Zona përmbytjeje',
      'Hartë zyrtare rreziku',
      Icons.flood,
      Color(0xff4f91ff),
    );
  }
  if (id == 'geo-risk') {
    return const LayerInfo(
      'geo-risk',
      'Rrezik gjeologjik',
      'Hartat tematike të qarqeve',
      Icons.terrain,
      Color(0xffff9b55),
    );
  }
  if (id == 'population') {
    return const LayerInfo(
      'population',
      'Popullsia',
      'Censi 2023 në Shqipëri; tregues kombëtarë për katër vendet',
      Icons.grid_on,
      Color(0xffd49cff),
    );
  }
  if (id == 'land-cover') {
    return const LayerInfo(
      'land-cover',
      'Mbulesa e tokës',
      'ESA WorldCover 2021 · katër vendet',
      Icons.landscape_outlined,
      Color(0xff91d797),
    );
  }
  if (id == 'protected') {
    return const LayerInfo(
      'protected',
      'Zona të mbrojtura',
      'Kufijtë zyrtarë',
      Icons.park,
      Color(0xff62e899),
    );
  }
  if (id == 'biodiversity') {
    return const LayerInfo(
      'biodiversity',
      'Flora dhe fauna',
      'Shpërndarja e specieve',
      Icons.pets,
      Color(0xffa9e85c),
    );
  }
  if (id == 'biodiversity-flora') {
    return const LayerInfo(
      'biodiversity-flora',
      'Flora e regjistruar',
      'Regjistrim historik nga GBIF',
      Icons.local_florist_outlined,
      Color(0xffa9e85c),
    );
  }
  if (id == 'biodiversity-fauna') {
    return const LayerInfo(
      'biodiversity-fauna',
      'Fauna e regjistruar',
      'Regjistrim historik nga GBIF',
      Icons.pets,
      Color(0xff73d9a8),
    );
  }
  if (id == 'geoportal') {
    return const LayerInfo(
      'geoportal',
      'Harta zyrtare',
      'Geoportali shtetëror',
      Icons.public,
      Color(0xffffdc72),
    );
  }
  if (id == 'fire') {
    return const LayerInfo(
      'fire',
      'Zjarr',
      '',
      Icons.local_fire_department,
      Color(0xffff655d),
    );
  }
  if (id == 'storm') {
    return const LayerInfo(
      'storm',
      'Stuhi',
      '',
      Icons.thunderstorm,
      Color(0xff91b5ff),
    );
  }
  if (id == 'flood') {
    return const LayerInfo(
      'flood',
      'Përmbytje',
      '',
      Icons.flood,
      Color(0xff62c8ff),
    );
  }
  if (id == 'volcano') {
    return const LayerInfo(
      'volcano',
      'Vullkan',
      '',
      Icons.volcano,
      Color(0xffff9c66),
    );
  }
  if (id == 'cameras') {
    return const LayerInfo(
      'cameras',
      'Kamera',
      '',
      Icons.videocam,
      Color(0xffd7a6ff),
    );
  }
  if (id == 'ships') {
    return const LayerInfo(
      'ships',
      'Anije',
      '',
      Icons.directions_boat,
      Color(0xff66d9ff),
    );
  }
  if (id == 'borders') {
    return const LayerInfo(
      'borders',
      'Kufi',
      '',
      Icons.compare_arrows_rounded,
      Color(0xffffd166),
    );
  }
  if (id == 'roadwork') {
    return const LayerInfo(
      'roadwork',
      'Rrugë',
      '',
      Icons.construction,
      Color(0xffffa24b),
    );
  }
  if (id == 'traffic-jam') {
    return const LayerInfo(
      'traffic-jam',
      'Trafik i rënduar',
      '',
      Icons.warning_rounded,
      Color(0xffff4f55),
    );
  }
  if (id == 'speed-camera') {
    return const LayerInfo(
      'speed-camera',
      'Kamerë shpejtësie',
      'Pikë fikse e hartëzuar',
      Icons.speed,
      Color(0xffffd166),
    );
  }
  if (id == 'police-alert') {
    return const LayerInfo(
      'police-alert',
      'Njoftim policor',
      'Kontroll, kufizim ose devijim zyrtar',
      Icons.local_police_outlined,
      Color(0xff72a7ff),
    );
  }
  if (id == 'health-alert') {
    return const LayerInfo(
      'health-alert',
      'Alarm shëndetësor',
      '',
      Icons.health_and_safety,
      Color(0xffff6f91),
    );
  }
  if (id == 'food-alert') {
    return const LayerInfo(
      'food-alert',
      'Siguri ushqimore',
      '',
      Icons.no_food_rounded,
      Color(0xffffa24b),
    );
  }
  if (id == 'port-alert') {
    return const LayerInfo(
      'port-alert',
      'Njoftim detar',
      '',
      Icons.anchor_rounded,
      Color(0xff52d9ff),
    );
  }
  if (id == 'hydrology-alert') {
    return const LayerInfo(
      'hydrology-alert',
      'Alarm hidrologjik',
      '',
      Icons.flood,
      Color(0xff4f9dff),
    );
  }
  if (id == 'civic-alert') {
    return const LayerInfo(
      'civic-alert',
      'Njoftim civil',
      '',
      Icons.campaign_outlined,
      Color(0xffffd66e),
    );
  }
  if (id == 'frost') {
    return const LayerInfo(
      'frost',
      'Ngricë',
      '',
      Icons.ac_unit,
      Color(0xff8eeaff),
    );
  }
  if (id == 'hail') {
    return const LayerInfo(
      'hail',
      'Breshër',
      '',
      Icons.grain,
      Color(0xff9ddcff),
    );
  }
  if (id == 'drought') {
    return const LayerInfo(
      'drought',
      'Thatësirë',
      '',
      Icons.grass,
      Color(0xffffc15c),
    );
  }
  if (id == 'heat') {
    return const LayerInfo(
      'heat',
      'Vapë ekstreme',
      '',
      Icons.device_thermostat,
      Color(0xffff5f55),
    );
  }
  if (id == 'wind') {
    return const LayerInfo(
      'wind',
      'Erë e fortë',
      '',
      Icons.air,
      Color(0xffb8d8ff),
    );
  }
  if (id == 'transit') {
    return const LayerInfo(
      'transit',
      'Autobus',
      '',
      Icons.directions_bus,
      Color(0xff70c7ff),
    );
  }
  if (id == 'health') {
    return const LayerInfo(
      'health',
      'Shëndet',
      '',
      Icons.local_hospital,
      Color(0xffff6685),
    );
  }
  if (id == 'pharmacy') {
    return const LayerInfo(
      'pharmacy',
      'Farmaci',
      '',
      Icons.medication,
      Color(0xff54e49b),
    );
  }
  if (id == 'police') {
    return const LayerInfo(
      'police',
      'Polici',
      '',
      Icons.local_police,
      Color(0xff72a7ff),
    );
  }
  if (id == 'fire_station') {
    return const LayerInfo(
      'fire_station',
      'Zjarrfikëse',
      '',
      Icons.fire_truck,
      Color(0xffff6b55),
    );
  }
  if (id == 'aed') {
    return const LayerInfo(
      'aed',
      'Defibrilator',
      '',
      Icons.monitor_heart,
      Color(0xffff4d7d),
    );
  }
  if (id == 'charging') {
    return const LayerInfo(
      'charging',
      'Karikues',
      '',
      Icons.ev_station,
      Color(0xff86ef6a),
    );
  }
  if (id == 'parking') {
    return const LayerInfo(
      'parking',
      'Parkim',
      '',
      Icons.local_parking,
      Color(0xff77b9ff),
    );
  }
  if (id == 'services') {
    return const LayerInfo(
      'services',
      'Shërbim',
      '',
      Icons.place,
      Color(0xffff8eb0),
    );
  }
  if (id == 'utilities') {
    return const LayerInfo(
      'utilities',
      'Energji',
      '',
      Icons.power,
      Color(0xffffdf64),
    );
  }
  if (id == 'power-outage') {
    return const LayerInfo(
      'power-outage',
      'Ndërprerje energjie',
      '',
      Icons.power_off_rounded,
      Color(0xffffd454),
    );
  }
  if (id == 'water-outage') {
    return const LayerInfo(
      'water-outage',
      'Ndërprerje uji',
      '',
      Icons.water_drop_outlined,
      Color(0xff55d8ff),
    );
  }
  if (id == 'water') {
    return const LayerInfo(
      'water',
      'Uji',
      '',
      Icons.water_drop,
      Color(0xff5fd8ff),
    );
  }
  if (id == 'environment') {
    return const LayerInfo(
      'environment',
      'Mjedis',
      '',
      Icons.recycling,
      Color(0xff67e6ad),
    );
  }
  if (id == 'drinking-water') {
    return const LayerInfo(
      'drinking-water',
      'Ujë i pijshëm',
      '',
      Icons.local_drink_outlined,
      Color(0xff65d9f2),
    );
  }
  if (id == 'places') {
    return const LayerInfo(
      'places',
      'Vend',
      '',
      Icons.explore,
      Color(0xffffdc72),
    );
  }
  if (id == 'cems') {
    return const LayerInfo(
      'cems',
      'Copernicus',
      '',
      Icons.satellite_alt,
      Color(0xffff7f73),
    );
  }
  return layerInfo.firstWhere(
    (item) => item.id == id,
    orElse: () => layerInfo.first,
  );
}

class _SwipeDismissSheet extends StatefulWidget {
  final Widget child;
  final Color accent;

  const _SwipeDismissSheet({required this.child, required this.accent});

  @override
  State<_SwipeDismissSheet> createState() => _SwipeDismissSheetState();
}

class _SwipeDismissSheetState extends State<_SwipeDismissSheet> {
  final ScrollController _scrollController = ScrollController();
  double _downwardDistance = 0;
  bool _closing = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _pointerMove(PointerMoveEvent event) {
    if (_closing ||
        (_scrollController.hasClients && _scrollController.offset > .5)) {
      _downwardDistance = 0;
      return;
    }
    if (event.delta.dy > 0) {
      _downwardDistance += event.delta.dy;
    } else if (event.delta.dy < -2) {
      _downwardDistance = 0;
    }
    if (_downwardDistance > 78) {
      _closing = true;
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _downwardDistance = 0,
    onPointerMove: _pointerMove,
    child: ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: ink.withValues(alpha: .84),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.accent.withValues(alpha: .11),
                ink.withValues(alpha: .82),
                Colors.black.withValues(alpha: .72),
              ],
            ),
            border: Border.all(
              color: widget.accent.withValues(alpha: .58),
              width: 1.2,
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: widget.accent.withValues(alpha: .18),
                blurRadius: 28,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .82,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 34,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 11),
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .35),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 32),
                      child: widget.child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class SyriHome extends StatefulWidget {
  final bool loadData;
  const SyriHome({super.key, required this.loadData});

  @override
  State<SyriHome> createState() => _SyriHomeState();
}

class _SyriHomeState extends State<SyriHome> with WidgetsBindingObserver {
  static const _referenceLayerIds = {
    'land-cover',
    'flood-zones',
    'population',
    'protected',
    'biodiversity',
  };
  final api = SyriApi();
  final mapController = MapController();
  final enabled = <String>{'news'};
  final enabledNewsTypes = <String>{
    'good',
    'major',
    'crash',
    'crime',
    'violence',
    'death',
    'fire',
    'weather',
  };
  final enabledHazards = <String>{};
  final enabledCameraTypes = <String>{
    'traffic',
    'city',
    'border',
    'nature',
    'youtube',
  };
  final favoriteCities = <String>{};
  final results = <String, FeedResult<List<Event>>>{};
  int? _newsCacheKey;
  List<Event> _cachedRawNews = const [];
  List<Event> _cachedNews = const [];
  final busy = <String>{};
  final failures = <String>{};
  final sourceCheckedAt = <String, DateTime>{};
  City city = cities.first;
  FeedResult<Weather>? weather;
  FeedResult<RadarLayer>? radar;
  FeedResult<AirQuality>? airQuality;
  final regionalAirQuality = <String, FeedResult<AirQuality>>{};
  FeedResult<MarineWeather>? marineWeather;
  LatLng? userPoint;
  int tab = 0;
  int cityGeneration = 0;
  bool mapReady = false;
  bool locating = false;
  String eventFilter = 'Të gjitha';
  String? selectedMapCategory = 'news';
  final activeMapCategories = <String>{'news'};
  String? expandedCategory;
  Timer? planeTimer, motionTimer;
  final eventSearchController = TextEditingController();
  String eventSearchQuery = '';
  bool showRadar = true;
  bool rainLegendDismissed = false;
  bool waterLegendDismissed = false;
  bool airLegendDismissed = false;
  bool mapLegendDismissed = false;
  final dismissedReferenceLegends = <String>{};
  bool satelliteLegendDismissed = false;
  String? availableSatelliteDay;
  bool satelliteUnavailable = false;
  bool importantNewsOnly = true;
  bool notificationsEnabled = false;
  bool worldNotifications = false;
  double minimumEarthquakeMagnitude = 4;
  DateTime notificationStart = DateTime.now();
  bool notificationSound = true;
  bool urgentNotificationsOnly = true;
  bool quietNotificationsAtNight = true;
  bool autoRefreshOnResume = true;
  bool showLegends = true;
  bool touristMode = false;
  String touristLanguage = 'en';
  double satelliteOpacity = .68;
  int nearbyRadiusKm = 35;
  int newsMaxHours = 48;
  int notificationMaxAgeMinutes = 60;
  final notificationLayers = <String>{'quakes', 'hazard:fire', 'hazard:flood'};
  final enabledNewsCountries = <String>{...supportedNewsCountries};
  final notifiedEventIds = <String>{};
  final LayerHitNotifier<Event> _waterHitNotifier = ValueNotifier(null);
  int planeRefreshSeconds = 30;
  double mapZoom = 11;
  DateTime _lastMapZoomRender = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _mapZoomRenderTimer;
  Timer? _mapZoomSettleTimer;
  Timer? _baseTileRetryTimer;
  int _baseTileRevision = 0;
  int _baseTileRetryCount = 0;
  DateTime? _baseTileRetryWindow;
  double? _pendingMapZoom;
  Future<int>? cacheBytesFuture;
  DateTime? _lastEventsRefresh;
  String? _weatherToastMessage;
  bool _weatherToastSuccess = true;
  Timer? _weatherToastTimer;
  Timer? _connectionTimer;
  Timer? _offlineNoticeTimer;
  bool? _online;
  bool _checkingConnection = false;
  bool _showOfflineNotice = false;
  bool _showWelcome = false;
  bool _mapShellReady = false;
  bool _welcomeDelayElapsed = false;
  bool _settingsLoaded = false;
  Timer? _welcomeTimer;
  Timer? _welcomeSafetyTimer;
  Timer? _dataRenderTimer;

  bool get _isAlbania => city.country == 'Shqipëri';

  List<City> get _orderedCities =>
      orderedCitiesForPicker(cities, favoriteCities);

  @override
  void initState() {
    super.initState();
    _showWelcome = widget.loadData;
    _mapShellReady = !widget.loadData;
    WidgetsBinding.instance.addObserver(this);
    pendingNotificationPayload.addListener(_openPendingNotification);
    _openPendingNotification();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.loadData) {
        // The first Flutter frame should be the animated logo, not a costly
        // map build. Count its display time only after it has actually drawn.
        setState(() => _mapShellReady = true);
        _welcomeTimer = Timer(const Duration(milliseconds: 1250), () {
          _welcomeDelayElapsed = true;
          _finishWelcome();
        });
        _welcomeSafetyTimer = Timer(const Duration(seconds: 3), () {
          if (mounted && _showWelcome) setState(() => _showWelcome = false);
        });
        unawaited(_checkConnection());
        _connectionTimer = Timer.periodic(
          const Duration(seconds: 45),
          (_) => unawaited(_checkConnection()),
        );
      }
      unawaited(_initialize());
    });
  }

  void _openPendingNotification() {
    final payload = pendingNotificationPayload.value;
    if (payload == null || payload.isEmpty) return;
    pendingNotificationPayload.value = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final event = eventFromNotificationPayload(payload);
      if (event != null) {
        setState(() => tab = 0);
        _eventDetails(event);
      } else if (isWeatherNotificationPayload(payload)) {
        _weatherDetails();
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  Future<void> _initialize() async {
    try {
      await _loadSettings();
    } catch (_) {
      // The default settings still allow the map to open.
    }
    if (!mounted) return;
    _settingsLoaded = true;
    _finishWelcome();
    if (widget.loadData) unawaited(refresh());
  }

  void _finishWelcome() {
    if (mounted && _showWelcome && _welcomeDelayElapsed && _settingsLoaded) {
      _welcomeSafetyTimer?.cancel();
      setState(() => _showWelcome = false);
    }
  }

  void _scheduleDataRender() {
    if (!mounted || _dataRenderTimer != null) return;
    _dataRenderTimer = Timer(const Duration(milliseconds: 48), () {
      _dataRenderTimer = null;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    pendingNotificationPayload.removeListener(_openPendingNotification);
    _weatherToastTimer?.cancel();
    _connectionTimer?.cancel();
    _offlineNoticeTimer?.cancel();
    _welcomeTimer?.cancel();
    _welcomeSafetyTimer?.cancel();
    _dataRenderTimer?.cancel();
    _mapZoomRenderTimer?.cancel();
    _mapZoomSettleTimer?.cancel();
    _baseTileRetryTimer?.cancel();
    planeTimer?.cancel();
    motionTimer?.cancel();
    eventSearchController.dispose();
    _waterHitNotifier.dispose();
    api.client.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (widget.loadData) unawaited(_checkConnection());
      _startPlaneTimer();
      if (autoRefreshOnResume && widget.loadData) refresh();
    } else {
      planeTimer?.cancel();
      motionTimer?.cancel();
    }
  }

  Future<void> _checkConnection() async {
    if (_checkingConnection) return;
    _checkingConnection = true;
    var reachable = false;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
    try {
      for (final address in const [
        'https://api.open-meteo.com/',
        'https://www.openstreetmap.org/',
      ]) {
        try {
          final request = await client
              .headUrl(Uri.parse(address))
              .timeout(const Duration(seconds: 5));
          final response = await request.close().timeout(
            const Duration(seconds: 5),
          );
          await response.drain<void>();
          reachable = true; // Any HTTP response confirms a connection.
          break;
        } catch (_) {
          // Check the second independent source before reporting offline.
        }
      }
    } finally {
      client.close(force: true);
      _checkingConnection = false;
    }
    if (!mounted) return;
    final wasOnline = _online;
    _online = reachable;
    api.offline = !reachable;
    if (reachable) {
      _offlineNoticeTimer?.cancel();
      if (_showOfflineNotice) setState(() => _showOfflineNotice = false);
    } else if (wasOnline != false) {
      _offlineNoticeTimer?.cancel();
      setState(() => _showOfflineNotice = true);
      _offlineNoticeTimer = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _showOfflineNotice = false);
      });
    }
  }

  void _startPlaneTimer() {
    planeTimer?.cancel();
    motionTimer?.cancel();
    if (widget.loadData && tab == 0 && enabled.contains('planes')) {
      planeTimer = Timer.periodic(
        Duration(seconds: planeRefreshSeconds),
        (_) => _load('planes', () => api.aircraft(city)),
      );
      motionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _retryMissingBaseTiles() {
    final now = DateTime.now();
    if (_baseTileRetryWindow == null ||
        now.difference(_baseTileRetryWindow!) > const Duration(minutes: 1)) {
      _baseTileRetryWindow = now;
      _baseTileRetryCount = 0;
    }
    if (_baseTileRetryTimer != null || _baseTileRetryCount >= 2) return;
    _baseTileRetryTimer = Timer(const Duration(seconds: 5), () {
      _baseTileRetryTimer = null;
      if (!mounted) return;
      _baseTileRetryCount++;
      setState(() => _baseTileRevision++);
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key
        in prefs
            .getKeys()
            .where(
              (key) =>
                  key.startsWith('space_tle_') ||
                  key.startsWith('space_checked_') ||
                  key.startsWith('space_attempt_'),
            )
            .toList()) {
      await prefs.remove(key);
    }
    final oldLayers = prefs.getStringList('setting_map_layers');
    if (oldLayers != null &&
        oldLayers.any(
          (id) => const {
            'space-moon',
            'space-satellites',
            'sky-view',
            'earth-night',
            'radio',
          }.contains(id),
        )) {
      await prefs.setStringList(
        'setting_map_layers',
        oldLayers
            .where(
              (id) => !const {
                'space-moon',
                'space-satellites',
                'sky-view',
                'earth-night',
                'radio',
              }.contains(id),
            )
            .toList(),
      );
    }
    await prefs.remove('setting_tomtom_key');
    if (!mounted) return;
    setSyriEnglish(false);
    setState(() {
      showRadar = prefs.getBool('setting_radar') ?? true;
      importantNewsOnly = prefs.getBool('setting_important_news') ?? true;
      planeRefreshSeconds = prefs.getInt('setting_plane_refresh') ?? 30;
      notificationsEnabled = prefs.getBool('setting_notifications') ?? false;
      notificationStart =
          DateTime.tryParse(
            prefs.getString('setting_notifications_started_at') ?? '',
          ) ??
          DateTime.now();
      worldNotifications = prefs.getBool('setting_notification_world') ?? false;
      minimumEarthquakeMagnitude =
          (prefs.getDouble('setting_quake_minimum') ?? 4).clamp(0.0, 7.0);
      notifiedEventIds.addAll(
        prefs.getStringList('setting_notified_ids') ?? const [],
      );
      notificationSound = prefs.getBool('setting_notification_sound') ?? true;
      urgentNotificationsOnly =
          prefs.getBool('setting_notification_urgent') ?? true;
      quietNotificationsAtNight =
          prefs.getBool('setting_notification_quiet') ?? true;
      autoRefreshOnResume = prefs.getBool('setting_auto_refresh') ?? true;
      showLegends = prefs.getBool('setting_show_legends') ?? true;
      notificationMaxAgeMinutes =
          prefs.getInt('setting_notification_max_age') ?? 60;
      touristMode = prefs.getBool('setting_tourist_mode') ?? false;
      touristLanguage =
          touristLanguageNames.containsKey(
            prefs.getString('setting_tourist_language'),
          )
          ? prefs.getString('setting_tourist_language')!
          : 'en';
      satelliteOpacity = prefs.getDouble('setting_satellite_opacity') ?? .68;
      nearbyRadiusKm = prefs.getInt('setting_nearby_radius') ?? 35;
      newsMaxHours = prefs.getInt('setting_news_hours') ?? 48;
      favoriteCities
        ..clear()
        ..addAll(prefs.getStringList('setting_favorite_cities') ?? const []);
      final savedCity = prefs.getString('setting_city');
      if (savedCity != null) {
        city = cities.firstWhere(
          (item) => item.name == savedCity,
          orElse: () => cities.first,
        );
      }
      final savedMapLayers = prefs.getStringList('setting_map_layers');
      if (savedMapLayers != null) {
        enabled
          ..clear()
          ..addAll(
            savedMapLayers.where(
              (id) =>
                  id != 'traffic-live' &&
                  id != 'geo-risk' &&
                  id != 'official-maps' &&
                  id != 'river-levels' &&
                  id != 'river-quality' &&
                  id != 'air-stations' &&
                  !const {
                    'services',
                    'pharmacies',
                    'aed',
                    'mobility',
                    'utilities',
                    'civic-alerts',
                    'energy-grid',
                    'environment',
                    'sky-view',
                    'earth-night',
                    'radio',
                  }.contains(id),
            ),
          );
      }
      final savedCategory = prefs.getString('setting_map_category');
      selectedMapCategory =
          mapCategories.any((item) => item.id == savedCategory)
          ? savedCategory
          : mapCategories
                .where((item) => _categoryLayers(item.id).any(enabled.contains))
                .map((item) => item.id)
                .firstOrNull;
      final savedCategories = prefs.getStringList('setting_map_categories');
      activeMapCategories
        ..clear()
        ..addAll(
          savedCategories == null
              ? [?selectedMapCategory]
              : savedCategories.where(
                  (id) => mapCategories.any((category) => category.id == id),
                ),
        );
      if (selectedMapCategory != null &&
          !activeMapCategories.contains(selectedMapCategory)) {
        selectedMapCategory = activeMapCategories.firstOrNull;
      }
      expandedCategory = null;
      final savedNewsTypes = prefs.getStringList('setting_news_types');
      if (savedNewsTypes != null) {
        enabledNewsTypes
          ..clear()
          ..addAll(savedNewsTypes);
      }
      final savedNewsCountries = prefs.getStringList('setting_news_countries');
      if (savedNewsCountries != null) {
        enabledNewsCountries
          ..clear()
          ..addAll(savedNewsCountries);
        if (!(prefs.getBool('setting_country_expansion_v1') ?? false)) {
          enabledNewsCountries.addAll(const [
            'Maqedonia e Veriut',
            'Mali i Zi',
          ]);
        }
      }
      final savedHazards = prefs.getStringList('setting_hazard_types');
      if (savedHazards != null) {
        enabledHazards
          ..clear()
          ..addAll(savedHazards);
      }
      final savedLayers = prefs.getStringList('setting_notification_layers');
      if (savedLayers != null) {
        notificationLayers
          ..clear()
          ..addAll(savedLayers.where(notificationAllowedKeys.contains));
      }
    });
    if (touristMode) {
      final ready = await SyriTranslation.prepare();
      if (!mounted) return;
      setState(() {
        setSyriEnglish(ready);
        if (!ready) touristMode = false;
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && mapReady) mapController.move(city.point, 11);
      // Warm the on-device language models after the first frame so external
      // English alerts can be shown in Albanian without delaying map startup.
      if (mounted && !touristMode) unawaited(SyriTranslation.prepare());
    });
    _startPlaneTimer();
    if (notificationsEnabled &&
        prefs.getString('setting_notifications_started_at') == null) {
      unawaited(
        prefs.setString(
          'setting_notifications_started_at',
          notificationStart.toIso8601String(),
        ),
      );
    }
    unawaited(_configureBackgroundNotifications(notificationsEnabled));
    if (enabled.contains('satellite') && widget.loadData) {
      unawaited(_checkSatelliteImagery());
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setting_radar', showRadar);
    await prefs.setBool('setting_important_news', importantNewsOnly);
    await prefs.setInt('setting_plane_refresh', planeRefreshSeconds);
    await prefs.setBool('setting_notifications', notificationsEnabled);
    await prefs.setBool('setting_notification_world', worldNotifications);
    await prefs.setDouble('setting_quake_minimum', minimumEarthquakeMagnitude);
    await prefs.setBool('setting_notification_sound', notificationSound);
    await prefs.setBool('setting_notification_urgent', urgentNotificationsOnly);
    await prefs.setBool(
      'setting_notification_quiet',
      quietNotificationsAtNight,
    );
    await prefs.setBool('setting_auto_refresh', autoRefreshOnResume);
    await prefs.setBool('setting_show_legends', showLegends);
    await prefs.setInt(
      'setting_notification_max_age',
      notificationMaxAgeMinutes,
    );
    await prefs.setBool('setting_tourist_mode', touristMode);
    await prefs.setString('setting_tourist_language', touristLanguage);
    await prefs.setDouble('setting_satellite_opacity', satelliteOpacity);
    await prefs.setInt('setting_nearby_radius', nearbyRadiusKm);
    await prefs.setInt('setting_news_hours', newsMaxHours);
    await prefs.setStringList(
      'setting_favorite_cities',
      favoriteCities.toList(),
    );
    await prefs.setString('setting_city', city.name);
    await prefs.setStringList('setting_map_layers', enabled.toList());
    await prefs.setStringList(
      'setting_map_categories',
      activeMapCategories.toList(),
    );
    if (selectedMapCategory case final category?) {
      await prefs.setString('setting_map_category', category);
    } else {
      await prefs.remove('setting_map_category');
    }
    await prefs.setStringList('setting_news_types', enabledNewsTypes.toList());
    await prefs.setStringList(
      'setting_news_countries',
      enabledNewsCountries.toList(),
    );
    await prefs.setBool('setting_country_expansion_v1', true);
    await prefs.setStringList('setting_hazard_types', enabledHazards.toList());
    await prefs.setStringList(
      'setting_notification_layers',
      notificationLayers.toList(),
    );
  }

  Future<void> _clearDataCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKeys = prefs
        .getKeys()
        .where((key) => key.startsWith('data_') || key.startsWith('time_'))
        .toList();
    for (final key in cacheKeys) {
      await prefs.remove(key);
    }
    if (!mounted) return;
    setState(() {
      results.clear();
      weather = null;
      radar = null;
      airQuality = null;
      marineWeather = null;
      failures.clear();
      cacheBytesFuture = _cachedDataBytes();
    });
    _toast(
      _ui('Të dhënat e burimeve u pastruan.', 'Saved source data cleared.'),
    );
    if (widget.loadData) await refresh();
  }

  Future<int> _cachedDataBytes() async =>
      cachedSourceBytes(await SharedPreferences.getInstance());

  Future<void> _confirmClearDataCache() async {
    final bytes = await _cachedDataBytes();
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: mint.withValues(alpha: .35)),
        ),
        title: Text(
          _ui('Pastro të dhënat e burimeve?', 'Clear saved source data?'),
        ),
        content: Text(
          _ui(
            'Të dhëna të ruajtura nga burimet: ${formattedCacheSize(bytes)}. Këto kopje do të hiqen dhe do të shkarkohen përsëri. Harta e ruajtur dhe cilësimet nuk preken.',
            'Saved source data: ${formattedCacheSize(bytes)}. These copies will be removed and downloaded again. Cached map tiles and settings stay.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_ui('Anulo', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(_ui('Pastro', 'Clear')),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await _clearDataCache();
  }

  Future<void> _load(
    String key,
    Future<FeedResult<List<Event>>> Function() action,
  ) async {
    if (busy.contains(key)) return;
    final generation = cityGeneration;
    busy.add(key);
    failures.remove(key);
    sourceCheckedAt[key] = DateTime.now();
    _scheduleDataRender();
    try {
      final value = await action();
      const cityScoped = {
        'planes',
        'local',
        'traffic-jam',
        'speed-cameras',
        'police-alerts',
        'transit',
        'airports',
        'services',
        'pharmacies',
        'aed',
        'mobility',
        'drinking-water',
        'river-levels',
        'utilities',
        'health-alerts',
        'food-alerts',
        'port-alerts',
        'agriculture',
        'hydrology-alerts',
        'civic-alerts',
        'official-maps',
        'protected',
        'biodiversity',
        'water',
      };
      if (!mounted ||
          (cityScoped.contains(key) && generation != cityGeneration)) {
        return;
      }
      results[key] = value;
      if (value.stale) failures.add(key);
      _scheduleDataRender();
      await _rememberVisibleEvents(value.value, worldFeed: key == 'world');
    } catch (_) {
      if (mounted) {
        failures.add(key);
        _scheduleDataRender();
      }
    } finally {
      if (mounted) {
        busy.remove(key);
        _scheduleDataRender();
      }
    }
  }

  Future<void> _loadWeather({bool forceRefresh = false}) async {
    final generation = cityGeneration;
    setState(() {
      busy.add('weather');
      failures.remove('weather');
      sourceCheckedAt['weather'] = DateTime.now();
    });
    try {
      final value = await api.weather(city, forceRefresh: forceRefresh);
      if (!mounted || generation != cityGeneration) return;
      setState(() {
        weather = value;
        if (value.stale) failures.add('weather');
      });
    } catch (_) {
      if (mounted && generation == cityGeneration) {
        setState(() => failures.add('weather'));
      }
    } finally {
      if (mounted && generation == cityGeneration) {
        setState(() => busy.remove('weather'));
      }
    }
  }

  Future<void> _refreshWeather() async {
    if (busy.contains('weather')) return;
    await _loadWeather(forceRefresh: true);
    if (!mounted) return;
    if (failures.contains('weather')) {
      _weatherToast('Nuk u mor moti i ri; po shfaqet kopja e fundit.', false);
    } else {
      _weatherToast('Moti në ${city.name} u rifreskua.', true);
    }
  }

  Future<void> refresh() async {
    if (!widget.loadData) return;
    await Future.wait([
      _loadWeather(),
      _load('quakes', api.earthquakes),
      for (final source in regionalNewsSources)
        _load(source.name, () => api.news(source.name, source.url)),
      _load('local', () => api.localNews(city)),
      _load('world', api.worldNews),
      if (enabled.contains('planes')) _load('planes', () => api.aircraft(city)),
      if (enabled.contains('hazards')) ...[
        _load('fires', api.activeFires),
        _load('hazards', api.hazards),
      ],
      if (enabled.contains('weather')) _loadRadar(),
      _loadAirQuality(),
      if (enabled.contains('marine')) _loadMarineWeather(),
      if (enabled.contains('satellite')) _checkSatelliteImagery(),
      for (final id in const [
        'roadwork',
        'traffic-jam',
        'speed-cameras',
        'police-alerts',
        'borders',
        'transit',
        'services',
        'pharmacies',
        'aed',
        'mobility',
        'drinking-water',
        'places',
        'cems',
        'cameras',
        'ships',
        'water',
        'utilities',
        'health-alerts',
        'food-alerts',
        'port-alerts',
        'agriculture',
        'hydrology-alerts',
        'civic-alerts',
        'official-maps',
        'protected',
        'biodiversity',
      ])
        if (enabled.contains(id)) _loadLayer(id),
    ]);
  }

  Future<void> _refreshEventsOnOpen({bool force = false}) async {
    if (!widget.loadData) return;
    final now = DateTime.now();
    if (!force &&
        _lastEventsRefresh != null &&
        now.difference(_lastEventsRefresh!) < const Duration(minutes: 2)) {
      return;
    }
    _lastEventsRefresh = now;
    await Future.wait([
      _loadWeather(forceRefresh: true),
      _load('quakes', api.earthquakes),
      _load('fires', api.activeFires),
      _load('hazards', api.hazards),
      for (final source in regionalNewsSources)
        if (enabledNewsCountries.contains(source.country))
          _load(
            source.name,
            () => api.news(source.name, source.url, forceRefresh: true),
          ),
      _load('local', () => api.localNews(city)),
      if (eventFilter == 'Bota') _load('world', api.worldNews),
      for (final id in const [
        'utilities',
        'health-alerts',
        'food-alerts',
        'hydrology-alerts',
        'civic-alerts',
        'port-alerts',
      ])
        _loadLayer(id),
    ]);
  }

  void _updateNewsCache() {
    final countryFilter = enabledNewsCountries.toList()..sort();
    final cacheKey = Object.hash(
      DateTime.now().millisecondsSinceEpoch ~/ 60000,
      newsMaxHours,
      importantNewsOnly,
      Object.hashAll(countryFilter),
      Object.hashAll([
        for (final source in regionalNewsSources) results[source.name]?.value,
        results['local']?.value,
      ]),
    );
    if (_newsCacheKey == cacheKey) return;
    final value = <Event>[
      for (final source in regionalNewsSources) ...?results[source.name]?.value,
      ...?results['local']?.value,
    ];
    final cutoff = DateTime.now().subtract(Duration(hours: newsMaxHours));
    final uniqueUrls = <String>{};
    value.removeWhere(
      (event) =>
          event.time == null ||
          event.time!.isBefore(cutoff) ||
          !_isRegionalNews(event) ||
          !_newsCountryEnabled(event) ||
          !uniqueUrls.add(event.url) ||
          (importantNewsOnly && !event.important),
    );
    value.sort(
      (a, b) => (b.time ?? DateTime(1970)).compareTo(a.time ?? DateTime(1970)),
    );
    _cachedRawNews = value;
    _cachedNews = collapseNewsStories(value);
    _newsCacheKey = cacheKey;
  }

  List<Event> get _allNews {
    _updateNewsCache();
    return _cachedRawNews;
  }

  List<Event> get news {
    _updateNewsCache();
    return _cachedNews;
  }

  bool _isRegionalNews(Event event) {
    if (event.point != null) return true;
    final text = normalize('${event.title} ${event.summary ?? ''}');
    return const [
      'shqiperi',
      'shqiptar',
      'kosove',
      'kosovar',
      'albania',
      'tirane',
      'prishtine',
      'maqedoni',
      'tetove',
      'gostivar',
      'struge',
      'kercove',
      'mali i zi',
      'ulqin',
      'tuz',
    ].any(text.contains);
  }

  bool _newsCountryEnabled(Event event) {
    final country = newsCountry(event);
    return country == null
        ? enabledNewsCountries.length == supportedNewsCountries.length
        : enabledNewsCountries.contains(country);
  }

  List<Event> get worldNews {
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final items = <Event>[
      for (final source in regionalNewsSources) ...?results[source.name]?.value,
    ];
    final seen = <String>{};
    items.removeWhere(
      (event) =>
          event.time == null ||
          event.time!.isBefore(cutoff) ||
          _isRegionalNews(event) ||
          !_isMajorWorldNews(event) ||
          !seen.add(normalize(event.title)),
    );
    items.sort(
      (a, b) => (b.time ?? DateTime(1970)).compareTo(a.time ?? DateTime(1970)),
    );
    if (items.isNotEmpty) return items.take(8).toList();
    return (results['world']?.value ?? const <Event>[]).take(8).toList();
  }

  bool _isMajorWorldNews(Event event) {
    final text = normalize('${event.title} ${event.summary ?? ''}');
    return const [
      'lufte',
      'sulm',
      'raket',
      'armepushim',
      'zgjedhje',
      'president',
      'kryeminister',
      'qeveri',
      'parlament',
      'termet',
      'stuhi',
      'permbyt',
      'shperthim',
      'krize',
      'vrit',
      'marreveshje',
      'nato',
      'ukraine',
      'rusi',
      'izrael',
      'iran',
      'kine',
      'shba',
    ].any(text.contains);
  }

  bool _passesEarthquakeMinimum(Event event) =>
      event.kind != 'quakes' ||
      (double.tryParse(
                RegExp(r'M\s*([0-9.]+)').firstMatch(event.title)?.group(1) ??
                    '',
              ) ??
              0) >=
          minimumEarthquakeMagnitude;

  List<Event> get mapEvents => [
    if (enabled.contains('marine') &&
        marineWeather != null &&
        const Distance().as(
              LengthUnit.Kilometer,
              city.point,
              _nearestPortPoint(),
            ) <
            80)
      Event(
        id: 'marine-${city.name}',
        title: 'Gjendja e detit pranë ${city.name}',
        description: 'Parashikim detar nga Open-Meteo.',
        source: 'Open-Meteo',
        url: 'https://open-meteo.com/en/docs/marine-weather-api',
        kind: 'marine',
        point: _nearestPortPoint(),
      ),
    if (enabled.contains('news'))
      ...news.where(
        (event) =>
            event.point != null && enabledNewsTypes.contains(event.newsType),
      ),
    if (enabled.contains('quakes'))
      ...(results['quakes']?.value ?? const <Event>[]).where(
        _passesEarthquakeMinimum,
      ),
    if (enabled.contains('planes')) ...?results['planes']?.value,
    if (enabled.contains('hazards'))
      ...(results['fires']?.value ?? const <Event>[]).where(
        (event) => enabledHazards.contains(event.kind),
      ),
    if (enabled.contains('hazards'))
      ...(results['hazards']?.value ?? const <Event>[]).where(
        (event) => enabledHazards.contains(event.kind),
      ),
    if (enabled.contains('cameras')) ...?results['cameras']?.value,
    if (enabled.contains('tv'))
      ...tvChannels
          .where((channel) => enabledNewsCountries.contains(channel.country))
          .map((channel) => channel.toEvent()),
    if (enabled.contains('ships'))
      ...(results['ships']?.value ?? const <Event>[]).where(
        (event) => enabledNewsCountries.contains(
          event.id.endsWith('-me') ? 'Mali i Zi' : 'Shqipëri',
        ),
      ),
    if (enabled.contains('roadwork')) ...?results['roadwork']?.value,
    if (enabled.contains('traffic-jam')) ...?results['traffic-jam']?.value,
    if (enabled.contains('speed-cameras')) ...?results['speed-cameras']?.value,
    if (enabled.contains('police-alerts')) ...?results['police-alerts']?.value,
    if (enabled.contains('borders')) ...?results['borders']?.value,
    if (enabled.contains('transit')) ...?results['transit']?.value,
    if (enabled.contains('airports')) ...?results['airports']?.value,
    if (enabled.contains('services'))
      ...(results['services']?.value ?? const <Event>[]).where(
        (event) => const {
          'health',
          'police',
          'fire_station',
          'services',
        }.contains(event.kind),
      ),
    if (enabled.contains('pharmacies'))
      ...(results['pharmacies']?.value ?? const <Event>[]).where(
        (event) => event.kind == 'pharmacy',
      ),
    if (enabled.contains('aed'))
      ...(results['aed']?.value ?? const <Event>[]).where(
        (event) => event.kind == 'aed',
      ),
    if (enabled.contains('mobility'))
      ...(results['mobility']?.value ?? const <Event>[]).where(
        (event) => const {'parking', 'charging'}.contains(event.kind),
      ),
    if (enabled.contains('utilities')) ...?results['utilities']?.value,
    if (enabled.contains('water'))
      ...(results['water']?.value ?? const <Event>[]).where(
        (event) => enabledNewsCountries.contains(
          event.id.endsWith('-me') ? 'Mali i Zi' : 'Shqipëri',
        ),
      ),
    if (enabled.contains('drinking-water'))
      ...?results['drinking-water']?.value,
    if (enabled.contains('river-levels')) ...?results['river-levels']?.value,
    if (enabled.contains('places')) ...?results['places']?.value,
    if (enabled.contains('cems')) ...?results['cems']?.value,
    if (enabled.contains('health-alerts')) ...?results['health-alerts']?.value,
    if (enabled.contains('food-alerts')) ...?results['food-alerts']?.value,
    if (enabled.contains('port-alerts')) ...?results['port-alerts']?.value,
    if (enabled.contains('agriculture'))
      ...(results['agriculture']?.value ?? const <Event>[]).where(
        (event) => event.kind != 'agriculture-info',
      ),
    if (enabled.contains('hydrology-alerts'))
      ...?results['hydrology-alerts']?.value,
    if (enabled.contains('civic-alerts')) ...?results['civic-alerts']?.value,
    if (enabled.contains('energy-grid')) ...?results['energy-grid']?.value,
    if (enabled.contains('internet-outages'))
      ...?results['internet-outages']?.value,
    if (enabled.contains('population')) ...?results['population']?.value,
    if (enabled.contains('protected')) ...?results['protected']?.value,
    if (enabled.contains('biodiversity')) ...?results['biodiversity']?.value,
  ];

  void _toast(String value) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xff122927),
          elevation: 12,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 104),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: mint.withValues(alpha: .65)),
          ),
          content: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: mint, size: 19),
              const SizedBox(width: 10),
              Expanded(
                child: AppText(
                  value,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
  }

  void _weatherToast(String message, bool success) {
    _weatherToastTimer?.cancel();
    setState(() {
      _weatherToastMessage = message;
      _weatherToastSuccess = success;
    });
    _weatherToastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _weatherToastMessage = null);
    });
  }

  Widget _weatherToastChip() {
    final success = _weatherToastSuccess;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 9, 18, 0),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: glassBlur, sigmaY: glassBlur),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: glassSurface(
                18,
                outline: success ? mint : Colors.amber,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    success ? Icons.check_circle_outline : Icons.info_outline,
                    color: success ? mint : Colors.amber,
                    size: 16,
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: AppText(
                      _weatherToastMessage ?? '',
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _offlineNoticeChip() => Dismissible(
    key: const ValueKey('offline-notice'),
    direction: DismissDirection.horizontal,
    onDismissed: (_) {
      _offlineNoticeTimer?.cancel();
      if (mounted) setState(() => _showOfflineNotice = false);
    },
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: glassBlur, sigmaY: glassBlur),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: glassSurface(18, outline: Colors.amber),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    color: Colors.amber,
                    size: 16,
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: AppText(
                      _ui(
                        'Pa internet · po shfaqen të dhënat e ruajtura',
                        'Offline · showing saved data',
                      ),
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Set<String> _notificationKeys(Event event) {
    if (event.kind == 'news') return {'news', 'news:${event.newsType}'};
    if (const {
      'fire',
      'storm',
      'flood',
      'volcano',
      'hazards',
    }.contains(event.kind)) {
      return {'alerts', 'hazard:${event.kind}'};
    }
    if (event.kind == 'quakes') return {'alerts', 'quakes'};
    if (const {
      'power-outage',
      'water-outage',
      'civic-alert',
      'energy-grid',
      'internet-outage',
    }.contains(event.kind)) {
      return {
        'services',
        event.kind == 'civic-alert' ? 'civic-alerts' : 'utilities',
        event.kind,
      };
    }
    if (const {
      'frost',
      'hail',
      'drought',
      'heat',
      'wind',
    }.contains(event.kind)) {
      return {'weather', 'agriculture', event.kind};
    }
    if (const {
      'planes',
      'transit',
      'roadwork',
      'traffic-jam',
      'speed-camera',
      'police-alert',
      'borders',
      'airport-arrival',
      'airport-departure',
    }.contains(event.kind)) {
      return {'transport', event.kind};
    }
    if (const {
      'health-alert',
      'food-alert',
      'hydrology-alert',
      'cems',
    }.contains(event.kind)) {
      return {'alerts', '${event.kind}s', event.kind};
    }
    if (const {
      'ships',
      'port-alert',
      'water',
      'drinking-water',
    }.contains(event.kind)) {
      return {'sea', event.kind};
    }
    if (const {'environment', 'river-level'}.contains(event.kind)) {
      return {
        'environment',
        event.kind == 'river-level' ? 'river-levels' : event.kind,
      };
    }
    return {event.kind};
  }

  Future<void> _rememberVisibleEvents(
    List<Event> events, {
    bool worldFeed = false,
  }) async {
    if (!notificationsEnabled || events.isEmpty) return;
    if (worldFeed && !worldNotifications) return;
    // Opening the app is not a notification event. A cold start can still be
    // in an inactive lifecycle state while feeds load, which previously sent
    // a burst of old reports just as the user opened the map.
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) return;
    final now = DateTime.now();
    final cutoff = now.subtract(Duration(minutes: notificationMaxAgeMinutes));
    final seen = events
        .where(
          (event) =>
              event.time != null &&
              event.time!.isAfter(cutoff) &&
              isEventsFeedKind(event.kind) &&
              _notificationKeys(event).any(notificationLayers.contains),
        )
        .map((event) => event.id);
    notifiedEventIds.addAll(seen);
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    notifiedEventIds.addAll(
      prefs.getStringList('setting_notified_ids') ?? const <String>[],
    );
    await prefs.setStringList(
      'setting_notified_ids',
      notifiedEventIds.toList().reversed.take(500).toList(),
    );
  }

  Future<bool> _requestNotificationPermission() async {
    await initializeNotifications();
    final android = syriNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final ios = syriNotifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final androidAllowed = await android?.requestNotificationsPermission();
    final iosAllowed = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return androidAllowed ?? iosAllowed ?? true;
  }

  Future<void> _showNotification(
    String title,
    String body, {
    String? payload,
  }) async {
    await initializeNotifications();
    final hour = DateTime.now().hour;
    if (quietNotificationsAtNight && (hour >= 23 || hour < 7)) return;
    final notificationTitle = syriEnglish
        ? await SyriTranslation.translate(title)
        : title;
    final notificationBody = syriEnglish
        ? await SyriTranslation.translate(body)
        : body;
    await syriNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      title: notificationTitle,
      body: notificationBody,
      payload: payload,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'syri_alerts',
          'Alarmet SYRI',
          channelDescription: 'Alarmet publike të zgjedhura në SYRI',
          importance: Importance.high,
          priority: Priority.high,
          playSound: notificationSound,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(presentSound: notificationSound),
      ),
    );
  }

  Future<void> _open(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme)) {
      _toast('Lidhja nuk është e vlefshme.');
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _toast('Lidhja nuk u hap.');
      }
    } catch (_) {
      _toast('Lidhja nuk u hap. Kontrolloni internetin.');
    }
  }

  Future<void> _loadLayer(String id) async {
    if (id == 'satellite') await _checkSatelliteImagery();
    if (id == 'planes') await _load(id, () => api.aircraft(city));
    if (id == 'hazards') {
      _load('fires', api.activeFires);
      await _load(id, api.hazards);
    }
    if (id == 'roadwork') await _load(id, api.roadAlerts);
    if (id == 'traffic-jam') {
      await _load(id, () => api.trafficCongestion(city));
    }
    if (id == 'speed-cameras') {
      await _load(id, () => api.speedCameras(city));
    }
    if (id == 'police-alerts') {
      await _load(id, () => api.officialRoadSafetyNotices(city));
    }
    if (id == 'borders') await _load(id, api.borderCrossings);
    if (id == 'transit') await _load(id, () => api.transit(city));
    if (id == 'airports') {
      await _load(id, () async {
        final directory = api.regionalAirports(enabledNewsCountries);
        if (!enabledNewsCountries.contains('Shqipëri')) {
          return FeedResult(directory, DateTime.now(), false);
        }
        try {
          final flights = await api.tiranaAirportFlights();
          return FeedResult(
            [...directory, ...flights.value],
            flights.fetched,
            flights.stale,
          );
        } catch (_) {
          return FeedResult(directory, DateTime.now(), true);
        }
      });
    }
    if (id == 'services') await _load(id, () => api.nearbyServices(city));
    if (id == 'places') await _load(id, () => api.nearbyPlaces(city));
    if (id == 'protected') {
      await _load(id, () async {
        final regional = api.regionalProtectedAreas(enabledNewsCountries);
        if (!enabledNewsCountries.contains(city.country)) {
          return FeedResult(regional, DateTime.now(), false);
        }
        try {
          final local = await api.protectedAreas(city);
          return FeedResult(
            [...regional, ...local.value],
            local.fetched,
            local.stale,
          );
        } catch (_) {
          return FeedResult(regional, DateTime.now(), true);
        }
      });
    }
    if (id == 'biodiversity') {
      await _load(id, () => api.biodiversityObservations(enabledNewsCountries));
    }
    if (id == 'drinking-water') {
      await _load(id, () => api.drinkingWater(city));
    }
    if (id == 'river-levels') {
      await _load(id, api.kosovoRiverLevels);
    }
    if (id == 'cems') await _load(id, api.copernicusEvents);
    if (id == 'air') await _loadAirQuality();
    if (id == 'marine') await _loadMarineWeather();
    if (id == 'weather') await _loadRadar();
    if (id == 'cameras') {
      await _load(id, api.cameras);
    }
    if (id == 'ships') {
      setState(
        () => results[id] = FeedResult(api.ships(), DateTime.now(), false),
      );
    }
    if (id == 'water') {
      await _load(id, () async {
        Future<FeedResult<List<Event>>> safe(
          Future<FeedResult<List<Event>>> Function() loader,
        ) async {
          try {
            return await loader();
          } catch (_) {
            return FeedResult(const <Event>[], DateTime.now(), true);
          }
        }

        final feeds = await Future.wait([
          if (enabledNewsCountries.contains('Shqipëri'))
            safe(api.bathingWaterQuality),
          if (enabledNewsCountries.contains('Mali i Zi'))
            safe(api.montenegroBathingWater),
        ]);
        return FeedResult(
          [
            ...feeds.expand((feed) => feed.value),
            ...api.inlandBathingWater(enabledNewsCountries),
          ],
          feeds.isEmpty ? DateTime.now() : feeds.last.fetched,
          feeds.any((feed) => feed.stale),
        );
      });
    }
    if (id == 'utilities') {
      await _load(id, () => api.utilityAlerts(city));
    }
    if (id == 'health-alerts') {
      await _load(id, () => api.healthAlerts(city));
    }
    if (id == 'food-alerts') {
      await _load(id, () => api.foodAlerts(city));
    }
    if (id == 'port-alerts') {
      await _load(id, () => api.portAlerts(city));
    }
    if (id == 'agriculture') {
      await _load(id, () => api.agricultureAlerts(city));
    }
    if (id == 'hydrology-alerts') {
      await _load(id, () => api.hydrologyAlerts(city));
    }
    if (id == 'civic-alerts') {
      await _load(id, () => api.civicAlerts(city));
    }
    if (id == 'energy-grid') {
      setState(() => results[id] = api.energyGrid());
    }
    if (id == 'internet-outages') {
      await _load(id, api.internetOutages);
    }
    if (const {'pharmacies', 'aed', 'mobility'}.contains(id)) {
      await _load(id, () => api.nearbyServices(city));
    }
    if (id == 'official-maps') {
      final portals = [
        for (final country in supportedNewsCountries)
          if (enabledNewsCountries.contains(country))
            (
              country: country,
              portal: switch (country) {
                'Kosovë' => (
                  code: 'xk',
                  title: 'Geoportali zyrtar i Kosovës',
                  source: 'Agjencia Kadastrale e Kosovës',
                  url: 'https://geoportal.rks-gov.net/portal/main',
                  coverage: 'Kosovë',
                ),
                'Maqedonia e Veriut' => (
                  code: 'mk',
                  title: 'Geoportali zyrtar i Maqedonisë së Veriut',
                  source: 'Agjencia e Kadastrës së Patundshmërive',
                  url: 'https://ossp.katastar.gov.mk/OSSP/',
                  coverage: 'Maqedonia e Veriut',
                ),
                'Mali i Zi' => (
                  code: 'me',
                  title: 'Geoportali zyrtar i Malit të Zi',
                  source: 'Administrata e Pronës së Paluajtshme',
                  url: 'https://geoportal.co.me/',
                  coverage: 'Mali i Zi',
                ),
                _ => (
                  code: 'al',
                  title: 'Geoportali zyrtar ASIG',
                  source: 'ASIG',
                  url: 'https://geoportal.asig.gov.al/',
                  coverage: 'Shqipëri',
                ),
              },
            ),
      ];
      setState(() {
        results[id] = FeedResult(
          [
            for (final item in portals)
              Event(
                id: 'geoportal-${item.portal.code}',
                title: item.portal.title,
                description:
                    'Mbulimi: ${item.portal.coverage}\nShtresa: ortofoto, njësi administrative, hidrografi, rrjet rrugor dhe harta topografike\nBurimi: ${item.portal.source}\nHapni burimin për hartën interaktive zyrtare.',
                source: item.portal.source,
                url: item.portal.url,
                kind: 'geoportal',
                point: cities
                    .firstWhere((place) => place.country == item.country)
                    .point,
                approximate: true,
              ),
          ],
          DateTime.now(),
          false,
        );
      });
    }
    if (id == 'population') {
      final figures = [
        (
          country: 'Shqipëri',
          value: '2 335 930',
          year: '1 janar 2026',
          source: 'INSTAT',
          url: 'https://www.instat.gov.al/sq/temat/treguesit-demografike-dhe-sociale/popullsia/publikimet/2026/popullsia-e-shqiperise-1-janar-2026/',
        ),
        (
          country: 'Kosovë',
          value: '1 585 590',
          year: '2024',
          source: 'ASK',
          url: 'https://ask.rks-gov.net/Releases/Details/8656',
        ),
        (
          country: 'Maqedonia e Veriut',
          value: '1 820 509',
          year: '30 qershor 2025',
          source: 'Enti Shtetëror i Statistikës',
          url: 'https://makstat.stat.gov.mk/PXWeb/pxweb/en/MakStat/MakStat__Naselenie__ProcenkiNaselenie__ProcenkiPopis2021__Proceni30Juni/30062021_MKD_Za_PX.px/',
        ),
        (
          country: 'Mali i Zi',
          value: '623 115',
          year: 'mesi i vitit 2025',
          source: 'MONSTAT',
          url: 'https://www.monstat.org/cg/novosti.php?id=4700',
        ),
      ];
      setState(
        () => results[id] = FeedResult(
          [
            for (final item in figures)
              if (enabledNewsCountries.contains(item.country))
                Event(
                  id: 'population-${item.country}',
                  title: 'Popullsia e ${item.country}: ${item.value}',
                  description:
                      'Vlera: ${item.value} banorë\nPeriudha: ${item.year}\nBurimi: ${item.source}\nShënim: Ky është tregues kombëtar, jo dendësia e zonës ku është vendosur ikona.',
                  source: item.source,
                  url: item.url,
                  kind: 'population',
                  point: cities
                      .firstWhere((place) => place.country == item.country)
                      .point,
                  approximate: true,
                ),
          ],
          DateTime.now(),
          false,
        ),
      );
    }
  }

  List<String> _categoryLayers(String id) => switch (id) {
    'alerts' => [
      'quakes',
      'hazards',
      'cems',
      'health-alerts',
      'food-alerts',
      'hydrology-alerts',
      'internet-outages',
      'landslides',
    ],
    'weather' => ['weather', 'air', 'agriculture'],
    'services' => [
      'services',
      'pharmacies',
      'aed',
      'mobility',
      'utilities',
      'civic-alerts',
      'energy-grid',
    ],
    'territory' => [
      'land-cover',
      'flood-zones',
      'population',
      'protected',
      'biodiversity',
      'satellite',
    ],
    'sea' => ['marine', 'port-alerts', 'ships', 'water', 'drinking-water'],
    'transport' => [
      'planes',
      'airports',
      'traffic-jam',
      'speed-cameras',
      'police-alerts',
      'transit',
      'roadwork',
      'borders',
    ],
    _ => [id],
  };

  bool _categoryActive(String id) => activeMapCategories.contains(id);

  bool _needsLayerLoad(String id) =>
      _online == false &&
          (results[id] != null ||
              (id == 'weather' && radar != null) ||
              (id == 'air' && airQuality != null) ||
              (id == 'marine' && marineWeather != null))
      ? false
      : switch (id) {
          'tv' => false,
          'planes' => true,
          'weather' => radar == null || radar!.stale,
          'air' => airQuality == null || airQuality!.stale,
          'marine' => marineWeather == null || marineWeather!.stale,
          _ => results[id] == null || results[id]!.stale,
        };

  List<String> get _activeReferenceLayers =>
      _referenceLayerIds.where(enabled.contains).toList();

  void _clearAllLayers() {
    setState(() {
      enabled.clear();
      enabledNewsTypes.clear();
      enabledHazards.clear();
      enabledCameraTypes.clear();
      radar = null;
      rainLegendDismissed = true;
      waterLegendDismissed = true;
      airLegendDismissed = true;
      mapLegendDismissed = true;
      dismissedReferenceLegends.clear();
      satelliteLegendDismissed = true;
      selectedMapCategory = null;
      activeMapCategories.clear();
      expandedCategory = null;
    });
    _startPlaneTimer();
    unawaited(_saveSettings());
  }

  void _setCategory(String id, bool turnOn) {
    final layers = _categoryLayers(id);
    setState(() {
      if (turnOn) {
        activeMapCategories.add(id);
        selectedMapCategory = id;
        enabled.addAll(layers);
        if (id == 'territory') {
          mapLegendDismissed = false;
          dismissedReferenceLegends.clear();
        }
        if (id == 'territory') satelliteLegendDismissed = false;
        if (id == 'weather') rainLegendDismissed = false;
        if (id == 'weather') {
          airLegendDismissed = false;
        }
        if (id == 'sea') waterLegendDismissed = false;
        if (id == 'news') {
          enabledNewsTypes.addAll(const {
            'good',
            'major',
            'crash',
            'crime',
            'violence',
            'death',
            'fire',
            'weather',
          });
        }
        if (id == 'alerts') {
          enabledHazards.addAll(const {
            'fire',
            'storm',
            'flood',
            'volcano',
            'hazards',
          });
        }
        if (id == 'cameras') {
          enabledCameraTypes.addAll(const {
            'traffic',
            'city',
            'border',
            'nature',
            'youtube',
          });
        }
      } else {
        activeMapCategories.remove(id);
        for (final layer in layers) {
          if (!activeMapCategories.any(
            (category) => _categoryLayers(category).contains(layer),
          )) {
            enabled.remove(layer);
          }
        }
        if (selectedMapCategory == id) {
          selectedMapCategory = activeMapCategories.firstOrNull;
        }
        if (expandedCategory == id) expandedCategory = null;
        if (id == 'news') enabledNewsTypes.clear();
        if (id == 'alerts') enabledHazards.clear();
        if (id == 'cameras') enabledCameraTypes.clear();
      }
    });
    if (turnOn && widget.loadData) {
      for (final layer in layers) {
        if (!_needsLayerLoad(layer)) continue;
        if (layer == 'quakes') {
          _load('quakes', api.earthquakes);
        } else {
          _loadLayer(layer);
        }
      }
    }
    _startPlaneTimer();
    unawaited(_saveSettings());
  }

  Future<void> _loadAirQuality() async {
    final generation = cityGeneration;
    sourceCheckedAt['air'] = DateTime.now();
    failures.remove('air');
    try {
      final value = await api.airQuality(city);
      if (mounted && generation == cityGeneration) {
        setState(() {
          airQuality = value;
          if (value.stale) failures.add('air');
        });
      }
    } catch (_) {
      if (mounted) setState(() => failures.add('air'));
    }
    if (mounted && generation == cityGeneration && enabled.contains('air')) {
      unawaited(_loadRegionalAirQuality(generation));
    }
  }

  Future<void> _loadRegionalAirQuality(int generation) async {
    final selected = cities
        .where((item) => enabledNewsCountries.contains(item.country))
        .toList();
    final readings = await api.airQualityForCities(selected);
    if (mounted && generation == cityGeneration) {
      setState(() {
        regionalAirQuality
          ..clear()
          ..addAll(readings);
      });
    }
  }

  Future<void> _loadMarineWeather() async {
    final generation = cityGeneration;
    sourceCheckedAt['marine'] = DateTime.now();
    failures.remove('marine');
    try {
      final value = await api.marine(city);
      if (mounted && generation == cityGeneration) {
        setState(() {
          marineWeather = value;
          if (value.stale) failures.add('marine');
        });
      }
    } catch (_) {
      if (mounted && generation == cityGeneration) {
        setState(() => failures.add('marine'));
      }
    }
  }

  Future<void> _loadRadar() async {
    if (!showRadar) return;
    sourceCheckedAt['radar'] = DateTime.now();
    failures.remove('radar');
    try {
      final value = await api.radar();
      if (mounted) {
        setState(() {
          radar = value;
          if (value.stale) failures.add('radar');
        });
      }
    } catch (_) {
      if (mounted) setState(() => failures.add('radar'));
    }
  }

  void _selectCity(City value) {
    cityGeneration++;
    setState(() {
      city = value;
      weather = null;
      airQuality = null;
      marineWeather = null;
      results.remove('planes');
      results.remove('local');
      results.remove('transit');
      results.remove('traffic-jam');
      results.remove('speed-cameras');
      results.remove('police-alerts');
      results.remove('services');
      results.remove('drinking-water');
      results.remove('places');
      results.remove('utilities');
      results.remove('health-alerts');
      results.remove('food-alerts');
      results.remove('port-alerts');
      results.remove('agriculture');
      results.remove('hydrology-alerts');
      results.remove('civic-alerts');
      results.remove('protected');
      busy.removeAll(const {
        'planes',
        'local',
        'traffic-jam',
        'speed-cameras',
        'police-alerts',
        'transit',
        'services',
        'drinking-water',
        'utilities',
        'health-alerts',
        'food-alerts',
        'port-alerts',
        'agriculture',
        'hydrology-alerts',
        'civic-alerts',
        'protected',
      });
    });
    if (mapReady) mapController.move(value.point, 11);
    if (widget.loadData) {
      _loadWeather();
      _loadAirQuality();
      _load('local', () => api.localNews(city));
      for (final id in const [
        'planes',
        'traffic-jam',
        'transit',
        'services',
        'drinking-water',
        'places',
        'utilities',
        'marine',
        'health-alerts',
        'food-alerts',
        'port-alerts',
        'agriculture',
        'hydrology-alerts',
        'civic-alerts',
        'protected',
      ]) {
        if (enabled.contains(id)) _loadLayer(id);
      }
    }
    unawaited(_saveSettings());
  }

  Future<void> _locate() async {
    setState(() => locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _toast('Aktivizoni vendndodhjen ose zgjidhni qytetin.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _toast('Vendndodhja nuk u lejua. Harta punon edhe manualisht.');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );
      if (!mounted) return;
      userPoint = LatLng(position.latitude, position.longitude);
      setState(() {});
      if (mapReady) mapController.move(userPoint!, 13);
    } catch (_) {
      _toast('Pozicioni nuk u gjet. Provoni përsëri.');
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  void _sheet(Widget child, {Color accent = mint}) => showModalBottomSheet(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .52),
    builder: (_) => _SwipeDismissSheet(accent: accent, child: child),
  );

  Widget _heading(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppText(
        title,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -.8,
        ),
      ),
      const SizedBox(height: 7),
      AppText(subtitle, style: const TextStyle(color: muted, height: 1.5)),
      const SizedBox(height: 22),
    ],
  );

  @override
  Widget build(BuildContext context) => _showWelcome && !_mapShellReady
      ? const SyriWelcomeOverlay()
      : Stack(
          fit: StackFit.expand,
          children: [
            Scaffold(
              extendBody: true,
              body: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    _topBar(),
                    if (tab != 0 && _showOfflineNotice) _offlineNoticeChip(),
                    if (tab != 0 && _weatherToastMessage != null)
                      _weatherToastChip(),
                    Expanded(
                      child: IndexedStack(
                        index: tab == 0 ? 0 : 1,
                        children: [
                          _mapPage(),
                          tab == 1
                              ? _eventsPage()
                              : tab == 2
                              ? _settingsPage()
                              : _donatePage(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: _dock(),
            ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_showWelcome,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  child: _showWelcome
                      ? const SyriWelcomeOverlay(key: ValueKey('welcome'))
                      : const SizedBox.shrink(key: ValueKey('welcome-hidden')),
                ),
              ),
            ),
          ],
        );

  Widget _dock() => SafeArea(
    minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: glassBlur, sigmaY: glassBlur),
        child: Container(
          height: 58,
          padding: const EdgeInsets.all(4),
          decoration: glassSurface(
            34,
            shadows: const [
              BoxShadow(
                color: Color(0x55000000),
                blurRadius: 22,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              _dockItem(0, Icons.map_outlined, Icons.map, _ui('Harta', 'Map')),
              _dockItem(
                1,
                Icons.dynamic_feed_outlined,
                Icons.dynamic_feed,
                _ui('Ngjarje', 'Events'),
              ),
              _dockItem(
                2,
                Icons.settings_outlined,
                Icons.settings,
                _ui('Cilësime', 'Settings'),
              ),
              _dockItem(
                3,
                Icons.volunteer_activism_outlined,
                Icons.volunteer_activism,
                _ui('Mbështet', 'Support'),
                accent: donationAccent,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _dockItem(
    int index,
    IconData idleIcon,
    IconData activeIcon,
    String label, {
    Color accent = mint,
  }) {
    final selected = tab == index;
    return Expanded(
      child: Tooltip(
        message: label,
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: ValueKey('dock-$index'),
              borderRadius: BorderRadius.circular(27),
              splashColor: accent.withValues(alpha: .22),
              highlightColor: accent.withValues(alpha: .10),
              onTap: () {
                if (selected) return;
                HapticFeedback.selectionClick();
                setState(() {
                  tab = index;
                  if (index == 2) cacheBytesFuture = _cachedDataBytes();
                });
                _startPlaneTimer();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  color: selected
                      ? accent.withValues(alpha: .13)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(27),
                  border: Border.all(
                    color: selected
                        ? accent.withValues(alpha: .34)
                        : Colors.transparent,
                  ),
                ),
                child: Center(
                  child: AnimatedScale(
                    scale: selected ? 1.09 : 1,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutBack,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOut,
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: Icon(
                        selected ? activeIcon : idleIcon,
                        key: ValueKey(selected),
                        size: 24,
                        color: selected ? accent : const Color(0xffd5d8ca),
                        shadows: selected
                            ? [
                                Shadow(
                                  color: accent.withValues(alpha: .7),
                                  blurRadius: 12,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: glassBlur, sigmaY: glassBlur),
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: glassSurface(
            24,
            shadows: const [
              BoxShadow(
                color: Color(0x44000000),
                blurRadius: 20,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Stack(
            children: [
              IgnorePointer(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          mint.withValues(alpha: .34),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xffe1ff91), mint, Color(0xff63dca3)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .48),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: mint.withValues(alpha: .34),
                            blurRadius: 13,
                            spreadRadius: 1,
                          ),
                          const BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 7,
                            offset: Offset(2, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.visibility_outlined,
                        color: ink,
                        size: 23,
                        shadows: [Shadow(color: Colors.white54, blurRadius: 3)],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const AppText(
                      'SYRI',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: InkWell(
                  onTap: _cityPicker,
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    width: 82,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .045),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: mint.withValues(alpha: .16)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.place_outlined, size: 17, color: mint),
                        const SizedBox(height: 1),
                        AppText(
                          _cityDisplayName,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: _compactSyriNowButton(),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  String get _cityDisplayName {
    if (city.name.length <= 9) return city.name;
    return const {
          'Fushë Kosovë': 'FK',
          'Gjirokastër': 'GJ',
          'Pogradec': 'PG',
          'Malishevë': 'MA',
          'Podujevë': 'PD',
        }[city.name] ??
        normalize(city.name).substring(0, 2).toUpperCase();
  }

  Widget _compactSyriNowButton() => Tooltip(
    message: _ui(
      'SYRI Tani · Përmbledhja e ${city.name}',
      'SYRI Now · ${city.name} briefing',
    ),
    child: InkWell(
      key: const ValueKey('header-syri-now'),
      onTap: _syriNowDetails,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: 76,
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xffe1ff91), mint, Color(0xff63dca3)],
          ),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withValues(alpha: .45)),
          boxShadow: [
            BoxShadow(color: mint.withValues(alpha: .32), blurRadius: 13),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome_rounded, color: ink, size: 22),
            Text(
              _ui('TANI', 'NOW'),
              style: const TextStyle(
                color: ink,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _cityPickerHeading(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 17, 12, 7),
    child: Align(
      alignment: Alignment.centerLeft,
      child: AppText(
        label,
        style: const TextStyle(
          color: mint,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: .8,
        ),
      ),
    ),
  );

  Widget _cityPickerRow(City item, StateSetter update) {
    final selected = item == city;
    final favorite = favoriteCities.contains(item.name);
    return AnimatedContainer(
      key: ValueKey('city-${item.country}-${item.name}'),
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: selected ? mint.withValues(alpha: .18) : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        border: selected
            ? Border.all(color: mint.withValues(alpha: .95), width: 1.6)
            : null,
        boxShadow: selected
            ? [BoxShadow(color: mint.withValues(alpha: .14), blurRadius: 15)]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          selected: selected,
          leading: Icon(
            selected ? Icons.location_on_rounded : Icons.location_city_outlined,
            color: mint,
          ),
          title: AppText(
            item.name,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: favorite
                    ? _ui('Hiq nga të preferuarat', 'Remove from favorites')
                    : _ui('Shto te të preferuarat', 'Add to favorites'),
                onPressed: () {
                  setState(() {
                    favorite
                        ? favoriteCities.remove(item.name)
                        : favoriteCities.add(item.name);
                  });
                  update(() {});
                  unawaited(_saveSettings());
                },
                icon: Icon(
                  favorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: favorite ? Colors.amberAccent : muted,
                ),
              ),
              if (!selected) const Icon(Icons.chevron_right, color: muted),
            ],
          ),
          onTap: () {
            Navigator.pop(context);
            _selectCity(item);
          },
        ),
      ),
    );
  }

  void _cityPicker() => showModalBottomSheet(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: .52),
    builder: (context) {
      var query = '';
      return StatefulBuilder(
        builder: (context, update) {
          final matchingCities = _orderedCities
              .where((item) => normalize(item.name).contains(query))
              .toList();
          final favorites = matchingCities
              .where((item) => favoriteCities.contains(item.name))
              .toList();
          return ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: glassBlur, sigmaY: glassBlur),
              child: Container(
                height: MediaQuery.sizeOf(context).height * .75,
                decoration: glassSurface(28),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 38,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 17),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .35),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const AppText(
                        'Zgjidh qytetin',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        onChanged: (value) =>
                            update(() => query = normalize(value)),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search, color: mint),
                          hintText: _ui('Kërko', 'Search'),
                          filled: true,
                          fillColor: panel.withValues(alpha: .76),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: .12),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: .12),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: const BorderSide(
                              color: mint,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView(
                          children: [
                            if (favorites.isNotEmpty) ...[
                              _cityPickerHeading(
                                _ui('Të preferuarat', 'Favorites'),
                              ),
                              for (final item in favorites)
                                _cityPickerRow(item, update),
                            ],
                            for (final country in cityPickerCountryOrder)
                              if (matchingCities.any(
                                (item) =>
                                    item.country == country &&
                                    !favoriteCities.contains(item.name),
                              )) ...[
                                _cityPickerHeading(country),
                                for (final item in matchingCities)
                                  if (item.country == country &&
                                      !favoriteCities.contains(item.name))
                                    _cityPickerRow(item, update),
                              ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );

  Future<void> _checkSatelliteImagery() async {
    for (var age = 1; age <= 4; age++) {
      final day = DateTime.now().toUtc().subtract(Duration(days: age));
      final label =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final url = Uri.parse(
        'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/VIIRS_SNPP_CorrectedReflectance_TrueColor/default/$label/GoogleMapsCompatible_Level9/6/23/35.jpg',
      );
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      try {
        final request = await client.headUrl(url);
        final response = await request.close().timeout(
          const Duration(seconds: 7),
        );
        if (response.statusCode == 200 && response.contentLength > 4000) {
          if (mounted) {
            setState(() {
              availableSatelliteDay = label;
              satelliteUnavailable = false;
            });
          }
          return;
        }
      } catch (_) {
        // Try an earlier observation before declaring imagery unavailable.
      } finally {
        client.close(force: true);
      }
    }
    if (mounted) {
      setState(() {
        availableSatelliteDay = null;
        satelliteUnavailable = true;
      });
    }
  }

  void _scheduleMapZoomRender(double zoom) {
    if (!mounted) return;
    _pendingMapZoom = zoom;
    // A pinch can fire dozens of camera changes per second. Rebuilding every
    // marker and polygon for each change stalls tile drawing on slower phones.
    _mapZoomSettleTimer?.cancel();
    _mapZoomSettleTimer = Timer(const Duration(milliseconds: 190), () {
      if (!mounted || _pendingMapZoom == null) return;
      _mapZoomRenderTimer?.cancel();
      _mapZoomRenderTimer = null;
      if ((_pendingMapZoom! - mapZoom).abs() < .01) return;
      _lastMapZoomRender = DateTime.now();
      setState(() => mapZoom = _pendingMapZoom!);
    });
    if ((zoom - mapZoom).abs() < .22) return;
    final elapsed = DateTime.now().difference(_lastMapZoomRender);
    const interval = Duration(milliseconds: 240);
    if (elapsed >= interval) {
      _mapZoomRenderTimer?.cancel();
      _mapZoomRenderTimer = null;
      _lastMapZoomRender = DateTime.now();
      setState(() => mapZoom = _pendingMapZoom!);
      return;
    }
    _mapZoomRenderTimer ??= Timer(interval - elapsed, () {
      _mapZoomRenderTimer = null;
      if (!mounted || _pendingMapZoom == null) return;
      _lastMapZoomRender = DateTime.now();
      setState(() => mapZoom = _pendingMapZoom!);
    });
  }

  bool get _mapSourcesLoading {
    if (!widget.loadData || tab != 0 || busy.isEmpty) return false;
    final visibleLayers = activeMapCategories.expand(_categoryLayers).toSet();
    return busy.any((key) {
      // Aircraft refresh in the background while their existing markers stay
      // visible; repeatedly showing a progress line would be distracting.
      if (key == 'planes' && results[key] != null) return false;
      if (visibleLayers.contains(key)) return true;
      if (key == 'fires' && visibleLayers.contains('hazards')) return true;
      if (activeMapCategories.contains('news')) {
        return key == 'local' ||
            key == 'world' ||
            regionalNewsSources.any((source) => source.name == key);
      }
      return false;
    });
  }

  Widget _mapPage() {
    final events = mapEvents;
    // At a continental scale even compact symbols obscure the map. Keep
    // recognizable icons at country and regional scales and reserve dots for
    // the furthest zoom only.
    final overview = mapZoom < markerDotUntilZoom;
    final groups = overview
        ? <MapMarkerGroup>[]
        : groupMapMarkers(
            events.where((event) => event.geometry == null).toList(),
            mapZoom,
            clusterNearby: true,
          );
    final coincidentPositions = layoutCoincidentMarkers(groups, mapZoom);
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Semantics(
              label: _ui(
                'Harta interaktive e ${city.name}',
                'Interactive map of ${city.name}',
              ),
              child: FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: city.point,
                  initialZoom: 11,
                  minZoom: 5,
                  maxZoom: 18,
                  backgroundColor: ink,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onMapReady: () {
                    mapReady = true;
                    mapController.move(city.point, 11);
                  },
                  onPositionChanged: (camera, _) {
                    _scheduleMapZoomRender(camera.zoom);
                  },
                ),
                children: [
                  ColorFiltered(
                    colorFilter: const ColorFilter.matrix([
                      0.2126,
                      0.7152,
                      0.0722,
                      0,
                      -18,
                      0.2126,
                      0.7152,
                      0.0722,
                      0,
                      -8,
                      0.2126,
                      0.7152,
                      0.0722,
                      0,
                      -8,
                      0,
                      0,
                      0,
                      1,
                      0,
                    ]),
                    child: darkModeTilesContainerBuilder(
                      context,
                      TileLayer(
                        key: ValueKey('base-tiles-$_baseTileRevision'),
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'al.syri.syri',
                        maxZoom: 19,
                        keepBuffer: 5,
                        panBuffer: 1,
                        tileDisplay: const TileDisplay.instantaneous(),
                        evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
                        errorTileCallback: (_, _, _) =>
                            _retryMissingBaseTiles(),
                      ),
                    ),
                  ),
                  if (enabled.contains('satellite') &&
                      availableSatelliteDay != null)
                    TileLayer(
                      urlTemplate:
                          'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/VIIRS_SNPP_CorrectedReflectance_TrueColor/default/$availableSatelliteDay/GoogleMapsCompatible_Level9/{z}/{y}/{x}.jpg',
                      userAgentPackageName: 'al.syri.syri',
                      maxNativeZoom: 9,
                      maxZoom: 18,
                      tileBuilder: (context, child, tile) =>
                          Opacity(opacity: satelliteOpacity, child: child),
                      tileDisplay: const TileDisplay.fadeIn(
                        duration: Duration(milliseconds: 240),
                      ),
                    ),
                  if (enabled.contains('land-cover'))
                    TileLayer(
                      wmsOptions: WMSTileLayerOptions(
                        baseUrl: 'https://titiler.terrascope.be/wms?',
                        layers: const ['esa-worldcover-map-10m-2021-v2_map'],
                        version: '1.3.0',
                        otherParameters: const {'time': '2021-01-01'},
                      ),
                      userAgentPackageName: 'al.syri.syri',
                      maxNativeZoom: 14,
                      maxZoom: 20,
                      keepBuffer: 2,
                      panBuffer: 1,
                      tileDisplay: const TileDisplay.fadeIn(
                        duration: Duration(milliseconds: 180),
                      ),
                      tileBuilder: (context, child, tile) =>
                          Opacity(opacity: .57, child: child),
                    ),
                  if (enabledNewsCountries.contains('Shqipëri') &&
                      enabled.contains('population'))
                    _publicWmsLayer(
                      'https://geoportal.asig.gov.al/service/instat/wms?',
                      const ['pop_to_grid_2023'],
                      opacity: .48,
                    ),
                  if (enabled.contains('protected') &&
                      enabledNewsCountries.isNotEmpty)
                    TileLayer(
                      key: ValueKey(
                        'protected-${protectedAreaLayerDefinitions(enabledNewsCountries)}',
                      ),
                      wmsOptions: WMSTileLayerOptions(
                        baseUrl: 'https://bio.discomap.eea.europa.eu/arcgis/services/ProtectedSites/NatDAv23_Dyna_WM/MapServer/WMSServer?',
                        layers: const ['0', '1', '3', '4'],
                        version: '1.3.0',
                        otherParameters: {
                          'layerDefs': protectedAreaLayerDefinitions(
                            enabledNewsCountries,
                          ),
                        },
                      ),
                      userAgentPackageName: 'al.syri.syri',
                      maxNativeZoom: 14,
                      maxZoom: 20,
                      keepBuffer: 2,
                      panBuffer: 1,
                      tileBuilder: (context, child, tile) =>
                          Opacity(opacity: .58, child: child),
                    ),
                  if (enabled.contains('flood-zones'))
                    TileLayer(
                      wmsOptions: WMSTileLayerOptions(
                        baseUrl:
                            'https://ows.globalfloods.eu/glofas-ows/ows.py?',
                        layers: const ['FloodHazard100y'],
                        version: '1.3.0',
                      ),
                      userAgentPackageName: 'al.syri.syri',
                      maxNativeZoom: 13,
                      maxZoom: 20,
                      keepBuffer: 2,
                      panBuffer: 1,
                      tileBuilder: (context, child, tile) =>
                          Opacity(opacity: .55, child: child),
                    ),
                  if (enabled.contains('weather') && showRadar && radar != null)
                    TileLayer(
                      urlTemplate: radar!.value.tileUrl,
                      userAgentPackageName: 'al.syri.syri',
                      maxNativeZoom: 7,
                      maxZoom: 19,
                      tileDisplay: const TileDisplay.fadeIn(
                        duration: Duration(milliseconds: 250),
                      ),
                    ),
                  if (!overview &&
                      enabled.contains('water') &&
                      results['water']?.value.any(
                            (event) => event.geometry != null,
                          ) ==
                          true)
                    GestureDetector(
                      onTap: () {
                        final hit = _waterHitNotifier.value?.hitValues;
                        if (hit != null && hit.isNotEmpty) {
                          _eventDetails(hit.first);
                        }
                      },
                      child: PolygonLayer<Event>(
                        hitNotifier: _waterHitNotifier,
                        polygons: [
                          for (final event in results['water']!.value)
                            if (event.geometry case final geometry?)
                              Polygon<Event>(
                                points: geometry,
                                color: bathingWaterColor(event)
                                    .withValues(alpha: .48),
                                borderColor: bathingWaterColor(event),
                                borderStrokeWidth: 3.5,
                                hitValue: event,
                              ),
                        ],
                      ),
                    ),
                  MarkerLayer(
                    markers: [
                      if (enabled.contains('air'))
                        for (final place in cities)
                          if (enabledNewsCountries.contains(place.country))
                            if (place.name == city.name && airQuality != null)
                              _airCityMarker(place, airQuality!)
                            else if (regionalAirQuality[place.name] != null)
                              _airCityMarker(
                                place,
                                regionalAirQuality[place.name]!,
                              ),
                      if (overview)
                        for (final event in events) _overviewMarker(event),
                      for (final group in groups)
                        _marker(
                          group.events,
                          displayPoint:
                              coincidentPositions[group] ?? group.anchor,
                          compact:
                              coincidentPositions.containsKey(group) &&
                              (group.category == 'news' ||
                                  group.category == 'alerts' ||
                                  group.category == 'sea' ||
                                  group.category == 'tv'),
                        ),
                      if (userPoint != null)
                        Marker(
                          point: userPoint!,
                          width: 22,
                          height: 22,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(top: 14, left: 0, right: 0, child: _mapHeader()),
        if (_mapSourcesLoading)
          Positioned(
            left: 0,
            right: 0,
            bottom: 92,
            child: Center(
              child: IgnorePointer(
                child: Semantics(
                  label: _ui(
                    'Po ngarkohen të dhënat e hartës',
                    'Loading map data',
                  ),
                  child: Container(
                    width: 104,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: ink.withValues(alpha: .78),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: mint.withValues(alpha: .28)),
                      boxShadow: [
                        BoxShadow(
                          color: mint.withValues(alpha: .16),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: LinearProgressIndicator(
                      minHeight: 2.5,
                      borderRadius: BorderRadius.circular(3),
                      backgroundColor: Colors.white.withValues(alpha: .12),
                      valueColor: const AlwaysStoppedAnimation<Color>(mint),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (expandedCategory case final category?)
          Positioned(top: 82, left: 12, child: _mapSubcategoryRail(category)),
        Positioned(
          right: 11,
          bottom: 92,
          child: Column(
            children: [
              _mapButton(
                Icons.dashboard_customize_outlined,
                'Zgjidh kategoritë',
                _layerPicker,
              ),
              const SizedBox(height: 7),
              _mapButton(
                Icons.add,
                'Zmadho',
                () => mapController.move(
                  mapController.camera.center,
                  (mapController.camera.zoom + 1).clamp(5, 18),
                ),
              ),
              const SizedBox(height: 7),
              _mapButton(
                Icons.remove,
                'Zvogëlo',
                () => mapController.move(
                  mapController.camera.center,
                  (mapController.camera.zoom - 1).clamp(5, 18),
                ),
              ),
              const SizedBox(height: 10),
              _mapButton(
                locating ? Icons.hourglass_top : Icons.my_location,
                'Vendndodhja ime',
                locating ? null : _locate,
              ),
            ],
          ),
        ),
        Positioned(
          left: 8,
          bottom: 88,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                button: true,
                label: _ui(
                  'Kreditë e hartës OpenStreetMap',
                  'OpenStreetMap attribution',
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => _open('https://www.openstreetmap.org/copyright'),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: AppText(
                        [
                          '© OSM',
                          if (enabled.contains('weather') && radar != null)
                            'RainViewer',
                          if (enabled.contains('land-cover')) 'ESA WorldCover',
                        ].join(' · '),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .32),
                          fontSize: 7,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Semantics(
                label: _ui(
                  'Zmadhimi i hartës ${mapZoomPercent(mapZoom)} për qind, niveli ${mapZoom.toStringAsFixed(1)}',
                  'Map zoom ${mapZoomPercent(mapZoom)} percent, level ${mapZoom.toStringAsFixed(1)}',
                ),
                child: AppText(
                  ' · ${mapZoomPercent(mapZoom)}% · z${mapZoom.toStringAsFixed(1)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .38),
                    fontSize: 7,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  LatLng _nearestPortPoint() {
    final ports = api.ships().where((event) => event.point != null).toList();
    ports.sort(
      (a, b) => const Distance()
          .as(LengthUnit.Kilometer, city.point, a.point!)
          .compareTo(
            const Distance().as(LengthUnit.Kilometer, city.point, b.point!),
          ),
    );
    return ports.first.point!;
  }

  Color _airAqiColor(double aqi) => aqi <= 20
      ? const Color(0xff70d7ff)
      : aqi <= 40
      ? const Color(0xff6df3a3)
      : aqi <= 60
      ? const Color(0xffffdf64)
      : aqi <= 80
      ? const Color(0xffffa65f)
      : const Color(0xffff7385);

  Marker _airCityMarker(City place, FeedResult<AirQuality> reading) {
    final compact = !showAirPill(mapZoom);
    final color = _airAqiColor(reading.value.europeanAqi);
    final hasPollen =
        reading.value.olivePollen != null || reading.value.grassPollen != null;
    return Marker(
      key: ValueKey('air-${place.name}'),
      point: place.point,
      // The geographic point stays fixed. The air symbol sits just to the
      // right of it, leaving the centered agriculture symbol readable.
      alignment: Alignment.centerLeft,
      width: compact ? 46 : 100,
      height: 42,
      child: Semantics(
        button: true,
        label:
            'Ajri dhe poleni në ${place.name}, AQI ${reading.value.europeanAqi.round()}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _airDetails(location: place, reading: reading),
          child: Padding(
            padding: const EdgeInsets.only(left: 28),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: compact ? 12 : 70,
                height: compact ? 12 : 30,
                decoration: BoxDecoration(
                  color: compact ? color : ink.withValues(alpha: .84),
                  shape: compact ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: compact ? null : BorderRadius.circular(15),
                  border: Border.all(color: color, width: compact ? 1 : 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: .25),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: compact
                    ? null
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.air, color: color, size: 14),
                          const SizedBox(width: 3),
                          Text(
                            '${reading.value.europeanAqi.round()}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (hasPollen) ...[
                            const SizedBox(width: 2),
                            const Icon(Icons.spa, color: mint, size: 12),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Marker _overviewMarker(Event event) {
    final info = infoFor(event.kind);
    final color = event.kind == 'water'
        ? bathingWaterColor(event)
        : event.kind == 'news' && event.tone == 'good'
        ? Colors.greenAccent
        : event.kind == 'news' && event.tone == 'bad'
        ? Colors.orangeAccent
        : info.color;
    final dotSize = (5 + (mapZoom - 5) * 2).clamp(5.0, 12.0);
    return Marker(
      point: event.displayPoint,
      width: 26,
      height: 26,
      child: Semantics(
        label: '${info.name}: ${event.title}. Zmadho hartën',
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => mapController.move(event.displayPoint, 11.5),
          child: Center(
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: ink, width: 1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Marker _marker(
    List<Event> group, {
    LatLng? displayPoint,
    bool compact = false,
  }) {
    final info = infoFor(group.first.kind);
    final event = group.first;
    final markerColor = event.kind == 'water'
        ? bathingWaterColor(event)
        : event.kind == 'news' && event.tone == 'good'
        ? Colors.greenAccent
        : event.kind == 'news' && event.tone == 'bad'
        ? Colors.orangeAccent
        : info.color;
    final markerIcon = event.kind == 'news'
        ? (event.tone == 'good'
              ? Icons.sentiment_satisfied_alt
              : event.tone == 'bad'
              ? Icons.warning_amber_rounded
              : Icons.article_outlined)
        : info.icon;
    return Marker(
      point: displayPoint ?? event.displayPoint,
      width: event.kind == 'tv'
          ? tvMarkerSpacing(mapZoom)
          : event.kind == 'news'
          ? (compact ? math.max(44, newsMarkerSpacing(mapZoom)) : 52)
          : compact
          ? coincidentMarkerSpacing(mapZoom)
          : 48,
      height: event.kind == 'tv'
          ? tvMarkerSpacing(mapZoom)
          : event.kind == 'news'
          ? (compact ? math.max(44, newsMarkerSpacing(mapZoom)) : 52)
          : compact
          ? coincidentMarkerSpacing(mapZoom)
          : 48,
      child: Semantics(
        label: event.kind == 'tv'
            ? event.title
            : syriEnglish
            ? 'Map marker: ${group.length}'
            : '${info.name}: ${group.length}',
        button: true,
        child: GestureDetector(
          onTap: () {
            if (group.first.kind == 'marine') {
              _marineDetails();
              return;
            }
            if (group.length == 1) {
              _eventDetails(group.first);
            } else {
              _sheet(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _heading(
                      group.first.kind.startsWith('airport-')
                          ? '${group.length} fluturime'
                          : '${group.length} raportime',
                      group.first.kind.startsWith('airport-')
                          ? 'Mbërritje dhe nisje nga tabela zyrtare.'
                          : 'Të grupuara në të njëjtën pikë.',
                    ),
                    ...group.map(_eventTile),
                  ],
                ),
                accent: markerColor,
              );
            }
          },
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: Transform.scale(
              scale: event.kind == 'tv'
                  ? tvMarkerScale(mapZoom)
                  : event.kind == 'news'
                  ? newsMarkerScale(mapZoom, compact: compact)
                  : compact
                  ? coincidentMarkerScale(mapZoom)
                  : markerScaleForKind(event.kind, mapZoom),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  _markerSymbol(event, markerIcon, markerColor),
                  if (group.length > 1)
                    Positioned(
                      right: -10,
                      top: -8,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 19,
                          minHeight: 19,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: ink.withValues(alpha: .94),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: markerColor, width: 1.2),
                        ),
                        child: AppText(
                          group.length > 99 ? '99+' : '${group.length}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: markerColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _markerSymbol(Event event, IconData fallback, Color color) {
    if (event.kind == 'tv') {
      final channel = tvChannels.firstWhere(
        (item) => event.id == 'tv-${item.id}',
      );
      return Container(
        width: 46,
        height: 46,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xe6192c2b),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: color.withValues(alpha: .8), width: 1.4),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 5)],
        ),
        child: channel.logoAsset == null
            ? Center(
                child: Text(
                  channel.mapLabel,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            : Image.asset(channel.logoAsset!, fit: BoxFit.contain),
      );
    }
    if (event.kind == 'biodiversity-flora' ||
        event.kind == 'biodiversity-fauna') {
      return Container(
        width: 21,
        height: 21,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 5)],
        ),
      );
    }
    if (event.kind == 'water') {
      return Container(
        width: 25,
        height: 25,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black, blurRadius: 7)],
        ),
      );
    }
    if (event.kind == 'planes') {
      return Transform.rotate(
        angle: ((event.heading ?? 0) * math.pi / 180),
        child: Icon(
          Icons.flight,
          color: color,
          size: 33,
          shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
        ),
      );
    }
    if (event.kind == 'news') {
      if (event.newsType == 'violence') {
        return CustomPaint(
          size: const Size(43, 43),
          painter: PistolMarkerPainter(),
        );
      }
      if (event.newsType == 'crime') {
        return const Icon(
          Icons.gavel,
          color: Colors.redAccent,
          size: 32,
          shadows: [Shadow(color: Colors.black, blurRadius: 6)],
        );
      }
      if (event.newsType == 'death') {
        return const Icon(
          Icons.heart_broken,
          color: Colors.blueGrey,
          size: 34,
          shadows: [Shadow(color: Colors.black, blurRadius: 6)],
        );
      }
      if (event.newsType == 'crash') {
        return Icon(
          Icons.car_crash,
          color: Colors.orangeAccent,
          size: 34,
          shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
        );
      }
      if (event.newsType == 'good') {
        return const Icon(
          Icons.campaign,
          color: Colors.greenAccent,
          size: 34,
          shadows: [Shadow(color: Colors.black, blurRadius: 6)],
        );
      }
    }
    if (event.kind == 'places') {
      final text = normalize('${event.title} ${event.description}');
      final icon = text.contains('shpell') || text.contains('cave')
          ? Icons.terrain
          : text.contains('muze')
          ? Icons.museum_outlined
          : text.contains('keshtjell') || text.contains('castle')
          ? Icons.castle_outlined
          : text.contains('arkeolog') || text.contains('histor')
          ? Icons.account_balance_outlined
          : text.contains('kamp')
          ? Icons.cabin_outlined
          : text.contains('panoram')
          ? Icons.landscape_outlined
          : Icons.hiking;
      return Icon(
        icon,
        color: color,
        size: 33,
        shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
      );
    }
    if (event.kind == 'environment') {
      final text = normalize('${event.title} ${event.description}');
      final icon = text.contains('ajrit') || text.contains('aqi')
          ? Icons.air
          : text.contains('mbetje') || text.contains('depozitim')
          ? Icons.delete_outline
          : text.contains('burim') || text.contains('ujerash')
          ? Icons.water_drop_outlined
          : text.contains('rezervat') || text.contains('mbrojtur')
          ? Icons.park_outlined
          : Icons.recycling;
      return Icon(
        icon,
        color: color,
        size: 33,
        shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
      );
    }
    return Icon(
      fallback,
      color: color,
      size: 33,
      shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
    );
  }

  String _clock(DateTime value) {
    final time = value.toLocal();
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Widget _mapHeader() => Column(
    children: [
      _categoryPills(),
      if (showLegends && _mapLegendWidgets().isNotEmpty) ...[
        const SizedBox(height: 6),
        _mapLegendButton(),
      ],
      if (_weatherToastMessage != null) _weatherToastChip(),
      if (_showOfflineNotice) _offlineNoticeChip(),
    ],
  );

  void _dismissMapLegend(VoidCallback change, VoidCallback? refresh) {
    setState(change);
    refresh?.call();
  }

  List<Widget> _mapLegendWidgets([VoidCallback? refresh]) => [
    if (enabled.contains('water') &&
        results['water']?.value.isNotEmpty == true &&
        showLegends &&
        !waterLegendDismissed)
      Dismissible(
        key: const ValueKey('water-legend'),
        direction: DismissDirection.horizontal,
        onDismissed: (_) =>
            _dismissMapLegend(() => waterLegendDismissed = true, refresh),
        child: _bathingWaterLegend(),
      ),
    if (enabled.contains('air') &&
        airQuality != null &&
        showLegends &&
        !airLegendDismissed)
      Dismissible(
        key: const ValueKey('air-legend'),
        direction: DismissDirection.horizontal,
        onDismissed: (_) =>
            _dismissMapLegend(() => airLegendDismissed = true, refresh),
        child: InkWell(
          onTap: _airDetails,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: ink.withValues(alpha: .82),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: _airAqiColor(airQuality!.value.europeanAqi)
                    .withValues(alpha: .6),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.air,
                  color: _airAqiColor(airQuality!.value.europeanAqi),
                  size: 17,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppText(
                        'Ajër/UV/polen',
                        style: TextStyle(fontSize: 10, color: muted),
                      ),
                      AppText(
                        'AQI ${airQuality!.value.europeanAqi.round()} · ${airQuality!.value.label} · ${city.name}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      AppText(
                        '${regionalAirQuality.length} qytete · prek pikat anash për ajrin, UV dhe polenin',
                        style: const TextStyle(fontSize: 10, color: muted),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 17, color: muted),
              ],
            ),
          ),
        ),
      ),
    if (enabled.contains('weather') &&
        showRadar &&
        radar != null &&
        !rainLegendDismissed &&
        showLegends) ...[
      const SizedBox(height: 7),
      Dismissible(
        key: const ValueKey('rain-legend'),
        direction: DismissDirection.horizontal,
        onDismissed: (_) =>
            _dismissMapLegend(() => rainLegendDismissed = true, refresh),
        child: _rainLegend(),
      ),
    ],
    if (showLegends)
      for (final id in _activeReferenceLayers)
        if (!dismissedReferenceLegends.contains(id)) ...[
          const SizedBox(height: 7),
          Dismissible(
            key: ValueKey('reference-legend-$id'),
            direction: DismissDirection.horizontal,
            onDismissed: (_) => _dismissMapLegend(
              () => dismissedReferenceLegends.add(id),
              refresh,
            ),
            child: _individualReferenceLegend(id),
          ),
        ],
    if (enabled.contains('satellite') &&
        !satelliteLegendDismissed &&
        showLegends) ...[
      const SizedBox(height: 7),
      Dismissible(
        key: const ValueKey('satellite-legend'),
        direction: DismissDirection.horizontal,
        onDismissed: (_) =>
            _dismissMapLegend(() => satelliteLegendDismissed = true, refresh),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: ink.withValues(alpha: .82),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  (satelliteUnavailable
                          ? Colors.redAccent
                          : Colors.lightBlueAccent)
                      .withValues(alpha: .4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppText(
                'Sateliti i ditës',
                style: TextStyle(color: muted, fontSize: 10),
              ),
              const SizedBox(height: 3),
              AppText(
                satelliteUnavailable
                    ? 'NASA VIIRS · imazhi nuk është i disponueshëm tani'
                    : availableSatelliteDay == null
                    ? 'NASA VIIRS · po kontrollohet imazhi…'
                    : 'NASA VIIRS · pamje e $availableSatelliteDay · jo imazh live',
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    ],
  ];

  Widget _mapLegendButton() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Align(
      alignment: Alignment.centerRight,
      child: ActionChip(
        avatar: const Icon(Icons.info_outline, color: mint, size: 17),
        label: AppText(_ui('Legjenda', 'Legends')),
        onPressed: () => _sheet(
          StatefulBuilder(
            builder: (context, update) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppText(
                  'Legjenda',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                ..._mapLegendWidgets(() => update(() {})),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _categoryPills() => SizedBox(
    height: 58,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      children: [
        for (final category in mapCategories)
          Padding(
            padding: const EdgeInsets.only(right: 7, top: 3, bottom: 3),
            child: Container(
              decoration: glassSurface(
                26,
                outline: _categoryActive(category.id)
                    ? category.color.withValues(alpha: .85)
                    : Colors.white.withValues(alpha: .18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    key: ValueKey('map-category-${category.id}'),
                    onTap: () => _setCategory(
                      category.id,
                      !_categoryActive(category.id),
                    ),
                    borderRadius: BorderRadius.circular(26),
                    child: SizedBox(
                      height: 50,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 15, right: 8),
                        child: Row(
                          children: [
                            Icon(
                              category.icon,
                              color: category.color,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            AppText(
                              category.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_subcategoryChoices(category.id).isNotEmpty)
                    Builder(
                      builder: (pillContext) => IconButton(
                        key: ValueKey('map-expand-${category.id}'),
                        tooltip: _ui('Nënkategoritë', 'Subcategories'),
                        onPressed: () {
                          final opening = expandedCategory != category.id;
                          setState(() {
                            expandedCategory = opening ? category.id : null;
                          });
                          if (opening) {
                            Scrollable.ensureVisible(
                              pillContext,
                              alignment: .78,
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                            );
                          }
                        },
                        icon: Icon(
                          expandedCategory == category.id
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: category.color,
                          size: 20,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 14, top: 3, bottom: 3),
          child: InkWell(
            key: const ValueKey('map-clear-all-pill'),
            onTap: _clearAllLayers,
            borderRadius: BorderRadius.circular(26),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: glassSurface(26),
              child: Row(
                children: [
                  const Icon(
                    Icons.layers_clear_rounded,
                    color: muted,
                    size: 19,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    _ui('Hiqi të gjitha', 'Clear All'),
                    style: const TextStyle(color: muted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _mapSubcategoryRail(String id) {
    final category = mapCategories.firstWhere((item) => item.id == id);
    final choices = _subcategoryChoices(id);
    final maxHeight = MediaQuery.sizeOf(context).height * .52;
    final height = (56.0 + choices.length * 46.0).clamp(56.0, maxHeight);
    return SizedBox(
      width: 190,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: glassBlur, sigmaY: glassBlur),
          child: Container(
            decoration: glassSurface(
              18,
              outline: category.color.withValues(alpha: .55),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      const SizedBox(width: 11),
                      Icon(category.icon, color: category.color, size: 17),
                      const SizedBox(width: 7),
                      Expanded(
                        child: AppText(
                          category.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: _ui(
                          'Mbyll nënkategoritë',
                          'Close subcategories',
                        ),
                        onPressed: () =>
                            setState(() => expandedCategory = null),
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(5, 0, 5, 13),
                    itemCount: choices.length,
                    itemBuilder: (context, index) {
                      final choice = choices[index];
                      final active = _subcategoryActive(choice.$1);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Material(
                          color: active
                              ? choice.$4.withValues(alpha: .15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                          child: InkWell(
                            key: ValueKey('map-subcategory-${choice.$1}'),
                            borderRadius: BorderRadius.circular(11),
                            onTap: () => _setSubcategory(choice.$1, !active),
                            child: SizedBox(
                              height: 44,
                              child: Row(
                                children: [
                                  const SizedBox(width: 7),
                                  Icon(choice.$3, color: choice.$4, size: 17),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: AppText(
                                      choice.$2,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    active
                                        ? Icons.check_circle_rounded
                                        : Icons.circle_outlined,
                                    color: active ? choice.$4 : muted,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 7),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bathingWaterLegend() => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: ink.withValues(alpha: .82),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: .35)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppText(
          'Ujërat e larjes',
          style: TextStyle(fontSize: 10, color: muted),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          runSpacing: 5,
          children: [
            for (final item in const [
              ('E shkëlqyer', Color(0xff96ccff)),
              ('E mirë', Color(0xff81fb7f)),
              ('E mjaftueshme', Color(0xffffda00)),
              ('E dobët', Color(0xfffa7f7f)),
              ('Pa klasifikim', Color(0xffababab)),
            ])
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: item.$2,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  AppText(item.$1, style: const TextStyle(fontSize: 10)),
                ],
              ),
          ],
        ),
      ],
    ),
  );

  List<(String, String, IconData, Color)> _subcategoryChoices(
    String category,
  ) => switch (category) {
    'news' => const [
      ('news:good', 'Të mira', Icons.campaign, Colors.greenAccent),
      ('news:major', 'Të mëdha', Icons.priority_high, Color(0xff91b5ff)),
      ('news:crash', 'Aksidente', Icons.car_crash, Colors.orangeAccent),
      ('news:crime', 'Krime', Icons.gavel, Colors.redAccent),
      ('news:violence', 'Dhunë/armë', Icons.crisis_alert, Colors.redAccent),
      ('news:death', 'Humbje jete', Icons.heart_broken, Colors.blueGrey),
      (
        'news:fire',
        'Zjarre',
        Icons.local_fire_department,
        Colors.deepOrangeAccent,
      ),
      (
        'news:weather',
        'Mot i rrezikshëm',
        Icons.thunderstorm,
        Colors.lightBlueAccent,
      ),
    ],
    'weather' => const [
      ('weather', 'Radar shiu', Icons.radar, Colors.lightBlueAccent),
      ('air', 'Ajër/UV/polen', Icons.air, Colors.tealAccent),
      (
        'agriculture',
        'Bujqësi',
        Icons.agriculture_outlined,
        Colors.lightGreenAccent,
      ),
    ],
    'alerts' => const [
      ('quakes', 'Tërmete', Icons.vibration_rounded, Colors.amber),
      (
        'hazard:fire',
        'Zjarre aktive',
        Icons.local_fire_department,
        Colors.deepOrangeAccent,
      ),
      ('hazard:storm', 'Stuhi', Icons.thunderstorm, Colors.purpleAccent),
      ('hazard:flood', 'Përmbytje', Icons.flood, Colors.blueAccent),
      ('hazard:volcano', 'Vullkane', Icons.volcano, Colors.redAccent),
      ('cems', 'Harta dëmi', Icons.satellite_alt, Color(0xffff7f73)),
      (
        'health-alerts',
        'Shëndeti publik',
        Icons.health_and_safety,
        Colors.pinkAccent,
      ),
      (
        'food-alerts',
        'Siguria ushqimore',
        Icons.no_food_rounded,
        Colors.orangeAccent,
      ),
      (
        'hydrology-alerts',
        'Lumenj/rezervuarë',
        Icons.water_damage_outlined,
        Colors.blueAccent,
      ),
      (
        'internet-outages',
        'Internet',
        Icons.wifi_off_rounded,
        Colors.deepOrangeAccent,
      ),
      (
        'landslides',
        'Rrëshqitje dheu',
        Icons.landscape_outlined,
        Colors.orangeAccent,
      ),
    ],
    'transport' => const [
      ('planes', 'Avionë live', Icons.flight, mint),
      ('airports', 'Aeroporte', Icons.flight_takeoff, Color(0xff8ed7ff)),
      (
        'traffic-jam',
        'Trafik i rënduar',
        Icons.warning_amber_rounded,
        Colors.redAccent,
      ),
      ('speed-cameras', 'Kamera shpejtësie', Icons.speed, Colors.amberAccent),
      (
        'police-alerts',
        'Njoftime policore',
        Icons.local_police_outlined,
        Color(0xff72a7ff),
      ),
      ('transit', 'Autobusë', Icons.directions_bus, Colors.lightBlueAccent),
      ('roadwork', 'Bllokime rrugësh', Icons.construction, Colors.orangeAccent),
      (
        'borders',
        'Pritje në kufi',
        Icons.compare_arrows_rounded,
        Colors.amberAccent,
      ),
    ],
    'services' => const [
      ('services', 'Urgjencë/shëndet', Icons.local_hospital, Colors.pinkAccent),
      ('pharmacies', 'Farmaci', Icons.local_pharmacy, Colors.pinkAccent),
      ('aed', 'Defibrilatorë', Icons.monitor_heart, Colors.redAccent),
      (
        'mobility',
        'Parkim/karikim',
        Icons.ev_station_outlined,
        Colors.lightGreenAccent,
      ),
      ('utilities', 'Energji dhe ujë', Icons.power, Colors.amberAccent),
      ('energy-grid', 'Energjia live', Icons.electric_bolt, Colors.amberAccent),
      (
        'civic-alerts',
        'Njoftime civile',
        Icons.campaign_outlined,
        Colors.amberAccent,
      ),
    ],
    'territory' => const [
      (
        'land-cover',
        'Mbulesa e tokës',
        Icons.landscape_outlined,
        Colors.lightGreenAccent,
      ),
      ('flood-zones', 'Zona përmbytjeje', Icons.flood, Colors.blueAccent),
      ('population', 'Popullsia', Icons.grid_on, Colors.purpleAccent),
      ('protected', 'Zona të mbrojtura', Icons.park, Colors.greenAccent),
      ('biodiversity', 'Flora dhe fauna', Icons.pets, Colors.lightGreenAccent),
      (
        'satellite',
        'Sateliti i ditës',
        Icons.satellite_alt,
        Colors.lightBlueAccent,
      ),
    ],
    'sea' => const [
      ('marine', 'Gjendja e detit', Icons.waves, Colors.cyanAccent),
      ('port-alerts', 'Njoftime detare', Icons.anchor, Colors.lightBlueAccent),
      ('ships', 'Porte dhe tragete', Icons.directions_boat, Colors.blueAccent),
      ('water', 'Ujërat e larjes', Icons.water_drop, Colors.tealAccent),
      (
        'drinking-water',
        'Ujë i pijshëm',
        Icons.local_drink_outlined,
        Colors.cyanAccent,
      ),
    ],
    _ => const <(String, String, IconData, Color)>[],
  };

  bool _subcategoryActive(String id) => id.startsWith('news:')
      ? enabled.contains('news') && enabledNewsTypes.contains(id.substring(5))
      : id.startsWith('hazard:')
      ? enabled.contains('hazards') && enabledHazards.contains(id.substring(7))
      : enabled.contains(id);

  String? _parentCategoryForSubcategory(String id) {
    for (final category in [expandedCategory, selectedMapCategory]) {
      if (category != null &&
          _subcategoryChoices(category).any((choice) => choice.$1 == id)) {
        return category;
      }
    }
    for (final category in mapCategories) {
      if (_subcategoryChoices(category.id).any((choice) => choice.$1 == id)) {
        return category.id;
      }
    }
    return null;
  }

  Future<void> _setSubcategory(String id, bool turnOn) async {
    final parent = _parentCategoryForSubcategory(id);
    if (turnOn && parent != null) {
      setState(() {
        activeMapCategories.add(parent);
        selectedMapCategory = parent;
      });
    }
    if (id.startsWith('news:')) {
      final type = id.substring(5);
      setState(() {
        if (turnOn) {
          enabled.add('news');
          enabledNewsTypes.add(type);
        } else {
          enabledNewsTypes.remove(type);
          if (enabledNewsTypes.isEmpty) enabled.remove('news');
        }
      });
    } else if (id.startsWith('hazard:')) {
      final type = id.substring(7);
      setState(() {
        if (turnOn) {
          enabled.add('hazards');
          enabledHazards.add(type);
        } else {
          enabledHazards.remove(type);
          if (enabledHazards.isEmpty) enabled.remove('hazards');
        }
      });
      if (turnOn && widget.loadData && _needsLayerLoad('hazards')) {
        await _loadLayer('hazards');
      }
    } else {
      setState(() {
        turnOn ? enabled.add(id) : enabled.remove(id);
        if (id == 'weather' && turnOn) rainLegendDismissed = false;
        if (id == 'air' && turnOn) airLegendDismissed = false;
        if (id == 'water' && turnOn) waterLegendDismissed = false;
        if (_referenceLayerIds.contains(id) && turnOn) {
          mapLegendDismissed = false;
          dismissedReferenceLegends.remove(id);
        }
        if (id == 'satellite' && turnOn) satelliteLegendDismissed = false;
      });
      if (turnOn && widget.loadData && _needsLayerLoad(id)) {
        if (id == 'quakes') {
          await _load('quakes', api.earthquakes);
        } else {
          await _loadLayer(id);
          if (id == 'internet-outages' &&
              (results[id]?.value.isEmpty ?? true) &&
              mounted) {
            _toast('IODA nuk raporton ndërprerje aktive në 48 orët e fundit.');
          }
        }
      }
    }
    _startPlaneTimer();
    unawaited(_saveSettings());
  }

  Widget _individualReferenceLegend(String id) {
    return InkWell(
      onTap: _referenceLegendDetails,
      borderRadius: BorderRadius.circular(16),
      child: _referenceLegendSection(id),
    );
  }

  void _referenceLegendDetails() {
    final layers = _activeReferenceLayers;
    _sheet(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(
            'Si lexohet harta',
            'Rreziku i përmbytjes dhe zonat e mbrojtura mbulojnë katër vendet. Dendësia e popullsisë, cilësia e lumenjve dhe stacionet e ajrit mbeten shtresa zyrtare vetëm për Shqipërinë. Vitet ndryshojnë sipas burimit.',
          ),
          for (final id in layers) ...[
            _referenceLegendSection(id),
            const SizedBox(height: 14),
          ],
          TextButton(
            onPressed: () => _open(switch (city.country) {
              'Kosovë' => 'https://geoportal.rks-gov.net/portal/main',
              'Maqedonia e Veriut' => 'https://ossp.katastar.gov.mk/OSSP/',
              'Mali i Zi' => 'https://geoportal.co.me/',
              _ => 'https://geoportal.asig.gov.al/',
            }),
            child: AppText(
              _isAlbania
                  ? 'Hap Geoportalin ASIG ↗'
                  : 'Hap Geoportalin e ${city.country} ↗',
            ),
          ),
        ],
      ),
      accent: Colors.amberAccent,
    );
  }

  Widget _referenceLegendSection(String id) {
    final info = infoFor(id);
    final explanation = switch (id) {
      'land-cover' => 'ESA WorldCover 2021, rezolucion 10 m, mbulon Shqipërinë, Kosovën, Maqedoninë e Veriut dhe Malin e Zi. Kjo është klasifikim satelitor i tokës, jo gjendje live.',
      'river-quality' => 'Pikat blu me kontur të kuq janë vendet e monitorimit të lumenjve në inventarin AKM 2024; shtresa nuk publikon matje live.',
      'air-stations' => 'Pikat bojëqielli janë stacionet e monitorimit të ajrit në inventarin AKM 2024. Për AQI-në aktuale përdor Ajër/UV/polen.',
      'flood-zones' => 'Harta Copernicus GloFAS tregon zonat me rrezik përmbytjeje për periudhë kthimi 100-vjeçare në të katër vendet. Është model historik rreziku, jo përmbytje aktuale.',
      'population' => 'Qelizat 1 km² të ngjyrosura mbulojnë vetëm Shqipërinë dhe bazohen në Censin 2023. Pikat për secilin vend japin një vlerësim kombëtar me vitin dhe burimin e tij; ato nuk janë dendësi lokale.',
      'protected' => 'Sipërfaqet e ngjyrosura tregojnë zona të mbrojtura në të katër vendet nga inventari NatDA i Agjencisë Evropiane të Mjedisit (raportim deri në maj 2025). Pikat e parqeve dhe zonave pranë qytetit shërbejnë për hapjen e detajeve.',
      'biodiversity' => 'Pikat tregojnë regjistrime të hapura të florës dhe faunës nga GBIF në vendet e aktivizuara. Viti dhe burimi shfaqen te detajet; nuk janë vrojtime live dhe nuk përfaqësojnë të gjitha speciet.',
      'geo-risk' => 'Harta burimore është raster dhe shfaqej e copëzuar në telefon, ndaj nuk vendoset më sipër hartës. Konsulto hartën zyrtare në ASIG për qarkun përkatës.',
      _ => info.note,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: info.color.withValues(alpha: .28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            'Nënkategoria: ${info.name}',
            style: const TextStyle(fontSize: 10, color: muted),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(info.icon, color: info.color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: AppText(
                  info.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppText(
            explanation,
            style: const TextStyle(color: muted, height: 1.4),
          ),
          if (id == 'land-cover') ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 7,
              children: [
                for (final item in const <(String, Color)>[
                  ('Pyje', Color(0xff006400)),
                  ('Shkurre', Color(0xffffbb22)),
                  ('Kullota', Color(0xffffff4c)),
                  ('Tokë bujqësore', Color(0xfff096ff)),
                  ('Ndërtime', Color(0xfffa0000)),
                  ('Ujë', Color(0xff0064c8)),
                ])
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 10, height: 10, color: item.$2),
                      const SizedBox(width: 5),
                      AppText(item.$1, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
              ],
            ),
          ],
          if (id == 'population') ...[
            const SizedBox(height: 10),
            _colorScale(
              const [
                Color(0xfff7f3ee),
                Color(0xffffd8ad),
                Color(0xffffb36c),
                Color(0xffff8133),
                Color(0xffe6500d),
                Color(0xff8e2600),
              ],
              '0–10',
              '25 001+ banorë/km²',
            ),
          ],
          if (id == 'protected') ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 7,
              children: [
                for (final item in const <(String, Color)>[
                  ('Rezervat strikt', Color(0xff9bd500)),
                  ('Zonë e egër', Color(0xff8b9b00)),
                  ('Park kombëtar', Color(0xff668a00)),
                  ('Monument natyror', Color(0xffffe060)),
                  ('Habitat/specie', Color(0xffe5a700)),
                  ('Peizazh i mbrojtur', Color(0xffdf61d8)),
                  ('Përdorim i qëndrueshëm', Color(0xff1769da)),
                  ('Tjetër/pa klasifikim', Color(0xffaaaaaa)),
                ])
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 10, height: 10, color: item.$2),
                      const SizedBox(width: 5),
                      AppText(item.$1, style: const TextStyle(fontSize: 11)),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _colorScale(List<Color> colors, String start, String end) => Column(
    children: [
      Container(
        height: 8,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(colors: colors),
        ),
      ),
      const SizedBox(height: 4),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          AppText(start, style: const TextStyle(fontSize: 10, color: muted)),
          AppText(end, style: const TextStyle(fontSize: 10, color: muted)),
        ],
      ),
    ],
  );

  void _geologyDetails() => _sheet(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'Rreziku gjeologjik',
          'Harta zyrtare sipas qarqeve nga Shërbimi Gjeologjik dhe ASIG.',
        ),
        _referenceLegendSection('geo-risk'),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => _open('https://geoportal.asig.gov.al/'),
          child: const AppText('Hap hartën zyrtare ↗'),
        ),
        _disableLayerButton('geo-risk'),
      ],
    ),
    accent: Colors.orangeAccent,
  );

  void _landslideDetails() => _sheet(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'Rreziku nga rrëshqitjet',
          'NASA LHASA · përditësim afër kohës reale',
        ),
        const AppText(
          'LHASA kombinon reshjet satelitore, lagështinë e tokës dhe pjerrësinë për të vlerësuar probabilitetin e rrëshqitjeve të shkaktuara nga shiu.',
          style: TextStyle(height: 1.55),
        ),
        const SizedBox(height: 14),
        _bullet('Mbulimi', 'Shqipëri dhe Kosovë'),
        _bullet('Vonesa minimale', 'rreth 5 orë'),
        _bullet('Rezolucioni', 'afërsisht 1 km'),
        _bullet('Kuptimi', 'rrezik i modeluar, jo incident i konfirmuar'),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _open('https://pmmpublisher.pps.eosdis.nasa.gov/'),
            icon: const Icon(Icons.open_in_new),
            label: const AppText('Hap hartën NASA LHASA'),
          ),
        ),
      ],
    ),
    accent: Colors.orangeAccent,
  );

  Widget _rainLegend() => ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 7),
        decoration: BoxDecoration(
          color: ink.withValues(alpha: .76),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: .09)),
        ),
        child: Column(
          children: [
            const Row(
              children: [
                AppText(
                  'Radar shiu · Intensiteti i reshjeve',
                  style: TextStyle(fontSize: 10, color: Colors.white),
                ),
                Spacer(),
                AppText(
                  'Radar live',
                  style: TextStyle(fontSize: 10, color: muted),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Container(
              height: 7,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xff56d6ff),
                    Color(0xff20a7ff),
                    Color(0xff58e86b),
                    Color(0xffffe34f),
                    Color(0xffff8b3d),
                    Color(0xffff334e),
                    Color(0xffb65cff),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 3),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppText('E lehtë', style: TextStyle(fontSize: 9, color: muted)),
                AppText(
                  'Mesatare',
                  style: TextStyle(fontSize: 9, color: muted),
                ),
                AppText(
                  'Shumë e fortë',
                  style: TextStyle(fontSize: 9, color: muted),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _mapButton(IconData icon, String label, VoidCallback? action) =>
      Tooltip(
        message: label,
        child: Semantics(
          button: true,
          enabled: action != null,
          label: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: action,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: glassBlur,
                      sigmaY: glassBlur,
                    ),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: glassSurface(
                        14,
                        shadows: const [
                          BoxShadow(color: Color(0x33000000), blurRadius: 12),
                        ],
                      ),
                      child: Icon(
                        icon,
                        color: action == null ? muted : mint,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  TileLayer _publicWmsLayer(
    String baseUrl,
    List<String> layers, {
    double opacity = .6,
  }) => TileLayer(
    wmsOptions: WMSTileLayerOptions(baseUrl: baseUrl, layers: layers),
    userAgentPackageName: 'al.syri.syri',
    maxNativeZoom: 18,
    maxZoom: 20,
    panBuffer: 0,
    keepBuffer: 1,
    tileDisplay: const TileDisplay.fadeIn(
      duration: Duration(milliseconds: 180),
    ),
    tileBuilder: (context, child, tile) =>
        Opacity(opacity: opacity, child: child),
  );

  String _dayName(DateTime date) =>
      const ['Hën', 'Mar', 'Mër', 'Enj', 'Pre', 'Sht', 'Die'][date.weekday - 1];

  String _forecastDayName(DateTime date) => _ui(
    _dayName(date),
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][date.weekday - 1],
  );

  IconData _weatherIcon(String symbol) => symbol.contains('thunder')
      ? Icons.thunderstorm
      : symbol.contains('snow') || symbol.contains('sleet')
      ? Icons.ac_unit
      : symbol.contains('rain')
      ? Icons.water_drop
      : symbol.contains('cloud') || symbol.contains('fog')
      ? Icons.cloud
      : Icons.wb_sunny;

  Color _weatherColor(String symbol) => symbol.contains('thunder')
      ? Colors.amber
      : symbol.contains('rain')
      ? Colors.lightBlueAccent
      : symbol.contains('snow')
      ? Colors.cyanAccent
      : mint;

  void _weatherDetails() {
    var refreshing = false;
    _sheet(
      StatefulBuilder(
        builder: (sheetContext, updateSheet) {
          final current = weather;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _heading(
                      'Moti në ${city.name}',
                      'Gjendja tani nga Open-Meteo + MET Norway · parashikim 6-ditor',
                    ),
                  ),
                  IconButton(
                    tooltip: _ui('Rifresko motin', 'Refresh weather'),
                    onPressed: refreshing
                        ? null
                        : () async {
                            updateSheet(() => refreshing = true);
                            await _refreshWeather();
                            if (sheetContext.mounted) {
                              updateSheet(() => refreshing = false);
                            }
                          },
                    icon: refreshing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                    color: mint,
                  ),
                ],
              ),
              if (current == null)
                const AppText('Parashikimi nuk është i disponueshëm.')
              else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      _weatherIcon(current.value.symbol),
                      size: 72,
                      color: _weatherColor(current.value.symbol),
                    ),
                    const SizedBox(width: 16),
                    AppText(
                      '${current.value.temperature.round()}°',
                      style: const TextStyle(
                        fontSize: 70,
                        fontWeight: FontWeight.w300,
                        color: mint,
                      ),
                    ),
                  ],
                ),
                AppText(
                  current.value.label,
                  style: const TextStyle(fontSize: 21),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _badge(
                      current.value.rain >= .05
                          ? 'Reshje tani ${current.value.rain.toStringAsFixed(1)} mm'
                          : 'Mundësi shiu ${current.value.rainChance}%',
                      current.value.rain >= .05 || current.value.rainAhead
                          ? Colors.lightBlueAccent
                          : muted,
                    ),
                    _badge(
                      current.value.thunderAhead
                          ? 'Bubullima të mundshme'
                          : 'Pa bubullima',
                      current.value.thunderAhead ? Colors.amber : muted,
                    ),
                    _badge(
                      current.value.hailAhead
                          ? 'Breshër i mundshëm'
                          : 'Pa sinjal breshëri',
                      current.value.hailAhead ? Colors.orangeAccent : muted,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _bullet(
                  'Temperatura',
                  '${current.value.temperature.round()}°C',
                ),
                _bullet('Era', '${current.value.wind.toStringAsFixed(1)} km/h'),
                _bullet(
                  'Reshje tani / në orën e ardhshme',
                  '${current.value.rain.toStringAsFixed(1)} mm',
                ),
                _bullet('Lindja e diellit', _clock(current.value.sunrise)),
                _bullet('Perëndimi i diellit', _clock(current.value.sunset)),
                if (airQuality != null)
                  _bullet(
                    'Cilësia e ajrit',
                    '${airQuality!.value.label} · AQI ${airQuality!.value.europeanAqi.round()}',
                  ),
                _bullet('Parashikimi', dateLabel(current.value.time)),
                _bullet('Përditësuar', dateLabel(current.fetched)),
                if (current.stale)
                  const AppText(
                    'Kopje e ruajtur; burimi nuk u arrit.',
                    style: TextStyle(color: Colors.amber),
                  ),
                const SizedBox(height: 20),
                const AppText(
                  '6 DITËT E ARDHSHME',
                  style: TextStyle(
                    color: muted,
                    fontSize: 11,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 128,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: current.value.days.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, index) {
                      final day = current.value.days[index];
                      return Container(
                        width: 92,
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .055),
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .08),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            AppText(
                              _dayName(day.date),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Icon(
                              _weatherIcon(day.symbol),
                              color: _weatherColor(day.symbol),
                              size: 27,
                            ),
                            AppText(
                              '${day.maximum.round()}° / ${day.minimum.round()}°',
                              style: const TextStyle(fontSize: 12),
                            ),
                            AppText(
                              'Shi ${day.rainChance}%',
                              style: const TextStyle(
                                fontSize: 10,
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const AppText(
                'Ky është parashikim modelesh, jo matje në rrugën tuaj ose paralajmërim zyrtar.',
                style: TextStyle(color: muted, height: 1.5),
              ),
              TextButton(
                onPressed: () => _open('https://open-meteo.com/'),
                child: const AppText('Hap Open-Meteo ↗'),
              ),
            ],
          );
        },
      ),
      accent: weather == null ? mint : _weatherColor(weather!.value.symbol),
    );
  }

  void _airDetails({City? location, FeedResult<AirQuality>? reading}) {
    final current = reading ?? airQuality;
    final displayCity = location ?? city;
    _sheet(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(
            'Ajri në ${displayCity.name}',
            'Modeli CAMS përmes Open-Meteo.',
          ),
          if (current == null)
            const AppText('Të dhënat e ajrit nuk janë ende të disponueshme.')
          else ...[
            AppText(
              'AQI ${current.value.europeanAqi.round()}',
              style: const TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w700,
                color: Colors.tealAccent,
              ),
            ),
            AppText(current.value.label, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 18),
            _bullet('PM2.5', '${current.value.pm25.toStringAsFixed(1)} μg/m³'),
            _bullet('PM10', '${current.value.pm10.toStringAsFixed(1)} μg/m³'),
            _bullet('Indeksi UV', current.value.uv.toStringAsFixed(1)),
            _bullet('Pluhur', '${current.value.dust.toStringAsFixed(1)} μg/m³'),
            _bullet(
              'Polen ulliri',
              current.value.olivePollen == null
                  ? 'Pa të dhëna sezonale'
                  : '${current.value.olivePollen!.toStringAsFixed(1)} kokrra/m³',
            ),
            _bullet(
              'Polen bari',
              current.value.grassPollen == null
                  ? 'Pa të dhëna sezonale'
                  : '${current.value.grassPollen!.toStringAsFixed(1)} kokrra/m³',
            ),
            _bullet('Përditësuar', dateLabel(current.value.time)),
            const SizedBox(height: 12),
            const AppText(
              'Këto janë vlera të modeluara rajonale, jo domosdoshmërisht matje nga një sensor në rrugën tuaj.',
              style: TextStyle(color: muted, height: 1.5),
            ),
          ],
          TextButton(
            onPressed: () =>
                _open('https://open-meteo.com/en/docs/air-quality-api'),
            child: const AppText('Hap burimin ↗'),
          ),
          _disableLayerButton('air'),
        ],
      ),
      accent: Colors.tealAccent,
    );
  }

  void _marineDetails() {
    final current = marineWeather;
    _sheet(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(
            'Deti pranë ${city.name}',
            'Parashikim detar nga Open-Meteo.',
          ),
          if (current == null)
            const AppText('Të dhënat detare nuk janë ende të disponueshme.')
          else ...[
            _bullet(
              'Lartësia e valëve',
              '${current.value.waveHeight.toStringAsFixed(1)} m',
            ),
            _bullet(
              'Periudha e valëve',
              '${current.value.wavePeriod.toStringAsFixed(1)} s',
            ),
            _bullet(
              'Temperatura e detit',
              '${current.value.seaTemperature.toStringAsFixed(1)}°C',
            ),
            _bullet(
              'Shpejtësia e rrymës',
              '${current.value.currentSpeed.toStringAsFixed(1)} km/h',
            ),
            _bullet('Përditësuar', dateLabel(current.value.time)),
            const SizedBox(height: 12),
            const AppText(
              'Parashikimi nuk zëvendëson informacionin zyrtar ose mjetet e navigimit detar.',
              style: TextStyle(color: muted, height: 1.5),
            ),
          ],
          TextButton(
            onPressed: () =>
                _open('https://open-meteo.com/en/docs/marine-weather-api'),
            child: const AppText('Hap burimin ↗'),
          ),
          _disableLayerButton('marine'),
        ],
      ),
      accent: Colors.cyanAccent,
    );
  }

  void _agricultureDetails() {
    final events = results['agriculture']?.value ?? const <Event>[];
    final summary = events.where((event) => event.kind == 'agriculture-info');
    final risks = events.where((event) => event.kind != 'agriculture-info');
    final current = summary.isEmpty ? null : summary.first;
    _sheet(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(
            'Bujqësia në ${city.name}',
            'Kushtet e tokës dhe motit nga Open-Meteo.',
          ),
          if (current == null)
            const AppText('Të dhënat bujqësore nuk janë ende të disponueshme.')
          else ...[
            ...current.description
                .split('\n')
                .where((line) => line.trim().isNotEmpty)
                .map((line) {
                  final parts = line.split(': ');
                  return _bullet(
                    parts.length > 1 ? parts.first : 'Informacion',
                    parts.length > 1 ? parts.skip(1).join(': ') : line,
                  );
                }),
            const SizedBox(height: 12),
            AppText(
              risks.isEmpty
                  ? 'Nuk ka prag alarmi bujqësor për ditën e sotme.'
                  : '${risks.length} paralajmërime bujqësore aktive:',
              style: TextStyle(
                color: risks.isEmpty ? mint : Colors.orangeAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
            for (final risk in risks)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  infoFor(risk.kind).icon,
                  color: infoFor(risk.kind).color,
                ),
                title: AppText(risk.title),
                subtitle: AppText(
                  risk.description.split('\n').first,
                  style: const TextStyle(color: muted),
                ),
              ),
          ],
          TextButton(
            onPressed: () => _open('https://open-meteo.com/en/docs'),
            child: const AppText('Hap burimin ↗'),
          ),
          _disableLayerButton('agriculture'),
        ],
      ),
      accent: Colors.lightGreenAccent,
    );
  }

  Widget _disableLayerButton(String id) => OutlinedButton.icon(
    onPressed: () {
      setState(() => enabled.remove(id));
      Navigator.of(context).pop();
    },
    icon: const Icon(Icons.visibility_off_outlined),
    label: const AppText('Çaktivizo këtë nënkategori'),
  );

  void _layerPicker() {
    _sheet(
      StatefulBuilder(
        builder: (context, update) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              _ui('Zgjidh kategoritë', 'Choose categories'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            AppText(
              _ui(
                'Ndez kategoritë që dëshiron dhe përshtat nënkategoritë.',
                'Turn on the categories you want and adjust their subcategories.',
              ),
              style: const TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            for (final category in mapCategories) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: glassSurface(
                  16,
                  outline: _categoryActive(category.id)
                      ? category.color.withValues(alpha: .65)
                      : Colors.white.withValues(alpha: .13),
                ),
                child: _subcategoryChoices(category.id).isEmpty
                    ? ListTile(
                        key: ValueKey('picker-category-${category.id}'),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                        leading: Icon(
                          category.icon,
                          color: category.color,
                          size: 22,
                        ),
                        title: AppText(
                          category.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch.adaptive(
                              key: ValueKey(
                                'picker-category-toggle-${category.id}',
                              ),
                              value: _categoryActive(category.id),
                              activeTrackColor: category.color,
                              onChanged: (value) {
                                _setCategory(category.id, value);
                                update(() {});
                              },
                            ),
                            const SizedBox(width: 18),
                          ],
                        ),
                        onTap: () {
                          _setCategory(
                            category.id,
                            !_categoryActive(category.id),
                          );
                          update(() {});
                        },
                      )
                    : Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                          splashColor: category.color.withValues(alpha: .12),
                        ),
                        child: ExpansionTile(
                          key: ValueKey('picker-category-${category.id}'),
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            8,
                            0,
                            8,
                            9,
                          ),
                          leading: Icon(
                            category.icon,
                            color: category.color,
                            size: 22,
                          ),
                          title: AppText(
                            category.name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Switch.adaptive(
                                key: ValueKey(
                                  'picker-category-toggle-${category.id}',
                                ),
                                value: _categoryActive(category.id),
                                activeTrackColor: category.color,
                                onChanged: (value) {
                                  _setCategory(category.id, value);
                                  update(() {});
                                },
                              ),
                              Icon(
                                Icons.expand_more,
                                size: 18,
                                color: category.color,
                              ),
                            ],
                          ),
                          children: [
                            for (final choice in _subcategoryChoices(
                              category.id,
                            ))
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Material(
                                  color: _subcategoryActive(choice.$1)
                                      ? choice.$4.withValues(alpha: .11)
                                      : ink.withValues(alpha: .28),
                                  borderRadius: BorderRadius.circular(11),
                                  child: SwitchListTile.adaptive(
                                    key: ValueKey(
                                      'picker-subcategory-${choice.$1}',
                                    ),
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    secondary: Icon(
                                      choice.$3,
                                      color: choice.$4,
                                      size: 18,
                                    ),
                                    title: AppText(
                                      choice.$2,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    value: _subcategoryActive(choice.$1),
                                    activeTrackColor: choice.$4,
                                    onChanged: (value) async {
                                      await _setSubcategory(choice.$1, value);
                                      if (mounted) update(() {});
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
              ),
            ],
            const SizedBox(height: 5),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('map-clear-layers'),
                onPressed: () {
                  _clearAllLayers();
                  update(() {});
                },
                icon: const Icon(Icons.layers_clear),
                label: Text(_ui('Hiqi të gjitha', 'Clear All')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bullet(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 7),
          child: Icon(Icons.circle, size: 6, color: mint),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AppText(
            '$label: $value',
            style: const TextStyle(height: 1.45),
          ),
        ),
      ],
    ),
  );

  String _tr(String key) =>
      touristCopy[touristMode ? touristLanguage : 'sq']?[key] ??
      touristCopy['sq']![key] ??
      key;

  String _ui(String albanian, String english) =>
      syriEnglish ? english : albanian;

  String _localizedWeather(String symbol) {
    if (symbol.contains('thunder')) return _tr('thunder');
    if (symbol.contains('snow') || symbol.contains('sleet')) return _tr('snow');
    if (symbol.contains('rain')) return _tr('rain');
    if (symbol.contains('cloud') || symbol.contains('fog')) {
      return _tr('cloudy');
    }
    return _tr('clear');
  }

  List<Event> get _briefingEvents {
    const newsKeys = {
      'Star Plus TV',
      'KALLXO',
      'RTSH',
      'BalkanWeb',
      'Telegrafi',
      'Reporteri',
      'Gazeta Express',
      'Portalb',
      'Alsat',
      'Koha Javore',
      'Ul-info',
      'local',
      'world',
    };
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    final seen = <String>{};
    final values =
        <Event>[
          ...news,
          for (final entry in results.entries)
            if (!newsKeys.contains(entry.key)) ...entry.value.value,
        ].where((event) {
          if (!isBriefingKind(event.kind) ||
              !_passesEarthquakeMinimum(event) ||
              event.kind == 'cameras' ||
              event.kind == 'geoportal' ||
              event.time == null ||
              event.time!.isBefore(cutoff) ||
              !seen.add('${event.kind}:${event.id}')) {
            return false;
          }
          if (event.point == null) return false;
          final distance = const Distance().as(
            LengthUnit.Kilometer,
            city.point,
            event.point!,
          );
          return distance <= math.max(nearbyRadiusKm, 35);
        }).toList();
    int priority(Event event) {
      if (const {
        'fire',
        'storm',
        'flood',
        'volcano',
        'quakes',
        'power-outage',
        'water-outage',
        'health-alert',
      }.contains(event.kind)) {
        return 0;
      }
      if (event.kind == 'news' && event.tone == 'bad') return 1;
      return 2;
    }

    values.sort((a, b) {
      final byPriority = priority(a).compareTo(priority(b));
      if (byPriority != 0) return byPriority;
      return b.time!.compareTo(a.time!);
    });
    return values.take(5).toList();
  }

  String get _briefingSummary {
    final parts = <String>[];
    if (weather != null) {
      parts.add(
        '${weather!.value.temperature.round()}° · ${_localizedWeather(weather!.value.symbol)} · ${_tr('rainChance')} ${weather!.value.rainChance}%',
      );
    }
    final count = _briefingEvents.length;
    parts.add(
      count == 0
          ? _tr('noUrgent')
          : '$count ${_tr('nearbyUpdates').toLowerCase()}',
    );
    return parts.join('\n');
  }

  void _syriNowDetails() {
    final updates = _briefingEvents;
    _sheet(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('SYRI Tani · ${city.name}', _tr('nowSubtitle')),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: mint.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: mint.withValues(alpha: .32)),
            ),
            child: weather == null
                ? AppText(
                    _tr('weatherUnavailable'),
                    style: const TextStyle(color: muted),
                  )
                : Row(
                    children: [
                      Icon(
                        _weatherIcon(weather!.value.symbol),
                        size: 48,
                        color: _weatherColor(weather!.value.symbol),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppText(
                              '${weather!.value.temperature.round()}° · ${_localizedWeather(weather!.value.symbol)}',
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            AppText(
                              '${_tr('rainChance')} ${weather!.value.rainChance}%${airQuality == null ? '' : ' · ${_tr('airQuality')} AQI ${airQuality!.value.europeanAqi.round()}'}',
                              style: const TextStyle(color: muted, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
          if (weather != null) ...[
            if (weather!.value.days.isNotEmpty) ...[
              const SizedBox(height: 16),
              AppText(
                _ui('PARASHIKIMI 7-DITOR', '7-DAY FORECAST'),
                style: const TextStyle(
                  color: muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 105,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: weather!.value.days.take(7).length,
                  separatorBuilder: (_, _) => const SizedBox(width: 7),
                  itemBuilder: (_, index) {
                    final day = weather!.value.days[index];
                    return Container(
                      width: 76,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .055),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: .12),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          AppText(
                            '${_forecastDayName(day.date)} ${day.date.day}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Icon(
                            _weatherIcon(day.symbol),
                            color: _weatherColor(day.symbol),
                            size: 23,
                          ),
                          AppText(
                            '${day.maximum.round()}°/${day.minimum.round()}°',
                            style: const TextStyle(fontSize: 11),
                          ),
                          AppText(
                            '${_ui('Shi', 'Rain')} ${day.rainChance}%',
                            style: const TextStyle(fontSize: 9, color: muted),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 13),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _badge(
                  '${_ui('Erë', 'Wind')} ${weather!.value.wind.toStringAsFixed(0)} km/h',
                  Colors.lightBlueAccent,
                ),
                _badge(
                  '${_ui('Reshje', 'Rain')} ${weather!.value.rain.toStringAsFixed(1)} mm',
                  Colors.cyanAccent,
                ),
                _badge(
                  '${_ui('Lindja', 'Sunrise')} ${weather!.value.sunrise.hour.toString().padLeft(2, '0')}:${weather!.value.sunrise.minute.toString().padLeft(2, '0')}',
                  Colors.amberAccent,
                ),
                _badge(
                  '${_ui('Perëndimi', 'Sunset')} ${weather!.value.sunset.hour.toString().padLeft(2, '0')}:${weather!.value.sunset.minute.toString().padLeft(2, '0')}',
                  Colors.orangeAccent,
                ),
              ],
            ),
            const SizedBox(height: 8),
            AppText(
              '${_ui('Moti', 'Weather')}: Open-Meteo · ${_ui('përditësuar', 'updated')} ${weather!.fetched.hour.toString().padLeft(2, '0')}:${weather!.fetched.minute.toString().padLeft(2, '0')}',
              style: const TextStyle(color: muted, fontSize: 11),
            ),
          ],
          const SizedBox(height: 22),
          AppText(
            _tr('nearbyUpdates').toUpperCase(),
            style: const TextStyle(
              color: muted,
              fontSize: 11,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          if (updates.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: panel,
                borderRadius: BorderRadius.circular(18),
              ),
              child: AppText(
                _tr('noUrgent'),
                style: const TextStyle(color: muted, height: 1.5),
              ),
            )
          else
            ...updates.map(_eventTile),
          const SizedBox(height: 8),
          AppText(
            _tr('sourceReminder'),
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _shareVisualCard(
                title: 'SYRI Tani · ${city.name}',
                body:
                    _briefingSummary +
                    (updates.isEmpty
                        ? ''
                        : '\n\n${updates.take(3).map((event) => '• ${event.title}').join('\n')}'),
                source: 'SYRI · ${dateLabel(DateTime.now())}',
                location: city.name,
                url: '',
                accent: mint,
              ),
              icon: const Icon(Icons.ios_share_outlined),
              label: AppText(_tr('shareBriefing')),
            ),
          ),
        ],
      ),
      accent: mint,
    );
  }

  Future<void> _shareVisualCard({
    required String title,
    required String body,
    required String source,
    required String location,
    required String url,
    required Color accent,
  }) async {
    try {
      final cardTitle = syriEnglish
          ? await SyriTranslation.translate(title)
          : await SyriTranslation.translateToAlbanian(title);
      final cardBody = syriEnglish
          ? await SyriTranslation.translate(body)
          : await SyriTranslation.translateToAlbanian(body);
      final cardSource = syriEnglish
          ? await SyriTranslation.translate(source)
          : source;
      const width = 1080;
      const height = 1350;
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final bounds = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
      canvas.drawRect(
        bounds,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff071716), Color(0xff173331), Color(0xff091c1b)],
          ).createShader(bounds),
      );
      canvas.drawCircle(
        Offset(width * .86, height * .08),
        260,
        Paint()..color = accent.withValues(alpha: .12),
      );
      canvas.drawCircle(
        Offset(width * .10, height * .90),
        310,
        Paint()..color = mint.withValues(alpha: .08),
      );

      final logoBytes = await rootBundle.load('assets/syri_brand.png');
      final logoCodec = await ui.instantiateImageCodec(
        logoBytes.buffer.asUint8List(),
      );
      final logoFrame = await logoCodec.getNextFrame();
      final logoImage = logoFrame.image;
      canvas.drawImageRect(
        logoImage,
        Rect.fromLTWH(
          0,
          0,
          logoImage.width.toDouble(),
          logoImage.height.toDouble(),
        ),
        const Rect.fromLTWH(72, 70, 142, 142),
        Paint()..filterQuality = FilterQuality.high,
      );
      logoImage.dispose();
      logoCodec.dispose();

      double drawText(
        String text,
        double x,
        double y, {
        required double size,
        required Color color,
        FontWeight weight = FontWeight.w400,
        double maxWidth = 936,
        int? maxLines,
        double heightFactor = 1.22,
      }) {
        final painter = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: color,
              fontSize: size,
              fontWeight: weight,
              height: heightFactor,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: maxLines,
          ellipsis: maxLines == null ? null : '…',
        )..layout(maxWidth: maxWidth);
        painter.paint(canvas, Offset(x, y));
        return painter.height;
      }

      drawText(
        'SYRI',
        246,
        82,
        size: 68,
        color: Colors.white,
        weight: FontWeight.w900,
        maxWidth: 500,
      );
      drawText(
        syriEnglish
            ? 'SEE YOUR REGION INSTANTLY'
            : 'SISTEMI YNË I RAPORTIMIT DHE INFORMIMIT',
        249,
        158,
        size: 20,
        color: muted,
        weight: FontWeight.w600,
        maxWidth: 620,
      );
      final card = RRect.fromRectAndRadius(
        const Rect.fromLTWH(58, 260, 964, 930),
        const Radius.circular(46),
      );
      canvas.drawRRect(card, Paint()..color = const Color(0xee17302f));
      canvas.drawRRect(
        card,
        Paint()
          ..color = accent.withValues(alpha: .55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      var y = 326.0;
      y +=
          drawText(
            location.toUpperCase(),
            112,
            y,
            size: 25,
            color: accent,
            weight: FontWeight.w800,
            maxWidth: 820,
          ) +
          34;
      y +=
          drawText(
            cardTitle,
            112,
            y,
            size: 54,
            color: Colors.white,
            weight: FontWeight.w800,
            maxWidth: 820,
            maxLines: 4,
            heightFactor: 1.14,
          ) +
          38;
      y +=
          drawText(
            cardBody,
            112,
            y,
            size: 31,
            color: const Color(0xffd8e3df),
            maxWidth: 820,
            maxLines: 8,
            heightFactor: 1.38,
          ) +
          34;
      drawText(
        '${_tr('source')}: $cardSource',
        112,
        math.min(y, 1070.0),
        size: 24,
        color: muted,
        weight: FontWeight.w600,
        maxWidth: 820,
        maxLines: 2,
      );
      drawText(
        _tr('publicData'),
        72,
        1244,
        size: 22,
        color: muted,
        maxWidth: 936,
        maxLines: 1,
      );
      final image = await recorder.endRecording().toImage(width, height);
      final data = await image.toByteData(format: ImageByteFormat.png);
      if (data == null) throw StateError('PNG');
      final bytes = data.buffer.asUint8List();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'image/png')],
          fileNameOverrides: ['syri-card.png'],
          title: cardTitle,
          subject: cardTitle,
          text: url.isEmpty ? cardTitle : '$cardTitle\n$url',
        ),
      );
    } catch (_) {
      _toast('Karta nuk u nda. Provoni përsëri.');
    }
  }

  Future<void> _call112() async {
    try {
      if (!await launchUrl(Uri(scheme: 'tel', path: '112'))) {
        _toast('Telefonata nuk u hap.');
      }
    } catch (_) {
      _toast('Telefonata nuk u hap.');
    }
  }

  void _touristGuide() {
    final updates = _briefingEvents.take(3).toList();
    _sheet(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(
            '${_tr('touristGuide')} · ${city.name}',
            _tr('touristSubtitle'),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.redAccent.withValues(alpha: .35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.emergency_outlined,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(width: 9),
                    AppText(
                      _tr('emergency'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                AppText(
                  _tr('emergencyBody'),
                  style: const TextStyle(
                    color: Color(0xffd7e0dd),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 13),
                FilledButton.icon(
                  onPressed: _call112,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.call),
                  label: AppText(_tr('call112')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppText(
            _tr('nearbyUpdates').toUpperCase(),
            style: const TextStyle(
              color: muted,
              fontSize: 11,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          if (updates.isEmpty)
            AppText(
              _tr('noUrgent'),
              style: const TextStyle(color: muted, height: 1.5),
            )
          else
            ...updates.map(_eventTile),
          const SizedBox(height: 12),
          AppText(
            _tr('officialSources'),
            style: const TextStyle(color: muted, height: 1.5),
          ),
        ],
      ),
      accent: Colors.lightBlueAccent,
    );
  }

  void _tvDetails(Event event) {
    final channel = tvChannels.firstWhere(
      (item) => event.id == 'tv-${item.id}',
    );
    const accent = Color(0xffffa967);
    _sheet(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _badge(_ui('KANAL TELEVIZIV', 'TV CHANNEL'), accent),
          const SizedBox(height: 20),
          Text(
            channel.name,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 76,
                height: 58,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0x331b3131),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accent.withValues(alpha: 0.45)),
                ),
                child: channel.logoAsset == null
                    ? Center(
                        child: Text(
                          channel.name,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    : Image.asset(
                        channel.logoAsset!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.live_tv_rounded,
                              color: accent,
                              size: 32,
                            ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: ink,
                    minimumSize: const Size(0, 54),
                  ),
                  onPressed: () => _open(channel.url),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: Text(_ui('Hap kanalin', 'Open channel')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _tvFact(_ui('Qyteti', 'City'), channel.city),
          _tvFact(
            _ui('Vendi', 'Country'),
            syriEnglish
                ? switch (channel.country) {
                    'Shqipëri' => 'Albania',
                    'Kosovë' => 'Kosovo',
                    'Mali i Zi' => 'Montenegro',
                    _ => 'North Macedonia',
                  }
                : channel.country,
          ),
          _tvFact(
            _ui('Lloji', 'Type'),
            syriEnglish
                ? switch (channel.type) {
                    'Lajme' => 'News',
                    'Publik' => 'Public broadcaster',
                    _ => 'General',
                  }
                : channel.type,
          ),
          const SizedBox(height: 12),
          Text(
            _ui(
              'Hapet faqja zyrtare e transmetuesit. Disponueshmëria e videos dhe kufizimet rajonale varen prej tij.',
              'Opens the broadcaster’s official page. Video availability and regional restrictions are controlled by the broadcaster.',
            ),
            style: const TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ),
      accent: accent,
    );
  }

  Widget _tvFact(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      children: [
        const Icon(Icons.circle, size: 6, color: mint),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(color: muted)),
        Flexible(child: Text(value)),
      ],
    ),
  );

  void _eventDetails(Event event) {
    if (event.kind == 'tv') {
      _tvDetails(event);
      return;
    }
    if (event.kind == 'planes') {
      _planeDetails(event);
      return;
    }
    final info = infoFor(event.kind);
    final related = relatedReports(event, _allNews);
    _sheet(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _badge(info.name, info.color),
              const Spacer(),
              Flexible(
                child: AppText(
                  event.source,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(color: muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          _badge(event.dataMode, _dataModeColor(event.dataMode)),
          const SizedBox(height: 19),
          AppText(
            event.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          if (event.kind == 'news') ...[
            const SizedBox(height: 14),
            AppText(
              event.summary ?? 'Ky burim nuk ka dhënë një përmbledhje të shkurtër. Artikulli i plotë hapet te faqja origjinale.',
              style: const TextStyle(
                color: Color(0xffd7e0dd),
                fontSize: 15,
                height: 1.55,
              ),
            ),
          ],
          if (event.kind == 'cameras') ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _open(event.url),
                icon: const Icon(Icons.play_circle_fill_rounded),
                label: AppText(_ui('Hap kamerën tani', 'Watch camera now')),
              ),
            ),
            const SizedBox(height: 7),
            AppText(
              _ui(
                'Pamja hapet te faqja origjinale. Disponueshmëria mund të ndryshojë.',
                'Opens on the original camera page. Availability may vary.',
              ),
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ],
          if (event.kind == 'places') ...[
            const SizedBox(height: 14),
            _placeInsightCard(event),
          ],
          if (const {
            'quakes',
            'fire',
            'storm',
            'flood',
            'volcano',
            'hazards',
            'cems',
          }.contains(event.kind)) ...[
            const SizedBox(height: 14),
            _riskSummary(event),
          ],
          const SizedBox(height: 13),
          if (event.time != null && event.kind != 'cameras')
            Row(
              children: [
                Icon(
                  DateTime.now().difference(event.time!).inHours <= 2
                      ? Icons.bolt_rounded
                      : Icons.schedule_rounded,
                  size: 14,
                  color: DateTime.now().difference(event.time!).inHours <= 2
                      ? mint
                      : muted,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: AppText(
                    '${_eventTimeVerb(event)} · ${dateLabel(event.time!)} · ${_freshnessLabel(event.time!)}',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          _eventSourceStatus(event),
          if (related.isNotEmpty) ...[
            const SizedBox(height: 15),
            AppText(
              _ui(
                'Mbulime të tjera · përputhje automatike',
                'Other coverage · automatically matched',
              ),
              style: const TextStyle(color: mint, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 7),
            for (final report in related)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: AppText(
                  report.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: AppText(
                  '${report.source} · ${dateLabel(report.time!)}',
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
                trailing: const Icon(Icons.open_in_new, size: 17, color: mint),
                onTap: () => _open(report.url),
              ),
          ],
          const SizedBox(height: 18),
          ...event.description
              .split('\n')
              .where((line) => line.trim().isNotEmpty)
              .map((line) {
                final parts = line.split(': ');
                return _bullet(
                  parts.length > 1 ? parts.first : 'Informacion',
                  parts.length > 1 ? parts.skip(1).join(': ') : line,
                );
              }),
          if (event.approximate && event.point != null) ...[
            const SizedBox(height: 15),
            _badge('Vendndodhje e përafërt', Colors.amber),
          ],
          const SizedBox(height: 24),
          if (event.kind != 'cameras')
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _open(event.url),
                icon: const Icon(Icons.open_in_new),
                label: const AppText('Lexo te burimi'),
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('share-event-card'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.lightBlueAccent,
                side: const BorderSide(color: Colors.lightBlueAccent),
              ),
              onPressed: () => _shareVisualCard(
                title: event.title,
                body: event.summary ?? event.description,
                source: event.source,
                location: event.point == null
                    ? 'Bota'
                    : matchCity('${event.title} ${event.description}')?.name ??
                          city.name,
                url: event.url,
                accent: info.color,
              ),
              icon: const Icon(Icons.share_rounded),
              label: AppText(_tr('shareCard')),
            ),
          ),
          if (event.point != null && event.kind != 'planes') ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _open(
                  'https://www.google.com/maps/dir/?api=1&destination=${event.point!.latitude},${event.point!.longitude}',
                ),
                icon: const Icon(Icons.directions_outlined),
                label: const AppText('Navigo te kjo pikë'),
              ),
            ),
          ],
          if (event.kind == 'places') ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _open(
                  'https://www.google.com/search?q=${Uri.encodeQueryComponent('${event.title} ${city.country} aktivitete')}',
                ),
                icon: const Icon(Icons.search),
                label: const AppText('Kërko më shumë për këtë vend'),
              ),
            ),
          ],
          const SizedBox(height: 10),
          const AppText(
            'Raportimi i plotë hapet te botuesi origjinal.',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ],
      ),
      accent: info.color,
    );
  }

  String _eventTimeVerb(Event event) => switch (event.kind) {
    'news' => _ui('Publikuar', 'Published'),
    'river-level' => _ui('Matur', 'Measured'),
    'airport-arrival' || 'airport-departure' => _ui('Kontrolluar', 'Checked'),
    _ => _ui('Raportuar', 'Reported'),
  };

  Widget _eventSourceStatus(Event event) {
    String? key;
    FeedResult<List<Event>>? feed;
    for (final entry in results.entries) {
      if (entry.value.value.any((item) => item.id == event.id)) {
        key = entry.key;
        feed = entry.value;
        break;
      }
    }
    final checked = key == null ? null : sourceCheckedAt[key];
    final status = feed == null
        ? _ui(
            'Gjendja e burimit nuk është e disponueshme.',
            'Source status is unavailable.',
          )
        : feed.stale || failures.contains(key)
        ? _ui(
            'Po shfaqet kopja e fundit e ruajtur.',
            'Showing the latest saved copy.',
          )
        : _ui('Burimi është i disponueshëm.', 'Source is available.');
    final updated = feed == null
        ? ''
        : _ui(
            'Përditësuar: ${dateLabel(feed.fetched)}',
            'Updated: ${dateLabel(feed.fetched)}',
          );
    final checkedLabel = checked == null
        ? _ui('Kontrolli i fundit: i panjohur', 'Last check: unknown')
        : _ui(
            'Kontrolluar: ${dateLabel(checked)}',
            'Checked: ${dateLabel(checked)}',
          );
    return Semantics(
      label: '$status $updated $checkedLabel',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            feed == null || feed.stale || failures.contains(key)
                ? Icons.info_outline
                : Icons.verified_outlined,
            color: feed == null || feed.stale || failures.contains(key)
                ? Colors.amberAccent
                : mint,
            size: 15,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              [
                status,
                if (updated.isNotEmpty) updated,
                checkedLabel,
              ].join(' · '),
              style: const TextStyle(color: muted, fontSize: 11, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  String _freshnessLabel(DateTime time) {
    final age = DateTime.now().difference(time);
    if (age.isNegative || age.inMinutes < 2) return _ui('tani', 'now');
    if (age.inMinutes < 60) {
      return _ui('${age.inMinutes} min më parë', '${age.inMinutes} min ago');
    }
    if (age.inHours < 24) {
      return _ui('${age.inHours} orë më parë', '${age.inHours} hours ago');
    }
    return _ui('${age.inDays} ditë më parë', '${age.inDays} days ago');
  }

  Color _dataModeColor(String mode) => switch (mode) {
    'LIVE' => Colors.greenAccent,
    'AFËR KOHËS REALE' => Colors.orangeAccent,
    'PARASHIKIM' => Colors.lightBlueAccent,
    'RAPORTIM' => const Color(0xff91b5ff),
    'LIDHJE E JASHTME' => Colors.amber,
    _ => muted,
  };

  Widget _placeInsightCard(Event event) => FutureBuilder<PlaceInsight>(
    future: api.placeInsight(event),
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Row(
          children: [
            SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            AppText('Po kërkojmë informacion për vendin…'),
          ],
        );
      }
      final insight = snapshot.data;
      if (insight == null) return const SizedBox.shrink();
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.amberAccent.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.amberAccent.withValues(alpha: .25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText(
              'RRETH VENDIT',
              style: TextStyle(
                color: Colors.amberAccent,
                fontSize: 11,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (insight.summary != null) ...[
              const SizedBox(height: 9),
              AppText(
                insight.summary!,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(height: 1.5),
              ),
              const SizedBox(height: 5),
              AppText(
                'Wikipedia${insight.language == 'en' ? ' · anglisht' : ''}',
                style: const TextStyle(color: muted, fontSize: 11),
              ),
            ],
            const SizedBox(height: 13),
            const AppText(
              'Aktivitete dhe përdorime',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ...insight.activities.map(
              (activity) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: mint,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: AppText(activity)),
                  ],
                ),
              ),
            ),
            if (insight.sourceUrl != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _open(insight.sourceUrl!),
                  icon: const Icon(Icons.menu_book_outlined, size: 17),
                  label: const AppText('Lexo përmbledhjen e plotë'),
                ),
              ),
          ],
        ),
      );
    },
  );

  Widget _riskSummary(Event event) {
    final message = switch (event.kind) {
      'quakes' => 'Kontrollo magnitudën, thellësinë dhe orën. Një ngjarje e cekët mund të ndihet më fort pranë epiqendrës.',
      'fire' => 'Shiko kohën e zbulimit, sipërfaqen dhe sinjalet e fundit. Pika satelitore mund të jetë burim nxehtësie dhe jo zjarr i konfirmuar.',
      'storm' => 'Kontrollo nivelin e alarmit, zonën dhe kohën e përditësimit përpara udhëtimit.',
      'flood' => 'Krahaso zonën e raportuar me rrugën tënde dhe ndiq udhëzimet e autoriteteve vendore.',
      'volcano' => 'Ky është sinjal rajonal nga një sistem global; hap burimin për zonën e ndikimit.',
      'cems' => 'Copernicus publikon harta satelitore të zonës dhe dëmit pas aktivizimit të emergjencës.',
      'health-alert' => 'Lexo udhëzimin e institucionit shëndetësor dhe kontrollo datën, zonën dhe grupet më të rrezikuara.',
      'food-alert' => 'Kontrollo emrin, markën, lotin dhe afatin e produktit përpara përdorimit ose kthimit.',
      'port-alert' => 'Kontrollo portin, linjën, orarin dhe nëse lundrimi është pezulluar ose vonuar.',
      'frost' =>
        'Mbro bimët e ndjeshme dhe kontrollo temperaturën minimale të natës.',
      'hail' =>
        'Siguro kulturat, serrat dhe automjetet kur ka mundësi breshëri.',
      'drought' =>
        'Krahaso lagështinë e tokës, reshjet dhe avullimin përpara ujitjes.',
      'heat' =>
        'Planifiko ujitjen dhe mbrojtjen e kafshëve jashtë orëve më të nxehta.',
      'wind' =>
        'Kontrollo rafalet përpara punës në sera, pemëtari ose zona të hapura.',
      _ => 'Hap burimin zyrtar për zonën, nivelin dhe udhëzimet më të fundit.',
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: infoFor(event.kind).color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: infoFor(event.kind).color.withValues(alpha: .35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: infoFor(event.kind).color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: AppText(message, style: const TextStyle(height: 1.45)),
          ),
        ],
      ),
    );
  }

  void _planeDetails(Event event) {
    final route = api.aircraftRoute(event.title);
    _sheet(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _badge('AVION LIVE', mint),
              const Spacer(),
              const AppText('ADSB.lol', style: TextStyle(color: muted)),
            ],
          ),
          const SizedBox(height: 18),
          AppText(
            event.title,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          AppText(
            event.time == null
                ? 'Pozicion i freskët'
                : 'Pozicioni · ${dateLabel(event.time!)}',
            style: const TextStyle(color: muted),
          ),
          const SizedBox(height: 20),
          ...event.description
              .split('\n')
              .where((line) => line.trim().isNotEmpty)
              .map((line) {
                final parts = line.split(': ');
                return _bullet(
                  parts.length > 1 ? parts.first : 'Informacion',
                  parts.length > 1 ? parts.skip(1).join(': ') : line,
                );
              }),
          const Divider(height: 30),
          const AppText(
            'ITINERARI',
            style: TextStyle(color: muted, fontSize: 11, letterSpacing: 1.4),
          ),
          const SizedBox(height: 12),
          FutureBuilder<FeedResult<AircraftRoute>>(
            future: route,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    AppText('Po kërkojmë itinerarin…'),
                  ],
                );
              }
              if (!snapshot.hasData) {
                return const AppText(
                  'Origjina dhe destinacioni nuk publikohen për këtë fluturim.',
                  style: TextStyle(color: muted, height: 1.5),
                );
              }
              final value = snapshot.data!.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bullet('Kompania', value.airline),
                  _bullet('Nisja', '${value.originName} (${value.originCode})'),
                  _bullet(
                    'Destinacioni',
                    '${value.destinationName} (${value.destinationCode})',
                  ),
                  if (snapshot.data!.stale)
                    const AppText(
                      'Itinerar nga kopja e ruajtur.',
                      style: TextStyle(color: Colors.amber, fontSize: 12),
                    ),
                  const SizedBox(height: 5),
                  const AppText(
                    'Itinerari lidhet me kodin e fluturimit dhe mund të ndryshojë ose të jetë i pasaktë.',
                    style: TextStyle(color: muted, fontSize: 12, height: 1.45),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _open(event.url),
              icon: const Icon(Icons.open_in_new),
              label: const AppText('Ndiq avionin te ADSB.lol'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _shareVisualCard(
                title: event.title,
                body: event.description,
                source: event.source,
                location: city.name,
                url: event.url,
                accent: infoFor('planes').color,
              ),
              icon: const Icon(Icons.ios_share_outlined),
              label: AppText(_tr('shareCard')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .13),
      borderRadius: BorderRadius.circular(8),
    ),
    child: AppText(
      value,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
    ),
  );

  Widget _eventTile(Event event) {
    final info = infoFor(event.kind);
    final icon = event.kind == 'news'
        ? (event.newsType == 'violence'
              ? Icons.crisis_alert
              : event.newsType == 'death'
              ? Icons.heart_broken
              : event.newsType == 'crime'
              ? Icons.gavel
              : event.newsType == 'crash'
              ? Icons.car_crash
              : event.tone == 'good'
              ? Icons.sentiment_satisfied_alt
              : event.tone == 'bad'
              ? Icons.warning_amber_rounded
              : info.icon)
        : info.icon;
    final color = event.kind == 'news' && event.tone == 'good'
        ? Colors.greenAccent
        : event.kind == 'news' && event.newsType == 'violence'
        ? Colors.redAccent
        : event.kind == 'news' && event.newsType == 'death'
        ? Colors.blueGrey
        : event.kind == 'news' && event.tone == 'bad'
        ? Colors.orangeAccent
        : info.color;
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: .10), panel, panel],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: .32)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _eventDetails(event),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 29,
                    height: 29,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(icon, size: 17, color: color),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: AppText(
                      event.source,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(Icons.north_east, size: 15, color: muted),
                ],
              ),
              const SizedBox(height: 11),
              AppText(
                event.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              if (event.kind != 'news' && event.kind != 'planes') ...[
                const SizedBox(height: 7),
                AppText(
                  event.description
                      .split('\n')
                      .where((line) => line.trim().isNotEmpty)
                      .take(2)
                      .join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 11),
              Row(
                children: [
                  Expanded(
                    child: AppText(
                      event.time == null
                          ? 'Pa datë të publikuar'
                          : dateLabel(event.time!),
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppText(
                    event.dataMode,
                    style: TextStyle(
                      fontSize: 9,
                      color: _dataModeColor(event.dataMode),
                      fontWeight: FontWeight.w700,
                      letterSpacing: .25,
                    ),
                  ),
                ],
              ),
              if (event.kind == 'news') ...[
                const SizedBox(height: 7),
                AppText(
                  event.point == null
                      ? 'Pa vendndodhje të përcaktuar'
                      : '${matchCity(event.title)?.name ?? 'Rajoni'} · vendndodhje e përafërt',
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _eventSearchText(String value) =>
      normalize(value)
          .replaceAll(RegExp('[áàâäãå]'), 'a')
          .replaceAll(RegExp('[éèêë]'), 'e')
          .replaceAll(RegExp('[íìîï]'), 'i')
          .replaceAll(RegExp('[óòôöõ]'), 'o')
          .replaceAll(RegExp('[úùûü]'), 'u')
          .replaceAll(RegExp('[šś]'), 's')
          .replaceAll(RegExp('[žź]'), 'z')
          .replaceAll(RegExp('[ćč]'), 'c')
          .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

  bool _eventMatchesSearch(Event event, String query) {
    final info = infoFor(event.kind);
    final text = _eventSearchText(
      '${event.title} ${event.summary ?? ''} ${event.description} '
      '${event.source} ${event.kind} ${info.name}',
    );
    const aliases = <String, List<String>>{
      'fire': ['fire', 'zjarr', 'wildfire', 'incendio', 'pozar'],
      'zjarr': ['fire', 'zjarr', 'wildfire', 'incendio', 'pozar'],
      'gunshot': ['gunshot', 'shooting', 'te shtena', 'arme', 'qellim'],
      'shooting': ['gunshot', 'shooting', 'te shtena', 'arme', 'qellim'],
      'arme': ['gunshot', 'shooting', 'te shtena', 'arme', 'pistolete'],
      'water': ['water', 'uje', 'uji', 'wasser', 'acqua'],
      'uje': ['water', 'uje', 'uji', 'wasser', 'acqua'],
      'quality': ['quality', 'cilesi', 'qualitat', 'qualita'],
      'cilesi': ['quality', 'cilesi', 'qualitat', 'qualita'],
      'earthquake': ['earthquake', 'termet', 'potres', 'sisma'],
      'termet': ['earthquake', 'termet', 'potres', 'sisma'],
      'flood': ['flood', 'permbytje', 'inondation', 'uberschwemmung'],
      'permbytje': ['flood', 'permbytje', 'inondation'],
      'crime': ['crime', 'krim', 'dhune', 'violence'],
      'krim': ['crime', 'krim', 'dhune', 'violence'],
      'accident': ['accident', 'aksident', 'crash', 'perplasje'],
      'aksident': ['accident', 'aksident', 'crash', 'perplasje'],
      'traffic': ['traffic', 'trafik', 'kolone', 'congestion'],
      'trafik': ['traffic', 'trafik', 'kolone', 'congestion'],
      'storm': ['storm', 'stuhi', 'thunder', 'bubullime'],
      'weather': ['weather', 'mot', 'moti', 'meteo'],
      'power': ['power', 'energji', 'electricity', 'rryme'],
      'outage': ['outage', 'nderprerje', 'blackout'],
    };
    final words = _eventSearchText(query)
        .split(' ')
        .where((word) => word.isNotEmpty);
    return words.every((word) {
      final alternatives = aliases[word] ?? [word];
      return alternatives.any(text.contains);
    });
  }

  Widget _eventSearchField() => Container(
    decoration: BoxDecoration(
      color: panel.withValues(alpha: .76),
      borderRadius: BorderRadius.circular(23),
      border: Border.all(color: Colors.white.withValues(alpha: .16)),
      boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 18)],
    ),
    child: TextField(
      key: const ValueKey('events-search'),
      controller: eventSearchController,
      textInputAction: TextInputAction.search,
      onChanged: (value) => setState(() => eventSearchQuery = value),
      decoration: InputDecoration(
        hintText: _ui(
          'Kërko zjarr, të shtëna, cilësi uji…',
          'Search fires, gunshots, water quality…',
        ),
        hintStyle: const TextStyle(color: muted, fontSize: 14),
        prefixIcon: const Icon(Icons.search, color: mint),
        suffixIcon: eventSearchQuery.isEmpty
            ? null
            : IconButton(
                tooltip: _ui('Pastro kërkimin', 'Clear search'),
                onPressed: () {
                  eventSearchController.clear();
                  setState(() => eventSearchQuery = '');
                },
                icon: const Icon(Icons.close, color: muted),
              ),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
      ),
    ),
  );

  Widget _eventsPage() {
    const newsKeys = {
      'Star Plus TV',
      'KALLXO',
      'RTSH',
      'BalkanWeb',
      'Telegrafi',
      'Reporteri',
      'Gazeta Express',
      'Portalb',
      'Alsat',
      'Koha Javore',
      'Ul-info',
      'local',
      'world',
    };
    final seen = <String>{};
    final allLoaded =
        <Event>[
              ...news,
              for (final entry in results.entries)
                if (!newsKeys.contains(entry.key)) ...entry.value.value,
            ]
            .where(
              (event) =>
                  isEventsFeedKind(event.kind) &&
                  _passesEarthquakeMinimum(event) &&
                  event.time != null &&
                  event.time!.isAfter(
                    DateTime.now().subtract(
                      Duration(hours: event.kind == 'news' ? newsMaxHours : 48),
                    ),
                  ) &&
                  seen.add('${event.kind}:${event.id}'),
            )
            .toList()
          ..sort(
            (a, b) =>
                (b.time ?? DateTime(1970)).compareTo(a.time ?? DateTime(1970)),
          );
    List<Event> items;
    if (eventSearchQuery.trim().isNotEmpty) {
      final searchSeen = <String>{};
      items =
          <Event>[...allLoaded, ...worldNews]
              .where((event) => searchSeen.add('${event.kind}:${event.id}'))
              .where((event) => _eventMatchesSearch(event, eventSearchQuery))
              .toList()
            ..sort(
              (a, b) => (b.time ?? DateTime(1970)).compareTo(
                a.time ?? DateTime(1970),
              ),
            );
    } else if (eventFilter == 'Bota') {
      items = worldNews;
    } else if (eventFilter == 'Pranë qytetit') {
      items = allLoaded
          .where(
            (event) =>
                event.point != null &&
                const Distance().as(
                      LengthUnit.Kilometer,
                      city.point,
                      event.displayPoint,
                    ) <=
                    nearbyRadiusKm,
          )
          .toList();
    } else if (eventFilter == 'Lajme') {
      items = allLoaded.where((event) => event.kind == 'news').toList();
    } else if (eventFilter == 'Alarme') {
      items = allLoaded
          .where(
            (event) => const {
              'quakes',
              'fire',
              'storm',
              'flood',
              'volcano',
              'hazards',
              'cems',
              'frost',
              'hail',
              'drought',
              'heat',
              'wind',
              'hydrology-alert',
              'internet-outage',
            }.contains(event.kind),
          )
          .toList();
    } else if (eventFilter == 'Shëndet') {
      items = allLoaded
          .where(
            (event) =>
                const {'health-alert', 'food-alert'}.contains(event.kind),
          )
          .toList();
    } else if (eventFilter == 'Transport') {
      items = allLoaded
          .where(
            (event) => const {
              'planes',
              'transit',
              'roadwork',
              'borders',
              'airport-arrival',
              'airport-departure',
            }.contains(event.kind),
          )
          .toList();
    } else if (eventFilter == 'Shërbime') {
      items = allLoaded
          .where(
            (event) => const {
              'health',
              'pharmacy',
              'police',
              'fire_station',
              'aed',
              'charging',
              'parking',
              'services',
              'utilities',
              'power-outage',
              'water-outage',
              'civic-alert',
              'energy-grid',
            }.contains(event.kind),
          )
          .toList();
    } else if (eventFilter == 'Deti') {
      items = allLoaded
          .where(
            (event) =>
                const {'ships', 'port-alert', 'water'}.contains(event.kind),
          )
          .toList();
    } else if (eventFilter == 'Mjedisi') {
      items = allLoaded
          .where(
            (event) => const {
              'water',
              'environment',
              'river-level',
            }.contains(event.kind),
          )
          .toList();
    } else {
      items = allLoaded;
    }
    return RefreshIndicator(
      onRefresh: () => _refreshEventsOnOpen(force: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(17),
            decoration: glassSurface(21, outline: mint.withValues(alpha: .34)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: _badge('HAPËSIRA SHQIPFOLËSE', mint),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: busy.isEmpty
                          ? () => unawaited(_refreshEventsOnOpen(force: true))
                          : null,
                      tooltip: _ui('Rifresko', 'Refresh'),
                      icon: const Icon(Icons.refresh, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                const AppText(
                  'Çfarë po ndodh?',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const AppText(
                  'Raportime publike, gjithmonë me burimin.',
                  style: TextStyle(color: muted, fontSize: 13),
                ),
                const SizedBox(height: 11),
                AppText(
                  _ui(
                    '${items.length} raportime në këtë pamje',
                    '${items.length} reports in this view',
                  ),
                  style: const TextStyle(
                    color: mint,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          _eventSearchField(),
          const SizedBox(height: 12),
          if (eventSearchQuery.trim().isNotEmpty) ...[
            AppText(
              '${items.length} rezultate në të gjitha burimet',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 10),
          ],
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  ['Të gjitha', 'Bota', 'Pranë qytetit', 'Alarme', 'Lajme']
                      .map(
                        (filter) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: AppText(filter),
                            selected: eventFilter == filter,
                            backgroundColor: panel,
                            selectedColor: mint.withValues(alpha: .22),
                            side: BorderSide(
                              color: eventFilter == filter
                                  ? mint.withValues(alpha: .72)
                                  : Colors.white.withValues(alpha: .18),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            onSelected: (_) =>
                                setState(() => eventFilter = filter),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
          if (eventSearchQuery.trim().isEmpty && eventFilter == 'Bota') ...[
            const SizedBox(height: 10),
            const AppText(
              'Maksimumi 8 lajme botërore të rëndësishme · vetëm 24 orët e fundit',
              style: TextStyle(color: muted, fontSize: 11),
            ),
          ],
          const SizedBox(height: 17),
          if (failures.contains('Star Plus TV') || failures.contains('KALLXO'))
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: AppText(
                'Disa burime nuk u arritën. Kopjet e ruajtura mund të jenë të vjetra.',
                style: TextStyle(color: Colors.amber, height: 1.5),
              ),
            ),
          if (busy.isNotEmpty) const LinearProgressIndicator(minHeight: 2),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 42),
              child: Column(
                children: [
                  const Icon(Icons.travel_explore, size: 44, color: muted),
                  const SizedBox(height: 15),
                  AppText(
                    busy.isNotEmpty
                        ? 'Po kërkojmë raportimet…'
                        : eventSearchQuery.trim().isNotEmpty
                        ? 'Nuk u gjet asnjë raportim për këtë kërkim.'
                        : 'Nuk ka raportime në këtë filtër.',
                  ),
                  const SizedBox(height: 8),
                  const AppText(
                    'Kjo nuk do të thotë se nuk ka ngjarje.',
                    style: TextStyle(color: muted),
                  ),
                ],
              ),
            )
          else
            ...items.map(_eventTile),
          const AppText(
            'Titujt tregojnë raportime të botuesve. Pikat e qyteteve nuk janë adresa të verifikuara incidentesh.',
            style: TextStyle(color: muted, fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  List<(String, String, IconData, Color)> _notificationSubcategories(
    String category,
  ) =>
      _subcategoryChoices(category)
          .where((choice) => notificationAllowedKeys.contains(choice.$1))
          .toList();

  Future<String> _backgroundNotificationStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (!notificationsEnabled) return 'Njoftimet janë të fikura.';
    if (prefs.getBool('setting_background_scheduled') != true) {
      return 'Kontrolli në sfond nuk është planifikuar.';
    }
    if (Platform.isAndroid) {
      try {
        if (!await Workmanager().isScheduledByUniqueName(syriBackgroundTask)) {
          return 'Android nuk ka një kontroll aktiv në sfond.';
        }
      } catch (_) {}
    }
    final checked = DateTime.tryParse(
      prefs.getString('setting_background_checked') ?? '',
    );
    var batterySaverOn = false;
    if (Platform.isAndroid) {
      try {
        batterySaverOn =
            await _syriPowerChannel.invokeMethod<bool>('isBatterySaverOn') ??
            false;
      } catch (_) {}
    }
    if (batterySaverOn) {
      return 'Kursimi i baterisë është aktiv dhe mund të ndalë kontrollet në sfond.';
    }
    if (checked == null) {
      return 'Android nuk e ka kryer ende kontrollin e parë në sfond.';
    }
    final ago = DateTime.now().difference(checked);
    final date =
        '${checked.day.toString().padLeft(2, '0')}.'
        '${checked.month.toString().padLeft(2, '0')} '
        '${checked.hour.toString().padLeft(2, '0')}:'
        '${checked.minute.toString().padLeft(2, '0')}';
    final reports = prefs.getInt('setting_background_report_count') ?? 0;
    final lastAlert = DateTime.tryParse(
      prefs.getString('setting_background_notified_at') ?? '',
    );
    final lastAlertLabel = lastAlert == null
        ? 'Ende pa alarm të përshtatshëm'
        : 'Alarmi i fundit: ${lastAlert.day.toString().padLeft(2, '0')}.${lastAlert.month.toString().padLeft(2, '0')} ${lastAlert.hour.toString().padLeft(2, '0')}:${lastAlert.minute.toString().padLeft(2, '0')}';
    return ago > const Duration(hours: 2)
        ? 'Kontrolli i fundit: $date · Android mund ta ketë shtyrë.'
        : 'Kontrolli i fundit: $date · $reports raportime të shqyrtuara. $lastAlertLabel.';
  }

  void _notificationSettings() => _sheet(
    StatefulBuilder(
      builder: (context, update) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading(
            'Njoftimet',
            'Zgjidh kategoritë dhe nënkategoritë për të cilat dëshiron alarm.',
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.notifications_active, color: mint),
            title: const AppText('Aktivizo njoftimet'),
            subtitle: AppText(
              notificationsEnabled
                  ? 'Alarmet e zgjedhura janë aktive.'
                  : 'Lejo SYRI të shfaqë njoftime.',
              style: const TextStyle(color: muted, fontSize: 12),
            ),
            value: notificationsEnabled,
            onChanged: (value) async {
              var allowed = true;
              if (value) allowed = await _requestNotificationPermission();
              if (!mounted) return;
              setState(() {
                notificationsEnabled = value && allowed;
                if (notificationsEnabled) notificationStart = DateTime.now();
              });
              if (notificationsEnabled) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString(
                  'setting_notifications_started_at',
                  notificationStart.toIso8601String(),
                );
              }
              unawaited(
                _configureBackgroundNotifications(notificationsEnabled),
              );
              update(() {});
              _saveSettings();
              if (value && !allowed) {
                _toast('Leja për njoftime nuk u dha.');
              }
            },
          ),
          const Divider(),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.crisis_alert, color: Colors.redAccent),
            title: const AppText('Vetëm njoftime të rëndësishme'),
            subtitle: const AppText(
              'Filtron lajmet e zakonshme dhe mban alarmet me ndikim.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            value: urgentNotificationsOnly,
            onChanged: (value) {
              setState(() => urgentNotificationsOnly = value);
              update(() {});
              _saveSettings();
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.volume_up_outlined, color: mint),
            title: const AppText('Tingulli'),
            value: notificationSound,
            onChanged: (value) {
              setState(() => notificationSound = value);
              update(() {});
              _saveSettings();
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(
              Icons.bedtime_outlined,
              color: Colors.indigoAccent,
            ),
            title: const AppText('Orari i qetësisë'),
            subtitle: const AppText(
              'Mos shfaq njoftime nga 23:00 deri në 07:00.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            value: quietNotificationsAtNight,
            onChanged: (value) {
              setState(() => quietNotificationsAtNight = value);
              update(() {});
              _saveSettings();
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule_outlined, color: mint),
            title: const AppText('Kontrolli në sfond'),
            subtitle: FutureBuilder<String>(
              future: _backgroundNotificationStatus(),
              builder: (_, snapshot) => AppText(
                snapshot.data ?? 'Po kontrollohet gjendja…',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ),
          ),
          if (Platform.isAndroid)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.battery_alert_outlined, color: mint),
              title: const AppText('Lejo njoftimet në sfond'),
              subtitle: const AppText(
                'Hap cilësimet e SYRI në telefon, zgjidh Bateria dhe vendos Pa kufizime. Në Samsung shtoje edhe te Aplikacionet që nuk flenë. Kursimi i baterisë mund t’i vonojë njoftimet.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              trailing: const Icon(Icons.open_in_new, color: mint, size: 18),
              onTap: () async {
                try {
                  await _syriPowerChannel.invokeMethod<void>(
                    'openAppBatterySettings',
                  );
                } catch (_) {
                  if (mounted) _toast('Cilësimet e telefonit nuk u hapën.');
                }
              },
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history_toggle_off, color: mint),
            title: const AppText('Mosha maksimale e njoftimit'),
            subtitle: const AppText(
              'Raportimet më të vjetra nuk dërgohen si njoftime.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            trailing: DropdownButton<int>(
              value: notificationMaxAgeMinutes,
              underline: const SizedBox.shrink(),
              items: const [30, 60, 120]
                  .map(
                    (minutes) => DropdownMenuItem(
                      value: minutes,
                      child: AppText('$minutes min'),
                    ),
                  )
                  .toList(),
              onChanged: (minutes) {
                if (minutes == null) return;
                setState(() => notificationMaxAgeMinutes = minutes);
                update(() {});
                _saveSettings();
              },
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.public, color: Colors.lightBlueAccent),
            title: const AppText('Njoftime nga bota'),
            subtitle: const AppText(
              'Kur është fikur, përdoren vetëm vendet aktive te cilësimet.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            value: worldNotifications,
            onChanged: (value) {
              setState(() => worldNotifications = value);
              update(() {});
              _saveSettings();
            },
          ),
          const SizedBox(height: 8),
          AppText(
            'Magnituda minimale e tërmetit: ${minimumEarthquakeMagnitude.toStringAsFixed(1)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Slider(
            value: minimumEarthquakeMagnitude,
            min: 0,
            max: 7,
            divisions: 14,
            label: minimumEarthquakeMagnitude.toStringAsFixed(1),
            onChanged: (value) {
              setState(() => minimumEarthquakeMagnitude = value);
              update(() {});
            },
            onChangeEnd: (_) => _saveSettings(),
          ),
          const SizedBox(height: 12),
          for (final category in mapCategories.where(
            (item) => const {'news', 'alerts', 'weather'}.contains(item.id),
          )) ...[
            SwitchListTile(
              key: ValueKey('notification-category-${category.id}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              secondary: Icon(category.icon, color: category.color),
              title: AppText(
                category.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              value: category.id == 'weather'
                  ? notificationLayers.contains('weather')
                  : _notificationSubcategories(
                      category.id,
                    ).every((choice) => notificationLayers.contains(choice.$1)),
              onChanged: (value) {
                setState(() {
                  final keys = category.id == 'weather'
                      ? ['weather']
                      : _notificationSubcategories(category.id)
                            .map((choice) => choice.$1);
                  for (final key in keys) {
                    value
                        ? notificationLayers.add(key)
                        : notificationLayers.remove(key);
                  }
                  notificationLayers.remove(
                    category.id == 'weather' ? '' : category.id,
                  );
                });
                update(() {});
                _saveSettings();
              },
            ),
            for (final choice
                in category.id == 'weather'
                    ? const <(String, String, IconData, Color)>[]
                    : _notificationSubcategories(category.id))
              SwitchListTile(
                key: ValueKey('notification-subcategory-${choice.$1}'),
                dense: true,
                visualDensity: const VisualDensity(vertical: -3),
                contentPadding: const EdgeInsets.only(left: 28),
                secondary: Icon(choice.$3, color: choice.$4, size: 18),
                title: AppText(choice.$2, style: const TextStyle(fontSize: 13)),
                value: notificationLayers.contains(choice.$1),
                onChanged: (value) {
                  setState(() {
                    value
                        ? notificationLayers.add(choice.$1)
                        : notificationLayers.remove(choice.$1);
                  });
                  update(() {});
                  _saveSettings();
                },
              ),
            const Divider(height: 18),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: notificationsEnabled
                  ? () => _showNotification(
                      'SYRI · Njoftim prove',
                      'Njoftimet po funksionojnë në këtë pajisje.',
                    )
                  : null,
              icon: const Icon(Icons.notification_add_outlined),
              label: const AppText('Dërgo njoftim prove'),
            ),
          ),
          const SizedBox(height: 10),
          const AppText(
            'Kur aplikacioni është i mbyllur, Android kontrollon periodikisht burimet. Njoftimi në çastin e botimit kërkon shërbim push.',
            style: TextStyle(color: muted, fontSize: 11, height: 1.45),
          ),
        ],
      ),
    ),
    accent: mint,
  );

  void _openSourcesPage() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        backgroundColor: ink,
        appBar: AppBar(
          backgroundColor: ink.withValues(alpha: .92),
          surfaceTintColor: Colors.transparent,
          title: const AppText(
            'Burimet',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(top: false, child: _sourcesPage()),
      ),
    ),
  );

  String _sourceName(String key) => switch (key) {
    'quakes' => 'Tërmete',
    'fires' => 'Zjarre aktive',
    'hazards' => 'Alarme natyrore',
    'planes' => 'Avionë live',
    'local' => 'Lajme lokale',
    'world' => 'Lajme nga bota',
    'roadwork' => 'Bllokime rrugësh',
    'traffic-jam' => 'Trafik i rënduar',
    'speed-cameras' => 'Kamera shpejtësie',
    'police-alerts' => 'Njoftime policore',
    'borders' => 'Pritje në kufi',
    'transit' => 'Autobusë',
    'airports' => 'Aeroporte',
    'services' => 'Shërbime publike',
    'pharmacies' => 'Farmaci',
    'aed' => 'Defibrilatorë',
    'mobility' => 'Parkim dhe karikim',
    'environment' => 'Mjedisi',
    'river-levels' => 'Nivelet e lumenjve',
    'places' => 'Eksploro',
    'cems' => 'Emergjenca Copernicus',
    'cameras' => 'Kamera publike',
    'ships' => 'Anije',
    'water' => 'Cilësia e plazheve',
    'drinking-water' => 'Ujë i pijshëm',
    'utilities' => 'Ujë dhe energji',
    'health-alerts' => 'Alarme shëndetësore',
    'food-alerts' => 'Siguri ushqimore',
    'port-alerts' => 'Njoftime detare',
    'agriculture' => 'Bujqësi',
    'hydrology-alerts' => 'Alarme hidrologjike',
    'civic-alerts' => 'Njoftime bashkiake',
    'official-maps' => 'Harta zyrtare',
    _ => key,
  };

  void _sourceHealth() => _sheet(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(
          'Gjendja e burimeve',
          'Kontrollo cilat të dhëna janë aktuale, në cache ose të paarritshme.',
        ),
        _healthRow(
          'Moti',
          weather?.fetched,
          weather?.stale ?? failures.contains('weather'),
          checkedAt: sourceCheckedAt['weather'],
        ),
        _healthRow(
          showRadar
              ? 'Radari i shiut'
              : 'Radari i shiut · i fikur te cilësimet',
          radar?.fetched,
          radar?.stale ?? failures.contains('radar'),
          checkedAt: sourceCheckedAt['radar'],
        ),
        _healthRow(
          'Ajri, UV dhe poleni',
          airQuality?.fetched,
          airQuality?.stale ?? failures.contains('air'),
          checkedAt: sourceCheckedAt['air'],
        ),
        for (final entry in results.entries)
          _healthRow(
            _sourceName(entry.key),
            entry.value.fetched,
            entry.value.stale || failures.contains(entry.key),
            checkedAt: sourceCheckedAt[entry.key],
          ),
        for (final key in failures.where((key) => !results.containsKey(key)))
          _healthRow(
            _sourceName(key),
            null,
            true,
            checkedAt: sourceCheckedAt[key],
          ),
        const SizedBox(height: 15),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              refresh();
            },
            icon: const Icon(Icons.sync),
            label: const AppText('Rifresko burimet aktive'),
          ),
        ),
      ],
    ),
    accent: Colors.tealAccent,
  );

  Widget _healthRow(
    String name,
    DateTime? fetched,
    bool stale, {
    DateTime? checkedAt,
  }) {
    final ok = fetched != null && !stale;
    final color = ok
        ? Colors.greenAccent
        : stale
        ? Colors.amber
        : muted;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        ok
            ? Icons.check_circle_outline
            : stale
            ? Icons.history
            : Icons.circle_outlined,
        color: color,
        size: 20,
      ),
      title: AppText(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${fetched == null
            ? _ui('Ende pa të dhëna', 'No data yet')
            : stale
            ? _ui('Kopje e ruajtur: ${dateLabel(fetched)}', 'Saved copy: ${dateLabel(fetched)}')
            : _ui('Përditësuar ${_freshnessLabel(fetched)}', 'Updated ${_freshnessLabel(fetched)}')}\n'
        '${checkedAt == null ? _ui('Nuk është kontrolluar ende', 'Not checked yet') : _ui('Kontrolluar: ${dateLabel(checkedAt)}', 'Checked: ${dateLabel(checkedAt)}')}',
        style: TextStyle(color: color, fontSize: 11),
      ),
    );
  }

  Widget _donatePage() => ListView(
    key: const ValueKey('donate-page'),
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
    children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xff49343d), Color(0xff203332), Color(0xff102220)],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: donationAccent.withValues(alpha: .45)),
          boxShadow: [
            BoxShadow(
              color: donationAccent.withValues(alpha: .10),
              blurRadius: 28,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: donationAccent.withValues(alpha: .17),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: donationAccent.withValues(alpha: .46),
                    ),
                  ),
                  child: const Icon(
                    Icons.volunteer_activism_rounded,
                    color: donationAccent,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _ui('MBËSHTET SYRI-N', 'SUPPORT SYRI'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: donationAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              _ui('Përshëndetje, jam Piero.', 'Hi, I’m Piero.'),
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                height: 1.12,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              _ui(
                'SYRI-n e ndërtoj dhe e mbaj vetë. Burimet e informacionit, mirëmbajtja dhe çdo përditësim kërkojnë shumë kohë dhe para nga xhepi im.',
                'I build and maintain SYRI on my own. Information sources, maintenance and every update take a lot of time and money from my own pocket.',
              ),
              style: const TextStyle(
                color: Color(0xffd9e2df),
                fontSize: 15,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _ui(
                'Dua që aplikacioni të mbetet falas dhe pa reklama. Nëse të ka vlejtur, edhe një kontribut i vogël do të më ndihmonte shumë. Do të të isha vërtet mirënjohës.',
                'I want the app to stay free and ad-free. If it has been useful to you, even a small contribution would help me a great deal. I’d be truly grateful.',
              ),
              style: const TextStyle(
                color: Color(0xffd9e2df),
                fontSize: 15,
                height: 1.55,
              ),
            ),
            if (donationUrl.isNotEmpty) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _open(donationUrl),
                  icon: const Icon(Icons.coffee_rounded),
                  label: Text(_ui('Më bli një kafe', 'Buy me a coffee')),
                  style: FilledButton.styleFrom(
                    backgroundColor: donationAccent,
                    foregroundColor: ink,
                    minimumSize: const Size(0, 54),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _open(paypalDonationUrl),
                  icon: const Icon(Icons.paypal_rounded),
                  label: Text(
                    _ui('Ose dhuro me PayPal', 'Or donate with PayPal'),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xffd9e2df),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: .30),
                    ),
                    minimumSize: const Size(0, 48),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 18),
      Center(
        child: TextButton.icon(
          onPressed: () => _open(creatorLinkedInUrl),
          icon: const Icon(Icons.open_in_new_rounded, size: 17),
          label: Text(
            _ui('Njihu me Pieron në LinkedIn', 'Meet Piero on LinkedIn'),
          ),
          style: TextButton.styleFrom(foregroundColor: const Color(0xff8ed7ff)),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        _ui(
          'Dhurimi është vullnetar. SYRI mbetet falas për të gjithë. Faleminderit nga zemra. — Piero',
          'Donating is optional. SYRI stays free for everyone. Thank you from the heart. — Piero',
        ),
        textAlign: TextAlign.center,
        style: const TextStyle(color: muted, fontSize: 13, height: 1.5),
      ),
    ],
  );

  Widget _settingsPage() => ListView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
    children: [
      _heading(
        'Cilësime',
        'Kontrollo çfarë shfaqet dhe sa shpesh rifreskohet.',
      ),
      Card(
        key: const ValueKey('settings-guide'),
        color: mint.withValues(alpha: .12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: mint.withValues(alpha: .48)),
        ),
        child: ListTile(
          leading: const Icon(Icons.auto_stories_outlined, color: mint),
          title: Text(
            _ui('Si përdoret SYRI', 'How to use SYRI'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            _ui(
              'Qyteti, harta, kategoritë e ruajtura, ngjarjet dhe njoftimet me shembuj vizualë.',
              'Visual steps for your city, map, saved categories, events and notifications.',
            ),
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right, color: mint),
          onTap: () => _openInfoPage(SyriInfoKind.guide),
        ),
      ),
      _settingsSectionTitle(
        Icons.tune_rounded,
        _ui('PËR TY', 'FOR YOU'),
        _ui(
          'Gjuha dhe njoftimet sipas dëshirës.',
          'Language and alerts your way.',
        ),
      ),
      Card(
        color: notificationsEnabled ? mint.withValues(alpha: .1) : panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: notificationsEnabled
                ? mint.withValues(alpha: .55)
                : Colors.white10,
          ),
        ),
        child: ListTile(
          leading: Icon(
            notificationsEnabled
                ? Icons.notifications_active
                : Icons.notifications_none,
            color: mint,
          ),
          title: const AppText(
            'Njoftimet e personalizuara',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: AppText(
            notificationsEnabled
                ? '${notificationLayers.length} zgjedhje aktive'
                : 'Alarme, lajme dhe mot sipas zgjedhjes',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: _notificationSettings,
        ),
      ),
      Card(
        key: const ValueKey('tourist-mode-settings'),
        color: touristMode
            ? Colors.lightBlueAccent.withValues(alpha: .09)
            : panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: touristMode
                ? Colors.lightBlueAccent.withValues(alpha: .45)
                : Colors.white10,
          ),
        ),
        child: Column(
          children: [
            SwitchListTile(
              secondary: const Icon(
                Icons.travel_explore,
                color: Colors.lightBlueAccent,
              ),
              title: const Text(
                'Language / Gjuha',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                touristMode
                    ? 'English is active · Tap to return to Albanian'
                    : 'Tourist mode · Change the entire app to English',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              value: touristMode,
              onChanged: (value) async {
                if (!value) {
                  setState(() {
                    touristMode = false;
                    setSyriEnglish(false);
                  });
                  await _saveSettings();
                  return;
                }
                _toast('Po përgatitet përkthimi English…');
                final ready = await SyriTranslation.prepare();
                if (!mounted) return;
                if (!ready) {
                  _toast(
                    'Gjuha English nuk u shkarkua. Kontrolloni internetin dhe provoni përsëri.',
                  );
                  return;
                }
                setState(() {
                  touristLanguage = 'en';
                  touristMode = true;
                  setSyriEnglish(true);
                });
                await _saveSettings();
              },
            ),
            if (touristMode) ...[
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.translate, color: mint),
                title: Text('App language'),
                subtitle: Text(
                  'The interface, reports, bullet points and share cards are translated on your device.',
                  style: TextStyle(color: muted, fontSize: 12),
                ),
                trailing: Text(
                  'English',
                  style: TextStyle(color: mint, fontWeight: FontWeight.w700),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.explore_outlined, color: mint),
                title: AppText(_tr('touristGuide')),
                subtitle: AppText(
                  _tr('touristSubtitle'),
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right, color: muted),
                onTap: _touristGuide,
              ),
            ],
          ],
        ),
      ),
      _settingsSectionTitle(
        Icons.public_outlined,
        _ui('VENDET', 'COUNTRIES'),
        _ui(
          'Zgjidh vendet që të interesojnë.',
          'Choose the countries that matter to you.',
        ),
      ),
      Material(
        color: panel,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < supportedNewsCountries.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              SwitchListTile(
                key: ValueKey('country-news-${supportedNewsCountries[i]}'),
                title: AppText(supportedNewsCountries[i]),
                subtitle: AppText(
                  'Lajme dhe shtresa të disponueshme për ${supportedNewsCountries[i]}',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
                value: enabledNewsCountries.contains(supportedNewsCountries[i]),
                onChanged: (value) {
                  cityGeneration++;
                  setState(() {
                    value
                        ? enabledNewsCountries.add(supportedNewsCountries[i])
                        : enabledNewsCountries.remove(
                            supportedNewsCountries[i],
                          );
                    results.remove('protected');
                    results.remove('biodiversity');
                    results.remove('water');
                    results.remove('airports');
                  });
                  if (enabled.contains('population')) _loadLayer('population');
                  if (enabled.contains('protected')) _loadLayer('protected');
                  if (enabled.contains('biodiversity')) {
                    _loadLayer('biodiversity');
                  }
                  if (enabled.contains('water')) _loadLayer('water');
                  if (enabled.contains('airports')) _loadLayer('airports');
                  if (enabled.contains('air')) _loadAirQuality();
                  if (enabled.contains('official-maps')) {
                    _loadLayer('official-maps');
                  }
                  unawaited(_saveSettings());
                },
              ),
            ],
          ],
        ),
      ),
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: AppText(
          'Filtrohen lajmet, parqet, aeroportet, regjistrimet e biodiversitetit, portet dhe pikat e ujit. Rreziku i përmbytjes dhe zonat e mbrojtura mbulojnë të katër vendet.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
      ),
      _settingsSectionTitle(
        Icons.layers_outlined,
        _ui('HARTA DHE PËRMBAJTJA', 'MAP AND CONTENT'),
        _ui(
          'Zgjidh çfarë shfaqet në hartë.',
          'Choose what appears on the map.',
        ),
      ),
      Material(
        color: panel,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.priority_high, color: mint),
              title: const AppText('Vetëm lajme të rëndësishme'),
              subtitle: const AppText(
                'Aksidente, krime, emergjenca dhe ngjarje të mëdha.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              value: importantNewsOnly,
              onChanged: (value) {
                setState(() => importantNewsOnly = value);
                _saveSettings();
              },
            ),
            const Divider(height: 1),
            SwitchListTile(
              secondary: const Icon(Icons.radar, color: Colors.lightBlueAccent),
              title: const AppText('Radar shiu në hartë'),
              subtitle: const AppText(
                'Shtresë RainViewer kur Moti është aktiv.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              value: showRadar,
              onChanged: (value) {
                setState(() {
                  showRadar = value;
                  if (value) rainLegendDismissed = false;
                  if (!value) radar = null;
                });
                if (value) _loadRadar();
                _saveSettings();
              },
            ),
            const Divider(height: 1),
            SwitchListTile(
              secondary: const Icon(Icons.info_outline, color: Colors.amber),
              title: const AppText('Shfaq legjendat e hartës'),
              subtitle: const AppText(
                'Shfaq shpjegimet e të gjitha shtresave aktive në një vend.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              value: showLegends,
              onChanged: (value) {
                setState(() => showLegends = value);
                _saveSettings();
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.opacity, color: Colors.lightBlueAccent),
              title: const AppText('Transparenca e satelitit'),
              subtitle: Slider(
                value: satelliteOpacity,
                min: .3,
                max: .9,
                divisions: 6,
                label: '${(satelliteOpacity * 100).round()}%',
                onChanged: (value) => setState(() => satelliteOpacity = value),
                onChangeEnd: (_) => _saveSettings(),
              ),
              trailing: AppText(
                '${(satelliteOpacity * 100).round()}%',
                style: const TextStyle(color: muted),
              ),
            ),
          ],
        ),
      ),
      _settingsSectionTitle(
        Icons.sync_rounded,
        _ui('RIFRESKIMI', 'UPDATES'),
        _ui('Sa të reja dhe sa shpesh.', 'How recent and how often.'),
      ),
      Material(
        color: panel,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(
                Icons.article_outlined,
                color: Color(0xff91b5ff),
              ),
              title: const AppText('Mosha maksimale e lajmeve'),
              subtitle: const AppText(
                'Lajmet më të vjetra hiqen automatikisht.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              trailing: DropdownButton<int>(
                value: newsMaxHours,
                underline: const SizedBox.shrink(),
                items: const [12, 24, 48]
                    .map(
                      (v) =>
                          DropdownMenuItem(value: v, child: AppText('$v orë')),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => newsMaxHours = value);
                  _saveSettings();
                },
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.near_me_outlined, color: mint),
              title: const AppText('Rrezja “Pranë qytetit”'),
              subtitle: AppText(
                'Ngjarje brenda $nearbyRadiusKm km nga vendi i zgjedhur.',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              trailing: DropdownButton<int>(
                value: nearbyRadiusKm,
                underline: const SizedBox.shrink(),
                items: const [10, 25, 35, 50, 100]
                    .map(
                      (v) =>
                          DropdownMenuItem(value: v, child: AppText('$v km')),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => nearbyRadiusKm = value);
                  _saveSettings();
                },
              ),
            ),
            const Divider(height: 1),
            SwitchListTile(
              secondary: const Icon(Icons.sync, color: Colors.tealAccent),
              title: const AppText('Rifresko kur hapet aplikacioni'),
              subtitle: const AppText(
                'Kontrollon automatikisht burimet kur rikthehesh në SYRI.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              value: autoRefreshOnResume,
              onChanged: (value) {
                setState(() => autoRefreshOnResume = value);
                _saveSettings();
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.flight, color: mint),
              title: const AppText('Rifreskimi i avionëve'),
              subtitle: const AppText(
                'Lëvizja vizuale vazhdon çdo sekondë.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              trailing: DropdownButton<int>(
                value: planeRefreshSeconds,
                underline: const SizedBox.shrink(),
                items: const [15, 30, 60]
                    .map(
                      (v) => DropdownMenuItem(value: v, child: AppText('$v s')),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => planeRefreshSeconds = value);
                  _startPlaneTimer();
                  _saveSettings();
                },
              ),
            ),
          ],
        ),
      ),
      _settingsSectionTitle(
        Icons.folder_outlined,
        _ui('HAPËSIRA', 'STORAGE'),
        _ui(
          'Shiko dhe pastro të dhënat e ruajtura.',
          'Review and clear saved data.',
        ),
      ),
      Material(
        color: panel,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          key: const ValueKey('settings-clear-cache'),
          leading: const Icon(
            Icons.cleaning_services_outlined,
            color: Colors.amber,
          ),
          title: Text(
            _ui(
              'Pastro të dhënat e ruajtura të burimeve',
              'Clear saved source data',
            ),
          ),
          subtitle: FutureBuilder<int>(
            future: cacheBytesFuture,
            builder: (context, snapshot) => Text(
              snapshot.hasData
                  ? _ui(
                      '${formattedCacheSize(snapshot.data!)} nga burimet · Harta dhe cilësimet ruhen.',
                      '${formattedCacheSize(snapshot.data!)} of source data · Map tiles and settings stay.',
                    )
                  : _ui(
                      'Po llogaritet madhësia e të dhënave…',
                      'Calculating stored data…',
                    ),
              style: const TextStyle(color: muted, fontSize: 12),
            ),
          ),
          trailing: const Icon(Icons.delete_outline_rounded, color: muted),
          onTap: busy.isEmpty ? _confirmClearDataCache : null,
        ),
      ),
      _settingsSectionTitle(
        Icons.verified_outlined,
        _ui('BURIMET', 'SOURCES'),
        _ui('Origjina dhe gjendja e të dhënave.', 'Data origins and status.'),
      ),
      Material(
        color: panel,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            ListTile(
              key: const ValueKey('settings-sources'),
              leading: const Icon(Icons.public_outlined, color: mint),
              title: const AppText(
                'Burimet dhe kreditet',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const AppText(
                'Origjina, licencat dhe lidhjet e të dhënave.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right, color: muted),
              onTap: _openSourcesPage,
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(
                Icons.monitor_heart_outlined,
                color: Colors.tealAccent,
              ),
              title: const AppText(
                'Gjendja e burimeve',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: AppText(
                results.isEmpty &&
                        weather == null &&
                        radar == null &&
                        airQuality == null
                    ? 'Burimet nuk janë kontrolluar ende.'
                    : failures.isEmpty
                    ? 'Burimet e kontrolluara po përgjigjen normalisht.'
                    : '${failures.length} burime po përdorin cache ose nuk u arritën.',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right, color: muted),
              onTap: () async {
                if (showRadar && radar == null) await _loadRadar();
                if (mounted) _sourceHealth();
              },
            ),
          ],
        ),
      ),
      _settingsSectionTitle(
        Icons.description_outlined,
        _ui('DOKUMENTET', 'DOCUMENTS'),
        _ui(
          'Privatësia dhe rregullat e përdorimit.',
          'Privacy and terms of use.',
        ),
      ),
      _settingsInfoLink(
        SyriInfoKind.privacy,
        Icons.shield_outlined,
        _ui('Politika e privatësisë', 'Privacy policy'),
      ),
      _settingsInfoLink(
        SyriInfoKind.terms,
        Icons.description_outlined,
        _ui('Kushtet e përdorimit', 'Terms of use'),
      ),
    ],
  );

  Widget _settingsSectionTitle(IconData icon, String title, String subtitle) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 34,
              width: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: mint.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: mint.withValues(alpha: .26)),
              ),
              child: Icon(icon, color: mint, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: mint,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _settingsInfoLink(SyriInfoKind kind, IconData icon, String label) =>
      Card(
        color: panel.withValues(alpha: glassOpacity),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        child: ListTile(
          leading: Icon(icon, color: mint),
          title: Text(label),
          trailing: const Icon(Icons.chevron_right, color: muted),
          onTap: () => _openInfoPage(kind),
        ),
      );

  void _openInfoPage(SyriInfoKind kind) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SyriInfoPage(kind: kind, english: syriEnglish),
    ),
  );

  Widget _sourcesPage() => ListView(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
    children: [
      _heading(
        'Një sy. Shumë burime.',
        'Informacion publik, me origjinë të qartë.',
      ),
      Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: mint,
          borderRadius: BorderRadius.circular(19),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.verified_outlined, color: ink),
            SizedBox(width: 11),
            Expanded(
              child: AppText(
                'SYRI të çon te burimi. Pa llogari, pa abonim dhe pa pretenduar raportimin e të tjerëve.',
                style: TextStyle(
                  color: ink,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(19),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              'Sistemi Ynë i Raportimit dhe Informimit',
              style: TextStyle(fontWeight: FontWeight.bold, color: mint),
            ),
            SizedBox(height: 7),
            AppText(
              'SYRI · See Your Region Instantly',
              style: TextStyle(color: muted),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      const AppText(
        'TË DHËNA NË HARTË',
        style: TextStyle(color: muted, fontSize: 11, letterSpacing: 1.4),
      ),
      _source(
        'Open-Meteo',
        'Mot, mundësi reshjesh, lindje/perëndim dhe parashikim 6-ditor',
        'https://open-meteo.com/',
        Icons.cloud_outlined,
        'weather',
      ),
      _source(
        'EMSC',
        'Tërmete rajonale · CC BY 4.0',
        'https://www.seismicportal.eu/',
        Icons.sensors,
        'quakes',
      ),
      _source(
        'ADSB.lol',
        'Avionë të detektuar · ODbL',
        'https://www.adsb.lol/',
        Icons.flight,
        'planes',
      ),
      _source(
        'ADSBDB',
        'Kompania dhe itinerari sipas kodit të fluturimit',
        'https://www.adsbdb.com/',
        Icons.route_outlined,
        null,
      ),
      _source(
        'Aeroporti Ndërkombëtar i Tiranës',
        'Mbërritje, nisje, kompani, orar dhe status fluturimi',
        'https://tirana-airport.com/en',
        Icons.flight_takeoff,
        'airports',
      ),
      _source(
        'IHMK Kosovë',
        'Nivelet, ndryshimet dhe tendencat e lumenjve në stacionet publike',
        'https://ihmk-rks.net/?page=1%2C41',
        Icons.water_damage_outlined,
        'river-levels',
      ),
      _source(
        'GDACS + AKMC',
        'Fatkeqësi globale dhe njoftime vendore',
        'https://www.gdacs.org/',
        Icons.local_fire_department_outlined,
        'hazards',
      ),
      _source(
        'FireMap.live + NASA FIRMS',
        'Zjarre dhe pika termike të 7 ditëve',
        'https://firemap.live/',
        Icons.local_fire_department,
        'hazards',
      ),
      _source(
        'RainViewer',
        'Radar shiu · rifreskim rreth 5 minuta',
        'https://www.rainviewer.com/api.html',
        Icons.radar,
        null,
      ),
      _source(
        'NASA GIBS',
        'Pamje satelitore VIIRS e ditës për Shqipëri dhe Kosovë',
        'https://nasa-gibs.github.io/gibs-api-docs/',
        Icons.satellite_alt,
        'satellite',
      ),
      _source(
        'NASA LHASA',
        'Rreziku i modeluar i rrëshqitjeve të dheut pas reshjeve',
        'https://pmmpublisher.pps.eosdis.nasa.gov/',
        Icons.landscape_outlined,
        'landslides',
      ),
      _source(
        'IODA · Georgia Tech',
        'Anomali dhe ndërprerje interneti gjatë 48 orëve të fundit',
        'https://ioda.inetintel.cc.gatech.edu/',
        Icons.wifi_off_rounded,
        'internet-outages',
      ),
      _source(
        'OST + KOSTT',
        'Prodhimi, ngarkesa, shkëmbimet dhe gjendja e sistemit energjetik',
        'https://opendata.ost.al/',
        Icons.electric_bolt,
        'energy-grid',
      ),
      _source(
        'Bashkia Tiranë · GTFS',
        '27 linja, stacione, itinerare dhe orare të planifikuara',
        'https://pt.tirana.al/gtfs/gtfs.zip',
        Icons.directions_bus,
        'transit',
      ),
      _source(
        'Open-Meteo Air Quality',
        'AQI, PM2.5, PM10, pluhur, UV dhe polen',
        'https://open-meteo.com/en/docs/air-quality-api',
        Icons.air,
        'air',
      ),
      _source(
        'MET Norway',
        'Kontroll i dytë për reshjet dhe gjendjen aktuale të motit',
        'https://api.met.no/weatherapi/locationforecast/2.0/documentation',
        Icons.water_drop_outlined,
        null,
      ),
      _source(
        'Open-Meteo Marine',
        'Valë, rryma dhe temperaturë e detit',
        'https://open-meteo.com/en/docs/marine-weather-api',
        Icons.waves,
        'marine',
      ),
      _source(
        'ARRSH',
        'Njoftime për punime, bllokime dhe gjendjen e rrugëve',
        'https://www.arrsh.gov.al/',
        Icons.construction,
        'roadwork',
      ),
      _source(
        'MPB Kosovë · QKMK',
        'Pritjet dhe kolonat në pikat kufitare',
        'https://mpb.rks-gov.net/?culture=sq-al',
        Icons.compare_arrows_rounded,
        'borders',
      ),
      _source(
        'Copernicus EMS',
        'Aktivizime dhe harta satelitore të dëmit',
        'https://rapidmapping.emergency.copernicus.eu/',
        Icons.satellite_alt,
        'cems',
      ),
      _source(
        'OpenStreetMap · Overpass',
        'Transport, zona të mbrojtura dhe pika mjedisore',
        'https://overpass-api.de/',
        Icons.place_outlined,
        'transport',
      ),
      _source(
        'Bashkia Tiranë · Open Data',
        'Stacione dhe linja të transportit publik',
        'https://ckan.tirana.al/',
        Icons.directions_bus,
        'transit',
      ),
      _source(
        'EEA · Ujërat e larjes',
        'Klasifikimi i 119 pikave shqiptare sipas cilësisë',
        'https://www.eea.europa.eu/en/analysis/maps-and-charts/state-of-bathing-waters-in-2025',
        Icons.water_drop,
        'water',
      ),
      _source(
        'JP Morsko dobro · Mali i Zi',
        'Cilësia, data e mostrës dhe zonat bregdetare të monitoruara',
        'https://monitoring.morskodobro.me/?lang=en_US',
        Icons.water_drop,
        'water',
      ),
      _source(
        'ISHP · Maqedonia e Veriut',
        'Raporti 2025 për ujërat e larjes në liqene; për Ohrin shfaqet edhe njoftimi zyrtar i vitit 2026',
        'https://iph.mk/',
        Icons.water_drop,
        'water',
      ),
      _source(
        'MMPHI · Kosovë',
        'Raporti 2026 shpjegon mungesën e klasifikimit sistematik të ujërave të larjes',
        'https://mmphi.rks-gov.net/',
        Icons.water_drop,
        'water',
      ),
      _source(
        'KEDS + OSHEE',
        'Njoftime për ndërprerje energjie dhe uji, të filtruara sipas zonës',
        'https://www.keds-energy.com/shq/',
        Icons.power,
        'utilities',
      ),
      _source(
        'Geoportali Kombëtar ASIG',
        'Popullsia 2023, zonat e përmbytjeve, rreziku gjeologjik, lumenjtë, zonat e mbrojtura dhe biodiversiteti',
        'https://geoportal.asig.gov.al/',
        Icons.layers_outlined,
        null,
      ),
      _source(
        'Geoportali i Kosovës',
        'Ortofoto, hidrografi, rrugë, njësi administrative, zona të mbrojtura dhe harta topografike',
        'https://geoportal.rks-gov.net/portal/main',
        Icons.public,
        'official-maps',
      ),
      _source(
        'Ajri në Kosovë · IHMK',
        'Matje pranë kohës reale nga 12 stacione dhe parashikim treditor',
        'https://ajri.niph-rks.org/',
        Icons.air,
        'air',
      ),
      _source(
        'ISHP · MSHMS · IKSHPK',
        'Alarme dhe informacione për shëndetin publik',
        'https://www.ishp.gov.al/alerte/',
        Icons.health_and_safety,
        'health-alerts',
      ),
      _source(
        'AKU · AUVK · RASFF',
        'Alarme për ushqime ose produkte të rrezikshme',
        'https://webgate.ec.europa.eu/rasff-window/screen/search',
        Icons.no_food_rounded,
        'food-alerts',
      ),
      _source(
        'Drejtoria e Përgjithshme Detare',
        'Njoftime për porte, tragete dhe kufizime lundrimi',
        'https://dpdetare.gov.al/',
        Icons.anchor,
        'port-alerts',
      ),
      _source(
        'KESH · AMBU · IGJEO',
        'Nivele lumenjsh, prurje, shkarkime dhe paralajmërime për rezervuarë',
        'https://www.kesh.al/',
        Icons.water_damage_outlined,
        'hydrology-alerts',
      ),
      _source(
        'Bashki · Komuna · Policia',
        'Njoftime civile për mbyllje, evakuime dhe ndryshime që prekin një zonë',
        'https://www.asp.gov.al/',
        Icons.campaign_outlined,
        'civic-alerts',
      ),
      _source(
        'Vlora LIVE · SkylineWebcams',
        'Kamera shqiptare që hapen te transmetuesi origjinal',
        'https://vlora.live/',
        Icons.videocam,
        'cameras',
      ),
      _source(
        'OpenCCTV · katër vende',
        'Kamera publike me koordinata në Shqipëri, Kosovë, Maqedoninë e Veriut dhe Malin e Zi',
        'https://opencctv.org/cameras',
        Icons.videocam_outlined,
        'cameras',
      ),
      _source(
        'Kamerat rrugore · Maqedonia e Veriut',
        'Hartë zyrtare e kamerave në rrugët shtetërore, në shqip',
        'https://roads.org.mk/sq/rrjeti-rrugor/kamerat-mbikeqyrese/',
        Icons.traffic_rounded,
        'cameras',
      ),
      _source(
        'Kamerat kufitare · Mali i Zi',
        'Video publike të hyrjes dhe daljes në pikat kufitare, përfshirë Bozhajn e Sukobinën',
        'http://kamere.mup.gov.me/',
        Icons.videocam_outlined,
        'cameras',
      ),
      _source(
        'GjirafaVideo · SlowTV',
        '24 transmetime live nga qytete, rrugë dhe natyra e Kosovës',
        'https://video-swp.gjirafa.com/slow-tv-2-2',
        Icons.live_tv,
        'cameras',
      ),
      _source(
        'Kanale TV · Shqipëri',
        'Faqet zyrtare të RTSH, A2 CNN, Euronews Albania, News24, Ora News dhe ABC News',
        'https://tv.rtsh.al/',
        Icons.live_tv_rounded,
        'tv',
      ),
      _source(
        'Kanale TV · Kosovë',
        'Faqet zyrtare të Klan Kosova dhe KOHA/KTV',
        'https://klankosova.tv/tv',
        Icons.live_tv_rounded,
        'tv',
      ),
      _source(
        'Kanale TV · Mali i Zi',
        'Katër kanalet TVCG në portalin zyrtar RTCG',
        'https://rtcg.me/tv/tv-uzivo.html',
        Icons.live_tv_rounded,
        'tv',
      ),
      _source(
        'Kanale TV · Maqedonia e Veriut',
        'Faqet zyrtare të MRT dhe Alsat',
        'https://play.mrt.com.mk/',
        Icons.live_tv_rounded,
        'tv',
      ),
      _source(
        'Kufiri.LIVE',
        'Katalog publik i kamerave kufitare në Ballkan dhe Evropë',
        'https://kufiri.live/',
        Icons.compare_arrows_rounded,
        'cameras',
      ),
      _source(
        'Albanian Marine Traffic',
        'Harta zyrtare e anijeve',
        'https://vesselsdata.gov.al/',
        Icons.directions_boat,
        'ships',
      ),
      _source(
        'OpenStreetMap',
        'Harta · © kontribuesit · ODbL',
        'https://www.openstreetmap.org/copyright',
        Icons.map_outlined,
        null,
      ),
      const SizedBox(height: 20),
      const AppText(
        'MEDIA & INSTITUCIONE',
        style: TextStyle(color: muted, fontSize: 11, letterSpacing: 1.4),
      ),
      _source(
        'Star Plus TV',
        'Shkodër · tituj RSS',
        'https://www.starplus-tv.com/',
        Icons.rss_feed,
        'Star Plus TV',
      ),
      _source(
        'KALLXO',
        'Kosovë · tituj RSS',
        'https://kallxo.com/',
        Icons.rss_feed,
        'KALLXO',
      ),
      _source(
        'RTSH',
        'Shqipëri · tituj RSS',
        'https://rtsh.al/',
        Icons.rss_feed,
        'RTSH',
      ),
      _source(
        'BalkanWeb',
        'Shqipëri · tituj RSS',
        'https://www.balkanweb.com/',
        Icons.rss_feed,
        'BalkanWeb',
      ),
      _source(
        'Telegrafi',
        'Kosovë · tituj RSS',
        'https://telegrafi.com/',
        Icons.rss_feed,
        'Telegrafi',
      ),
      _source(
        'Reporteri',
        'Kosovë · tituj RSS',
        'https://reporteri.net/',
        Icons.rss_feed,
        'Reporteri',
      ),
      _source(
        'Gazeta Express',
        'Kosovë · tituj RSS',
        'https://gazetaexpress.com/',
        Icons.rss_feed,
        'Gazeta Express',
      ),
      _source(
        'Kërkim lokal',
        'Media që raportojnë për ${city.name}',
        'https://news.google.com/',
        Icons.travel_explore,
        'local',
      ),
      _source(
        'Top Channel',
        'Hap faqen origjinale',
        'https://top-channel.tv/',
        Icons.open_in_new,
        null,
      ),
      _source(
        'TV Klan',
        'Hap faqen origjinale',
        'https://tvklan.al/',
        Icons.open_in_new,
        null,
      ),
      _source(
        'RTSH',
        'Hap faqen origjinale',
        'https://rtsh.al/',
        Icons.open_in_new,
        null,
      ),
      _source(
        'Klan Kosova',
        'Hap faqen origjinale',
        'https://klankosova.tv/',
        Icons.open_in_new,
        null,
      ),
      _source(
        'RTK',
        'Hap faqen origjinale',
        'https://www.rtklive.com/',
        Icons.open_in_new,
        null,
      ),
      _source(
        'AKMC',
        'Mbrojtja civile · Shqipëri',
        'https://akmc.gov.al/',
        Icons.shield_outlined,
        null,
      ),
      _source(
        'IHMK',
        'Hidrometeorologjia · Kosovë',
        'https://ihmk-rks.net/',
        Icons.water_outlined,
        null,
      ),
      const SizedBox(height: 18),
      OutlinedButton.icon(
        onPressed: () => _openInfoPage(SyriInfoKind.privacy),
        icon: const Icon(Icons.info_outline),
        label: Text(_ui('Politika e privatësisë', 'Privacy policy')),
      ),
    ],
  );

  Widget _source(
    String name,
    String description,
    String url,
    IconData icon,
    String? key,
  ) {
    final fetched = key == 'weather'
        ? weather?.fetched
        : key == 'air'
        ? airQuality?.fetched
        : key == 'marine'
        ? marineWeather?.fetched
        : results[key]?.fetched;
    final status = key == null
        ? null
        : busy.contains(key)
        ? 'Po lidhet…'
        : failures.contains(key)
        ? (fetched == null ? 'Nuk u arrit' : 'Kopje e vjetër')
        : fetched == null
        ? 'Aktivizo shtresën'
        : 'Marrë ${dateLabel(fetched)}';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 3),
      leading: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: panel,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 21, color: mint),
      ),
      title: AppText(
        name,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: AppText(
        '$description${status == null ? '' : '\n$status'}',
        style: TextStyle(
          fontSize: 11,
          height: 1.5,
          color: failures.contains(key) ? Colors.amber : muted,
        ),
      ),
      trailing: const Icon(Icons.north_east, size: 17, color: muted),
      onTap: () => _open(url),
    );
  }
}
