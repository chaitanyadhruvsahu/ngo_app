import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ngo_app/core/api/api_exception.dart';
import 'package:ngo_app/core/i18n/language_menu.dart';
import 'package:ngo_app/core/i18n/translator.dart';
import 'package:ngo_app/core/theme/app_theme.dart';
import 'package:ngo_app/core/theme/workspace.dart';
import 'package:ngo_app/features/admin/application/admin_providers.dart';
import 'package:ngo_app/features/documents/services/save_file.dart';
import 'package:ngo_app/features/reporting/block_filter.dart';
import 'package:ngo_app/features/reporting/reporting_repository.dart';

String _error(Object error) =>
    error is ApiException ? error.userMessage : t('common.generic_error');
const _xlsxType =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
              title: Text(t('reports.title')),
              actions: const [LanguageMenu()],
              bottom: TabBar(isScrollable: true, tabs: [
                Tab(text: t('reports.dashboard')),
                Tab(text: t('reports.volunteers')),
                Tab(text: t('reports.exports')),
              ])),
          body: const TabBarView(
              children: [_DashboardTab(), _VolunteersTab(), _ExportsTab()]),
        ),
      );
}

class _VolunteersTab extends ConsumerStatefulWidget {
  const _VolunteersTab();
  @override
  ConsumerState<_VolunteersTab> createState() => _VolunteersState();
}

class _VolunteersState extends ConsumerState<_VolunteersTab> {
  int? _block;
  int _page = 1;
  late Future<Map<String, dynamic>> _rows;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _rows = ref
      .read(reportingRepositoryProvider)
      .volunteers(block: _block, page: _page);
  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: BlockFilter(
                value: _block,
                onChanged: (value) => setState(() {
                      _block = value;
                      _page = 1;
                      _load();
                    }))),
        Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
                future: _rows,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _Failure(
                        error: snapshot.error!, retry: () => setState(_load));
                  }
                  final data = snapshot.data!;
                  final rows = data['results'] as List;
                  return Column(children: [
                    Expanded(
                        child: rows.isEmpty
                            ? Center(child: Text(t('reports.empty')))
                            : ListView.builder(
                                itemCount: rows.length,
                                itemBuilder: (context, index) {
                                  final row = rows[index] as Map;
                                  final block = row['block_number'];
                                  return ListTile(
                                      isThreeLine: true,
                                      leading: const Icon(Icons.people_outline),
                                      title: Text('${row['full_name']}'),
                                      subtitle: Text(
                                          '${row['phone_number']}\n${row['fellow_name']} · ${block == null ? t('reports.unmapped') : t('reports.block_number', args: {
                                                  'number': '$block'
                                                })}'));
                                })),
                    _Pager(
                        page: _page,
                        data: data,
                        change: (page) => setState(() {
                              _page = page;
                              _load();
                            }))
                  ]);
                })),
      ]);
}

class _ExportsTab extends ConsumerStatefulWidget {
  const _ExportsTab();
  @override
  ConsumerState<_ExportsTab> createState() => _ExportsState();
}

class _ExportsState extends ConsumerState<_ExportsTab> {
  int? _block;
  int _page = 1;
  bool _busy = false;
  String? _message;
  late Future<Map<String, dynamic>> _history;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() =>
      _history = ref.read(reportingRepositoryProvider).history(page: _page);

