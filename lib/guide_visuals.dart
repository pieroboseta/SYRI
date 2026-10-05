import 'package:flutter/material.dart';

/// Small, local illustrations of SYRI controls. These are examples, not live data.
class GuideIllustration extends StatelessWidget {
  const GuideIllustration({
    super.key,
    required this.lesson,
    required this.english,
  });

  final int lesson;
  final bool english;

  static const _ink = Color(0xff0d2020);
  static const _mint = Color(0xffc7f36a);
  static const _blue = Color(0xff86b8ff);
  static const _red = Color(0xffff7385);
  static const _muted = Color(0xffa6bbb7);

  String t(String sq, String en) => english ? en : sq;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('guide-illustration-$lesson'),
    height: 185,
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 15),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: const Color(0xff102727),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _mint.withValues(alpha: .2)),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(painter: _GuideGridPainter()),
        Padding(
          padding: const EdgeInsets.all(12),
          child: switch (lesson) {
            0 => _city(),
            1 => _map(),
            2 => _layers(),
            3 => _savedLayers(),
            4 => _markers(),
            5 => _details(),
            6 => _events(),
            7 => _notifications(),
            8 => _language(),
            _ => _cache(),
          },
        ),
      ],
    ),
  );

  Widget _label(String text, {Color color = _mint}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: _ink.withValues(alpha: .91),
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: color.withValues(alpha: .45)),
    ),
    child: Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
    ),
  );

  Widget _city() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label(t('PREK EMRIN E QYTETIT', 'TAP THE CITY NAME')),
      const SizedBox(height: 9),
      Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: BoxDecoration(
            color: _ink.withValues(alpha: .9),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _mint.withValues(alpha: .5)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_on_outlined, color: _mint, size: 17),
              SizedBox(width: 5),
              Text('Shkodër', style: TextStyle(fontWeight: FontWeight.w700)),
              SizedBox(width: 5),
              Icon(Icons.keyboard_arrow_down, color: _mint, size: 18),
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(child: _label(t('★ Të preferuarat', '★ Favorites'))),
          const SizedBox(width: 8),
          Expanded(child: _label(t('4 vende', '4 countries'), color: _muted)),
        ],
      ),
      const Spacer(),
      Text(
        t(
          'Qyteti ndryshon lajmet, motin dhe SYRI Tani',
          'City changes news, weather and SYRI Now',
        ),
        style: const TextStyle(color: _muted, fontSize: 10),
      ),
    ],
  );

  Widget _savedLayers() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Flexible(child: _label(t('ZGJIDH KATEGORI', 'CHOOSE A CATEGORY'))),
          const Spacer(),
          _control(Icons.dashboard_customize_outlined, size: 16),
        ],
      ),
      const SizedBox(height: 13),
      Row(
        children: [
          Expanded(child: _label(t('Lajme  ●', 'News  ●'), color: _blue)),
          const SizedBox(width: 7),
          Expanded(child: _label(t('Alarme  ●', 'Alerts  ●'), color: _red)),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: _label(t('Tërmete  ○', 'Earthquakes  ○'), color: _muted),
          ),
          const SizedBox(width: 7),
          Expanded(child: _label(t('Kamera  ●', 'Cameras  ●'), color: _blue)),
        ],
      ),
      const Spacer(),
      Text(
        t(
          'Zgjedhjet ruhen për herën tjetër',
          'Selections remain saved next time',
        ),
        style: const TextStyle(color: _muted, fontSize: 10),
      ),
    ],
  );

  Widget _map() => Stack(
    children: [
      Align(
        alignment: Alignment.topLeft,
        child: _label(t('SHKODËR · HARTË', 'SHKODËR · MAP')),
      ),
      const Align(
        alignment: Alignment.center,
        child: Icon(Icons.place, color: _red, size: 44),
      ),
      Align(
        alignment: Alignment.bottomLeft,
        child: _label(t('Lëviz me gisht', 'Drag to move'), color: _muted),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _control(Icons.add),
            const SizedBox(height: 5),
            _control(Icons.remove),
            const SizedBox(height: 5),
            _control(Icons.my_location, size: 14),
          ],
        ),
      ),
    ],
  );

  Widget _control(IconData icon, {double size = 17}) => Container(
    height: 31,
    width: 31,
    decoration: BoxDecoration(
      color: _ink.withValues(alpha: .95),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white24),
    ),
    child: Icon(icon, color: _mint, size: size),
  );

  Widget _layers() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          _label(t('SHTRESAT', 'LAYERS')),
          const Spacer(),
          _control(Icons.dashboard_customize_outlined, size: 15),
        ],
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          _pill(Icons.article_outlined, t('Lajme', 'News'), _blue),
          const SizedBox(width: 6),
          _pill(Icons.warning_amber_rounded, t('Alarme', 'Alerts'), _red),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 112,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: _ink.withValues(alpha: .91),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _blue.withValues(alpha: .55)),
            ),
            child: Column(
              children: [
                _layerChoice(
                  Icons.article_outlined,
                  t('Lajme të tjera', 'Other news'),
                  _blue,
                  true,
                ),
                const SizedBox(height: 5),
                _layerChoice(
                  Icons.directions_car,
                  t('Aksidente', 'Crashes'),
                  Colors.orangeAccent,
                  false,
                ),
              ],
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _label(t('ÇELËSA', 'SWITCHES'), color: _muted),
              const SizedBox(height: 4),
              const Icon(Icons.toggle_on_rounded, color: _mint, size: 32),
            ],
          ),
        ],
      ),
    ],
  );

  Widget _layerChoice(IconData icon, String text, Color color, bool on) => Row(
    children: [
      Icon(icon, color: color, size: 13),
      const SizedBox(width: 5),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 9),
        ),
      ),
      Icon(
        on ? Icons.check_circle : Icons.circle_outlined,
        color: on ? color : _muted,
        size: 13,
      ),
    ],
  );

  Widget _pill(
    IconData icon,
    String text,
    Color color, {
    bool small = false,
  }) => Flexible(
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 7 : 10, vertical: 7),
      decoration: BoxDecoration(
        color: _ink.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: .75)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: small ? 14 : 17),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white, fontSize: small ? 10 : 11),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _markers() => Column(
    children: [
      Align(
        alignment: Alignment.topLeft,
        child: _label(t('IKONA TË NDRYSHME', 'DIFFERENT ICONS')),
      ),
      const Spacer(),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _sampleMarker(Icons.directions_car, '3', Colors.orangeAccent),
          _sampleMarker(Icons.article_outlined, '1', _blue),
          _sampleMarker(Icons.warning_amber_rounded, '2', _red),
        ],
      ),
      const Spacer(),
      Text(
        t(
          'Numri = sa pika të të njëjtit lloj',
          'Count = items of the same type',
        ),
        style: const TextStyle(color: _muted, fontSize: 10),
      ),
    ],
  );

  Widget _sampleMarker(IconData icon, String count, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: color, size: 28),
      if (count != '1')
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: _ink,
            shape: BoxShape.circle,
            border: Border.all(color: color),
          ),
          child: Text(count, style: TextStyle(color: color, fontSize: 10)),
        ),
    ],
  );

  Widget _details() => Center(
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _ink.withValues(alpha: .95),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _blue.withValues(alpha: .6)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('Titulli i njoftimit', 'Report title'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 5),
          Text(
            t('Përmbledhja dhe vendndodhja…', 'Summary and location…'),
            style: const TextStyle(color: _muted, fontSize: 10),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.schedule, color: _muted, size: 12),
              const SizedBox(width: 4),
              Text(
                t('Koha · Burimi', 'Time · Source'),
                style: const TextStyle(color: _muted, fontSize: 9),
              ),
              const Spacer(),
              Icon(Icons.open_in_new, color: _mint, size: 14),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _events() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: double.infinity,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _label('SYRI'),
              const SizedBox(width: 12),
              _label('Shkodër', color: _muted),
              const SizedBox(width: 12),
              _label(t('✦ TANI', '✦ NOW')),
            ],
          ),
        ),
      ),
      const SizedBox(height: 10),
      _label(t('NGJARJET', 'EVENTS'), color: _blue),
      const SizedBox(height: 6),
      _feedRow(
        Icons.warning_amber_rounded,
        t('Alarm i rëndësishëm', 'Important alert'),
        _red,
      ),
      const Spacer(),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: const [
          Icon(Icons.map_outlined, color: _muted, size: 16),
          Icon(Icons.dynamic_feed, color: _mint, size: 16),
          Icon(Icons.settings_outlined, color: _muted, size: 16),
          Icon(Icons.volunteer_activism_outlined, color: _red, size: 16),
        ],
      ),
    ],
  );

  Widget _feedRow(IconData icon, String title, Color color) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: _ink.withValues(alpha: .9),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 17),
        const SizedBox(width: 8),
        Expanded(child: Text(title, style: const TextStyle(fontSize: 11))),
        const Icon(Icons.north_east, color: _muted, size: 13),
      ],
    ),
  );

  Widget _notifications() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label(t('ZGJEDHJET E TUA', 'YOUR CHOICES')),
      const Spacer(),
      _toggleRow(t('Lajme', 'News'), true),
      const SizedBox(height: 7),
      _toggleRow(t('Tërmete 6+', 'Earthquakes 6+'), true),
      const SizedBox(height: 7),
      _toggleRow(t('Nga bota', 'World news'), false),
      const Spacer(),
    ],
  );

  Widget _toggleRow(String label, bool on) => Row(
    children: [
      Text(label, style: const TextStyle(fontSize: 11)),
      const Spacer(),
      Icon(
        on ? Icons.toggle_on : Icons.toggle_off,
        color: on ? _mint : _muted,
        size: 29,
      ),
    ],
  );

  Widget _language() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label(t('CILËSIMET · GJUHA', 'SETTINGS · LANGUAGE')),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _ink.withValues(alpha: .93),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _blue.withValues(alpha: .5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.travel_explore, color: _blue, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                t('Language / Gjuha', 'Language / Gjuha'),
                style: const TextStyle(fontSize: 11),
              ),
            ),
            Icon(
              english ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
              color: english ? _mint : _muted,
              size: 29,
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      _label(
        t('Mesazhet shfaqen me stilin e SYRI-t', 'Messages use SYRI’s style'),
        color: _muted,
      ),
      const Spacer(),
    ],
  );

  Widget _cache() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label(t('CACHE I HARTËS', 'MAP CACHE')),
      const Spacer(),
      Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            Expanded(
              child: Container(
                height: 43,
                decoration: BoxDecoration(
                  color: i < 3 ? _mint.withValues(alpha: .48) : Colors.white10,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: i < 3 ? _mint : _muted),
                ),
                child: Icon(
                  i < 3 ? Icons.check : Icons.wifi,
                  color: i < 3 ? _ink : _muted,
                  size: 18,
                ),
              ),
            ),
            if (i < 3) const SizedBox(width: 5),
          ],
        ],
      ),
      const Spacer(),
      Text(
        t(
          'Të shikuara më parë · Zona e re kërkon internet',
          'Viewed before · New areas need internet',
        ),
        style: const TextStyle(color: _muted, fontSize: 10),
      ),
    ],
  );
}

class _GuideGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0x2238a997)
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 31) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y < size.height; y += 31) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final road = Paint()
      ..color = const Color(0x554ba1a0)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(-10, size.height * .7)
      ..cubicTo(
        size.width * .27,
        size.height * .15,
        size.width * .5,
        size.height * .9,
        size.width + 10,
        size.height * .25,
      );
    canvas.drawPath(path, road);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
