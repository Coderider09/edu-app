import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../motion.dart';

/// Fades and slides a widget in once, after [delay]. Use [Stagger.of] for lists: each item comes a bit later.
class FadeSlideIn extends ConsumerStatefulWidget {
  final Widget child;
  final Duration delay;
  final Offset offset; // start offset in logical pixels
  final Duration duration;
  final bool scale;
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 24),
    this.duration = const Duration(milliseconds: 520),
    this.scale = false,
  });

  @override
  ConsumerState<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends ConsumerState<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.duration);
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    if (!ref.read(richMotionProvider)) {
      _c.value = 1;
    } else if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _t,
        child: widget.child,
        builder: (context, child) {
          final v = _t.value;
          Widget out = Transform.translate(offset: widget.offset * (1 - v), child: child);
          if (widget.scale) out = Transform.scale(scale: 0.9 + 0.1 * v, child: out);
          return Opacity(opacity: v.clamp(0, 1), child: out);
        },
      );
}

/// Delays for staggered lists: the n-th item appears [step] after the previous one, up to [max].
class Stagger {
  static Duration of(int index, {int stepMs = 60, int startMs = 0, int maxMs = 700}) =>
      Duration(milliseconds: (startMs + index * stepMs).clamp(0, maxMs));
}
