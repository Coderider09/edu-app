import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/ui/ui.dart';

/// Brand colours shown before the user picks a branch (indigo → orange, both modes in one).
const brandGradient = [Color(0xFF6366F1), Color(0xFFA855F7), Color(0xFFF97316)];

/// The app logo: a rounded white tile with the cap, gently floating.
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 88});

  @override
  Widget build(BuildContext context) => Float(
        distance: 6,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(size * 0.3),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 30, offset: const Offset(0, 12))
            ],
          ),
          child: ShaderMask(
            shaderCallback: (r) => const LinearGradient(colors: brandGradient).createShader(r),
            child: Icon(Icons.school_rounded, size: size * 0.58, color: Colors.white),
          ),
        ),
      );
}

/// Login/registration layout: aurora header with the logo and a form card that overlaps it.
class AuthScaffold extends ConsumerWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? footer;
  const AuthScaffold({super.key, required this.title, required this.subtitle, required this.children, this.footer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final top = MediaQuery.paddingOf(context).top;
    // One Column holds everything: the card is shifted up over the header, and taps
    // only reach it while the shifted area stays inside the same list item.
    return Scaffold(
      body: ListView(padding: EdgeInsets.zero, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          AuroraBackground(
            colors: brandGradient,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, top + 28, 24, 84),
              child: Column(children: [
                const FadeSlideIn(scale: true, child: AppLogo()),
                const SizedBox(height: 18),
                FadeSlideIn(
                  delay: Stagger.of(1, stepMs: 90),
                  child: Text(title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: -0.6)),
                ),
                const SizedBox(height: 6),
                FadeSlideIn(
                  delay: Stagger.of(2, stepMs: 90),
                  child: Text(subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 15, height: 1.4)),
                ),
              ]),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FadeSlideIn(
                delay: Stagger.of(3, stepMs: 90),
                offset: const Offset(0, 40),
                child: AppCard(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  shadowColor: brandGradient.first,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
                ),
              ),
            ),
          ),
          if (footer != null)
            Transform.translate(
              offset: const Offset(0, -44),
              child: FadeSlideIn(delay: Stagger.of(5, stepMs: 90), child: footer!),
            ),
        ]),
      ]),
    );
  }
}

/// Error line that slides in above the submit button.
class FormError extends StatelessWidget {
  final String? error;
  const FormError(this.error, {super.key});

  @override
  Widget build(BuildContext context) => AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: error == null
            ? const SizedBox(height: 20, width: double.infinity)
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: FadeSlideIn(
                  key: ValueKey(error),
                  offset: const Offset(0, -8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.wrong.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_rounded, color: AppColors.wrong, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child:
                            Text(error!, style: const TextStyle(color: AppColors.wrong, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                ),
              ),
      );
}

/// "—— or ——" divider between the form and social sign-in.
class OrDivider extends StatelessWidget {
  final String text;
  const OrDivider(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(text, style: TextStyle(color: mutedOf(context), fontWeight: FontWeight.w600)),
          ),
          const Expanded(child: Divider()),
        ]),
      );
}

/// "No account? Sign up" line under the card.
class AuthSwitchLink extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const AuthSwitchLink({super.key, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) => Center(
        child: Pressable(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(text,
                style:
                    TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ),
      );
}

/// Eye icon that flips with a small rotation when the password visibility changes.
class ObscureToggle extends StatelessWidget {
  final bool obscure;
  final VoidCallback onTap;
  const ObscureToggle({super.key, required this.obscure, required this.onTap});

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onTap,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, a) => RotationTransition(
            turns: Tween(begin: 0.75, end: 1.0).animate(a),
            child: FadeTransition(opacity: a, child: child),
          ),
          child: Icon(obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded, key: ValueKey(obscure)),
        ),
      );
}

/// Four segments that fill up as the password gets longer and more varied.
class PasswordStrength extends StatelessWidget {
  final String password;
  const PasswordStrength(this.password, {super.key});

  int get _score {
    if (password.isEmpty) return 0;
    if (password.length < 8) return 1;
    var score = 1;
    if (password.length >= 12) score++;
    if (RegExp(r'\d').hasMatch(password) && RegExp(r'[A-Za-zА-Яа-я]').hasMatch(password)) score++;
    if (RegExp(r'[^A-Za-zА-Яа-я0-9]').hasMatch(password) || RegExp(r'[A-ZА-Я]').hasMatch(password)) score++;
    return score.clamp(1, 4);
  }

  @override
  Widget build(BuildContext context) {
    final score = _score;
    const colors = [AppColors.wrong, AppColors.gold, Color(0xFF84CC16), AppColors.correct];
    return Row(children: [
      for (var i = 0; i < 4; i++)
        Expanded(
          child: AnimatedContainer(
            duration: Duration(milliseconds: 250 + i * 60),
            curve: Curves.easeOutCubic,
            height: 5,
            margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
            decoration: BoxDecoration(
              color: i < score ? colors[score - 1] : mutedOf(context).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
    ]);
  }
}
