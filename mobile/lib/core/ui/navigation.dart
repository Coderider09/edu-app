import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../motion.dart';
import '../theme/app_theme.dart';
import 'tokens.dart';

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const NavItem(this.icon, this.activeIcon, this.label);
}

/// Floating frosted-glass bottom bar: a gradient pill slides to the selected tab, its icon pops.
class FloatingNavBar extends ConsumerWidget {
  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onSelect;
  const FloatingNavBar({super.key, required this.items, required this.index, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = BranchPalette.of(ref.watch(branchProvider));
    final dark = Theme.of(context).brightness == Brightness.dark;
    final duration = motion(ref, 420, context: context);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.xl),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 68,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: (dark ? const Color(0xFF1B1F29) : Colors.white).withValues(alpha: dark ? 0.82 : 0.86),
                borderRadius: BorderRadius.circular(Radii.xl),
                border: Border.all(color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.06)),
                boxShadow: softShadow(context, strength: 1.4),
              ),
              child: LayoutBuilder(builder: (context, box) {
                final width = box.maxWidth / items.length;
                return Stack(children: [
                  AnimatedPositioned(
                    duration: duration,
                    curve: Curves.easeOutBack,
                    left: width * index,
                    top: 0,
                    bottom: 0,
                    width: width,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppGradients.of(palette.gradient),
                        borderRadius: BorderRadius.circular(Radii.xl - 6),
                        boxShadow: [
                          BoxShadow(
                              color: palette.primary.withValues(alpha: 0.4),
                              blurRadius: 14,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Row(children: [
                      for (var i = 0; i < items.length; i++)
                        Expanded(
                          child: _NavButton(
                            item: items[i],
                            selected: i == index,
                            duration: duration,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onSelect(i);
                            },
                          ),
                        ),
                    ]),
                  ),
                ]);
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final Duration duration;
  final VoidCallback onTap;
  const _NavButton({required this.item, required this.selected, required this.duration, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final muted = mutedOf(context);
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 1, end: selected ? 1.15 : 1),
            duration: duration,
            curve: Curves.elasticOut,
            builder: (context, v, child) => Transform.scale(scale: v, child: child),
            child: Icon(selected ? item.activeIcon : item.icon, color: selected ? Colors.white : muted, size: 24),
          ),
          AnimatedSize(
            duration: duration,
            curve: Curves.easeOutCubic,
            child: selected
                ? Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(item.label,
                        maxLines: 1,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                  )
                : const SizedBox.shrink(),
          ),
        ]),
      ),
    );
  }
}

/// Segmented control with a sliding thumb (periods, tabs, language, theme).
class SlidingSegments<T> extends ConsumerWidget {
  final List<(T, String)> items;
  final T value;
  final ValueChanged<T> onChanged;
  final List<Color>? colors; // thumb gradient
  final Color? trackColor;
  final Color? activeText;
  final Color? inactiveText;
  const SlidingSegments({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.colors,
    this.trackColor,
    this.activeText,
    this.inactiveText,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gradient = colors ?? BranchPalette.of(ref.watch(branchProvider)).gradient;
    final index = items.indexWhere((e) => e.$1 == value).clamp(0, items.length - 1);
    final duration = motion(ref, 380, context: context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: trackColor ?? (dark ? const Color(0xFF232733) : const Color(0xFFE9ECF3)),
        borderRadius: BorderRadius.circular(Radii.md),
      ),
      child: LayoutBuilder(builder: (context, box) {
        final width = box.maxWidth / items.length;
        return Stack(children: [
          AnimatedPositioned(
            duration: duration,
            curve: Curves.easeOutCubic,
            left: width * index,
            top: 0,
            bottom: 0,
            width: width,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppGradients.of(gradient),
                borderRadius: BorderRadius.circular(Radii.md - 4),
                boxShadow: [BoxShadow(color: gradient.first.withValues(alpha: 0.35), blurRadius: 10)],
              ),
            ),
          ),
          Positioned.fill(
            child: Row(children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onChanged(items[i].$1);
                    },
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: duration,
                        style: DefaultTextStyle.of(context).style.merge(TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: i == index
                                  ? (activeText ?? Colors.white)
                                  : (inactiveText ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65)),
                            )),
                        child: Text(items[i].$2, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ]);
      }),
    );
  }
}
