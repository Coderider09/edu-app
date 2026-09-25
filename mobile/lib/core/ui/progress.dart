import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../motion.dart';
import '../widgets/common.dart';
import 'tokens.dart';

/// Circular progress with a gradient stroke and rounded ends that fills up on appearance.
class ProgressRing extends ConsumerWidget {
  final double value; // 0..1
  final double size;
  final double stroke;
  final List<Color> colors;
  final Color? track;
  final Widget? child;
  final Duration duration;
  const ProgressRing({
    super.key,
    required this.value,
    required this.colors,
    this.size = 64,
    this.stroke = 7,
    this.track,
    this.child,
    this.duration = const Duration(milliseconds: 1100),
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackColor = track ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1)),
      duration: motion(ref, duration.inMilliseconds, context: context),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => CustomPaint(
        size: Size.square(size),
        painter: _RingPainter(v, colors, trackColor, stroke),
        child: SizedBox.square(dimension: size, child: Center(child: child)),
      ),
      child: child,
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final List<Color> colors;
  final Color track;
  final double stroke;
  _RingPainter(this.value, this.colors, this.track, this.stroke);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    canvas.drawArc(rect, 0, 2 * math.pi, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..color = track);
    if (value <= 0) return;
    final sweep = 2 * math.pi * value;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: 2 * math.pi,
          colors: [...colors, colors.first],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.colors != colors || old.track != track;
}

/// Linear progress with a gradient fill and rounded ends.
class GradientBar extends ConsumerWidget {
  final double value;
  final List<Color> colors;
  final double height;
  final Color? track;
  const GradientBar({super.key, required this.value, required this.colors, this.height = 10, this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackColor = track ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 1)),
      duration: motion(ref, 1000, context: context),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Container(
        height: height,
        decoration: BoxDecoration(color: trackColor, borderRadius: BorderRadius.circular(height)),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: v,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppGradients.of(colors, begin: Alignment.centerLeft, end: Alignment.centerRight),
              borderRadius: BorderRadius.circular(height),
              boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.35), blurRadius: 8)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatar surrounded by a level-progress ring.
class RingAvatar extends StatelessWidget {
  final String avatarId;
  final double size;
  final double progress;
  final List<Color> colors;
  final Color? track;
  const RingAvatar({
    super.key,
    required this.avatarId,
    required this.progress,
    required this.colors,
    this.size = 96,
    this.track,
  });

  @override
  Widget build(BuildContext context) => ProgressRing(
        value: progress,
        size: size,
        stroke: size * 0.06,
        colors: colors,
        track: track,
        child: Container(
          padding: EdgeInsets.all(size * 0.05),
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
          child: AvatarCircle(avatarId, size: size * 0.76),
        ),
      );
}

/// Seven animated bars: activity of the last days.
class WeekBars extends ConsumerWidget {
  final List<int> values; // oldest → today
  final List<String> labels;
  final List<Color> colors;
  final double height;
  const WeekBars({super.key, required this.values, required this.labels, required this.colors, this.height = 110});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maxValue = values.fold<int>(1, (m, v) => math.max(m, v));
    final muted = mutedOf(context);
    return SizedBox(
      height: height * 1.12 + 46,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (values[i] > 0)
                Text('${values[i]}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: muted)),
              const SizedBox(height: 4),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: values[i] / maxValue),
                duration: motion(ref, 700 + 90 * i, context: context),
                curve: Curves.easeOutBack,
                builder: (context, v, _) => Container(
                  width: 18,
                  height: math.max(6, height * v.clamp(0.0, 1.1)),
                  decoration: BoxDecoration(
                    gradient: values[i] > 0
                        ? AppGradients.of(colors, begin: Alignment.bottomCenter, end: Alignment.topCenter)
                        : null,
                    color: values[i] > 0 ? null : muted.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(labels[i],
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: i == values.length - 1 ? FontWeight.w900 : FontWeight.w600,
                    color: i == values.length - 1 ? colors.last : muted,
                  )),
            ]),
          ),
      ]),
    );
  }
}
