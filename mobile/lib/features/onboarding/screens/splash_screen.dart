import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/ui/ui.dart';
import '../../auth/auth_scaffold.dart';
import '../../auth/session_controller.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final session = ref.watch(sessionProvider);
    return Scaffold(
      body: AuroraBackground(
        colors: brandGradient,
        child: SafeArea(
          child: Column(children: [
            const Spacer(flex: 3),
            const FadeSlideIn(scale: true, duration: Duration(milliseconds: 700), child: AppLogo(size: 116)),
            const SizedBox(height: 24),
            FadeSlideIn(
              delay: const Duration(milliseconds: 250),
              child: Shine(
                period: const Duration(seconds: 3),
                borderRadius: BorderRadius.circular(8),
                child: const Text('EduApp',
                    style:
                        TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: -1)),
              ),
            ),
            const SizedBox(height: 8),
            FadeSlideIn(
              delay: const Duration(milliseconds: 400),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(s['app_tagline'],
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 16, height: 1.4)),
              ),
            ),
            const Spacer(flex: 2),
            SmoothSwitcher(
              child: session.status == SessionStatus.error
                  ? Padding(
                      key: const ValueKey('error'),
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(children: [
                        const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 32),
                        const SizedBox(height: 8),
                        Text(s['error_offline'],
                            textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                        const SizedBox(height: 16),
                        SoftButton(
                          label: s['retry'],
                          icon: Icons.refresh_rounded,
                          color: Colors.white,
                          onPressed: () => ref.read(sessionProvider.notifier).restore(),
                        ),
                      ]),
                    )
                  : const _Dots(key: ValueKey('loading')),
            ),
            const SizedBox(height: 56),
          ]),
        ),
      ),
    );
  }
}

/// Three white dots bouncing one after another.
class _Dots extends StatelessWidget {
  const _Dots({super.key});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Float(
              distance: 6,
              period: const Duration(milliseconds: 900),
              phase: i / 3,
              child: Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              ),
            ),
        ],
      );
}
