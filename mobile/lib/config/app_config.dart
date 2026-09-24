import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global configuration and storage handles, initialised once in [main].
class AppConfig {
  /// Android emulator reaches the host machine via 10.0.2.2.
  /// Override: flutter run --dart-define=API_BASE_URL=https://api.example.tj
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080',
  );

  /// OAuth "Web client ID" used as serverClientId so Google returns an ID token.
  static const String googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  /// Task images are served by the API as relative paths ("/static/ntc/...").
  static String mediaUrl(String url) => url.startsWith('/') ? '$apiBaseUrl$url' : url;

  static late final SharedPreferences prefs;
  static const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const cacheBox = 'http_cache';
  static const attemptsBox = 'attempts';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<String>(cacheBox);
    await Hive.openBox<String>(attemptsBox);
    prefs = await SharedPreferences.getInstance();
  }

  static Future<String?> getAccessToken() => secureStorage.read(key: 'access_token');
  static Future<String?> getRefreshToken() => secureStorage.read(key: 'refresh_token');

  static Future<void> saveTokens(String access, String refresh) async {
    await secureStorage.write(key: 'access_token', value: access);
    await secureStorage.write(key: 'refresh_token', value: refresh);
  }

  static Future<void> clearSession() async {
    await secureStorage.delete(key: 'access_token');
    await secureStorage.delete(key: 'refresh_token');
    await Hive.box<String>(cacheBox).clear();
    await Hive.box<String>(attemptsBox).clear();
  }

  static bool get onboardingSeen => prefs.getBool('onboarding_seen') ?? false;
  static Future<void> setOnboardingSeen() => prefs.setBool('onboarding_seen', true);
}
