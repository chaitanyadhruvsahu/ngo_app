import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ngo_app/core/api/api_exception.dart';
import 'package:ngo_app/core/i18n/translator.dart';
import 'package:ngo_app/core/theme/workspace.dart';
import 'package:ngo_app/features/admin/application/admin_providers.dart';
import 'package:ngo_app/features/jobs/application/jobs_providers.dart';
import 'package:ngo_app/features/reporting/block_filter.dart';

const _statuses = [
  'assigned',
  'in_progress',
  'submitted',
  'approved',
  'rejected'
];
String _text(dynamic value) => value?.toString() ?? '';
String _error(Object error) =>
    error is ApiException ? error.userMessage : t('common.generic_error');

class AdminJobsScreen extends ConsumerStatefulWidget {
  const AdminJobsScreen({super.key, this.initialStatus});
  final String? initialStatus;
  @override
  ConsumerState<AdminJobsScreen> createState() => _AdminJobsScreenState();
}

class _AdminJobsScreenState extends ConsumerState<AdminJobsScreen> {
  String? _status, _fellow;
  int? _block;
  int _page = 1;
  late Future<Map<String, dynamic>> _jobs;
  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _load();
  }

  void _load() {
    _jobs = ref
        .read(jobsRepositoryProvider)
        .list(status: _status, fellow: _fellow, block: _block, page: _page);
  }

  void _refresh() => setState(_load);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('jobs.title')), actions: [
        IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: t('jobs.refresh'))
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/admin/jobs/new');
          if (mounted) _refresh();
        },
        icon: const Icon(Icons.add),
        label: Text(t('jobs.create')),
      ),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(spacing: 16, runSpacing: 12, children: [
              BlockFilter(
                  value: _block,
                  onChanged: (value) => setState(() {
                        _block = value;
                        _page = 1;
                        _load();
                      })),
              SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration:
                        InputDecoration(labelText: t('jobs.status_label')),
                    items: [
                      DropdownMenuItem(
                          value: null, child: Text(t('jobs.all_statuses'))),
                      ..._statuses.map((s) => DropdownMenuItem(
                          value: s, child: Text(t('jobs.status.$s'))))
                    ],
                    onChanged: (value) => setState(() {
                      _status = value;
                      _page = 1;
                      _load();
                    }),
                  )),
              SizedBox(
                  width: MediaQuery.sizeOf(context).width < 600
                      ? MediaQuery.sizeOf(context).width - 48
                      : 300,
                  child: _FellowPicker(
                      value: _fellow,
                      allowAll: true,
                      onChanged: (value) => setState(() {
                            _fellow = value;
                            _page = 1;
                            _load();
                          }))),
            ])),
        Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
                future: _jobs,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text(_error(snapshot.error!)));
                  }
                  final data = snapshot.data!;
                  final rows = data['results'] as List;
                  return Column(children: [
                    Expanded(
                        child: rows.isEmpty
                            ? Center(child: Text(t('jobs.empty')))
                            : ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(24, 8, 24, 90),
                                itemCount: rows.length,
                                itemBuilder: (context, index) {
                                  final job =
                                      rows[index] as Map<String, dynamic>;
                                  return JobTile(
                                    job: job,
                                    admin: true,
                                    onTap: () async {
                                      await context
                                          .push('/admin/jobs/${job['id']}');
                                      if (mounted) _refresh();
                                    },
                                  );
                                },
                              )),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      IconButton(
                          tooltip: t('jobs.previous'),
                          onPressed: _page > 1
                              ? () => setState(() {
                                    _page--;
                                    _load();
                                  })
                              : null,
                          icon: const Icon(Icons.chevron_left)),
                      Text(t('jobs.page', args: {
                        'page': '$_page',
                        'count': '${data['count']}'
                      })),
                      IconButton(
                          tooltip: t('jobs.next'),
                          onPressed: data['next'] != null
                              ? () => setState(() {
                                    _page++;
                                    _load();
                                  })
                              : null,
                          icon: const Icon(Icons.chevron_right)),
                    ]),
                  ]);
                })),
      ]),
    );
  }
}

class _FellowPicker extends ConsumerWidget {
  const _FellowPicker(
      {required this.value,
      required this.onChanged,
      this.allowAll = false,
      this.exclude});
  final String? value, exclude;
  final bool allowAll;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(fellowListProvider)
      .when(
        loading: () => const LinearProgressIndicator(),
        error: (error, _) => Row(children: [
          Expanded(child: Text(_error(error))),
          IconButton(
              onPressed: () => ref.invalidate(fellowListProvider),
              icon: const Icon(Icons.refresh))
        ]),
        data: (fellows) => DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(labelText: t('jobs.fellow')),
          validator: (value) =>
              !allowAll && value == null ? t('jobs.required') : null,
          items: [
            if (allowAll)
              DropdownMenuItem(value: null, child: Text(t('jobs.all_fellows'))),
            for (final fellow in fellows.where((f) => f.id != exclude))
              DropdownMenuItem(
                  value: fellow.id,
                  child: Text(
                      fellow.fullName.isEmpty
                          ? fellow.email
                          : '${fellow.fullName} (${fellow.email})',
                      overflow: TextOverflow.ellipsis))
          ],
          onChanged: onChanged,
        ),
      );
}

