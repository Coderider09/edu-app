import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ui.dart';
import '../../auth/session_controller.dart';

/// Mandatory role selection right after registration (cannot be skipped).
class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GlassIconButton(
                icon: Icons.logout_rounded,
                onLight: true,
                tooltip: s['logout'],
                onPressed: () => ref.read(sessionProvider.notifier).logout(),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), children: [
            FadeSlideIn(
              child: Text(s['role_title'],
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 8),
            FadeSlideIn(
              delay: Stagger.of(1),
              child: Text(s['role_subtitle'],
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: mutedOf(context))),
            ),
            const SizedBox(height: 28),
            FadeSlideIn(
              delay: Stagger.of(2, stepMs: 100),
              offset: const Offset(0, 40),
              child: _RoleCard(
                title: s['role_abiturient'],
                description: s['role_abiturient_desc'],
                icon: Icons.school_rounded,
                decor: const [Icons.timer_rounded, Icons.emoji_events_rounded],
                palette: BranchPalette.abiturient,
                onTap: () => context.push('/survey/abiturient'),
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: Stagger.of(3, stepMs: 100),
              offset: const Offset(0, 40),
              child: _RoleCard(
                title: s['role_schoolboy'],
                description: s['role_schoolboy_desc'],
                icon: Icons.backpack_rounded,
                decor: const [Icons.menu_book_rounded, Icons.star_rounded],
                palette: BranchPalette.schoolboy,
                onTap: () => context.push('/survey/schoolboy'),
              ),
            ),
            const SizedBox(height: 24),
            FadeSlideIn(
              delay: Stagger.of(5, stepMs: 100),
              child: AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  const IconBadge(Icons.info_rounded, colors: AppGradients.sky, size: 36, glow: false),
                  const SizedBox(width: 12),
                  Expanded(child: Text(s['role_hint'], style: Theme.of(context).textTheme.bodyMedium)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final List<IconData> decor;
  final BranchPalette palette;
  final VoidCallback onTap;
  const _RoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.decor,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: Container(
          height: 190,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.xl),
            boxShadow: [
              BoxShadow(
                  color: palette.gradient.first.withValues(alpha: 0.4), blurRadius: 28, offset: const Offset(0, 14)),
            ],
          ),
          child: AuroraBackground(
            colors: palette.gradient,
            borderRadius: BorderRadius.circular(Radii.xl),
            child: Shine(
              borderRadius: BorderRadius.circular(Radii.xl),
              period: const Duration(milliseconds: 4200),
              child: Stack(children: [
                // Big faded icons in the corner
                Positioned(
                  right: -18,
                  bottom: -24,
                  child: Icon(icon, size: 150, color: Colors.white.withValues(alpha: 0.14)),
                ),
                for (var k = 0; k < decor.length; k++)
                  Positioned(
                    right: 24 + k * 54.0,
                    top: 22 + k * 8.0,
                    child: Float(
                      distance: 5,
                      phase: k / 2,
                      child: Icon(decor[k], size: 26, color: Colors.white.withValues(alpha: 0.55)),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                      ),
                      child: Icon(icon, color: Colors.white, size: 30),
                    ),
                    const Spacer(),
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Expanded(
                        child: Text(description,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), height: 1.3)),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: Icon(Icons.arrow_forward_rounded, color: palette.primary),
                      ),
                    ]),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      );
}
