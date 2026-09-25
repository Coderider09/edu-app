import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';
import 'effects.dart';
import 'pressable.dart';
import 'tokens.dart';

/// Main call-to-action: branch gradient, glow, a light beam passing over it, a spinner while [loading].
class GradientButton extends ConsumerWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final List<Color>? colors;
  final double height;
  final bool shine;
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.colors,
    this.height = 56,
    this.shine = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradient = colors ?? BranchPalette.of(ref.watch(branchProvider)).gradient;
    final enabled = onPressed != null && !loading;
    final radius = BorderRadius.circular(Radii.md);
    return Pressable(
      onTap: enabled ? onPressed : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onPressed == null ? 0.5 : 1,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: AppGradients.of(gradient, begin: Alignment.centerLeft, end: Alignment.centerRight),
            boxShadow: [
              BoxShadow(color: gradient.first.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: Shine(
            enabled: shine && enabled,
            borderRadius: radius,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, a) => ScaleTransition(scale: a, child: FadeTransition(opacity: a, child: child)),
                child: loading
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                      )
                    : Row(key: const ValueKey('label'), mainAxisSize: MainAxisSize.min, children: [
                        if (icon != null) ...[Icon(icon, color: Colors.white, size: 22), const SizedBox(width: 8)],
                        Flexible(
                          child: Text(label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
                        ),
                      ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Secondary action: tinted background in the accent colour.
class SoftButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final double height;
  const SoftButton({super.key, required this.label, required this.onPressed, this.icon, this.color, this.height = 52});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Pressable(
      onTap: onPressed,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: c.withValues(alpha: 0.25)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (icon != null) ...[Icon(icon, color: c, size: 22), const SizedBox(width: 8)],
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: c, fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
    );
  }
}

/// Round translucent icon button for use on gradients and images.
class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool onLight;
  const GlassIconButton({super.key, required this.icon, this.onPressed, this.tooltip, this.onLight = false});

  @override
  Widget build(BuildContext context) {
    final fg = onLight ? Theme.of(context).colorScheme.onSurface : Colors.white;
    final button = Pressable(
      onTap: onPressed,
      pressedScale: 0.88,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onLight ? surfaceOf(context) : Colors.white.withValues(alpha: 0.2),
          border: Border.all(color: onLight ? Colors.transparent : Colors.white.withValues(alpha: 0.3)),
          boxShadow: onLight ? softShadow(context) : null,
        ),
        child: Icon(icon, color: fg, size: 22),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