class AdminJobFormScreen extends ConsumerStatefulWidget {
  const AdminJobFormScreen({super.key, this.job});
  final Map<String, dynamic>? job;
  @override
  ConsumerState<AdminJobFormScreen> createState() => _AdminJobFormScreenState();
}

class _AdminJobFormScreenState extends ConsumerState<AdminJobFormScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController(),
      _description = TextEditingController(),
      _hours = TextEditingController(),
      _deadline = TextEditingController(),
      _note = TextEditingController();
  String? _fellow, _failure;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    final job = widget.job;
    if (job != null) {
      _title.text = _text(job['title']);
      _description.text = _text(job['description']);
      _hours.text = _text(job['expected_hours']);
      _deadline.text = _text(job['deadline']);
      _note.text = _text(job['internal_note']);
      _fellow = _text(job['assigned_to']);
    }
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _hours, _deadline, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    if (widget.job == null && _fellow == null) {
      setState(() => _failure = t('jobs.required'));
      return;
    }
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final values = <String, dynamic>{
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'expected_hours': _hours.text.trim(),
        'deadline': _deadline.text.isEmpty ? null : _deadline.text,
        'internal_note': _note.text.trim()
      };
      final repo = ref.read(jobsRepositoryProvider);
      if (widget.job == null) {
        values['assigned_to'] = _fellow;
        await repo.create(values);
      } else {
        await repo.update(widget.job!['id'] as String, values);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _failure = _error(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(t(widget.job == null ? 'jobs.create' : 'jobs.edit'))),
        body: Form(
            key: _form,
            child: ListView(padding: const EdgeInsets.all(24), children: [
              if (widget.job == null)
                _FellowPicker(
                    value: _fellow, onChanged: (value) => _fellow = value),
              TextFormField(
                  controller: _title,
                  maxLength: 255,
                  decoration: InputDecoration(labelText: t('jobs.job_title')),
                  validator: _required),
              TextFormField(
                  controller: _description,
                  minLines: 3,
                  maxLines: 8,
                  decoration: InputDecoration(labelText: t('jobs.description')),
                  validator: _required),
              TextFormField(
                  controller: _hours,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      InputDecoration(labelText: t('jobs.expected_hours')),
                  validator: (value) {
                    final hours = double.tryParse(value ?? '');
                    return hours == null ||
                            hours <= 0 ||
                            hours > 9999.99 ||
                            !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value!)
                        ? t('jobs.invalid_hours')
                        : null;
                  }),
              TextFormField(
                  controller: _deadline,
                  readOnly: true,
                  decoration: InputDecoration(
                      labelText: t('jobs.deadline'),
                      suffixIcon: IconButton(
                          onPressed: () => _deadline.clear(),
                          icon: const Icon(Icons.clear))),
                  onTap: () async {
                    final date = await showDatePicker(
                        context: context,
                        initialDate:
                            DateTime.tryParse(_deadline.text) ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100));
                    if (date != null) {
                      _deadline.text = date.toIso8601String().substring(0, 10);
                    }
                  }),
              TextFormField(
                  controller: _note,
                  minLines: 2,
                  maxLines: 6,
                  decoration:
                      InputDecoration(labelText: t('jobs.internal_note'))),
              if (_failure != null)
                Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_failure!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error))),
              const SizedBox(height: 24),
              FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(t(_busy ? 'jobs.saving' : 'jobs.save'))),
            ])),
      );
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? t('jobs.required') : null;

class AdminJobDetailScreen extends ConsumerStatefulWidget {
  const AdminJobDetailScreen({super.key, required this.jobId});
  final String jobId;
  @override
  ConsumerState<AdminJobDetailScreen> createState() =>
      _AdminJobDetailScreenState();
}

