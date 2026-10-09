import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syri/data.dart';
import 'package:syri/public_forecasts.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('sky forecast uses requested hour and keeps city positions', () async {
    final api = SyriApi(
      client: MockClient((request) async {
        expect(request.url.queryParameters['forecast_hours'], '12');
        return http.Response(
          jsonEncode({
            'hourly': {
              'time': ['2026-10-09T10:00', '2026-10-09T11:00'],
              'cloud_cover': [20, 90],
              'visibility': [12000, 700],
              'wind_speed_10m': [4, 18],
              'wind_direction_10m': [100, 180],
              'wind_gusts_10m': [8, 30],
            },
          }),
          200,
        );
      }),
    );
    final reading = await api.skyForCities([cities.first], hoursAhead: 1);
    expect(reading.value.single.title, contains('Mjegull'));
    expect(reading.value.single.description, contains('90%'));
    expect(reading.value.single.point, cities.first.point);
    expect(reading.value.single.measurements?['cloud'], 90);
    expect(reading.value.single.measurements?['visibility'], 700);
    expect(reading.value.single.dataMode, 'PARASHIKIM');
    api.client.close();
  });

  test('river model is labelled approximate and country filtered', () async {
    final api = SyriApi(
      client: MockClient((request) async {
        expect(request.url.queryParameters['latitude']!.split(',').length, 2);
        return http.Response(
          jsonEncode([
            for (var i = 0; i < 2; i++)
              {
                'latitude': 42.025,
                'longitude': 19.525,
                'daily': {
                  'time': ['2026-10-09', '2026-10-10'],
                  'river_discharge': [15.2, 17.1],
                },
              },
          ]),
          200,
        );
      }),
    );
    final reading = await api.riverForecasts({'Shqipëri'});
    expect(reading.value, hasLength(2));
    expect(reading.value.first.approximate, isTrue);
    expect(reading.value.first.description, contains('jo matje'));
    api.client.close();
  });

  test(
    'solar scale remains global and distinguishes observed from outlook',
    () async {
      final api = SyriApi(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              '0': {
                'G': {'Scale': '0'},
                'R': {'Scale': '0'},
                'S': {'Scale': '0'},
              },
              '1': {
                'G': {'Scale': '2'},
                'R': {'Scale': '0'},
                'S': {'Scale': '0'},
              },
              '2': {
                'G': {'Scale': '0'},
                'R': {'Scale': '0'},
                'S': {'Scale': '0'},
              },
              '3': {
                'G': {'Scale': '0'},
                'R': {'Scale': '0'},
                'S': {'Scale': '0'},
              },
            }),
            200,
          ),
        ),
      );
      final event = (await api.solarActivity()).value.single;
      expect(event.point, isNull);
      expect(event.title, contains('G0'));
      expect(event.description, contains('Dita 1: G2'));
      expect(event.dataMode, 'VËZHGIM GLOBAL');
      api.client.close();
    },
  );
}
