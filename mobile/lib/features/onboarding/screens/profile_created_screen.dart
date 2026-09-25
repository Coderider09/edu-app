import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ui.dart';
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
    final colors = BranchPalette.of(ref.watch(branchProvider)).gradient;
    return Scaffold(
      body: Stack(children: [
        Positioned.fill(
          child: AuroraBackground(colors: colors),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              const Spacer(),
              FadeSlideIn(
                scale: true,
                duration: const Duration(milliseconds: 800),
                child: Float(
                  child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
                    Pulse(
                      amplitude: 0.06,
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.14)),
                      ),
                    ),
                    RingAvatar(
                      avatarId: profile?.avatarId ?? 'owl',
                      progress: 1,
                      size: 160,
                      colors: const [Colors.white, Color(0xFFFFE08A)],
                      track: Colors.white24,
                    ),
                    const Positioned(
                      right: 12,
                      bottom: 12,
                      child: FadeSlideIn(
                        delay: Duration(milliseconds: 600),
                        scale: true,
                        child: IconBadge(Icons.check_rounded, colors: AppGradients.mint, size: 48),
                      ),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 36),
              FadeSlideIn(
                delay: const Duration(milliseconds: 300),
                child: Text(s['profile_created'],
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
              ),
              if (profile != null) ...[
                const SizedBox(height: 6),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 380),
                  child: Text(profile.name,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9), fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ],
              const SizedBox(height: 12),
              FadeSlideIn(
                delay: const Duration(milliseconds: 450),
                child: Text(s['profile_created_text'],
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 16)),
              ),
              const Spacer(),
              FadeSlideIn(
                delay: const Duration(milliseconds: 650),
                offset: const Offset(0, 30),
                child: Pressable(
                  onTap: () => context.go('/home'),
                  child: Shine(
                    borderRadius: BorderRadius.circular(Radii.md),
                    child: Container(
                      height: 58,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(Radii.md),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8))
                        ],
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(s['lets_go'],
                            style: TextStyle(color: colors.first, fontSize: 17, fontWeight: FontWeight.w900)),
                        const SizedBox(width: 8),
                        Icon(Icons.rocket_launch_rounded, color: colors.first),
                      ]),
                    ),
                  ),
                ),
              ),
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
