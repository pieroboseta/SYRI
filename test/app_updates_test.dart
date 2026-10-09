import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:syri/app_updates.dart';

void main() {
  test('version comparison handles newer, equal and malformed releases', () {
    expect(isNewerSyriVersion('v0.19.38', '0.19.37'), isTrue);
    expect(isNewerSyriVersion('0.20.0', '0.19.99'), isTrue);
    expect(isNewerSyriVersion('0.19.38', '0.19.38'), isFalse);
    expect(isNewerSyriVersion('0.19.37', '0.19.38'), isFalse);
    expect(isNewerSyriVersion('v0.20.0-beta', '0.19.38'), isFalse);
  });

  test('GitHub release is offered only after an APK has uploaded', () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), syriLatestReleaseApi);
      return http.Response(
        '{"tag_name":"v0.19.39","assets":['
        '{"name":"guide.mp4","state":"uploaded"},'
        '{"name":"SYRI-v0.19.39-release.apk","state":"uploaded"}]}',
        200,
      );
    });
    final release = await fetchLatestSyriRelease(client: client);
    expect(release?.version, '0.19.39');
    expect(
      release?.pageUrl,
      'https://github.com/pieroboseta/SYRI/releases/tag/v0.19.39',
    );
    expect(
      syriReleaseFromJson({
        'tag_name': 'v0.19.40',
        'assets': [
          {'name': 'SYRI.apk', 'state': 'starter'},
        ],
      }),
      isNull,
    );
    client.close();
  });

  test('network errors are reported instead of claiming the app is current',
      () async {
    final client = MockClient((_) async => http.Response('rate limit', 403));
    await expectLater(fetchLatestSyriRelease(client: client), throwsStateError);
    client.close();
  });
}
