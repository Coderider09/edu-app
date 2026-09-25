import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../config/app_config.dart';
import '../../core/l10n/strings.dart';
import '../../core/ui/ui.dart';
import '../../core/widgets/common.dart';
import 'session_controller.dart';

/// Google sign-in: gets an ID token on the device and exchanges it at /auth/oauth/google.
class GoogleSignInButton extends ConsumerStatefulWidget {
  const GoogleSignInButton({super.key});

  @override
  ConsumerState<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends ConsumerState<GoogleSignInButton> {
  bool _busy = false;

  Future<void> _signIn() async {
    final s = ref.read(stringsProvider);
    setState(() => _busy = true);
    try {
      final google = GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: AppConfig.googleServerClientId.isEmpty ? null : AppConfig.googleServerClientId,
      );
      final account = await google.signIn();
      if (account == null) return; // cancelled
      final idToken = (await account.authentication).idToken;
      if (idToken == null) throw Exception('No ID token');
      await ref.read(sessionProvider.notifier).google(idToken);
    } catch (e) {
      if (mounted) showError(context, s, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return Pressable(
      onTap: _busy ? null : _signIn,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: surfaceOf(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 1.5),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
              : ShaderMask(
                  shaderCallback: (r) => const SweepGradient(colors: [
                    Color(0xFF4285F4),
                    Color(0xFF34A853),
                    Color(0xFFFBBC05),
                    Color(0xFFEA4335),
                    Color(0xFF4285F4),
                  ]).createShader(r),
                  child:
                      const Text('G', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
          const SizedBox(width: 12),
          Text(s['google_sign_in'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
