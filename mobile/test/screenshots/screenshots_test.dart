// Renders the main screens with sample data into PNG files for design review.
//
//   flutter test --tags screenshots --run-skipped --update-goldens
//
// Output: test/screenshots/goldens/*.png (not committed).
@Tags(['screenshots'])
library;

import 'dart:io';

import 'package:eduapp/config/app_config.dart';
import 'package:eduapp/core/l10n/strings.dart';
import 'package:eduapp/core/theme/app_theme.dart';
import 'package:eduapp/features/auth/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart' as fx;
import 'screens.dart';

class _FakeSession extends SessionController {
  @override
  SessionState build() => SessionState(SessionStatus.ready, fx.profile);
}

Future<void> _loadFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  final fonts = Directory('$flutterRoot/bin/cache/artifacts/material_fonts');
  final roboto = FontLoader('Roboto');
  for (final f in fonts.listSync().whereType<File>()) {
    final name = f.uri.pathSegments.last;
    if (name.startsWith('roboto-') && !name.contains('italic')) {
      roboto.addFont(Future.value(ByteData.view(f.readAsBytesSync().buffer)));
    }
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.view(File('${fonts.path}/materialicons-regular.otf').readAsBytesSync().buffer)));
  await icons.load();
  final emoji = File('C:/Windows/Fonts/seguiemj.ttf');
  if (emoji.existsSync()) {
    await (FontLoader('Emoji')..addFont(Future.value(ByteData.view(emoji.readAsBytesSync().buffer)))).load();
  }
}

ThemeData _withFonts(ThemeData t) => t.copyWith(
      textTheme: t.textTheme.apply(fontFamily: 'Roboto', fontFamilyFallback: const ['Emoji']),
      primaryTextTheme: t.primaryTextTheme.apply(fontFamily: 'Roboto', fontFamilyFallback: const ['Emoji']),
      appBarTheme: t.appBarTheme.copyWith(
          titleTextStyle: t.appBarTheme.titleTextStyle?.copyWith(fontFamily: 'Roboto')),
    );

Future<void> shot(
  WidgetTester tester,
  String name,
  Widget screen, {
  List<Override> overrides = const [],
  Branch branch = Branch.abiturient,
  bool dark = false,
  Duration settle = const Duration(milliseconds: 2400),
  double height = 852,
}) async {
  tester.view.physicalSize = Size(1179, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  debugDisableShadows = false; // real blurred shadows, as on a device
  await tester.pumpWidget(ProviderScope(
    overrides: [
      sessionProvider.overrideWith(_FakeSession.new),
      branchProvider.overrideWith((ref) => branch),
      ...overrides,
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _withFonts(AppTheme.light(branch, fontFamily: 'Roboto')),
      darkTheme: _withFonts(AppTheme.dark(branch, fontFamily: 'Roboto')),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: const Locale('ru'),
      supportedLocales: Strings.supportedLocales,
      localizationsDelegates: Strings.delegates,
      home: screen,
    ),
  ));
  for (var i = 0; i < 12; i++) {
    await tester.pump(settle ~/ 12);
  }
  try {
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
  } finally {
    debugDisableShadows = true; // the test binding checks it is restored
  }
}

void main() {
  setUpAll(() async {
    await _loadFonts();
    SharedPreferences.setMockInitialValues({'language': 'ru', 'onboarding_seen': true});
    AppConfig.prefs = await SharedPreferences.getInstance();
    Hive.init(Directory.systemTemp.createTempSync('eduapp_shots').path);
    for (final box in [AppConfig.cacheBox, AppConfig.attemptsBox, AppConfig.packsBox, AppConfig.syncBox]) {
      await Hive.openBox<String>(box);
    }
  });

  for (final screen in screens) {
    testWidgets(screen.name, (tester) async {
      await shot(tester, screen.name, screen.builder(), overrides: screen.overrides, branch: screen.branch,
          dark: screen.dark, height: screen.height);
    });
  }
}