class _AdminJobDetailScreenState extends ConsumerState<AdminJobDetailScreen> {
  late Future<Map<String, dynamic>> _job;
  bool _busy = false;
  String? _failure;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _job = ref.read(jobsRepositoryProvider).detail(widget.jobId);
  }

  Future<void> _mutate(
      Future<Map<String, dynamic>> Function() operation) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      await operation();
      if (mounted) setState(_load);
    } catch (error) {
      if (mounted) {
        setState(() {
          _failure = _error(error);
          _load();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review(Map<String, dynamic> submission, bool approve) async {
    final reason = await _reasonDialog(context,
        title: t(approve ? 'jobs.approve' : 'jobs.reject'), required: !approve);
    if (reason == null || !mounted) return;
    await _mutate(() => ref.read(jobsRepositoryProvider).review(widget.jobId,
        submissionId: submission['id'] as String,
        decision: approve ? 'approved' : 'rejected',
        reason: reason));
  }

  Future<void> _reassign(Map<String, dynamic> job) async {
    final result = await showDialog<Map<String, String>>(
        context: context,
        builder: (context) =>
            _ReassignDialog(current: job['assigned_to'] as String));
    if (result == null || !mounted) return;
    await _mutate(() => ref.read(jobsRepositoryProvider).reassign(widget.jobId,
        assignedTo: result['fellow']!, reason: result['reason']!));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(t('jobs.detail')), actions: [
          IconButton(
              onPressed: _busy ? null : () => setState(_load),
              icon: const Icon(Icons.refresh),
              tooltip: t('jobs.refresh'))
        ]),
        body: FutureBuilder<Map<String, dynamic>>(
            future: _job,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text(_error(snapshot.error!)));
              }
              final job = snapshot.data!;
              final submissions = (job['submissions'] as List? ?? [])
                  .cast<Map<String, dynamic>>();
              return ListView(padding: const EdgeInsets.all(24), children: [
                Text(_text(job['title']),
                    style: Theme.of(context).textTheme.headlineSmall),
                Text(
                    '${_text(job['assigned_to_name'])} · ${t('jobs.status.${job['status']}')}'),
                const SizedBox(height: 16),
                Text(_text(job['description'])),
                Text('${t('jobs.expected_hours')}: ${job['expected_hours']}'),
                Text('${t('jobs.deadline')}: ${job['deadline'] ?? '—'}'),
                if (_busy) const LinearProgressIndicator(),
                if (_failure != null)
                  Text(_failure!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                Wrap(spacing: 12, children: [
                  if (job['can_edit'] == true)
                    OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                await Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                        builder: (_) =>
                                            AdminJobFormScreen(job: job)));
                                if (mounted) setState(_load);
                              },
                        child: Text(t('jobs.edit'))),
                  if (job['can_reassign'] == true)
                    OutlinedButton(
                        onPressed: _busy ? null : () => _reassign(job),
                        child: Text(t('jobs.reassign'))),
                ]),
                const Divider(),
                Text(t('jobs.internal_note'),
                    style: Theme.of(context).textTheme.titleMedium),
                Text(_text(job['internal_note'])),
                Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                        onPressed: _busy
                            ? null
                            : () async {
                                final note = await _reasonDialog(context,
                                    title: t('jobs.internal_note'),
                                    required: false,
                                    initial: _text(job['internal_note']),
                                    label: t('jobs.internal_note'));
                                if (note != null && mounted) {
                                  await _mutate(() => ref
                                      .read(jobsRepositoryProvider)
                                      .update(widget.jobId,
                                          {'internal_note': note}));
                                }
                              },
                        child: Text(t('jobs.edit_note')))),
                const Divider(),
                Text(t('jobs.submissions'),
                    style: Theme.of(context).textTheme.titleLarge),
                Text(t('jobs.metadata_warning')),
                if (submissions.isEmpty) Text(t('jobs.no_submissions')),
                for (final submission in submissions)
                  Card(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${t('jobs.actual_hours')}: ${submission['actual_hours']}'),
                                Text(
                                    '${t('jobs.submitted_at')}: ${submission['submitted_at']}'),
                                Text(
                                    '${t('jobs.submitted_by')}: ${submission['submitted_by']}'),
                                Text(
                                    '${t('jobs.review_status')}: ${t('jobs.status.${submission['review_status']}')}'),
                                if (_text(submission['review_reason'])
                                    .isNotEmpty)
                                  Text(
                                      '${t('jobs.reason')}: ${submission['review_reason']}'),
                                if (submission['device_timestamp'] != null)
                                  Text(
                                      '${t('jobs.device_time')}: ${submission['device_timestamp']}'),
                                if (submission['geotag_lat'] != null)
                                  Text(
                                      '${t('jobs.location')}: ${submission['geotag_lat']}, ${submission['geotag_lng']}'),
                                Wrap(spacing: 12, runSpacing: 12, children: [
                                  for (final photo
                                      in submission['photos'] as List? ?? [])
                                    _EvidencePhoto(
                                        key: ValueKey(photo['id']),
                                        jobId: widget.jobId,
                                        photo: photo as Map<String, dynamic>)
                                ]),
                                if (job['status'] == 'submitted' &&
                                    submission['review_status'] == 'pending')
                                  Wrap(spacing: 12, children: [
                                    FilledButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _review(submission, true),
                                        child: Text(t('jobs.approve'))),
                                    OutlinedButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _review(submission, false),
                                        child: Text(t('jobs.reject'))),
                                  ]),
                              ]))),
                const Divider(),
                Text(t('jobs.history'),
                    style: Theme.of(context).textTheme.titleLarge),
                for (final transition in job['transitions'] as List? ?? [])
                  ListTile(
                    title: Text(
                        '${transition['from_status'] == null ? '—' : t('jobs.status.${transition['from_status']}')} → ${t('jobs.status.${transition['to_status']}')}'),
                    subtitle: Text(
                        '${transition['created_at']}\n${_text(transition['reason'])}'),
                  ),
              ]);
            }),
      );
}

