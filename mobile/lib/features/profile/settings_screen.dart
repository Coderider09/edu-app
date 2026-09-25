import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/settings.dart';
import '../../core/widgets/common.dart';
import '../../data/repositories.dart';
import '../auth/session_controller.dart';

/// Language, theme, notifications, animations, roles, logout.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _sync(BuildContext context, WidgetRef ref, Map<String, dynamic> changes) async {
    try {
      final profile = await ref.read(profileRepositoryProvider).update(changes);
      ref.read(sessionProvider.notifier).setProfile(profile);
    } catch (e) {
      if (context.mounted) showError(context, ref.read(stringsProvider), e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final settings = ref.watch(settingsProvider);
    final profile = ref.watch(sessionProvider).profile;
    final lowFps = ref.watch(lowFpsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(s['settings'])),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
        _Group(title: s['language'], children: [
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'tj', label: Text(s['lang_tj'])),
              ButtonSegment(value: 'ru', label: Text(s['lang_ru'])),
            ],
            selected: {settings.language},
            onSelectionChanged: (v) {
              notifier.setLanguage(v.first);
              _sync(context, ref, {'language': v.first});
            },
          ),
        ]),
        _Group(title: s['theme'], children: [
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(value: ThemeMode.system, label: Text(s['theme_system'])),
              ButtonSegment(value: ThemeMode.light, label: Text(s['theme_light'])),
              ButtonSegment(value: ThemeMode.dark, label: Text(s['theme_dark'])),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (v) {
              notifier.setThemeMode(v.first);
              _sync(context, ref, {'theme': settings.copyWith(themeMode: v.first).themeName});
            },
          ),
        ]),
        const SizedBox(height: 8),
        Card(
          child: Column(children: [
            SwitchListTile(
              title: Text(s['notifications']),
              value: settings.notifications,
              onChanged: (v) {
                notifier.setNotifications(v);
                _sync(context, ref, {'notifications_enabled': v});
              },
            ),
            SwitchListTile(
              title: Text(s['reduce_motion']),
              subtitle: Text(s['reduce_motion_desc']),
              value: settings.reduceMotion || lowFps,
              onChanged: (v) {
                notifier.setReduceMotion(v);
                if (!v) ref.read(lowFpsProvider.notifier).state = false;
              },
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.download_for_offline_rounded),
            title: Text(s['offline_materials']),
            subtitle: Text(s['offline_materials_desc']),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push('/downloads'),
          ),
        ),
        if (profile != null) ...[
          SectionTitle(s['roles']),
          Card(
            child: Column(children: [
              for (final role in profile.roles)
                RadioListTile<String>(
                  value: role,
                  groupValue: profile.activeRole,
                  title: Text(s['role_name_$role']),
                  subtitle: role == profile.activeRole ? Text(s['active_role']) : null,
                  onChanged: (v) async {
                    if (v == null) return;
                    await _sync(context, ref, {'active_role': v});
                    if (context.mounted) context.go('/home');
                  },
                ),
              if (profile.activeRole != null)
                ListTile(
                  leading: const Icon(Icons.edit_note_rounded),
                  title: Text(s['edit_survey']),
                  onTap: () => context.push('/survey/${profile.activeRole}?mode=edit'),
                ),
              for (final role in ['abiturient', 'schoolboy'].where((r) => !profile.hasRole(r)))
                ListTile(
                  leading: const Icon(Icons.add_circle_outline_rounded),
                  title: Text(s['add_role_$role']),
                  onTap: () => context.push('/survey/$role?mode=add'),
                ),
            ]),
          ),
        ],
        const SizedBox(height: 24),
        OutlinedButton.icon(
          icon: const Icon(Icons.logout_rounded),
          label: Text(s['logout']),
          style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                content: Text(s['logout_confirm']),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s['cancel'])),
                  FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(s['logout'])),
                ],
              ),
            );
            if (ok == true) await ref.read(sessionProvider.notifier).logout();
          },
        ),
      ]),
    );
  }
}

class _Group extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Group({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...children,
        ]),
      );
}
