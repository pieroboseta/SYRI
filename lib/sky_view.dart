import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

const _skyAccent = Color(0xffb9a5ff);
const _degree = math.pi / 180;

class SkyObject {
  final String name;
  final double altitude;
  final double azimuth;
  final double? illumination;

  const SkyObject(this.name, this.altitude, this.azimuth, [this.illumination]);

  bool get visible => altitude > 0;
}

class _Equatorial {
  final double rightAscension;
  final double declination;
  final double? eclipticLongitude;

  const _Equatorial(
    this.rightAscension,
    this.declination, [
    this.eclipticLongitude,
  ]);
}

double _wrap(double angle) {
  final result = angle % (2 * math.pi);
  return result < 0 ? result + 2 * math.pi : result;
}

double _julianDay(DateTime time) =>
    time.toUtc().millisecondsSinceEpoch / 86400000 + 2440587.5;

_Equatorial _sun(double julianDay) {
  final days = julianDay - 2451545.0;
  final meanLongitude = (280.46 + 0.9856474 * days) * _degree;
  final anomaly = (357.528 + 0.9856003 * days) * _degree;
  final longitude =
      meanLongitude +
      1.915 * _degree * math.sin(anomaly) +
      0.020 * _degree * math.sin(2 * anomaly);
  final obliquity = (23.439 - 0.0000004 * days) * _degree;
  return _Equatorial(
    _wrap(
      math.atan2(
        math.cos(obliquity) * math.sin(longitude),
        math.cos(longitude),
      ),
    ),
    math.asin(math.sin(obliquity) * math.sin(longitude)),
    _wrap(longitude),
  );
}

_Equatorial _moon(double julianDay) {
  // Low-precision geocentric orbit. Sufficient for a general sky guide;
  // deliberately not used for eclipse or precise rise/set predictions.
  final days = julianDay - 2451543.5;
  final node = (125.1228 - 0.0529538083 * days) * _degree;
  const inclination = 5.1454 * _degree;
  final perigee = (318.0634 + 0.1643573223 * days) * _degree;
  final anomaly = (115.3654 + 13.0649929509 * days) * _degree;
  const eccentricity = 0.0549;
  final eccentricAnomaly =
      anomaly +
      eccentricity * math.sin(anomaly) * (1 + eccentricity * math.cos(anomaly));
  final x = 60.2666 * (math.cos(eccentricAnomaly) - eccentricity);
  final y =
      60.2666 *
      math.sqrt(1 - eccentricity * eccentricity) *
      math.sin(eccentricAnomaly);
  final argument = math.atan2(y, x) + perigee;
  final longitude = math.atan2(
    math.sin(node) * math.cos(argument) +
        math.cos(node) * math.sin(argument) * math.cos(inclination),
    math.cos(node) * math.cos(argument) -
        math.sin(node) * math.sin(argument) * math.cos(inclination),
  );
  final latitude = math.asin(math.sin(argument) * math.sin(inclination));
  final obliquity = (23.439 - 0.0000004 * (julianDay - 2451545.0)) * _degree;
  final equatorialX = math.cos(longitude) * math.cos(latitude);
  final equatorialY =
      math.sin(longitude) * math.cos(latitude) * math.cos(obliquity) -
      math.sin(latitude) * math.sin(obliquity);
  final equatorialZ =
      math.sin(longitude) * math.cos(latitude) * math.sin(obliquity) +
      math.sin(latitude) * math.cos(obliquity);
  return _Equatorial(
    _wrap(math.atan2(equatorialY, equatorialX)),
    math.asin(equatorialZ),
    _wrap(longitude),
  );
}

SkyObject _horizontal(
  String name,
  _Equatorial equatorial,
  DateTime time,
  double latitude,
  double longitude, [
  double? illumination,
]) {
  final jd = _julianDay(time);
  final sidereal = _wrap(
    (280.46061837 + 360.98564736629 * (jd - 2451545.0) + longitude) * _degree,
  );
  final hourAngle = sidereal - equatorial.rightAscension;
  final lat = latitude * _degree;
  final dec = equatorial.declination;
  final altitude = math.asin(
    math.sin(lat) * math.sin(dec) +
        math.cos(lat) * math.cos(dec) * math.cos(hourAngle),
  );
  final azimuth = _wrap(
    math.atan2(
      -math.sin(hourAngle),
      math.tan(dec) * math.cos(lat) - math.sin(lat) * math.cos(hourAngle),
    ),
  );
  return SkyObject(name, altitude / _degree, azimuth / _degree, illumination);
}

({SkyObject sun, SkyObject moon}) skySolarBodies(
  DateTime time,
  double latitude,
  double longitude,
) {
  final jd = _julianDay(time);
  final solar = _sun(jd);
  final lunar = _moon(jd);
  final phase =
      (1 - math.cos(lunar.eclipticLongitude! - solar.eclipticLongitude!)) / 2;
  return (
    sun: _horizontal('Sun', solar, time, latitude, longitude),
    moon: _horizontal('Moon', lunar, time, latitude, longitude, phase),
  );
}

