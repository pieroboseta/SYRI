import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:syri/data.dart';
import 'package:syri/notification_payload.dart';

void main() {
  test('notification retains exact report for a cold-start tap', () {
    final original = Event(
      id: 'fire-123',
      title: 'Zjarr në Shkodër',
      description: 'Detajet e ngjarjes',
      source: 'Burimi zyrtar',
      url: 'https://example.com/report',
      kind: 'fire',
      point: const LatLng(42.068, 19.512),
      time: DateTime.utc(2026, 9, 26, 22, 15),
    );
    final restored = eventFromNotificationPayload(
      eventNotificationPayload(original),
    );
    expect(restored?.id, original.id);
    expect(restored?.url, original.url);
    expect(restored?.point, original.point);
    expect(restored?.time, original.time);
    expect(eventFromNotificationPayload(weatherNotificationPayload), isNull);
    expect(isWeatherNotificationPayload(weatherNotificationPayload), isTrue);
  });
}
