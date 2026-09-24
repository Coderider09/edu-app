import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/settings.dart';
import '../../../core/widgets/common.dart';
import '../../../data/models.dart';
import '../../../data/repositories.dart';
import '../../auth/session_controller.dart';

/// first — right after registration; add — second role from settings; edit — change the questionnaire.
enum SurveyMode { first, add, edit }

final clustersProvider = FutureProvider.autoDispose<List<Cluster>>(
    (ref) => ref.watch(contentRepositoryProvider).clusters(ref.watch(settingsProvider).language));
final regionsProvider = FutureProvider.autoDispose<List<Region>>((ref) => ref.watch(contentRepositoryProvider).regions());

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

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(stringsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(_isAbiturient ? s['role_name_abiturient'] : s['role_name_schoolboy'])),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(24), children: [
          Text(s['survey_title'],
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 24),
          if (_isAbiturient) ..._abiturientFields(s) else ..._schoolFields(s),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3))
                : Text(widget.mode == SurveyMode.edit ? s['save'] : s['continue']),
          ),
        ]),
      ),
    );
  }

  List<Widget> _abiturientFields(Strings s) {
    final year = DateTime.now().year;
    final clusters = ref.watch(clustersProvider);
    final regions = ref.watch(regionsProvider);
    final lang = ref.watch(settingsProvider).language;
    return [
      Text(s['target_year'], style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final (label, value) in [(s['year_past'], year - 1), (s['year_current'], year), (s['year_next'], year + 1)])
          ChoiceChip(
            label: Text('$label ($value)'),
            selected: _targetYear == value,
            onSelected: (_) => setState(() => _targetYear = value),
          ),
      ]),
      const SizedBox(height: 24),
      Text(s['cluster_main'], style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      clusters.when(
        loading: () => const Column(children: [Skeleton(height: 72), SizedBox(height: 8), Skeleton(height: 72)]),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(clustersProvider)),
        data: (list) => Column(children: [
          for (final c in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ClusterTile(
                cluster: c,
                selected: _clusterId == c.id,
                onTap: () => setState(() {
                  _clusterId = c.id;
                  if (_backupClusterId == c.id) _backupClusterId = null;
                }),
              ),
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int?>(
            value: _backupClusterId,
            decoration: InputDecoration(labelText: s['cluster_backup']),
            isExpanded: true,
            items: [
              DropdownMenuItem<int?>(value: null, child: Text(s['none'])),
              for (final c in list.where((c) => c.id != _clusterId))
                DropdownMenuItem<int?>(value: c.id, child: Text(c.title, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _backupClusterId = v),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      regions.maybeWhen(
        data: (list) => DropdownButtonFormField<String?>(
          value: _region,
          decoration: InputDecoration(labelText: s['region_optional']),
          isExpanded: true,
          items: [
            DropdownMenuItem<String?>(value: null, child: Text(s['none'])),
            for (final r in list) DropdownMenuItem<String?>(value: r.code, child: Text(r.title(lang))),
          ],
          onChanged: (v) => setState(() => _region = v),
        ),
        orElse: () => const SizedBox.shrink(),
      ),
    ];
  }

  List<Widget> _schoolFields(Strings s) => [
        Text(s['grade'], style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.4,
          children: [
            for (var g = 1; g <= 11; g++)
              ChoiceChip(
                label: SizedBox(width: double.infinity, child: Text('$g', textAlign: TextAlign.center)),
                selected: _grade == g,
                onSelected: (_) => setState(() => _grade = g),
              ),
          ],
        ),
        const SizedBox(height: 24),
        TextField(controller: _school, decoration: InputDecoration(labelText: s['school_optional'])),
        const SizedBox(height: 24),
        Text(s['study_language'], style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'tj', label: Text(s['lang_tj'])),
            ButtonSegment(value: 'ru', label: Text(s['lang_ru'])),
          ],
          selected: {_studyLanguage},
          onSelectionChanged: (v) => setState(() => _studyLanguage = v.first),
        ),
      ];
}

class _ClusterTile extends StatelessWidget {
  final Cluster cluster;
  final bool selected;
  final VoidCallback onTap;
  const _ClusterTile({required this.cluster, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 2 : 1),
        color: selected ? scheme.primaryContainer.withValues(alpha: 0.5) : Theme.of(context).cardTheme.color,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(subjectIcon(cluster.icon), color: scheme.primary, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cluster.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(cluster.subjects.map((s) => s.title).join(' · '),
                    style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
            if (selected) Icon(Icons.check_circle_rounded, color: scheme.primary),
          ]),
        ),
      ),
    );
  }
}
