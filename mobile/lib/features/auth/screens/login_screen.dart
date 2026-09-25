import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/ui/ui.dart';
import '../auth_scaffold.dart';
import '../google_sign_in_button.dart';
import '../session_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _login = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final s = ref.read(stringsProvider);
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).login(_login.text.trim(), _password.text);
    } on ApiException catch (e) {
      setState(() => _error = switch (e.statusCode) {
            401 => s['err_login_failed'],
            403 => s['err_blocked'],
            429 => s['err_too_many'],
            _ => e.offline ? s['error_offline'] : s['error_generic'],
          });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return Form(
      key: _form,
      child: AuthScaffold(
        title: s['welcome_back'],
        subtitle: s['login_subtitle'],
        footer: AuthSwitchLink(text: s['no_account'], onTap: () => context.go('/register')),
        children: [
          TextFormField(
            controller: _login,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email, AutofillHints.telephoneNumber],
            decoration: InputDecoration(labelText: s['email_or_phone'], prefixIcon: const Icon(Icons.person_rounded)),
            validator: (v) => (v == null || v.trim().isEmpty) ? s['err_required'] : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: s['password'],
              prefixIcon: const Icon(Icons.lock_rounded),
              suffixIcon: ObscureToggle(obscure: _obscure, onTap: () => setState(() => _obscure = !_obscure)),
            ),
            validator: (v) => (v == null || v.isEmpty) ? s['err_required'] : null,
            onFieldSubmitted: (_) => _submit(),
          ),
          FormError(_error),
          GradientButton(
            label: s['login'],
            icon: Icons.login_rounded,
            loading: _busy,
            colors: brandGradient.take(2).toList(),
            onPressed: _submit,
          ),
          OrDivider(s['or']),
          const GoogleSignInButton(),
        ],
      ),
    );
  }
}
