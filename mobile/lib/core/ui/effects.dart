import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../motion.dart';

/// Slowly drifting soft colour blobs over a gradient — a living background for headers, splash and auth.
class AuroraBackground extends ConsumerStatefulWidget {
  final List<Color> colors;
  final Widget? child;
  final BorderRadius? borderRadius;
  const AuroraBackground({super.key, required this.colors, this.child, this.borderRadius});

  @override
  ConsumerState<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends ConsumerState<AuroraBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 14));

  @override
  void initState() {
    super.initState();
    if (ref.read(richMotionProvider)) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) => CustomPaint(
          painter: _AuroraPainter(colors, _c.value),
          child: child,
        ),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final List<Color> colors;
  final double t;
  _AuroraPainter(this.colors, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = LinearGradient(
      colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight).createShader(rect));
    final a = t * 2 * math.pi;
    final blobs = [
      (Offset(size.width * (0.2 + 0.1 * math.sin(a)), size.height * (0.2 + 0.1 * math.cos(a))), 0.55, Colors.white, 0.18),
      (Offset(size.width * (0.85 + 0.08 * math.cos(a)), size.height * (0.3 + 0.12 * math.sin(a))), 0.45,
          colors.last, 0.55),
      (Offset(size.width * (0.55 + 0.12 * math.sin(a + 2)), size.height * (1.0 + 0.1 * math.cos(a + 1))), 0.6,
          colors.first, 0.5),
    ];
    for (final (center, r, color, alpha) in blobs) {
      final radius = size.shortestSide * r + size.longestSide * 0.15;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.t != t || old.colors != colors;
}

/// A light beam that sweeps across the child from time to time (unlocked badges, primary buttons).
class Shine extends ConsumerStatefulWidget {
  final Widget child;
  final Duration period;
  final BorderRadius borderRadius;
  final bool enabled;
  const Shine({
    super.key,
    required this.child,
    this.period = const Duration(milliseconds: 3200),
    this.borderRadius = BorderRadius.zero,
    this.enabled = true,
  });

  @override
  ConsumerState<Shine> createState() => _ShineState();
}

class _ShineState extends ConsumerState<Shine> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period);

  @override
  void initState() {
    super.initState();
    if (widget.enabled && ref.read(richMotionProvider)) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Stack(children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                // The beam passes during the first 35% of the period, then rests
                final p = (_c.value / 0.35).clamp(0.0, 1.0);
                if (p == 0 || p == 1) return const SizedBox.shrink();
                return FractionallySizedBox(
                  alignment: Alignment(-1.6 + 3.2 * p, 0),
                  widthFactor: 0.35,
                  child: Transform(
                    transform: Matrix4.skewX(-0.35),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: 0.35),
                          Colors.white.withValues(alpha: 0),
                        ]),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ]),
    );
  }
}

/// Gentle breathing scale — for the streak fire and "new" badges.
class Pulse extends ConsumerStatefulWidget {
  final Widget child;
  final double amplitude;
  final Duration period;
  final bool enabled;
  const Pulse({
    super.key,
    required this.child,
    this.amplitude = 0.08,
    this.period = const Duration(milliseconds: 1400),
    this.enabled = true,
  });

  @override
  ConsumerState<Pulse> createState() => _PulseState();
}

class _PulseState extends ConsumerState<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period);

  @override
  void initState() {
    super.initState();
    if (widget.enabled && ref.read(richMotionProvider)) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: Tween(begin: 1.0, end: 1 + widget.amplitude)
            .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOutSine)),
        child: widget.child,
      );
}

/// Floats a widget up and down (onboarding illustrations, empty states).
class Float extends ConsumerStatefulWidget {
  final Widget child;
  final double distance;
  final Duration period;
  final double phase; // 0..1, to desynchronise several floating items
  const Float({
    super.key,
    required this.child,
    this.distance = 8,
    this.period = const Duration(milliseconds: 2600),
    this.phase = 0,
  });

  @override
  ConsumerState<Float> createState() => _FloatState();
}

class _FloatState extends ConsumerState<Float> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period);

  @override
  void initState() {
    super.initState();
    _c.value = widget.phase;
    if (ref.read(richMotionProvider)) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, math.sin(_c.value * 2 * math.pi) * widget.distance),
          child: child,
        ),
      );
}