class _Star {
  final String name;
  final double ra;
  final double dec;
  final double size;
  const _Star(this.name, this.ra, this.dec, [this.size = 2]);
}

// Bright guide stars, coordinates at J2000. For a casual sky guide the small
// precession since J2000 is below the visual precision of this overlay.
const _stars = <_Star>[
  _Star('Sirius', 101.287, -16.716, 3.5),
  _Star('Betelgeuse', 88.793, 7.407, 3),
  _Star('Rigel', 78.634, -8.202, 3),
  _Star('Bellatrix', 81.283, 6.350),
  _Star('Saiph', 86.939, -9.670),
  _Star('Mintaka', 83.001, -0.299),
  _Star('Alnilam', 84.053, -1.201),
  _Star('Alnitak', 85.190, -1.943),
  _Star('Vega', 279.235, 38.784, 3.5),
  _Star('Deneb', 310.358, 45.280, 3),
  _Star('Altair', 297.696, 8.868, 3),
  _Star('Polaris', 37.955, 89.264, 2.8),
  _Star('Dubhe', 165.932, 61.751),
  _Star('Merak', 165.460, 56.380),
  _Star('Phecda', 178.457, 53.694),
  _Star('Megrez', 183.857, 57.032),
  _Star('Alioth', 193.507, 55.960),
  _Star('Mizar', 200.981, 54.925),
  _Star('Alkaid', 206.885, 49.313),
  _Star('Caph', 2.293, 59.149),
  _Star('Schedar', 10.127, 56.537),
  _Star('Gamma Cas', 14.177, 60.717),
  _Star('Ruchbah', 21.454, 60.235),
  _Star('Segin', 28.599, 63.670),
];

const _constellations = <String, List<String>>{
  'Orion': [
    'Betelgeuse',
    'Bellatrix',
    'Mintaka',
    'Alnilam',
    'Alnitak',
    'Saiph',
    'Rigel',
    'Mintaka',
  ],
  'Ursa Major': [
    'Dubhe',
    'Merak',
    'Phecda',
    'Megrez',
    'Alioth',
    'Mizar',
    'Alkaid',
  ],
  'Cassiopeia': ['Caph', 'Schedar', 'Gamma Cas', 'Ruchbah', 'Segin'],
  'Summer Triangle': ['Vega', 'Deneb', 'Altair', 'Vega'],
};

class SkyView extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String placeName;
  final bool english;

  const SkyView({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.placeName,
    required this.english,
  });

  @override
  State<SkyView> createState() => _SkyViewState();
}

class _SkyViewState extends State<SkyView> {
  Timer? _clock;
  double _hoursOffset = 0;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final time = _now.add(Duration(minutes: (_hoursOffset * 60).round()));
    final bodies = skySolarBodies(time, widget.latitude, widget.longitude);
    final moonPercent = ((bodies.moon.illumination ?? 0) * 100).round();
    final daylight = bodies.sun.altitude > -6;
    final timeLabel = TimeOfDay.fromDateTime(time).format(context);
    final controls = Container(
      key: const ValueKey('sky-view-controls'),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 6),
      decoration: BoxDecoration(
        color: const Color(0xff112633).withValues(alpha: .78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _skyAccent.withValues(alpha: .56)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${widget.placeName} · $timeLabel · ${widget.english ? 'calculated sky' : 'qiell i llogaritur'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
          Text(
            '${widget.english ? 'Sun' : 'Dielli'} ${bodies.sun.visible ? '↑' : '↓'}  ·  '
            '${widget.english ? 'Moon' : 'Hëna'} ${bodies.moon.visible ? '↑' : '↓'} $moonPercent%',
            style: const TextStyle(color: _skyAccent, fontSize: 11),
          ),
          if (daylight)
            Text(
              widget.english
                  ? 'Stars hidden by daylight'
                  : 'Yjet nuk duken në dritë',
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              activeTrackColor: _skyAccent,
              thumbColor: _skyAccent,
            ),
            child: Slider(
              value: _hoursOffset,
              min: -12,
              max: 12,
              divisions: 48,
              onChanged: (value) => setState(() => _hoursOffset = value),
            ),
          ),
          Text(
            widget.english
                ? '−12 h     Now     +12 h'
                : '−12 orë     Tani     +12 orë',
            style: const TextStyle(color: Colors.white70, fontSize: 9),
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final landscape = constraints.maxWidth > constraints.maxHeight;
        final panelWidth = math.min(276.0, constraints.maxWidth * .34);
        final topInset = MediaQuery.paddingOf(context).top;
        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: const Color(0xff030c1c).withValues(alpha: .54),
                ),
              ),
            ),
            Positioned.fill(
              right: landscape ? panelWidth + 28 : 0,
              child: IgnorePointer(
                child: CustomPaint(
                  key: const ValueKey('sky-view-chart'),
                  painter: _SkyPainter(
                    time,
                    widget.latitude,
                    widget.longitude,
                    widget.english,
                  ),
                ),
              ),
            ),
            if (landscape)
              Positioned(
                top: topInset + 54,
                right: 14,
                width: panelWidth,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: math.max(
                      100,
                      constraints.maxHeight - topInset - 66,
                    ),
                  ),
                  child: SingleChildScrollView(child: controls),
                ),
              )
            else
              Positioned(left: 12, right: 70, bottom: 108, child: controls),
          ],
        );
      },
    );
  }
}