class _EvidencePhoto extends ConsumerStatefulWidget {
  const _EvidencePhoto({super.key, required this.jobId, required this.photo});
  final String jobId;
  final Map<String, dynamic> photo;
  @override
  ConsumerState<_EvidencePhoto> createState() => _EvidencePhotoState();
}

class _EvidencePhotoState extends ConsumerState<_EvidencePhoto> {
  late Future<Uint8List> _bytes;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _bytes = ref
        .read(jobsRepositoryProvider)
        .photo(widget.jobId, widget.photo['id'] as String);
  }

  @override
  Widget build(BuildContext context) => SizedBox(
      width: 220,
      child: Column(children: [
        FutureBuilder<Uint8List>(
            future: _bytes,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return TextButton(
                    onPressed: () => setState(_load),
                    child: Text(t('jobs.photo_retry')));
              }
              if (!snapshot.hasData) {
                return const SizedBox(
                    height: 140,
                    child: Center(child: CircularProgressIndicator()));
              }
              return InkWell(
                  onTap: () => showDialog<void>(
                      context: context,
                      builder: (context) => Dialog(
                              child: Stack(children: [
                            InteractiveViewer(
                                child: Image.memory(snapshot.data!,
                                    fit: BoxFit.contain)),
                            Positioned(
                                right: 0,
                                top: 0,
                                child: IconButton(
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(Icons.close)))
                          ]))),
                  child: Image.memory(snapshot.data!,
                      height: 140, fit: BoxFit.cover));
            }),
        if (widget.photo['exif_captured_at'] != null)
          Text('${t('jobs.exif_time')}: ${widget.photo['exif_captured_at']}'),
      ]));
}

Future<String?> _reasonDialog(BuildContext context,
    {required String title,
    required bool required,
    String initial = '',
    String? label}) async {
  return showDialog<String>(
      context: context,
      builder: (_) => _ReasonDialog(
          title: title, required: required, initial: initial, label: label));
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog(
      {required this.title,
      required this.required,
      required this.initial,
      this.label});
  final String title, initial;
  final String? label;
  final bool required;
  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text(widget.title),
          content: Form(
              key: _form,
              child: TextFormField(
                  controller: _controller,
                  minLines: 2,
                  maxLines: 6,
                  decoration: InputDecoration(
                      labelText: widget.label ?? t('jobs.reason')),
                  validator: widget.required ? _required : null)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(t('jobs.cancel'))),
            FilledButton(
                onPressed: () {
                  if (_form.currentState!.validate()) {
                    Navigator.pop(context, _controller.text.trim());
                  }
                },
                child: Text(t('jobs.confirm')))
          ]);
}

class _ReassignDialog extends StatefulWidget {
  const _ReassignDialog({required this.current});
  final String current;
  @override
  State<_ReassignDialog> createState() => _ReassignDialogState();
}

class _ReassignDialogState extends State<_ReassignDialog> {
  final _form = GlobalKey<FormState>(),
      _reasonKey = GlobalKey<FormFieldState<String>>();
  final _reason = TextEditingController();
  String? _fellow;
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: Text(t('jobs.reassign')),
          content: SizedBox(
              width: 400,
              child: Form(
                  key: _form,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    _FellowPicker(
                        value: _fellow,
                        exclude: widget.current,
                        onChanged: (value) => _fellow = value),
                    TextFormField(
                        key: _reasonKey,
                        controller: _reason,
                        decoration:
                            InputDecoration(labelText: t('jobs.reason')),
                        validator: _required),
                  ]))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(t('jobs.cancel'))),
            FilledButton(
                onPressed: () {
                  if (_form.currentState!.validate() && _fellow != null) {
                    Navigator.pop(context,
                        {'fellow': _fellow!, 'reason': _reason.text.trim()});
                  }
                },
                child: Text(t('jobs.confirm')))
          ]);
}
