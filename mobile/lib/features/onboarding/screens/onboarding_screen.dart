import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_config.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/settings.dart';

/// Three animated slides explaining what the app does.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _slides = [
    (Icons.emoji_events_rounded, [Color(0xFF4F46E5), Color(0xFF7C3AED)], 1),
    (Icons.menu_book_rounded, [Color(0xFFF97316), Color(0xFFFBBF24)], 2),
    (Icons.local_fire_department_rounded, [Color(0xFF22C55E), Color(0xFF14B8A6)], 3),
  ];

  Future<void> _finish() async {
    await AppConfig.setOnboardingSeen();
    if (mounted) context.go('/register');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final lang = ref.watch(settingsProvider).language;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'tj', label: Text(s['lang_tj'])),
                  ButtonSegment(value: 'ru', label: Text(s['lang_ru'])),
                ],
                selected: {lang},
                showSelectedIcon: false,
                onSelectionChanged: (v) => ref.read(settingsProvider.notifier).setLanguage(v.first),
              ),
              const Spacer(),
              TextButton(onPressed: _finish, child: Text(s['skip'])),
            ]),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) {
                final (icon, colors, n) = _slides[i];
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final page = _controller.hasClients && _controller.position.haveDimensions
                        ? _controller.page ?? 0
                        : 0.0;
                    final delta = (page - i).clamp(-1.0, 1.0);
                    return Opacity(
                      opacity: 1 - delta.abs() * 0.6,
                      child: Transform.translate(offset: Offset(delta * -80, 0), child: child),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      TweenAnimationBuilder<double>(
                        key: ValueKey(i),
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.elasticOut,
                        builder: (context, v, child) => Transform.scale(scale: 0.5 + 0.5 * v, child: child),
                        child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: colors),
                            boxShadow: [BoxShadow(color: colors.first.withValues(alpha: 0.35), blurRadius: 40)],
                          ),
                          child: Icon(icon, size: 100, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 48),
                      Text(s['onb_title_$n'],
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 16),
                      Text(s['onb_text_$n'],
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5)),
                    ]),
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_slides.length, (i) {
              final active = i == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 28 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: active ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: FilledButton(
              onPressed: () {
                if (_page < _slides.length - 1) {
                  _controller.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
                } else {
                  _finish();
                }
              },
              child: Text(_page < _slides.length - 1 ? s['next'] : s['start']),
            ),
          ),
        ]),
      ),
    );
  }
}
