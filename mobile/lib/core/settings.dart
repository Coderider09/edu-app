import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';

/// Local UI settings (persisted); language/theme are also synced to the profile on the server.
class AppSettings {
  final String language; // 'tj' | 'ru'
  final ThemeMode themeMode;
  final bool reduceMotion; // manual switch; low FPS also enables it automatically
  final bool notifications;

  const AppSettings({
    required this.language,
    required this.themeMode,
    required this.reduceMotion,
    required this.notifications,
  });

  /// Material widgets have no Tajik localization, so they use Russian;
  /// app strings follow [language] (see Strings).
  Locale get locale => const Locale('ru');

  String get themeName => switch (themeMode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };

  AppSettings copyWith({String? language, ThemeMode? themeMode, bool? reduceMotion, bool? notifications}) =>
      AppSettings(
        language: language ?? this.language,
        themeMode: themeMode ?? this.themeMode,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        notifications: notifications ?? this.notifications,
      );
}

ThemeMode themeModeFromName(String? name) => switch (name) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final p = AppConfig.prefs;
    return AppSettings(
      language: p.getString('language') ?? 'tj',
      themeMode: themeModeFromName(p.getString('theme')),
      reduceMotion: p.getBool('reduce_motion') ?? false,
      notifications: p.getBool('notifications') ?? true,
    );
  }

  Future<void> setLanguage(String lang) async {
    state = state.copyWith(language: lang);
    await AppConfig.prefs.setString('language', lang);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await AppConfig.prefs.setString('theme', state.themeName);
  }

  Future<void> setReduceMotion(bool value) async {
    state = state.copyWith(reduceMotion: value);
    await AppConfig.prefs.setBool('reduce_motion', value);
  }

  Future<void> setNotifications(bool value) async {
    state = state.copyWith(notifications: value);
    await AppConfig.prefs.setBool('notifications', value);
  }

  /// Apply values stored in the server profile (e.g. after login on a new device).
  Future<void> applyFromProfile({required String language, required String theme, required bool notifications}) async {
    await setLanguage(language);
    await setThemeMode(themeModeFromName(theme));
    await setNotifications(notifications);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