  Future<void> _download(String type) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final bytes = await ref
          .read(reportingRepositoryProvider)
          .export(type, block: _block);
      final filename =
          '${type == 'event_participant_list' ? 'event_candidate_roster' : type}.xlsx';
      if (kIsWeb) {
        saveFile(bytes, filename, _xlsxType);
        if (mounted) setState(() => _message = t('reports.download_started'));
      } else {
        final result = await FilePicker.platform.saveFile(
            fileName: filename,
            bytes: bytes,
            type: FileType.custom,
            allowedExtensions: ['xlsx']);
        if (mounted) {
          setState(() => _message =
              t(result == null ? 'reports.save_cancelled' : 'reports.saved'));
        }
      }
    } catch (error) {
      if (mounted) setState(() => _message = _error(error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _page = 1;
          _load();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        BlockFilter(
            value: _block,
            onChanged:
                _busy ? (_) {} : (value) => setState(() => _block = value)),
        const SizedBox(height: 16),
        Text(t('reports.export_privacy')),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 12, children: [
          FilledButton.icon(
              onPressed: _busy ? null : () => _download('fellow_contact_list'),
              icon: const Icon(Icons.download),
              label: Text(t('reports.fellow_contact_list'))),
          FilledButton.icon(
              onPressed:
                  _busy ? null : () => _download('event_participant_list'),
              icon: const Icon(Icons.download),
              label: Text(t('reports.event_participant_list'))),
        ]),
        const SizedBox(height: 12),
        Text(t('reports.candidate_note')),
        if (_busy)
          const Padding(
              padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
        if (_message != null)
          Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Semantics(liveRegion: true, child: Text(_message!))),
        const Divider(height: 32),
        Text(t('reports.history'),
            style: Theme.of(context).textTheme.titleLarge),
        Text(t('reports.history_note')),
        FutureBuilder<Map<String, dynamic>>(
            future: _history,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _Failure(
                    error: snapshot.error!, retry: () => setState(_load));
              }
              final data = snapshot.data!;
              final rows = data['results'] as List;
              return Column(children: [
                if (rows.isEmpty)
                  Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(t('reports.empty'))),
                ...rows.map((row) => ListTile(
                    title: Text(t('reports.${row['export_type']}')),
                    subtitle: Text(
                        '${displayTimestamp(row['run_at'])} · ${row['filters']['block'] == null ? t('reports.all_blocks') : t('reports.block_number', args: {
                                'number': '${row['filters']['block']}'
                              })}'))),
                _Pager(
                    page: _page,
                    data: data,
                    change: (page) => setState(() {
                          _page = page;
                          _load();
                        })),
              ]);
            }),
      ]);
}

class _DashboardTab extends ConsumerStatefulWidget {
  const _DashboardTab();
  @override
  ConsumerState<_DashboardTab> createState() => _DashboardState();
}

