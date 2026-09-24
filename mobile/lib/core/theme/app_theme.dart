import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Each branch has its own accent palette so users feel the difference of modes:
/// abiturient — indigo/violet (strict, exam), schoolboy — orange/green (friendly, playful).
enum Branch { neutral, abiturient, schoolboy }

class BranchPalette {
  final Color primary;
  final Color secondary;
  final List<Color> gradient;
  const BranchPalette(this.primary, this.secondary, this.gradient);

  static const neutral = BranchPalette(Color(0xFF3B82F6), Color(0xFF14B8A6), [Color(0xFF3B82F6), Color(0xFF14B8A6)]);
  static const abiturient = BranchPalette(Color(0xFF4F46E5), Color(0xFF7C3AED), [Color(0xFF4F46E5), Color(0xFF7C3AED)]);
  static const schoolboy = BranchPalette(Color(0xFFF97316), Color(0xFF22C55E), [Color(0xFFF97316), Color(0xFFFBBF24)]);

  static BranchPalette of(Branch b) => switch (b) {
        Branch.abiturient => abiturient,
        Branch.schoolboy => schoolboy,
        Branch.neutral => neutral,
      };
}

/// Semantic colours used by test feedback animations.
class AppColors {
  static const correct = Color(0xFF22C55E);
  static const wrong = Color(0xFFEF4444);
  static const gold = Color(0xFFF59E0B);
  static const streak = Color(0xFFFF6B00);
}

class AppTheme {
  static ThemeData light(Branch branch) => _build(branch, Brightness.light);
  static ThemeData dark(Branch branch) => _build(branch, Brightness.dark);

  static ThemeData _build(Branch branch, Brightness brightness) {
    final palette = BranchPalette.of(branch);
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      primary: palette.primary,
      secondary: palette.secondary,
      brightness: brightness,
    );
    final isDark = brightness == Brightness.dark;
    final radius = BorderRadius.circular(16);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? const Color(0xFF0F1115) : const Color(0xFFF6F7FB),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? const Color(0xFF1A1D24) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: radius),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1A1D24) : Colors.white,
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}

/// Active branch drives the palette; set by the session controller.
final branchProvider = StateProvider<Branch>((ref) => Branch.neutral);
