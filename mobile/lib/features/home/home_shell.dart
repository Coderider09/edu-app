import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/strings.dart';
import '../../core/ui/ui.dart';

/// Bottom navigation: home, rating, profile — a floating glass bar over the content.
class HomeShell extends ConsumerWidget {
  final StatefulNavigationShell shell;
  const HomeShell({super.key, required this.shell});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        extendBody: true,
        body: shell,
        bottomNavigationBar: AppNavBar(
          index: shell.currentIndex,
          onSelect: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        ),
      );
}

class AppNavBar extends ConsumerWidget {
  final int index;
  final ValueChanged<int> onSelect;
  const AppNavBar({super.key, required this.index, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    return FloatingNavBar(
      index: index,
      onSelect: onSelect,
      items: [
        NavItem(Icons.home_outlined, Icons.home_rounded, s['tab_home']),
        NavItem(Icons.leaderboard_outlined, Icons.leaderboard_rounded, s['tab_rating']),
        NavItem(Icons.person_outline_rounded, Icons.person_rounded, s['tab_profile']),
      ],
    );
  }
}
