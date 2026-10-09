import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:latlong2/latlong.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'data.dart';
import 'app_updates.dart';
import 'notification_payload.dart';
import 'news_sources.dart';

const syriBackgroundTask = 'syri-public-alert-check';
const syriUpdateTask = 'syri-app-update-check';

@pragma('vm:entry-point')
void syriBackgroundDispatcher() {
  Workmanager().executeTask((task, input) async {
    if (task != syriBackgroundTask && task != syriUpdateTask) return true;
    DartPluginRegistrant.ensureInitialized();
    try {
      if (task == syriUpdateTask) {
        await checkSyriBackgroundUpdate();
      } else {
        await checkSyriBackgroundAlerts();
      }
      return true;
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          task == syriUpdateTask
              ? 'setting_update_background_error_at'
              : 'setting_background_error_at',
          DateTime.now().toIso8601String(),
        );
      } catch (_) {}
      return false;
    }
  });
}

Future<void> configureSyriBackgroundUpdates() async {
  if (!Platform.isAndroid) return;
  try {
    await Workmanager().registerPeriodicTask(
      syriUpdateTask,
      syriUpdateTask,
      frequency: const Duration(hours: 24),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  } catch (_) {
    // The foreground check still works if Android does not schedule the job.
  }
}

Future<void> checkSyriBackgroundUpdate() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final installed = (await PackageInfo.fromPlatform()).version;
  final release = await fetchLatestSyriRelease();
  final now = DateTime.now();
  await prefs.setString('setting_update_checked_at', now.toIso8601String());
  if (release == null || !isNewerSyriVersion(release.version, installed)) {
    await prefs.remove('setting_update_available_version');
    await prefs.remove('setting_update_available_url');
    return;
  }
  await prefs.setString('setting_update_available_version', release.version);
  await prefs.setString('setting_update_available_url', release.pageUrl);
  final foregroundAt = DateTime.tryParse(
    prefs.getString('setting_app_foreground_at') ?? '',
  );
  final recentlyForeground = prefs.getBool('setting_app_foreground') == true &&
      foregroundAt != null &&
      now.difference(foregroundAt) < const Duration(minutes: 5);
  if (prefs.getString('setting_update_notified_version') == release.version ||
      recentlyForeground) {
    return;
  }
  final notifications = FlutterLocalNotificationsPlugin();
  await notifications.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('syri_launcher'),
    ),
  );
  final android = notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  if (await android?.areNotificationsEnabled() != true) return;
  await notifications.show(
    id: 0x53595249,
    title: 'Përditësim i ri i SYRI',
    body:
        'Versioni ${release.version} është gati. Prek për ta shkarkuar nga GitHub.',
    payload: updateNotificationPayload(release.pageUrl),
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        'syri_updates',
        'Përditësimet e SYRI',
        channelDescription: 'Versionet e reja të aplikacionit SYRI',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        playSound: false,
      ),
    ),
  );
  await prefs.setString('setting_update_notified_version', release.version);
}

