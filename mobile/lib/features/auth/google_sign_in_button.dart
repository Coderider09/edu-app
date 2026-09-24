import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../config/app_config.dart';
import '../../core/l10n/strings.dart';
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
    return OutlinedButton.icon(
      onPressed: _busy ? null : _signIn,
      icon: _busy
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
          : const Text('G', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF4285F4))),
      label: Text(s['google_sign_in']),
    );
  }
}