class _DashboardState extends ConsumerState<_DashboardTab> {
  String? _fellow;
  late Future<Map<String, dynamic>> _data;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repository = ref.read(reportingRepositoryProvider);
    _data = _fellow == null ? repository.blocks() : repository.fellow(_fellow!);
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(16), children: [
        Text(t('reports.dashboard_note')),
        const SizedBox(height: 16),
        ref.watch(fellowListProvider).when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => _Failure(
                  error: error,
                  retry: () => ref.invalidate(fellowListProvider)),
              data: (fellows) => DropdownButtonFormField<String>(
                  initialValue: _fellow,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: t('reports.fellow')),
                  items: [
                    DropdownMenuItem(
                        value: null, child: Text(t('reports.by_block'))),
                    ...fellows.map((fellow) => DropdownMenuItem(
                        value: fellow.id,
                        child: Text(
                            fellow.fullName.isEmpty
                                ? fellow.email
                                : fellow.fullName,
                            overflow: TextOverflow.ellipsis)))
                  ],
                  onChanged: (value) => setState(() {
                        _fellow = value;
                        _load();
                      })),
            ),
        const SizedBox(height: 16),
        FutureBuilder<Map<String, dynamic>>(
            future: _data,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return _Failure(
                    error: snapshot.error!, retry: () => setState(_load));
              }
              final rows = _fellow == null
                  ? snapshot.data!['results'] as List
                  : [snapshot.data!];
              double total(String key) => rows.fold(
                  0, (sum, row) => sum + (double.tryParse('${row[key]}') ?? 0));
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeading(
                        ux(context, 'The difference, in numbers.',
                            'असर, आँकड़ों में।'),
                        subtitle: ux(
                            context,
                            'Real work. Reviewed hours. A clearer picture of your community.',
                            'असली काम। स्वीकृत घंटे। आपके समुदाय की स्पष्ट तस्वीर।')),
                    ResponsiveColumns(columns: 3, children: [
                      MetricCard(
                          label: ux(context, 'Work assigned', 'सौंपे गए कार्य'),
                          value: total('job_count').toStringAsFixed(0),
                          icon: Icons.work_outline,
                          note:
                              ux(context, 'Across this view', 'इस दृश्य में')),
                      MetricCard(
                          label:
                              ux(context, 'Hours of impact', 'योगदान के घंटे'),
                          value: total('approved_hours').toStringAsFixed(1),
                          icon: Icons.volunteer_activism_outlined,
                          note: ux(context, 'Reviewed and approved',
                              'समीक्षित और स्वीकृत')),
                      MetricCard(
                          label: ux(context, 'Work approved', 'स्वीकृत कार्य'),
                          value: total('approval_count').toStringAsFixed(0),
                          icon: Icons.check_circle_outline,
                          note: ux(context, 'Progress worth celebrating',
                              'सराहनीय प्रगति')),
                    ]),
                    const SizedBox(height: 28),
                    ResponsiveColumns(columns: 2, breakpoint: 800, children: [
                      for (final row in rows)
                        SurfacePanel(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                              Row(children: [
                                Container(
                                    padding: const EdgeInsets.all(9),
                                    decoration: BoxDecoration(
                                        color: AppColors.lime
                                            .withValues(alpha: .4),
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: const Icon(
                                        Icons.location_on_outlined,
                                        size: 19,
                                        color: AppColors.primary)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Text(
                                        _fellow == null
                                            ? t('reports.block_number', args: {
                                                'number':
                                                    '${row['block_number']}'
                                              })
                                            : '${row['full_name']}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium))
                              ]),
                              const SizedBox(height: 18),
                              if (row['fellow_count'] != null)
                                _Metric('fellow_count', row['fellow_count']),
                              for (final key in [
                                'job_count',
                                'expected_hours',
                                'approved_hours',
                                'submission_count',
                                'approval_count'
                              ])
                                _Metric(key, row[key]),
                              const SizedBox(height: 16),
                              ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                      minHeight: 7,
                                      value: (double.tryParse(
                                                      '${row['job_count']}') ??
                                                  0) ==
                                              0
                                          ? 0
                                          : ((double.tryParse(
                                                          '${row['approval_count']}') ??
                                                      0) /
                                                  double.parse(
                                                      '${row['job_count']}'))
                                              .clamp(0, 1))),
                              const SizedBox(height: 8),
                              Text(
                                  ux(
                                      context,
                                      'Approved work / total assignments',
                                      'स्वीकृत कार्य / कुल कार्य'),
                                  style: const TextStyle(
                                      fontSize: 10, color: AppColors.muted)),
                            ]))
                    ]),
                  ]);
            }),
      ]);
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label;
  final Object? value;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(t('reports.$label'))),
        Text('$value')
      ]));
}

class _Failure extends StatelessWidget {
  const _Failure({required this.error, required this.retry});
  final Object error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error(error)),
        TextButton(onPressed: retry, child: Text(t('reports.retry')))
      ]));
}

class _Pager extends StatelessWidget {
  const _Pager({required this.page, required this.data, required this.change});
  final int page;
  final Map<String, dynamic> data;
  final ValueChanged<int> change;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
            tooltip: t('jobs.previous'),
            onPressed: page > 1 ? () => change(page - 1) : null,
            icon: const Icon(Icons.chevron_left)),
        Text(t('jobs.page',
            args: {'page': '$page', 'count': '${data['count']}'})),
        IconButton(
            tooltip: t('jobs.next'),
            onPressed: data['next'] != null ? () => change(page + 1) : null,
            icon: const Icon(Icons.chevron_right)),
      ]);
}
