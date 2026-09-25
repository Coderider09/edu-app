import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/ui.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../auth/session_controller.dart';
import 'profile_screen.dart';

/// Bottom sheet to change the name and pick an avatar; the chosen avatar grows into the preview.
Future<void> showEditProfileSheet(BuildContext context, WidgetRef ref, Profile profile) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditProfileSheet(profile: profile),
    );

class _EditProfileSheet extends ConsumerStatefulWidget {
  final Profile profile;
  const _EditProfileSheet({required this.profile});

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  late final _name = TextEditingController(text: widget.profile.name);
  late String _avatar = widget.profile.avatarId;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final s = ref.read(stringsProvider);
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final changes = {
      if (name != widget.profile.name) 'name': name,
      if (_avatar != widget.profile.avatarId) 'avatar_id': _avatar,
    };
    if (changes.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() => _busy = true);
    try {
      final updated = await ref.read(profileRepositoryProvider).update(changes);
      ref.read(sessionProvider.notifier).setProfile(updated);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s['saved'])));
    } catch (e) {
      if (mounted) showError(context, s, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final palette = BranchPalette.of(ref.watch(branchProvider));
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(s['edit_profile'], textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 18),
          Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, a) =>
                  ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.elasticOut), child: child),
              child: RingAvatar(
                key: ValueKey(_avatar),
                avatarId: _avatar,
                progress: 1,
                size: 96,
                colors: palette.gradient,
              ),
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            maxLength: 100,
            decoration: InputDecoration(
              labelText: s['your_name'],
              prefixIcon: const Icon(Icons.person_rounded),
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),
          Text(s['choose_avatar'], style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (final id in avatarEmoji.keys)
                Pressable(
                  pressedScale: 0.85,
                  onTap: () => setState(() => _avatar = id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutBack,
                    padding: EdgeInsets.all(id == _avatar ? 3 : 0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: id == _avatar ? AppGradients.of(palette.gradient) : null,
                    ),
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 250),
                      scale: id == _avatar ? 1 : 0.88,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: surfaceOf(context)),
                        child: AvatarCircle(id, size: 44),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          GradientButton(label: s['save'], icon: Icons.check_rounded, loading: _busy, onPressed: _save),
        ]),
      ),
    );
  }
}

/// Large animated badge with the achievement's description and reward.
Future<void> showAchievementSheet(BuildContext context, AchievementInfo a) => showModalBottomSheet<void>(
      context: context,
      builder: (_) => _AchievementSheet(a: a),
    );

class _AchievementSheet extends ConsumerWidget {
  final AchievementInfo a;
  const _AchievementSheet({required this.a});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final colors = a.unlocked ? achievementColors(a.icon) : AppGradients.silver;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          FadeSlideIn(
            scale: true,
            offset: Offset.zero,
            child: Pulse(
              enabled: a.unlocked,
              amplitude: 0.05,
              child: Shine(
                enabled: a.unlocked,
                borderRadius: BorderRadius.circular(36),
                period: const Duration(milliseconds: 2600),
                child: IconBadge(a.unlocked ? achievementIcon(a.icon) : Icons.lock_rounded, colors: colors, size: 112),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(a.title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
          if (a.description != null) ...[
            const SizedBox(height: 8),
            Text(a.description!, textAlign: TextAlign.center, style: TextStyle(color: mutedOf(context), fontSize: 15)),
          ],
          const SizedBox(height: 16),
          Wrap(spacing: 8, children: [
            Pill(a.unlocked ? s['achievement_unlocked'] : s['achievement_locked'],
                icon: a.unlocked ? Icons.check_circle_rounded : Icons.lock_clock_rounded,
                color: a.unlocked ? AppColors.correct : Theme.of(context).colorScheme.outline),
            if (a.pointsReward > 0)
              Pill(s.f('reward_points', {'n': a.pointsReward}), icon: Icons.star_rounded, color: AppColors.gold),
          ]),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}
