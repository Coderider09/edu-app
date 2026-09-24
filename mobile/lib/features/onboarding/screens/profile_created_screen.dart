import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/motion.dart';
import '../../../core/widgets/common.dart';
import '../../auth/session_controller.dart';

class ProfileCreatedScreen extends ConsumerStatefulWidget {
  const ProfileCreatedScreen({super.key});

  @override
  ConsumerState<ProfileCreatedScreen> createState() => _ProfileCreatedScreenState();
}

class _ProfileCreatedScreenState extends ConsumerState<ProfileCreatedScreen> {
  final _confetti = ConfettiController(duration: const Duration(seconds: 2));

  @override
  void initState() {
    super.initState();
    if (ref.read(richMotionProvider)) _confetti.play();
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final profile = ref.watch(sessionProvider).profile;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Stack(children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Spacer(),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.elasticOut,
                builder: (context, v, child) => Transform.scale(scale: v, child: child),
                child: Stack(alignment: Alignment.bottomRight, children: [
                  AvatarCircle(profile?.avatarId ?? 'owl', size: 140),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: scheme.primary,
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 28),
                  ),
                ]),
              ),
              const SizedBox(height: 32),
              Text(s['profile_created'],
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text(s['profile_created_text'], style: Theme.of(context).textTheme.bodyLarge),
              const Spacer(),
              FilledButton(onPressed: () => context.go('/home'), child: Text(s['lets_go'])),
            ]),
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 30,
            maxBlastForce: 30,
          ),
        ),
      ]),
    );
  }
}
