import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'data.dart';

/// A quiet, non-interactive forecast layer. It leaves map gestures and other
/// markers available while replacing dozens of weather point icons.
class SkyOverlayLayer extends StatelessWidget {
  final List<Event> readings;

  const SkyOverlayLayer(this.readings, {super.key});

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return IgnorePointer(
      child: MobileLayerTransformer(
        child: CustomPaint(
          size: camera.size,
          painter: SkyOverlayPainter(camera, readings),
        ),
      ),
    );
  }
}

class SkyOverlayPainter extends CustomPainter {
  final MapCamera camera;
  final List<Event> readings;

  const SkyOverlayPainter(this.camera, this.readings);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;
    final radius = (34.0 * math.pow(1.38, camera.zoom - 7))
        .clamp(55.0, 220.0)
        .toDouble();
    final grid = radius * .68;
    final occupied = <String>{};
    for (final reading in readings) {
      final point = reading.point;
      final data = reading.measurements;
      if (point == null || data == null) continue;
      final center = camera.projectAtZoom(point) - camera.pixelOrigin;
      if (center.dx < -radius ||
          center.dx > size.width + radius ||
          center.dy < -radius ||
          center.dy > size.height + radius) {
        continue;
      }
      // At regional zoom a single soft patch represents nearby city
      // forecasts; drawing every city would make the map opaque.
      final cell =
          '${(center.dx / grid).floor()}:${(center.dy / grid).floor()}';
      if (!occupied.add(cell)) continue;

      final cloud = ((data['cloud'] ?? 0) / 100).clamp(0.0, 1.0);
      if (cloud > .15) {
        final strength = (cloud * (camera.zoom < 9 ? .23 : .30)).clamp(
          0.0,
          .30,
        );
        final rect = Rect.fromCircle(center: center, radius: radius);
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..shader = RadialGradient(
              colors: [
                const Color(0xffdce9ee).withValues(alpha: strength),
                const Color(0xffa9c4d1).withValues(alpha: strength * .45),
                Colors.transparent,
              ],
              stops: const [0, .55, 1],
            ).createShader(rect),
        );
      }

      final visibility = data['visibility'] ?? 100000;
      if (visibility < 3000) {
        final fogStrength = ((3000 - visibility) / 3000 * .23).clamp(0.0, .23);
        final fogRadius = radius * .7;
        canvas.drawCircle(
          center,
          fogRadius,
          Paint()
            ..shader = RadialGradient(
              colors: [
                const Color(0xff76d9e5).withValues(alpha: fogStrength),
                Colors.transparent,
              ],
            ).createShader(Rect.fromCircle(center: center, radius: fogRadius)),
        );
      }

      final wind = data['wind'] ?? 0;
      final direction = data['direction'];
      if (direction != null && wind >= 6 && camera.zoom >= 8) {
        _drawWind(canvas, center, direction, wind);
      }
    }
  }

  void _drawWind(
    Canvas canvas,
    Offset center,
    double fromDegrees,
    double speed,
  ) {
    // Meteorological direction states where the wind comes from.
    final toward = (fromDegrees + 180) * math.pi / 180;
    final vector = Offset(math.sin(toward), -math.cos(toward));
    final length = (13 + speed * .45).clamp(16.0, 31.0);
    final start = center - vector * (length / 2);
    final tip = center + vector * (length / 2);
    final paint = Paint()
      ..color = const Color(0xffa6e7ff).withValues(alpha: .55)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final side = Offset(-vector.dy, vector.dx);
    canvas.drawLine(start, tip, paint);
    canvas.drawLine(tip, tip - vector * 5 + side * 3, paint);
    canvas.drawLine(tip, tip - vector * 5 - side * 3, paint);
  }

  @override
  bool shouldRepaint(covariant SkyOverlayPainter oldDelegate) =>
      oldDelegate.camera != camera || oldDelegate.readings != readings;
}
