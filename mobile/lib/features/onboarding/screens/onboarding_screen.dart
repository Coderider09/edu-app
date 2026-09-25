import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_config.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/settings.dart';
import '../../../core/ui/ui.dart';

/// Three animated slides explaining what the app does.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _Slide {
  final IconData icon;
  final List<Color> colors;
  final List<IconData> satellites; // small icons floating around the illustration
  const _Slide(this.icon, this.colors, this.satellites);
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _slides = [
    _Slide(Icons.emoji_events_rounded, [Color(0xFF6366F1), Color(0xFFA855F7)],
        [Icons.star_rounded, Icons.timer_rounded, Icons.check_circle_rounded]),
    _Slide(Icons.menu_book_rounded, [Color(0xFFFB923C), Color(0xFFF43F5E)],
        [Icons.calculate_rounded, Icons.science_rounded, Icons.translate_rounded]),
    _Slide(Icons.local_fire_department_rounded, [Color(0xFF10B981), Color(0xFF06B6D4)],
        [Icons.military_tech_rounded, Icons.leaderboard_rounded, Icons.bolt_rounded]),
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
    final slide = _slides[_page];
    final last = _page == _slides.length - 1;
    return Scaffold(
      body: Stack(children: [
        // Background tint follows the current slide.
        Positioned.fill(
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: slide.colors.first),
            duration: const Duration(milliseconds: 500),
            builder: (context, c, _) => DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [c!.withValues(alpha: 0.16), Theme.of(context).scaffoldBackgroundColor],
                  stops: const [0, 0.7],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
              child: Row(children: [
                SizedBox(
                  width: 150,
                  child: SlidingSegments<String>(
                    items: [('tj', s['lang_tj']), ('ru', s['lang_ru'])],
                    value: lang,
                    colors: slide.colors,
                    onChanged: (v) => ref.read(settingsProvider.notifier).setLanguage(v),
                  ),
                ),
                const Spacer(),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: last ? 0 : 1,
                  child: Pressable(
                    onTap: last ? null : _finish,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: surfaceOf(context).withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(s['skip'], style: TextStyle(color: mutedOf(context), fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              ]),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final page =
                        _controller.hasClients && _controller.position.haveDimensions ? _controller.page ?? 0 : 0.0;
                    final delta = (page - i).clamp(-1.0, 1.0);
                    return Opacity(
                      opacity: 1 - delta.abs() * 0.7,
                      child: Transform.translate(offset: Offset(delta * -120, 0), child: child),
                    );
                  },
                  child: _SlideView(slide: _slides[i], title: s['onb_title_${i + 1}'], text: s['onb_text_${i + 1}']),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                final active = i == _page;
                return GestureDetector(
                  onTap: () => _controller.animateToPage(i,
                      duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 32 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: active ? AppGradients.of(slide.colors) : null,
                      color: active ? null : mutedOf(context).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: GradientButton(
                label: last ? s['start'] : s['next'],
                icon: last ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
                colors: slide.colors,
                shine: last,
                onPressed: () {
                  if (!last) {
                    _controller.nextPage(duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
                  } else {
                    _finish();
                  }
                },
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  final String title;
  final String text;
  const _SlideView({required this.slide, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    // Satellites sit on a circle around the main illustration.
    const spots = [Alignment(-0.95, -0.7), Alignment(0.95, -0.35), Alignment(-0.7, 0.95)];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(
          width: 280,
          height: 280,
          child: Stack(alignment: Alignment.center, children: [
            // Soft rings
            for (final (size, alpha) in const [(270.0, 0.08), (220.0, 0.12)])
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(shape: BoxShape.circle, color: slide.colors.last.withValues(alpha: alpha)),
              ),
            FadeSlideIn(
              scale: true,
              duration: const Duration(milliseconds: 700),
              child: Float(
                child: Container(
                  width: 168,
                  height: 168,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppGradients.of(slide.colors),
                    boxShadow: [
                      BoxShadow(
                          color: slide.colors.first.withValues(alpha: 0.45),
                          blurRadius: 40,
                          offset: const Offset(0, 18)),
                    ],
                  ),
                  child: Icon(slide.icon, size: 84, color: Colors.white),
                ),
              ),
            ),
            for (var k = 0; k < slide.satellites.length; k++)
              Align(
                alignment: spots[k],
                child: FadeSlideIn(
                  delay: Stagger.of(k + 2, stepMs: 120),
                  scale: true,
                  child: Float(
                    distance: 5,
                    phase: k / 3,
                    period: Duration(milliseconds: 2200 + k * 300),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: surfaceOf(context),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: softShadow(context, color: slide.colors.first),
                      ),
                      child: Icon(slide.satellites[k], color: slide.colors[k % 2], size: 28),
                    ),
                  ),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 40),
        FadeSlideIn(
          delay: const Duration(milliseconds: 150),
          child: Text(title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 14),
        FadeSlideIn(
          delay: const Duration(milliseconds: 250),
          child: Text(text,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: mutedOf(context), height: 1.5)),
        ),
      ]),
    );
  }
}
