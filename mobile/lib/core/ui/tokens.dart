import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Spacing, radii and shadows shared by all screens.
class Gap {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
  static const page = EdgeInsets.fromLTRB(20, 8, 20, 120); // bottom: room for the floating navigation bar
}

class Radii {
  static const sm = 12.0;
  static const md = 18.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

/// Gradients of the app: the branch gradient plus a few accents for icons and badges.
class AppGradients {
  static LinearGradient of(List<Color> colors, {AlignmentGeometry begin = Alignment.topLeft,
      AlignmentGeometry end = Alignment.bottomRight}) =>
      LinearGradient(colors: colors, begin: begin, end: end);

  static LinearGradient branch(Branch b) => of(BranchPalette.of(b).gradient);

  static const fire = [Color(0xFFFF9A3C), Color(0xFFFF4D4D)];
  static const gold = [Color(0xFFFFD35C), Color(0xFFF59E0B)];
  static const mint = [Color(0xFF34D399), Color(0xFF059669)];
  static const sky = [Color(0xFF60A5FA), Color(0xFF6366F1)];
  static const rose = [Color(0xFFFB7185), Color(0xFFE11D48)];
  static const violet = [Color(0xFFA78BFA), Color(0xFF7C3AED)];
  static const silver = [Color(0xFFE2E8F0), Color(0xFF94A3B8)];
  static const bronze = [Color(0xFFF3B27A), Color(0xFFB45309)];

  /// A two-colour gradient derived from one colour (for subjects with an admin-defined colour).
  static List<Color> fromColor(Color c) {
    final hsl = HSLColor.fromColor(c);
    return [
      hsl.withLightness((hsl.lightness + 0.12).clamp(0, 1)).withHue((hsl.hue + 12) % 360).toColor(),
      hsl.withLightness((hsl.lightness - 0.06).clamp(0, 1)).toColor(),
    ];
  }
}

/// Soft coloured shadow under cards and buttons.
List<BoxShadow> softShadow(BuildContext context, {Color? color, double strength = 1}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final base = color ?? (dark ? Colors.black : const Color(0xFF1E293B));
  return [
    BoxShadow(
      color: base.withValues(alpha: (dark ? 0.35 : 0.08) * strength),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: base.withValues(alpha: (dark ? 0.2 : 0.04) * strength),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];
}

/// Colour of a card surface (white / dark grey).
Color surfaceOf(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0xFF191C24) : Colors.white;

/// Colour for secondary text.
Color mutedOf(BuildContext context) => Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
