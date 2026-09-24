import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/models.dart';
import '../../data/repositories.dart';
import '../auth/session_controller.dart';

typedef _BoardKey = ({String scope, String period});

final leaderboardProvider = FutureProvider.autoDispose.family<Leaderboard, _BoardKey>(
    (ref, key) => ref.watch(profileRepositoryProvider).leaderboard(scope: key.scope, period: key.period));

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
    final isAbiturient = profile?.isAbiturient ?? false;
    final scopes = isAbiturient
        ? [('cluster', s['scope_cluster']), if (profile?.abiturient?.region != null) ('region', s['scope_region'])]
        : [('grade', s['scope_grade'])];
    final scope = scopes.any((e) => e.$1 == _scope) ? _scope! : scopes.first.$1;
    final key = (scope: scope, period: _period);
    final board = ref.watch(leaderboardProvider(key));

    return Scaffold(
      appBar: AppBar(title: Text(s['rating'])),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(children: [
            Expanded(
              child: SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'week', label: Text(s['week'])),
                  ButtonSegment(value: 'all', label: Text(s['all_time'])),
                ],
                selected: {_period},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => _period = v.first),
              ),
            ),
          ]),
        ),
        if (scopes.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Wrap(spacing: 8, children: [
              for (final (value, label) in scopes)
                ChoiceChip(label: Text(label), selected: scope == value, onSelected: (_) => setState(() => _scope = value)),
            ]),
          ),
        const SizedBox(height: 8),
        Expanded(
          child: AsyncBody<Leaderboard>(
            value: board,
            onRetry: () => ref.invalidate(leaderboardProvider(key)),
            builder: (data) => RefreshIndicator(
              onRefresh: () async => ref.invalidate(leaderboardProvider(key)),
              child: data.entries.isEmpty
                  ? ListView(children: [
                      const SizedBox(height: 80),
                      Center(child: Text(s['rating_empty'])),
                    ])
                  : ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 100), children: [
                      _Podium(entries: data.entries.take(3).toList(), meId: profile?.id),
                      const SizedBox(height: 16),
                      for (final e in data.entries.skip(3))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _Row(entry: e, isMe: e.userId == profile?.id),
                        ),
                    ]),
            ),
          ),
        ),
        // The user's own position is always visible
        if (board.valueOrNull?.me != null)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: _Row(entry: board.valueOrNull!.me!, isMe: true, label: s['you']),
            ),
          ),
      ]),
    );
  }
}

class _Podium extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  final int? meId;
  const _Podium({required this.entries, required this.meId});

  @override
  Widget build(BuildContext context) {
    const heights = [120.0, 90.0, 70.0];
    const medals = [AppColors.gold, Color(0xFFB0BEC5), Color(0xFFCD7F32)];
    // Visual order: 2nd, 1st, 3rd
    final order = [1, 0, 2].where((i) => i < entries.length).toList();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final i in order)
          Expanded(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 500 + 150 * i),
              curve: Curves.easeOutBack,
              builder: (context, v, child) => Transform.translate(offset: Offset(0, 40 * (1 - v)), child: child),
              child: Column(children: [
                AvatarCircle(entries[i].avatarId, size: i == 0 ? 64 : 52),
                const SizedBox(height: 6),
                Text(entries[i].name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: entries[i].userId == meId ? Theme.of(context).colorScheme.primary : null,
                    )),
                Text('${entries[i].points}', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                Container(
                  height: heights[i],
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.topCenter,
                  padding: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    color: medals[i].withValues(alpha: 0.85),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                  child: Text('${i + 1}',
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isMe;
  final String? label;
  const _Row({required this.entry, required this.isMe, this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TapCard(
      color: isMe ? scheme.primaryContainer : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        SizedBox(
          width: 36,
          child: Text('${entry.rank}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        ),
        AvatarCircle(entry.avatarId, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label != null ? '$label · ${entry.name}' : entry.name,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        const Icon(Icons.star_rounded, color: AppColors.gold, size: 18),
        const SizedBox(width: 4),
        Text('${entry.points}', style: const TextStyle(fontWeight: FontWeight.w800)),
      ]),
    );
  }
}
