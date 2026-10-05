import 'dart:convert';

import 'package:latlong2/latlong.dart';

import 'data.dart';

/// A notification carries its own report so it opens even when the feed has
/// not finished refreshing after a cold start.
String eventNotificationPayload(Event event) => jsonEncode({
  'type': 'event',
  'id': event.id,
  'title': event.title,
  'description': event.description,
  'summary': event.summary,
  'source': event.source,
  'url': event.url,
  'kind': event.kind,
  'latitude': event.point?.latitude,
  'longitude': event.point?.longitude,
  'time': event.time?.toIso8601String(),
  'approximate': event.approximate,
});

const weatherNotificationPayload = '{"type":"weather"}';

Event? eventFromNotificationPayload(String? payload) {
  if (payload == null || payload.isEmpty) return null;
  try {
    final data = jsonDecode(payload) as Map<String, dynamic>;
    if (data['type'] != 'event') return null;
    final latitude = data['latitude'];
    final longitude = data['longitude'];
    return Event(
      id: data['id'] as String,
      title: data['title'] as String,
      description: data['description'] as String,
      summary: data['summary'] as String?,
      source: data['source'] as String,
      url: data['url'] as String,
      kind: data['kind'] as String,
      point: latitude is num && longitude is num
          ? LatLng(latitude.toDouble(), longitude.toDouble())
          : null,
      time: DateTime.tryParse(data['time'] as String? ?? ''),
      approximate: data['approximate'] == true,
    );
  } catch (_) {
    return null;
  }
}

bool isWeatherNotificationPayload(String? payload) =>
    payload == weatherNotificationPayload;
