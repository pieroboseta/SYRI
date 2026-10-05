import 'package:latlong2/latlong.dart';

import 'data.dart';

/// Returns only strong title matches. A shared city or map point by itself is
/// never enough evidence that two reports cover the same incident.
List<Event> relatedReports(Event selected, Iterable<Event> candidates) {
  final related = <Event>[];
  for (final other in candidates) {
    if (sameNewsStory(selected, other)) related.add(other);
  }
  related.sort((a, b) => b.time!.compareTo(a.time!));
  return related.take(8).toList();
}

/// Collapse strong matches for map and feed display while retaining the
/// original reports for source links inside the event detail sheet.
List<Event> collapseNewsStories(Iterable<Event> reports) {
  final sorted = [...reports]
    ..sort(
      (a, b) => (b.time ?? DateTime(1970)).compareTo(a.time ?? DateTime(1970)),
    );
  final visible = <Event>[];
  for (final report in sorted) {
    if (!visible.any((shown) => sameNewsStory(shown, report))) {
      visible.add(report);
    }
  }
  return visible;
}

bool sameNewsStory(Event first, Event second) {
  if (first.id == second.id || first.url == second.url) return false;
  if (first.kind != 'news' ||
      second.kind != 'news' ||
      first.time == null ||
      second.time == null ||
      first.time!.difference(second.time!).abs() > const Duration(hours: 48)) {
    return false;
  }
  final firstWords = _meaningfulWords(first.title);
  final secondWords = _meaningfulWords(second.title);
  if (firstWords.length < 4 || secondWords.length < 4) return false;
  final common = firstWords.intersection(secondWords).length;
  final union = firstWords.union(secondWords).length;
  final similarity = union == 0 ? 0 : common / union;
  final distant =
      first.point == null ||
      second.point == null ||
      const Distance().as(LengthUnit.Kilometer, first.point!, second.point!) >
          18;
  if (distant || first.newsType != second.newsType) {
    return common >= 6 && similarity >= .85;
  }
  return common >= 4 && similarity >= .62;
}

Set<String> _meaningfulWords(String value) {
  const stop = {
    'per',
    'nga',
    'dhe',
    'nje',
    'me',
    'ne',
    'te',
    'eshte',
    'sot',
    'pas',
    'the',
    'and',
    'for',
    'with',
    'from',
    'this',
    'that',
    'after',
  };
  return normalize(value)
      .split(RegExp(r'[^a-z0-9]+'))
      .where((word) => word.length >= 3 && !stop.contains(word))
      .toSet();
}
