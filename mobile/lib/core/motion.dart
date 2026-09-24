import 'dart:ui';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'settings.dart';

/// Set to true when frames are consistently slow (budget Android devices).
final lowFpsProvider = StateProvider<bool>((ref) => false);

/// Whether rich animations (confetti, flying points, shimmer) should run.
final richMotionProvider = Provider<bool>((ref) {
  final settings = ref.watch(settingsProvider);
  return !settings.reduceMotion && !ref.watch(lowFpsProvider);
});

/// Duration helper: zero when animations are reduced.
Duration motion(WidgetRef ref, int ms, {BuildContext? context}) {
  final disabledBySystem = context != null && MediaQuery.maybeDisableAnimationsOf(context) == true;
  if (disabledBySystem || !ref.read(richMotionProvider)) {
    return Duration(milliseconds: (ms * 0.3).round());
  }
  return Duration(milliseconds: ms);
}

/// Samples frame timings; if most frames miss the 60 fps budget, switches to simplified animations.
class FrameRateMonitor {
  static const _sampleSize = 120;
  static const _slowFrame = Duration(milliseconds: 25);

  static void start(WidgetRef ref) {
    final durations = <Duration>[];
    late TimingsCallback callback;
    callback = (List<FrameTiming> timings) {
      for (final t in timings) {
        durations.add(t.totalSpan);
      }
      if (durations.length < _sampleSize) return;
      final slow = durations.where((d) => d > _slowFrame).length;
      if (slow > durations.length * 0.3) {
        ref.read(lowFpsProvider.notifier).state = true;
      }
      durations.clear();
      if (ref.read(lowFpsProvider)) {
        SchedulerBinding.instance.removeTimingsCallback(callback);
      }
    };
    SchedulerBinding.instance.addTimingsCallback(callback);
  }
}
