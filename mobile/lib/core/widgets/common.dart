import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../l10n/strings.dart';
import '../motion.dart';
import '../theme/app_theme.dart';

/// Shimmering placeholder instead of a spinner while content loads.
class Skeleton extends ConsumerStatefulWidget {
  final double height;
  final double? width;
  final double radius;
  const Skeleton({super.key, this.height = 16, this.width, this.radius = 12});

  @override
  ConsumerState<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends ConsumerState<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

  @override
  void initState() {
    super.initState();
    _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF22262E) : const Color(0xFFE7E9EF);
    final highlight = dark ? const Color(0xFF2E333D) : const Color(0xFFF5F6FA);
    final animate = ref.watch(richMotionProvider);
    if (!animate) _c.stop();
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = animate ? _c.value : 0.0;
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + 3 * t - 1, 0),
              end: Alignment(3 * t - 1, 0),
              colors: [base, highlight, base],
            ),
          ),
        );
      },
    );
  }
}

/// A list of skeleton cards for list screens.
class SkeletonList extends StatelessWidget {
  final int count;
  final double itemHeight;
  const SkeletonList({super.key, this.count = 5, this.itemHeight = 84});

  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: const EdgeInsets.all(20),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Skeleton(height: itemHeight, radius: 16),
      );
}

/// Progress bar that fills smoothly instead of jumping.
class AnimatedProgressBar extends ConsumerWidget {
  final double value; // 0..1
  final Color? color;
  final double height;
  const AnimatedProgressBar({super.key, required this.value, this.color, this.height = 8});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1)),
        duration: motion(ref, 900, context: context),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: height,
          backgroundColor: scheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation(color ?? scheme.primary),
        ),
      ),
    );
  }
}

/// Number that counts up to its value.
class CountUp extends ConsumerWidget {
  final int value;
  final TextStyle? style;
  final String suffix;
  const CountUp(this.value, {super.key, this.style, this.suffix = ''});

  @override
  Widget build(BuildContext context, WidgetRef ref) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.toDouble()),
        duration: motion(ref, 1100, context: context),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Text('${v.round()}$suffix', style: style),
      );
}

/// Horizontal shake used for a wrong answer.
class Shake extends StatefulWidget {
  final Widget child;
  final int trigger; // increment to shake
  const Shake({super.key, required this.child, required this.trigger});

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  @override
  void didUpdateWidget(Shake old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger && widget.trigger > 0) _c.forward(from: 0);
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
        builder: (context, child) {
          final dx = math.sin(_c.value * math.pi * 5) * 10 * (1 - _c.value);
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
      );
}

/// "+10" that flies from the answer to the score counter and fades out.
class FlyingPoints extends StatelessWidget {
  final int points;
  final Offset from;
  final Offset to;
  final bool bonus;
  final VoidCallback onDone;
  const FlyingPoints({
    super.key,
    required this.points,
    required this.from,
    required this.to,
    required this.onDone,
    this.bonus = false,
  });

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 850),
        curve: Curves.easeInOutCubic,
        onEnd: onDone,
        builder: (context, t, child) {
          // Arc upwards on the way to the counter
          final p = Offset.lerp(from, to, t)! + Offset(0, -60 * math.sin(t * math.pi));
          return Positioned(
            left: p.dx,
            top: p.dy,
            child: Opacity(
              opacity: t < 0.8 ? 1 : (1 - t) * 5,
              child: Transform.scale(scale: 1 + 0.4 * math.sin(t * math.pi), child: child),
            ),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: Text(
            bonus ? '+$points 🔥' : '+$points',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: bonus ? AppColors.streak : AppColors.correct,
              shadows: const [Shadow(blurRadius: 8, color: Colors.black26)],
            ),
          ),
        ),
      );
}

/// Loading / error / data wrapper with skeletons and a retry button.
class AsyncBody<T> extends ConsumerWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;
  final Widget? loading;
  const AsyncBody({super.key, required this.value, required this.builder, required this.onRetry, this.loading});

  @override
  Widget build(BuildContext context, WidgetRef ref) => value.when(
        data: builder,
        loading: () => loading ?? const SkeletonList(),
        error: (e, _) => ErrorView(error: e, onRetry: onRetry),
        skipLoadingOnRefresh: true,
      );
}

class ErrorView extends ConsumerWidget {
  final Object error;
  final VoidCallback onRetry;
  const ErrorView({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final offline = error is ApiException && (error as ApiException).offline;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded, size: 56,
                color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(offline ? s['error_offline'] : s['error_generic'],
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(s['retry']),
            ),
          ],
        ),
      ),
    );
  }
}

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.gold.withValues(alpha: 0.18),
      child: Row(children: [
        const Icon(Icons.cloud_off_rounded, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(s['offline_cached'], style: const TextStyle(fontSize: 13))),
      ]),
    );
  }
}

/// Ready-made avatar icons (no photo upload in MVP).
const avatarEmoji = {
  'owl': '🦉', 'fox': '🦊', 'cat': '🐱', 'panda': '🐼', 'lion': '🦁', 'rabbit': '🐰',
  'bear': '🐻', 'penguin': '🐧', 'tiger': '🐯', 'koala': '🐨', 'eagle': '🦅', 'dolphin': '🐬',
};

class AvatarCircle extends StatelessWidget {
  final String avatarId;
  final double size;
  const AvatarCircle(this.avatarId, {super.key, this.size = 48});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.primaryContainer,
        ),
        child: Text(avatarEmoji[avatarId] ?? '🦉', style: TextStyle(fontSize: size * 0.55)),
      );
}

/// Icon names coming from the API (admin-editable) mapped to Material icons.
IconData subjectIcon(String? name) => switch (name) {
      'calculate' => Icons.calculate_rounded,
      'bolt' => Icons.bolt_rounded,
      'translate' => Icons.translate_rounded,
      'eco' => Icons.eco_rounded,
      'science' => Icons.science_rounded,
      'account_balance' => Icons.account_balance_rounded,
      'groups' => Icons.groups_rounded,
      'language' => Icons.language_rounded,
      'auto_stories' => Icons.auto_stories_rounded,
      'park' => Icons.park_rounded,
      'engineering' => Icons.engineering_rounded,
      'biotech' => Icons.biotech_rounded,
      'history_edu' => Icons.history_edu_rounded,
      'gavel' => Icons.gavel_rounded,
      'menu_book' => Icons.menu_book_rounded,
      _ => Icons.school_rounded,
    };

IconData achievementIcon(String? name) => switch (name) {
      'flag' => Icons.flag_rounded,
      'fire' => Icons.local_fire_department_rounded,
      'crown' => Icons.workspace_premium_rounded,
      'star' => Icons.star_rounded,
      'graduation' => Icons.school_rounded,
      'trophy' => Icons.emoji_events_rounded,
      'gem' => Icons.diamond_rounded,
      _ => Icons.military_tech_rounded,
    };

Color? parseHexColor(String? hex) {
  if (hex == null || !hex.startsWith('#') || hex.length != 7) return null;
  return Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
}

/// Rounded card with an optional tap ripple.
class TapCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  const TapCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(16), this.color});

  @override
  Widget build(BuildContext context) => Card(
        color: color,
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      );
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 12),
        child: Row(children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
          if (trailing != null) trailing!,
        ]),
      );
}

void showError(BuildContext context, Strings s, Object error) {
  final offline = error is ApiException && error.offline;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(offline ? s['error_offline'] : s['error_generic']),
    behavior: SnackBarBehavior.floating,
  ));
}
