import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/ui/ui.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../auth/session_controller.dart';

typedef _BoardKey = ({String scope, String period});

final leaderboardProvider = FutureProvider.autoDispose.family<Leaderboard, _BoardKey>(
    (ref, key) => ref.watch(profileRepositoryProvider).leaderboard(scope: key.scope, period: key.period));

const _medals = [AppGradients.gold, AppGradients.silver, AppGradients.bronze];

/// Rating among users of the same cluster (abiturient, optionally by region) or grade (schoolboy).
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  String _period = 'week';
  String? _scope;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final profile = ref.watch(sessionProvider).profile;
    final palette = BranchPalette.of(ref.watch(branchProvider));
    final isAbiturient = profile?.isAbiturient ?? false;
    final scopes = isAbiturient
        ? [('cluster', s['scope_cluster']), if (profile?.abiturient?.region != null) ('region', s['scope_region'])]
        : [('grade', s['scope_grade'])];
    final scope = scopes.any((e) => e.$1 == _scope) ? _scope! : scopes.first.$1;
    final key = (scope: scope, period: _period);
    final board = ref.watch(leaderboardProvider(key));
    final me = board.valueOrNull?.me;

    return Scaffold(
      body: Column(children: [
        AuroraBackground(
          colors: palette.gradient,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(s['rating'], style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  const Float(distance: 4, child: Icon(Icons.emoji_events_rounded, color: Color(0xFFFFE08A), size: 32)),
                ]),
                const SizedBox(height: 14),
                _GlassSegments(
                  items: [('week', s['week']), ('all', s['all_time'])],
                  value: _period,
                  onChanged: (v) => setState(() => _period = v),
                ),
                if (scopes.length > 1) ...[
                  const SizedBox(height: 10),
                  _GlassSegments(items: scopes, value: scope, onChanged: (v) => setState(() => _scope = v)),
                ],
              ]),
            ),
          ),
        ),
        Expanded(
          child: AsyncBody<Leaderboard>(
            value: board,
            onRetry: () => ref.invalidate(leaderboardProvider(key)),
            builder: (data) => RefreshIndicator(
              onRefresh: () async => ref.invalidate(leaderboardProvider(key)),
              child: SmoothSwitcher(
                child: data.entries.isEmpty
                    ? ListView(key: ValueKey('empty$key'), children: [
                        EmptyState(icon: Icons.emoji_events_rounded, text: s['rating_empty'], colors: AppGradients.gold),
                      ])
                    : ListView(
                        key: ValueKey(key),
                        padding: EdgeInsets.fromLTRB(20, 20, 20, me != null ? 190 : 120),
                        children: [
                          _Podium(entries: data.entries.take(3).toList(), meId: profile?.id),
                          const SizedBox(height: 20),
                          for (final (i, e) in data.entries.skip(3).indexed)
                            FadeSlideIn(
                              delay: Stagger.of(i, stepMs: 50, startMs: 400),
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _Row(entry: e, isMe: e.userId == profile?.id),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ]),
      // The user's own position is always visible above the navigation bar
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: me == null
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
              child: FadeSlideIn(child: _Row(entry: me, isMe: true, label: s['you'], floating: true)),
            ),
    );
  }
}

/// Segmented control drawn on the gradient header: translucent track, white thumb.
class _GlassSegments extends ConsumerWidget {
  final List<(String, String)> items;
  final String value;
  final ValueChanged<String> onChanged;
  const _GlassSegments({required this.items, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) => SlidingSegments<String>(
        items: items,
        value: value,
        onChanged: onChanged,
        colors: const [Colors.white, Colors.white],
        trackColor: Colors.white.withValues(alpha: 0.18),
        activeText: BranchPalette.of(ref.watch(branchProvider)).primary,
        inactiveText: Colors.white.withValues(alpha: 0.9),
      );
}

class _Podium extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  final int? meId;
  const _Podium({required this.entries, required this.meId});

  @override
  Widget build(BuildContext context) {
    const heights = [132.0, 100.0, 80.0];
    // Visual order: 2nd, 1st, 3rd
    final order = [1, 0, 2].where((i) => i < entries.length).toList();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final i in order)
          Expanded(
            child: FadeSlideIn(
              delay: Duration(milliseconds: [150, 0, 300][i]),
              offset: const Offset(0, 60),
              duration: const Duration(milliseconds: 700),
              child: Column(children: [
                if (i == 0)
                  const Float(
                    distance: 5,
                    child: Icon(Icons.workspace_premium_rounded, color: AppColors.gold, size: 34),
                  ),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppGradients.of(_medals[i]),
                    boxShadow: [BoxShadow(color: _medals[i].last.withValues(alpha: 0.45), blurRadius: 16)],
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(shape: BoxShape.circle, color: surfaceOf(context)),
                    child: AvatarCircle(entries[i].avatarId, size: i == 0 ? 72 : 58),
                  ),
                ),
                const SizedBox(height: 8),
                Text(entries[i].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: entries[i].userId == meId ? Theme.of(context).colorScheme.primary : null,
                    )),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.star_rounded, color: AppColors.gold, size: 16),
                  CountUp(entries[i].points,
                      style: TextStyle(color: mutedOf(context), fontWeight: FontWeight.w800, fontSize: 13)),
                ]),
                const SizedBox(height: 8),
                Container(
                  height: heights[i],
                  margin: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.topCenter,
                  padding: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    gradient: AppGradients.of(_medals[i], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [BoxShadow(color: _medals[i].last.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8))],
                  ),
                  child: Text('${i + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}

class _Row extends ConsumerWidget {
  final LeaderboardEntry entry;
  final bool isMe;
  final String? label;
  final bool floating;
  const _Row({required this.entry, required this.isMe, this.label, this.floating = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = BranchPalette.of(ref.watch(branchProvider));
    final medal = entry.rank >= 1 && entry.rank <= 3 ? _medals[entry.rank - 1] : null;
    final onGradient = isMe && floating;
    final fg = onGradient ? Colors.white : null;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      gradient: onGradient ? AppGradients.of(palette.gradient) : null,
      shadowColor: onGradient ? palette.primary : null,
      border: isMe && !floating ? Border.all(color: palette.primary, width: 2) : null,
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: medal != null ? AppGradients.of(medal) : null,
            color: medal == null ? (onGradient ? Colors.white24 : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06)) : null,
          ),
          child: Text('${entry.rank}',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: medal != null ? Colors.white : fg)),
        ),
        const SizedBox(width: 12),
        AvatarCircle(entry.avatarId, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label != null ? '$label · ${entry.name}' : entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w800, color: fg)),
        ),
        Icon(Icons.star_rounded, color: onGradient ? const Color(0xFFFFE08A) : AppColors.gold, size: 18),
        const SizedBox(width: 4),
        Text('${entry.points}', style: TextStyle(fontWeight: FontWeight.w900, color: fg)),
      ]),
    );
  }
}