class _SkyPainter extends CustomPainter {
  final DateTime time;
  final double latitude;
  final double longitude;
  final bool english;
  const _SkyPainter(this.time, this.latitude, this.longitude, this.english);

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(size.width * .43, size.height * .27);
    final center = Offset(size.width / 2, size.height * .43);
    final horizon = Paint()
      ..color = _skyAccent.withValues(alpha: .45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius, horizon);
    canvas.drawCircle(
      center,
      radius * .5,
      Paint()
        ..color = _skyAccent.withValues(alpha: .18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    for (final entry in <(String, Offset)>[
      (english ? 'N' : 'V', Offset(center.dx, center.dy - radius - 14)),
      (english ? 'E' : 'L', Offset(center.dx + radius + 10, center.dy)),
      (english ? 'S' : 'J', Offset(center.dx, center.dy + radius + 8)),
      (english ? 'W' : 'P', Offset(center.dx - radius - 14, center.dy)),
    ]) {
      _label(canvas, entry.$1, entry.$2, _skyAccent, 11);
    }
    Offset? projected(SkyObject object) {
      if (!object.visible) return null;
      final distance = radius * (90 - object.altitude) / 90;
      return Offset(
        center.dx + distance * math.sin(object.azimuth * _degree),
        center.dy - distance * math.cos(object.azimuth * _degree),
      );
    }

    final positions = <String, Offset>{};
    final bodies = skySolarBodies(time, latitude, longitude);
    for (final star in bodies.sun.altitude > -6 ? <_Star>[] : _stars) {
      final point = projected(
        _horizontal(
          star.name,
          _Equatorial(star.ra * _degree, star.dec * _degree),
          time,
          latitude,
          longitude,
        ),
      );
      if (point == null) continue;
      positions[star.name] = point;
    }
    final linePaint = Paint()
      ..color = _skyAccent.withValues(alpha: .42)
      ..strokeWidth = 1;
    for (final constellation in _constellations.values) {
      for (var i = 1; i < constellation.length; i++) {
        final a = positions[constellation[i - 1]];
        final b = positions[constellation[i]];
        if (a != null && b != null) canvas.drawLine(a, b, linePaint);
      }
    }
    for (final star in bodies.sun.altitude > -6 ? <_Star>[] : _stars) {
      final point = positions[star.name];
      if (point == null) continue;
      canvas.drawCircle(point, star.size, Paint()..color = Colors.white);
      if (star.size >= 3) {
        _label(
          canvas,
          star.name,
          point + const Offset(5, -13),
          Colors.white70,
          9,
        );
      }
    }
    for (final entry in _constellations.entries) {
      final points = entry.value
          .map((name) => positions[name])
          .whereType<Offset>()
          .toList();
      if (points.length < 3) continue;
      final x = points.map((p) => p.dx).reduce((a, b) => a + b) / points.length;
      final y = points.map((p) => p.dy).reduce((a, b) => a + b) / points.length;
      _label(canvas, entry.key, Offset(x, y + 13), _skyAccent, 10);
    }
    for (final body in [bodies.sun, bodies.moon]) {
      final point = projected(body);
      if (point == null) continue;
      final isSun = body.name == 'Sun';
      canvas.drawCircle(
        point,
        isSun ? 9 : 8,
        Paint()
          ..color = isSun ? const Color(0xffffd76b) : const Color(0xffe3ebff),
      );
      _label(
        canvas,
        isSun ? (english ? 'Sun' : 'Dielli') : (english ? 'Moon' : 'Hëna'),
        point + const Offset(10, -12),
        Colors.white,
        11,
      );
    }
  }

  void _label(
    Canvas canvas,
    String text,
    Offset point,
    Color color,
    double size,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, point);
  }

  @override
  bool shouldRepaint(covariant _SkyPainter oldDelegate) =>
      time != oldDelegate.time ||
      latitude != oldDelegate.latitude ||
      longitude != oldDelegate.longitude ||
      english != oldDelegate.english;
}
