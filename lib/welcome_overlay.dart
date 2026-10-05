import 'package:flutter/material.dart';

/// A brief, non-blocking handoff from the Android splash to the live map.
class SyriWelcomeOverlay extends StatefulWidget {
  const SyriWelcomeOverlay({super.key});

  @override
  State<SyriWelcomeOverlay> createState() => _SyriWelcomeOverlayState();
}

class _SyriWelcomeOverlayState extends State<SyriWelcomeOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1450),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -.18),
          radius: 1.2,
          colors: [Color(0xff1d3b35), Color(0xff0d2020)],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) => Transform.scale(
                  scale: .97 + .055 * _pulse.value,
                  child: Container(
                    width: 122,
                    height: 122,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(36),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xffc7f36a)
                              .withValues(alpha: .08 + .15 * _pulse.value),
                          blurRadius: 26 + 24 * _pulse.value,
                          spreadRadius: 4 * _pulse.value,
                        ),
                      ],
                    ),
                    child: child,
                  ),
                ),
                child: Image.asset(
                  'assets/syri_brand.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 30),
              const SizedBox(
                width: 70,
                child: LinearProgressIndicator(
                  minHeight: 2,
                  backgroundColor: Color(0xff26433c),
                  color: Color(0xffc7f36a),
                  borderRadius: BorderRadius.all(Radius.circular(4)),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
