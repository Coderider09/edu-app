import 'package:flutter/cupertino.dart';
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

  static const neutral = BranchPalette(Color(0xFF3B82F6), Color(0xFF14B8A6), [Color(0xFF3B82F6), Color(0xFF06B6D4)]);
  static const abiturient = BranchPalette(Color(0xFF5B4CF0), Color(0xFF9333EA), [Color(0xFF6366F1), Color(0xFFA855F7)]);
  static const schoolboy = BranchPalette(Color(0xFFF97316), Color(0xFF22C55E), [Color(0xFFFB923C), Color(0xFFF43F5E)]);

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
  /// [fontFamily] is for tests (screenshots load Roboto explicitly); the app uses the platform font.
  static ThemeData light(Branch branch, {String? fontFamily}) => _build(branch, Brightness.light, fontFamily);
  static ThemeData dark(Branch branch, {String? fontFamily}) => _build(branch, Brightness.dark, fontFamily);

  static ThemeData _build(Branch branch, Brightness brightness, String? fontFamily) {
    final palette = BranchPalette.of(branch);
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      primary: palette.primary,
      secondary: palette.secondary,
      brightness: brightness,
      surface: isDark ? const Color(0xFF191C24) : Colors.white,
    );
    final surface = isDark ? const Color(0xFF191C24) : Colors.white;
    final radius = BorderRadius.circular(18);
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness, fontFamily: fontFamily);
    final text = base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.8),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.6),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.4),
      titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.4),
    );

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: isDark ? const Color(0xFF0E1016) : const Color(0xFFF4F6FB),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: text.titleLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.w900, color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: radius),
          side: BorderSide(color: scheme.outlineVariant, width: 1.5),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF1F2330) : const Color(0xFFF1F3F9),
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.error, width: 1.5)),
        prefixIconColor: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.focused) ? scheme.primary : scheme.onSurface.withValues(alpha: 0.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide.none,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? palette.primary : null),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? const Color(0xFF2A2F3C) : const Color(0xFF1E2230),
        contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: const Color(0xFF1E2230), borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5), space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: palette.primary),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}

/// Active branch drives the palette; set by the session controller.
final branchProvider = StateProvider<Branch>((ref) => Branch.neutral);
