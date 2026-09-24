import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/app_theme.dart';
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
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: () => ref.read(sessionProvider.notifier).logout(),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(24), children: [
            Text(s['role_title'],
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(s['role_subtitle'], style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 32),
            _RoleCard(
              title: s['role_abiturient'],
              description: s['role_abiturient_desc'],
              icon: Icons.school_rounded,
              palette: BranchPalette.abiturient,
              delay: 0,
              onTap: () => context.push('/survey/abiturient'),
            ),
            const SizedBox(height: 16),
            _RoleCard(
              title: s['role_schoolboy'],
              description: s['role_schoolboy_desc'],
              icon: Icons.backpack_rounded,
              palette: BranchPalette.schoolboy,
              delay: 120,
              onTap: () => context.push('/survey/schoolboy'),
            ),
            const SizedBox(height: 24),
            Row(children: [
              Icon(Icons.info_outline_rounded, size: 18, color: Theme.of(context).colorScheme.outline),
              const SizedBox(width: 8),
              Expanded(child: Text(s['role_hint'], style: Theme.of(context).textTheme.bodySmall)),
            ]),
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
  final BranchPalette palette;
  final int delay;
  final VoidCallback onTap;
  const _RoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.palette,
    required this.delay,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 500 + delay),
        curve: Curves.easeOutBack,
        builder: (context, v, child) => Opacity(
          opacity: v.clamp(0, 1),
          child: Transform.translate(offset: Offset(0, 40 * (1 - v)), child: child),
        ),
        child: Material(
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(gradient: LinearGradient(colors: palette.gradient)),
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(icon, color: Colors.white, size: 36),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(description, style: TextStyle(color: Colors.white.withValues(alpha: 0.9))),
                    ]),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white),
                ]),
              ),
            ),
          ),
        ),
      );
}
