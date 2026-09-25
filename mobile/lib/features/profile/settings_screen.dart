import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/motion.dart';
import '../../core/settings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/ui.dart';
import '../../core/widgets/common.dart';
import '../../data/repositories.dart';
import '../auth/session_controller.dart';
import 'profile_sheets.dart';

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

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final s = ref.read(stringsProvider);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const IconBadge(Icons.logout_rounded, colors: AppGradients.rose, size: 56),
        content: Text(s['logout_confirm'], textAlign: TextAlign.center, style: const TextStyle(fontSize: 17)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s['cancel'])),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.wrong, minimumSize: const Size(120, 48)),
            onPressed: () => Navigator.pop(context, true),
            child: Text(s['logout']),
          ),
        ],
      ),
    );
    if (ok == true) await ref.read(sessionProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final settings = ref.watch(settingsProvider);
    final profile = ref.watch(sessionProvider).profile;
    final lowFps = ref.watch(lowFpsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final palette = BranchPalette.of(ref.watch(branchProvider));

    var n = 0;
    Widget item(Widget child) => FadeSlideIn(delay: Stagger.of(n++, stepMs: 60), child: child);

    return Scaffold(
      appBar: AppBar(title: Text(s['settings'])),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), children: [
        if (profile != null)
          item(AppCard(
            onTap: () => showEditProfileSheet(context, ref, profile),
            gradient: AppGradients.of(palette.gradient),
            shadowColor: palette.primary,
            child: Row(children: [
              Hero(
                tag: 'avatar',
                child: RingAvatar(
                  avatarId: profile.avatarId,
                  progress: profile.level.progress,
                  size: 64,
                  colors: const [Color(0xFFFFE08A), Colors.white],
                  track: Colors.white.withValues(alpha: 0.25),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900)),
                  if (profile.email ?? profile.phone case final contact?)
                    Text(contact,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
                ]),
              ),
              const GlassIconButton(icon: Icons.edit_rounded),
            ]),
          )),
        item(SectionHeader(s['language'])),
        item(SlidingSegments<String>(
          items: [('tj', s['lang_tj']), ('ru', s['lang_ru'])],
          value: settings.language,
          onChanged: (v) {
            notifier.setLanguage(v);
            _sync(context, ref, {'language': v});
          },
        )),
        item(SectionHeader(s['theme'])),
        item(SlidingSegments<ThemeMode>(
          items: [
            (ThemeMode.system, s['theme_system']),
            (ThemeMode.light, s['theme_light']),
            (ThemeMode.dark, s['theme_dark']),
          ],
          value: settings.themeMode,
          onChanged: (v) {
            notifier.setThemeMode(v);
            _sync(context, ref, {'theme': settings.copyWith(themeMode: v).themeName});
          },
        )),
        const SizedBox(height: 20),
        item(_Group(children: [
          _Tile(
            icon: Icons.notifications_rounded,
            colors: AppGradients.gold,
            title: s['notifications'],
            trailing: Switch(
              value: settings.notifications,
              onChanged: (v) {
                notifier.setNotifications(v);
                _sync(context, ref, {'notifications_enabled': v});
              },
            ),
          ),
          _Tile(
            icon: Icons.animation_rounded,
            colors: AppGradients.violet,
            title: s['reduce_motion'],
            subtitle: s['reduce_motion_desc'],
            trailing: Switch(
              value: settings.reduceMotion || lowFps,
              onChanged: (v) {
                notifier.setReduceMotion(v);
                if (!v) ref.read(lowFpsProvider.notifier).state = false;
              },
            ),
          ),
          _Tile(
            icon: Icons.download_for_offline_rounded,
            colors: AppGradients.mint,
            title: s['offline_materials'],
            subtitle: s['offline_materials_desc'],
            onTap: () => context.push('/downloads'),
          ),
        ])),
        if (profile != null) ...[
          item(SectionHeader(s['roles'])),
          item(_Group(children: [
            for (final role in profile.roles)
              _Tile(
                icon: role == 'abiturient' ? Icons.school_rounded : Icons.backpack_rounded,
                colors: role == 'abiturient' ? BranchPalette.abiturient.gradient : BranchPalette.schoolboy.gradient,
                title: s['role_name_$role'],
                subtitle: role == profile.activeRole ? s['active_role'] : null,
                trailing: _Check(selected: role == profile.activeRole),
                onTap: role == profile.activeRole
                    ? null
                    : () async {
                        await _sync(context, ref, {'active_role': role});
                        if (context.mounted) context.go('/home');
                      },
              ),
            if (profile.activeRole != null)
              _Tile(
                icon: Icons.edit_note_rounded,
                colors: AppGradients.sky,
                title: s['edit_survey'],
                onTap: () => context.push('/survey/${profile.activeRole}?mode=edit'),
              ),
            for (final role in ['abiturient', 'schoolboy'].where((r) => !profile.hasRole(r)))
              _Tile(
                icon: Icons.add_rounded,
                colors: AppGradients.mint,
                title: s['add_role_$role'],
                onTap: () => context.push('/survey/$role?mode=add'),
              ),
          ])),
        ],
        const SizedBox(height: 28),
        item(SoftButton(
          label: s['logout'],
          icon: Icons.logout_rounded,
          color: AppColors.wrong,
          onPressed: () => _logout(context, ref),
        )),
      ]),
    );
  }
}

/// Card with tiles separated by thin dividers.
class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0) const Divider(indent: 72, endIndent: 16),
            child,
          ],
        ]),
      );
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final List<Color> colors;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const _Tile({required this.icon, required this.colors, required this.title, this.subtitle, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(children: [
        IconBadge(icon, colors: colors, size: 42, glow: false),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
            if (subtitle != null)
              Text(subtitle!, style: TextStyle(color: mutedOf(context), fontSize: 12.5, height: 1.3)),
          ]),
        ),
        const SizedBox(width: 8),
        trailing ?? (onTap != null ? Icon(Icons.arrow_forward_ios_rounded, size: 16, color: mutedOf(context)) : const SizedBox()),
      ]),
    );
    return onTap == null ? row : Pressable(onTap: onTap, pressedScale: 0.98, child: row);
  }
}

/// Animated round check mark for the active role.
class _Check extends ConsumerWidget {
  final bool selected;
  const _Check({required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = BranchPalette.of(ref.watch(branchProvider));
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: selected ? AppGradients.of(palette.gradient) : null,
        border: selected ? null : Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 2),
      ),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 300),
        curve: Curves.elasticOut,
        scale: selected ? 1 : 0,
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
      ),
    );
  }
}
