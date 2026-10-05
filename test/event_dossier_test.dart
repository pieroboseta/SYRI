import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:syri/data.dart';
import 'package:syri/event_dossier.dart';

void main() {
  final now = DateTime.utc(2026, 9, 27, 12);
  Event report(String id, String title, {LatLng? point}) => Event(
    id: id,
    title: title,
    description: '',
    source: id,
    url: 'https://example.org/$id',
    kind: 'news',
    time: now,
    point: point ?? const LatLng(42.0683, 19.5126),
  );

  test(
    'links close matching updates but not unrelated reports at one city',
    () {
      final selected = report(
        'first',
        'Aksident në Shkodër, dy makina përplasen në rrugën kryesore',
      );
      final followUp = report(
        'second',
        'Aksident në Shkodër: dy makina përplasen në rrugën kryesore',
      );
      final unrelated = report(
        'third',
        'Arrestim në Shkodër pas kontrollit të policisë',
      );
      expect(relatedReports(selected, [followUp, unrelated]), [followUp]);
    },
  );

  test('one incident uses one visible report with other sources retained', () {
    final first = report(
      'first',
      'Aksident në Shkodër, dy makina përplasen në rrugën kryesore',
    );
    final second = report(
      'second',
      'Aksident në Shkodër: dy makina përplasen në rrugën kryesore',
    );
    final unrelated = report(
      'third',
      'Aksident në Shkodër, autobusi përplaset pranë spitalit',
    );
    final distant = report(
      'fourth',
      'Aksident në Shkodër, dy makina përplasen në rrugën kryesore',
      point: const LatLng(42.66, 21.16),
    );
    expect(collapseNewsStories([first, second, unrelated, distant]).length, 2);
    expect(relatedReports(first, [second, unrelated, distant]), [
      second,
      distant,
    ]);
  });
}
