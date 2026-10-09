import 'dart:convert';

import 'package:http/http.dart' as http;

const syriLatestReleaseApi =
    'https://api.github.com/repos/pieroboseta/SYRI/releases/latest';

class SyriRelease {
  const SyriRelease({required this.version, required this.pageUrl});

  final String version;
  final String pageUrl;
}

/// Compare published numeric versions, without treating a build number as a
/// separate release. GitHub's latest endpoint excludes draft/prereleases.
bool isNewerSyriVersion(String published, String installed) {
  List<int>? parts(String value) {
    final match = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)$').firstMatch(value.trim());
    if (match == null) return null;
    return [for (var i = 1; i <= 3; i++) int.parse(match.group(i)!)];
  }

  final remote = parts(published);
  final local = parts(installed);
  if (remote == null || local == null) return false;
  for (var i = 0; i < 3; i++) {
    if (remote[i] != local[i]) return remote[i] > local[i];
  }
  return false;
}

SyriRelease? syriReleaseFromJson(Map<String, dynamic> data) {
  final tag = data['tag_name'];
  final assets = data['assets'];
  if (tag is! String ||
      !RegExp(r'^v?\d+\.\d+\.\d+$').hasMatch(tag) ||
      assets is! List ||
      !assets.any(
        (asset) =>
            asset is Map &&
            asset['name'] is String &&
            (asset['name'] as String).toLowerCase().endsWith('.apk') &&
            asset['state'] == 'uploaded',
      )) {
    return null;
  }
  return SyriRelease(
    version: tag.startsWith('v') ? tag.substring(1) : tag,
    pageUrl: 'https://github.com/pieroboseta/SYRI/releases/tag/$tag',
  );
}

Future<SyriRelease?> fetchLatestSyriRelease({http.Client? client}) async {
  final requestClient = client ?? http.Client();
  try {
    final response = await requestClient
        .get(
          Uri.parse(syriLatestReleaseApi),
          headers: const {
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'SYRI-Android',
          },
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw StateError('GitHub releases: HTTP ${response.statusCode}');
    }
    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Invalid GitHub release');
    }
    final release = syriReleaseFromJson(data);
    if (release == null) {
      throw const FormatException('Latest GitHub release has no Android APK');
    }
    return release;
  } finally {
    if (client == null) requestClient.close();
  }
}
