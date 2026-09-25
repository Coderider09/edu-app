import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/settings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/ui/ui.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models.dart';
import '../../../data/repositories.dart';
import '../../auth/session_controller.dart';

/// first — right after registration; add — second role from settings; edit — change the questionnaire.
enum SurveyMode { first, add, edit }

final clustersProvider = FutureProvider.autoDispose<List<Cluster>>(
    (ref) => ref.watch(contentRepositoryProvider).clusters(ref.watch(settingsProvider).language));
final regionsProvider =
    FutureProvider.autoDispose<List<Region>>((ref) => ref.watch(contentRepositoryProvider).regions());

class SurveyScreen extends ConsumerStatefulWidget {
  final String role; // 'abiturient' | 'schoolboy'
  final SurveyMode mode;
  const SurveyScreen({super.key, required this.role, this.mode = SurveyMode.first});

  @override
  ConsumerState<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends ConsumerState<SurveyScreen> {
  // abiturient
  late int _targetYear;
  int? _clusterId;
  int? _backupClusterId;
  String? _region;
  // schoolboy
  int _grade = 9;
  final _school = TextEditingController();
  String _studyLanguage = 'tj';

  bool _saving = false;

  bool get _isAbiturient => widget.role == 'abiturient';

  @override
  void initState() {
    super.initState();
    _targetYear = DateTime.now().year;
    _studyLanguage = ref.read(settingsProvider).language;
    final profile = ref.read(sessionProvider).profile;
    if (widget.mode == SurveyMode.edit && profile != null) {
      final a = profile.abiturient;
      if (a != null) {
        _targetYear = a.targetYear;
        _clusterId = a.clusterId;
        _backupClusterId = a.backupClusterId;
        _region = a.region;
      }
      final sc = profile.school;
      if (sc != null) {
        _grade = sc.grade;
        _school.text = sc.schoolName ?? '';
        _studyLanguage = sc.languageOfStudy;
      }
    }
  }

  @override
  void dispose() {
    _school.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _survey => _isAbiturient
      ? {
          'cluster_id': _clusterId,
          if (_backupClusterId != null) 'backup_cluster_id': _backupClusterId,
          'target_year': _targetYear,
          if (_region != null) 'region': _region,
        }
      : {
          'grade': _grade,
          if (_school.text.trim().isNotEmpty) 'school_name': _school.text.trim(),
          'language_of_study': _studyLanguage,
        };

  Future<void> _submit() async {
    final s = ref.read(stringsProvider);
    if (_isAbiturient && _clusterId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s['cluster_main'])));
      return;
    }
    setState(() => _saving = true);
    final repo = ref.read(profileRepositoryProvider);
    final key = _isAbiturient ? 'abiturient' : 'school';
    try {
      final Profile profile;
      if (widget.mode == SurveyMode.edit) {
        profile = await repo.update({key: _survey});
      } else {
        profile = await repo.setRole({'role': widget.role, key: _survey});
      }
      ref.read(sessionProvider.notifier).setProfile(profile);
      if (!mounted) return;
      if (widget.mode == SurveyMode.first) {
        context.go('/profile-created');
      } else {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) showError(context, s, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<Color> get _colors => (_isAbiturient ? BranchPalette.abiturient : BranchPalette.schoolboy).gradient;

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    final sections = _isAbiturient ? _abiturientSections(s) : _schoolSections(s);
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
            child: _SurveyHeader(
          title: s['survey_title'],
          role: _isAbiturient ? s['role_name_abiturient'] : s['role_name_schoolboy'],
          icon: _isAbiturient ? Icons.school_rounded : Icons.backpack_rounded,
          colors: _colors,
        )),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          sliver: SliverList.list(children: [
            for (var i = 0; i < sections.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: FadeSlideIn(delay: Stagger.of(i + 1, stepMs: 90), child: sections[i]),
              ),
            FadeSlideIn(
              delay: Stagger.of(sections.length + 1, stepMs: 90),
              child: GradientButton(
                label: widget.mode == SurveyMode.edit ? s['save'] : s['continue'],
                icon: widget.mode == SurveyMode.edit ? Icons.check_rounded : Icons.arrow_forward_rounded,
                colors: _colors,
                loading: _saving,
                onPressed: _submit,
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  List<Widget> _abiturientSections(Strings s) {
    final year = DateTime.now().year;
    final clusters = ref.watch(clustersProvider);
    final regions = ref.watch(regionsProvider);
    final lang = ref.watch(settingsProvider).language;
    return [
      _Section(
        icon: Icons.event_rounded,
        title: s['target_year'],
        colors: AppGradients.sky,
        child: Row(children: [
          for (final (label, value) in [
            (s['year_past'], year - 1),
            (s['year_current'], year),
            (s['year_next'], year + 1)
          ])
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: value == year + 1 ? 0 : 8),
                child: _ChoiceTile(
                  selected: _targetYear == value,
                  colors: _colors,
                  onTap: () => setState(() => _targetYear = value),
                  child: Column(children: [
                    Text('$value', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
        ]),
      ),
      _Section(
        icon: Icons.hub_rounded,
        title: s['cluster_main'],
        colors: _colors,
        child: clusters.when(
          loading: () => const Column(children: [Skeleton(height: 72), SizedBox(height: 8), Skeleton(height: 72)]),
          error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(clustersProvider)),
          data: (list) => Column(children: [
            for (final c in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ClusterTile(
                  cluster: c,
                  selected: _clusterId == c.id,
                  colors: _colors,
                  onTap: () => setState(() {
                    _clusterId = c.id;
                    if (_backupClusterId == c.id) _backupClusterId = null;
                  }),
                ),
              ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int?>(
              key: ValueKey('backup-$_clusterId'),
              initialValue: _backupClusterId,
              decoration:
                  InputDecoration(labelText: s['cluster_backup'], prefixIcon: const Icon(Icons.alt_route_rounded)),
              isExpanded: true,
              borderRadius: BorderRadius.circular(Radii.md),
              items: [
                DropdownMenuItem<int?>(value: null, child: Text(s['none'])),
                for (final c in list.where((c) => c.id != _clusterId))
                  DropdownMenuItem<int?>(value: c.id, child: Text(c.title, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _backupClusterId = v),
            ),
          ]),
        ),
      ),
      ...regions.maybeWhen(
        data: (list) => [
          _Section(
            icon: Icons.place_rounded,
            title: s['region_optional'],
            colors: AppGradients.mint,
            child: DropdownButtonFormField<String?>(
              initialValue: _region,
              isExpanded: true,
              borderRadius: BorderRadius.circular(Radii.md),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.map_rounded)),
              items: [
                DropdownMenuItem<String?>(value: null, child: Text(s['none'])),
                for (final r in list) DropdownMenuItem<String?>(value: r.code, child: Text(r.title(lang))),
              ],
              onChanged: (v) => setState(() => _region = v),
            ),
          ),
        ],
        orElse: () => const <Widget>[],
      ),
    ];
  }

  List<Widget> _schoolSections(Strings s) => [
        _Section(
          icon: Icons.stairs_rounded,
          title: s['grade'],
          colors: _colors,
          child: GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.3,
            children: [
              for (var g = 1; g <= 11; g++)
                _ChoiceTile(
                  selected: _grade == g,
                  colors: _colors,
                  onTap: () => setState(() => _grade = g),
                  child: Text('$g', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                ),
            ],
          ),
        ),
        _Section(
          icon: Icons.apartment_rounded,
          title: s['school_optional'],
          colors: AppGradients.sky,
          child: TextField(
            controller: _school,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.edit_rounded)),
          ),
        ),
        _Section(
          icon: Icons.translate_rounded,
          title: s['study_language'],
          colors: AppGradients.mint,
          child: SlidingSegments<String>(
            items: [('tj', s['lang_tj']), ('ru', s['lang_ru'])],
            value: _studyLanguage,
            colors: _colors,
            onChanged: (v) => setState(() => _studyLanguage = v),
          ),
        ),
      ];
}

/// Aurora header in the colours of the chosen role.
class _SurveyHeader extends StatelessWidget {
  final String title;
  final String role;
  final IconData icon;
  final List<Color> colors;
  const _SurveyHeader({required this.title, required this.role, required this.icon, required this.colors});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final canPop = Navigator.of(context).canPop();
    return AuroraBackground(
      colors: colors,
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(Radii.xl)),
      child: Stack(children: [
        Positioned(
          right: -20,
          bottom: -30,
          child: Icon(icon, size: 170, color: Colors.white.withValues(alpha: 0.12)),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, top + 8, 20, 28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              height: 44,
              child: canPop
                  ? GlassIconButton(icon: Icons.arrow_back_rounded, onPressed: () => Navigator.of(context).maybePop())
                  : null,
            ),
            const SizedBox(height: 16),
            FadeSlideIn(child: Pill(role, icon: icon, onDark: true)),
            const SizedBox(height: 10),
            FadeSlideIn(
              delay: Stagger.of(1),
              child: Text(title,
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, height: 1.15)),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// A card with an icon title for one question of the survey.
class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Color> colors;
  final Widget child;
  const _Section({required this.icon, required this.title, required this.colors, required this.child});

  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            IconBadge(icon, colors: colors, size: 34, glow: false),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          ]),
          const SizedBox(height: 14),
          child,
        ]),
      );
}

/// Selectable tile that fills with the gradient when chosen.
class _ChoiceTile extends StatelessWidget {
  final bool selected;
  final List<Color> colors;
  final VoidCallback onTap;
  final Widget child;
  const _ChoiceTile({required this.selected, required this.colors, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? AppGradients.of(colors) : null,
            color: selected ? null : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            boxShadow: selected
                ? [BoxShadow(color: colors.first.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6))]
                : null,
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 250),
            style: DefaultTextStyle.of(context).style.copyWith(color: selected ? Colors.white : null),
            child: child,
          ),
        ),
      );
}

class _ClusterTile extends StatelessWidget {
  final Cluster cluster;
  final bool selected;
  final List<Color> colors;
  final VoidCallback onTap;
  const _ClusterTile({required this.cluster, required this.selected, required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) => Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: selected ? colors.first : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
              width: selected ? 2 : 1,
            ),
            color: selected ? colors.first.withValues(alpha: 0.08) : null,
          ),
          child: Row(children: [
            IconBadge(subjectIcon(cluster.icon),
                colors: selected ? colors : AppGradients.silver, size: 44, glow: selected),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cluster.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(cluster.subjects.map((s) => s.title).join(' · '),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: mutedOf(context))),
              ]),
            ),
            const SizedBox(width: 8),
            AnimatedScale(
              scale: selected ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              child: Icon(Icons.check_circle_rounded, color: colors.first),
            ),
          ]),
        ),
      );
}
