import 'package:flutter_test/flutter_test.dart';
import 'package:syri/data.dart';
import 'package:syri/map_markers.dart';
import 'package:syri/tv_channels.dart';

void main() {
  test(
    'channel directory covers four countries and uses real city anchors',
    () {
      expect(tvChannels.map((item) => item.country).toSet(), {
        'Shqipëri',
        'Kosovë',
        'Mali i Zi',
        'Maqedonia e Veriut',
      });
      expect(
        tvChannels.map((item) => item.id).toSet(),
        hasLength(tvChannels.length),
      );
      for (final channel in tvChannels) {
        expect(channel.url, startsWith('https://'));
        final city = cities.singleWhere(
          (item) =>
              item.name == channel.city && item.country == channel.country,
        );
        expect(channel.toEvent().point, city.point);
      }
    },
  );

  test('channels at the same studio city remain distinct tappable icons', () {
    expect(tvMarkerSpacing(7), greaterThanOrEqualTo(48));
    expect(tvMarkerSpacing(11), greaterThan(tvMarkerSpacing(7)));
    expect(
      tvChannels
          .where((item) => item.logoAsset == null)
          .every((item) => item.mapLabel.length <= 5),
      isTrue,
    );
    final tirana = tvChannels
        .where((item) => item.city == 'Tiranë')
        .map((item) => item.toEvent())
        .toList();
    final groups = groupMapMarkers(tirana, 11);
    expect(groups, hasLength(tirana.length));
    final displayed = layoutCoincidentMarkers(groups, 11);
    expect(displayed, hasLength(tirana.length));
    expect(displayed.values.toSet(), hasLength(tirana.length));
    expect(groups.map((group) => group.anchor).toSet(), hasLength(1));
  });
}
