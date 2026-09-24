import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/app_config.dart';
import 'config/router.dart';
import 'core/l10n/strings.dart';
import 'core/motion.dart';
import 'core/settings.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.init();
  runApp(const ProviderScope(child: EduApp()));
}

class EduApp extends ConsumerStatefulWidget {
  const EduApp({super.key});

  @override
  ConsumerState<EduApp> createState() => _EduAppState();
}

class _EduAppState extends ConsumerState<EduApp> {
  @override
  void initState() {
    super.initState();
    // Detect slow devices (2 GB RAM phones) and degrade animations automatically
    FrameRateMonitor.start(ref);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final settings = ref.watch(settingsProvider);
    final branch = ref.watch(branchProvider);

    return MaterialApp.router(
      title: 'EduApp',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(branch),
      darkTheme: AppTheme.dark(branch),
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: Strings.supportedLocales,
      localizationsDelegates: Strings.delegates,
      routerConfig: router,
    );
  }
}
