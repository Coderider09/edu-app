import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../motion.dart';
import 'pressable.dart';
import 'tokens.dart';

/// The standard card: rounded, soft shadow, press animation when tappable.
class AppCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Gradient? gradient;
  final double radius;
  final Color? shadowColor;
  final BoxBorder? border;
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.gradient,
    this.radius = Radii.lg,
    this.shadowColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? surfaceOf(context)) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: border,
        boxShadow: softShadow(context, color: shadowColor, strength: shadowColor == null ? 1 : 2.5),
      ),
      child: child,
    );
    return onTap == null ? card : Pressable(onTap: onTap, child: card);
  }
}

/// Rounded square with a gradient and a white icon — the app's icon style.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final List<Color> colors;
  final double size;
  final bool glow;
  const IconBadge(this.icon, {super.key, required this.colors, this.size = 48, this.glow = true});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: AppGradients.of(colors),
          borderRadius: BorderRadius.circular(size * 0.32),
          boxShadow: glow
              ? [BoxShadow(color: colors.last.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6))]
              : null,
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.55),
      );
}

/// Section header with an optional action on the right.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const SectionHeader(this.title, {super.key, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 28, bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: TextStyle(color: mutedOf(context), fontSize: 13)),
              ],
            ]),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

/// Small rounded label (level, role, status).
class Pill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? color;
  final bool onDark;
  const Pill(this.text, {super.key, this.icon, this.color, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    final fg = onDark ? Colors.white : c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withValues(alpha: 0.2) : c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: onDark ? Border.all(color: Colors.white.withValues(alpha: 0.25)) : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 4)],
        Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

/// Smoothly switches between children with fade + slight slide (tab contents, states).
class SmoothSwitcher extends ConsumerWidget {
  final Widget child;
  const SmoothSwitcher({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) => AnimatedSwitcher(
        duration: motion(ref, 350, context: context),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [
          ...previous,
          if (current != null) current,
        ]),
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(a),
            child: child,
          ),
        ),
        child: child,
      );
}

/// Friendly empty state: a floating icon badge and a message.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  final List<Color> colors;
  const EmptyState({super.key, required this.icon, required this.text, this.colors = AppGradients.sky});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(children: [
          IconBadge(icon, colors: colors, size: 64),
          const SizedBox(height: 14),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: mutedOf(context), fontSize: 15)),
        ]),
      );
}