Future<void> configureSyriBackgroundNotifications(bool enabled) async {
  if (!Platform.isAndroid) return;
  try {
    if (enabled) {
      await Workmanager().registerPeriodicTask(
        syriBackgroundTask,
        syriBackgroundTask,
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } else {
      await Workmanager().cancelByUniqueName(syriBackgroundTask);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setting_background_scheduled', enabled);
  } catch (_) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setting_background_scheduled', false);
  }
}

Future<void> checkSyriBackgroundAlerts() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  if (!(prefs.getBool('setting_notifications') ?? false)) return;
  final selected =
      (prefs.getStringList('setting_notification_layers') ?? const <String>[])
          .toSet();
  if (selected.isEmpty) return;
  final countries =
      (prefs.getStringList('setting_news_countries') ??
              const ['Shqipëri', 'Kosovë', 'Maqedonia e Veriut', 'Mali i Zi'])
          .toSet();
  final selectedCityName = prefs.getString('setting_city');
  final selectedCity = cities.firstWhere(
    (item) => item.name == selectedCityName,
    orElse: () => cities.first,
  );
  final api = SyriApi();
  final events = <(Event, bool, String?)>[];
  final tasks = <Future<void>>[];
  Future<void> add(
    Future<FeedResult<List<Event>>> Function() source, {
    bool world = false,
    String? sourceCountry,
  }) async {
    try {
      final feed = await source();
      if (!feed.stale) {
        events.addAll(feed.value.map((event) => (event, world, sourceCountry)));
      }
    } catch (_) {}
  }

  try {
    await prefs.setString(
      'setting_background_started',
      DateTime.now().toIso8601String(),
    );
    if (selected.contains('quakes')) tasks.add(add(api.earthquakes));
    if (selected.any((key) => key.startsWith('hazard:'))) {
      tasks.add(add(api.activeFires));
      tasks.add(add(api.hazards));
    }
    if (selected.any((key) => key.startsWith('news:'))) {
      for (final source in regionalNewsSources) {
        if (!countries.contains(source.country)) continue;
        tasks.add(
          add(
            () => api.news(source.name, source.url),
            sourceCountry: source.country,
          ),
        );
      }
      if (countries.contains(selectedCity.country)) {
        tasks.add(
          add(
            () => api.localNews(selectedCity),
            sourceCountry: selectedCity.country,
          ),
        );
      }
      if (prefs.getBool('setting_notification_world') ?? false) {
        tasks.add(add(api.worldNews, world: true));
      }
    }
    await Future.wait(tasks);
    final known =
        (prefs.getStringList('setting_notified_ids') ?? const <String>[])
            .toSet();
    final minimum = prefs.getDouble('setting_quake_minimum') ?? 4;
    final importantOnly = prefs.getBool('setting_notification_urgent') ?? true;
    final appVisible = prefs.getBool('setting_app_foreground') ?? false;
    final maxAge = Duration(
      minutes: prefs.getInt('setting_notification_max_age') ?? 60,
    );
    final now = DateTime.now();
    final started =
        DateTime.tryParse(
          prefs.getString('setting_notifications_started_at') ?? '',
        ) ??
        now;
    events.sort(
      (a, b) =>
          (b.$1.time ?? DateTime(1970)).compareTo(a.$1.time ?? DateTime(1970)),
    );
    final notifications = FlutterLocalNotificationsPlugin();
    await notifications.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('syri_launcher'),
      ),
    );
    var shown = 0;
    for (final (event, world, sourceCountry) in events) {
      final time = event.time;
      if (time == null ||
          time.isBefore(started) ||
          time.isBefore(now.subtract(maxAge)) ||
          known.contains(event.id)) {
        continue;
      }
      if (importantOnly &&
          event.kind == 'news' &&
          event.tone != 'bad' &&
          event.newsType != 'major') {
        continue;
      }
      if (event.kind == 'news' &&
          !selected.contains('news:${event.newsType}')) {
        continue;
      }
      if (event.kind == 'quakes') {
        final magnitude = double.tryParse(
          RegExp(r'M\s*([0-9.]+)').firstMatch(event.title)?.group(1) ?? '',
        );
        if (magnitude == null || magnitude < minimum) continue;
      }
      if (const {'fire', 'storm', 'flood', 'volcano'}.contains(event.kind) &&
          !selected.contains('hazard:${event.kind}')) {
        continue;
      }
      if (event.kind != 'news' &&
          event.kind != 'quakes' &&
          !const {'fire', 'storm', 'flood', 'volcano'}.contains(event.kind)) {
        continue;
      }
      if (!world &&
          event.kind != 'news' &&
          !_pointInEnabledCountry(event, countries)) {
        continue;
      }
      if (event.kind == 'news' &&
          !world &&
          (sourceCountry == null || !countries.contains(sourceCountry))) {
        continue;
      }
      known.add(event.id);
      // A delayed Android job can start as the user reopens the app. Mark
      // those reports seen, but do not deliver a burst over the visible map.
      if (appVisible) continue;
      if ((prefs.getBool('setting_notification_quiet') ?? true) &&
          (now.hour >= 23 || now.hour < 7)) {
        continue;
      }
      // Treat every eligible report in this check as seen. Otherwise the
      // fourth, fifth, etc. reports arrive as a delayed burst on later runs.
      if (shown >= 3) continue;
      await notifications.show(
        id: event.id.hashCode & 0x7fffffff,
        title: event.title,
        body: event.description.split('\n').first,
        payload: eventNotificationPayload(event),
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'syri_alerts',
            'Alarmet SYRI',
            channelDescription: 'Alarmet publike të zgjedhura në SYRI',
            importance: Importance.high,
            priority: Priority.high,
            playSound: prefs.getBool('setting_notification_sound') ?? true,
          ),
        ),
      );
      await prefs.setString(
        'setting_background_notified_at',
        now.toIso8601String(),
      );
      shown++;
    }
    if (!appVisible &&
        selected.contains('weather') &&
        shown < 3 &&
        !((prefs.getBool('setting_notification_quiet') ?? true) &&
            (now.hour >= 23 || now.hour < 7))) {
      try {
        final weather = (await api.weather(selectedCity)).value;
        final severe =
            weather.symbol.contains('thunder') ||
            weather.symbol.contains('snow') ||
            weather.rain >= 8 ||
            weather.wind >= 55;
        final noteworthy =
            severe || (!importantOnly && weather.rainChance >= 70);
        final signature =
            '${selectedCity.name}:${weather.symbol}:${now.year}-${now.month}-${now.day}-${now.hour}';
        if (noteworthy &&
            signature != prefs.getString('setting_background_weather_id')) {
          await notifications.show(
            id: signature.hashCode & 0x7fffffff,
            title: 'Moti në ${selectedCity.name}',
            body:
                'Mundësi reshjesh ${weather.rainChance}% · erë ${weather.wind.toStringAsFixed(0)} km/h',
            payload: weatherNotificationPayload,
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'syri_alerts',
                'Alarmet SYRI',
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
          );
          await prefs.setString('setting_background_weather_id', signature);
        }
      } catch (_) {}
    }
    await prefs.setStringList(
      'setting_notified_ids',
      known.toList().reversed.take(500).toList(),
    );
    await prefs.setString('setting_background_checked', now.toIso8601String());
    await prefs.setInt('setting_background_report_count', events.length);
  } finally {
    api.client.close();
  }
}

bool _pointInEnabledCountry(Event event, Set<String> countries) {
  final point = event.point;
  if (point == null) return false;
  City? nearest;
  var distance = double.infinity;
  for (final candidate in cities) {
    final current = const Distance().distance(candidate.point, point);
    if (current < distance) {
      distance = current;
      nearest = candidate;
    }
  }
  return nearest != null && countries.contains(nearest.country);
}
