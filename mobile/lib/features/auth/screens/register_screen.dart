import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_client.dart';
import '../../../core/l10n/strings.dart';
import '../../../core/ui/ui.dart';
import '../auth_scaffold.dart';
import '../google_sign_in_button.dart';
import '../session_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password]) {
      c.dispose();
    }
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
      await ref.read(sessionProvider.notifier).register(
            name: _name.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.trim(),
            password: _password.text,
          );
      // Router moves on to the mandatory role selection
    } on ApiException catch (e) {
      setState(() => _error = switch (e.statusCode) {
            409 => s['err_exists'],
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
        title: s['create_account'],
        subtitle: s['register_subtitle'],
        footer: AuthSwitchLink(text: s['have_account'], onTap: () => context.go('/login')),
        children: [
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: s['name'], prefixIcon: const Icon(Icons.badge_rounded)),
            validator: (v) => (v == null || v.trim().isEmpty) ? s['err_required'] : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: s['email'], prefixIcon: const Icon(Icons.email_rounded)),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return _phone.text.trim().isEmpty ? s['err_required'] : null;
              return _emailRe.hasMatch(value) ? null : s['err_email'];
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: s['phone_optional'],
              hintText: '+992 ...',
              prefixIcon: const Icon(Icons.phone_rounded),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: s['password'],
              prefixIcon: const Icon(Icons.lock_rounded),
              suffixIcon: ObscureToggle(obscure: _obscure, onTap: () => setState(() => _obscure = !_obscure)),
            ),
            validator: (v) => (v ?? '').length < 8 ? s['err_password_short'] : null,
            onFieldSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 10),
          PasswordStrength(_password.text),
          FormError(_error),
          GradientButton(
            label: s['register'],
            icon: Icons.rocket_launch_rounded,
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
