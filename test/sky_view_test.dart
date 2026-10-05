import 'package:flutter_test/flutter_test.dart';
import 'package:syri/sky_view.dart';

void main() {
  test('the Sun rises above Tirana at midday and is below at midnight', () {
    final day = skySolarBodies(DateTime.utc(2026, 3, 20, 11), 41.3275, 19.8187);
    final night = skySolarBodies(DateTime.utc(2026, 3, 20, 23), 41.3275, 19.8187);
    expect(day.sun.altitude, greaterThan(45));
    expect(night.sun.altitude, lessThan(-40));
    expect(day.sun.azimuth, inInclusiveRange(0, 360));
    expect(day.moon.illumination, inInclusiveRange(0, 1));
  });

  test('Moon phase changes through the month', () {
    final first = skySolarBodies(DateTime.utc(2026, 10, 1), 42, 20);
    final later = skySolarBodies(DateTime.utc(2026, 10, 15), 42, 20);
    expect((first.moon.illumination! - later.moon.illumination!).abs(),
        greaterThan(.2));
  });
}
