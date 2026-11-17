import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ngo_app/core/api/api_exception.dart';
import 'package:ngo_app/core/i18n/translator.dart';
import 'package:ngo_app/core/theme/app_theme.dart';
import 'package:ngo_app/core/theme/responsive_widgets.dart';
import 'package:ngo_app/features/jobs/application/jobs_providers.dart';
import 'package:ngo_app/features/jobs/data/jobs_repository.dart';

class FellowJobDetailScreen extends ConsumerStatefulWidget {
  const FellowJobDetailScreen({super.key, required this.jobId});
  final String jobId;
  @override
  ConsumerState<FellowJobDetailScreen> createState() =>
      _FellowJobDetailScreenState();
}

class _FellowJobDetailScreenState extends ConsumerState<FellowJobDetailScreen> {
  final _hours = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _photos = <JobPhotoCapture>[];
  late Future<Map<String, dynamic>> _job;
  bool _busy = false,
      _captureBusy = false,
      _locationAllowed = false,
      _locationConsent = false;
  int _maxPhotos = 5;
  String? _error;
  @override
  void initState() {
    super.initState();
    _refresh();
    _config();
  }

  void _refresh() {
    _job = ref.read(jobsRepositoryProvider).detail(widget.jobId);
  }

  Future<void> _config() async {
    try {
      final config = await ref.read(jobsRepositoryProvider).config();
      if (mounted) {
        setState(() {
          _locationAllowed = config['geotag_enabled'] == true;
          _maxPhotos = (config['max_photos'] as int? ?? 5).clamp(1, 5);
        });
      }
    } catch (_) {/* Default: no optional location collection. */}
  }

  @override
  void dispose() {
    _hours.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_busy || _captureBusy || _photos.length >= _maxPhotos) return;
    setState(() {
      _captureBusy = true;
      _error = null;
    });
    try {
      final photo = await ref.read(jobCaptureProvider).camera();
      if (mounted && photo != null) {
        if (photo.bytes.length > 10 * 1024 * 1024) {
          setState(() => _error = t('jobs.photo_too_large'));
        } else {
          setState(() => _photos.add(photo));
        }
      }
    } catch (_) {
      if (mounted) setState(() => _error = t('jobs.camera_error'));
    } finally {
      if (mounted) setState(() => _captureBusy = false);
    }
  }

  Future<void> _mutate(Future<dynamic> Function() action,
      {bool submission = false}) async {
    if (_busy || _captureBusy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (!mounted) return;
      setState(() {
        if (submission) {
          _photos.clear();
          _hours.clear();
          _locationConsent = false;
        }
        _refresh();
      });
      if (submission) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t('jobs.submit_success'))));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error =
            error is ApiException ? error.userMessage : t('jobs.action_error'));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || _captureBusy || !_form.currentState!.validate()) return;
    if (_photos.isEmpty) {
      setState(() => _error = t('jobs.photo_required'));
      return;
    }
    await _mutate(() async {
      final timestamp = DateTime.now();
      final location = _locationAllowed && _locationConsent
          ? await ref.read(jobCaptureProvider).optionalLocation()
          : null;
      return ref.read(jobsRepositoryProvider).submit(widget.jobId,
          actualHours: _hours.text.trim(),
          photos: List.of(_photos),
          deviceTimestamp: timestamp,
          latitude: location?.latitude,
          longitude: location?.longitude);
    }, submission: true);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(t('jobs.detail')), actions: [
        IconButton(
            onPressed: _busy || _captureBusy ? null : () => setState(_refresh),
            tooltip: t('jobs.refresh'),
            icon: const Icon(Icons.refresh))
      ]),
      body: PageContent(
        maxWidth: 760,
        child: FutureBuilder<Map<String, dynamic>>(
            future: _job,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text(t('jobs.load_error')));
              }
              final job = snapshot.data!;
              final status = job['status'] as String;
              final canSubmit =
                  ['assigned', 'in_progress', 'rejected'].contains(status);
              return Form(
                  key: _form,
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(job['title'] as String,
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            StatusBadge(
                                label: t('jobs.status_$status'),
                                complete: status == 'approved'),
                            const SizedBox(height: 12),
                            Text(job['description'] as String),
                            Text(
                                '${t('jobs.expected_hours')}: ${job['expected_hours']}'),
                            if (job['deadline'] != null)
                              Text(
                                  '${t('jobs.due_by')}: ${DateFormat.yMMMd(Localizations.localeOf(context).languageCode).format(DateTime.parse(job['deadline'] as String))}'),
                            if (_error != null)
                              Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  child: Text(_error!,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .error))),
                            if (_busy || _captureBusy)
                              const LinearProgressIndicator(),
                            if (status == 'assigned' || status == 'rejected')
                              OutlinedButton(
                                  onPressed: _busy || _captureBusy
                                      ? null
                                      : () => _mutate(() => ref
                                          .read(jobsRepositoryProvider)
                                          .start(widget.jobId)),
                                  child: Text(t('jobs.start'))),
                            if (canSubmit) ...[
                              const SizedBox(height: 20),
                              Text(t('jobs.submit_title'),
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: AppSpacing.sm),
                              Text(t('jobs.submit_hint')),
                              const SizedBox(height: AppSpacing.md),
                              Text(t('jobs.step_hours'),
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: AppSpacing.sm),
                              TextFormField(
                                  controller: _hours,
                                  enabled: !_busy,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: InputDecoration(
                                      labelText: t('jobs.actual_hours')),
                                  validator: (value) {
                                    final input = value?.trim() ?? '';
                                    final hours = double.tryParse(input);
                                    return !RegExp(r'^\d{1,4}(\.\d{1,2})?$')
                                                .hasMatch(input) ||
                                            hours == null ||
                                            hours <= 0 ||
                                            hours > 9999.99
                                        ? t('jobs.hours_error')
                                        : null;
                                  }),
                              const SizedBox(height: AppSpacing.lg),
                              Text(t('jobs.step_photos'),
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: AppSpacing.sm),
                              Text(t(kIsWeb
                                  ? 'jobs.browser_evidence'
                                  : 'jobs.camera_evidence')),
                              const SizedBox(height: AppSpacing.sm),
                              Wrap(spacing: 12, children: [
                                for (var i = 0; i < _photos.length; i++)
                                  SizedBox(
                                      width: 120,
                                      child: Column(children: [
                                        Image.memory(_photos[i].bytes,
                                            height: 100,
                                            cacheWidth: 240,
                                            fit: BoxFit.cover,
                                            semanticLabel:
                                                t('jobs.view_photo')),
                                        TextButton.icon(
                                            onPressed: _busy || _captureBusy
                                                ? null
                                                : () => setState(
                                                    () => _photos.removeAt(i)),
                                            icon: const Icon(
                                                Icons.delete_outline),
                                            label: Text(t('jobs.remove_photo')))
                                      ]))
                              ]),
                              OutlinedButton.icon(
                                  onPressed: _busy ||
                                          _captureBusy ||
                                          _photos.length >= _maxPhotos
                                      ? null
                                      : _capture,
                                  icon: const Icon(Icons.camera_alt_outlined),
                                  label: Text(
                                      '${t(kIsWeb ? 'jobs.browser_capture' : 'jobs.capture')} (${_photos.length}/$_maxPhotos)')),
                              if (_photos.isEmpty)
                                Padding(
                                    padding: const EdgeInsets.only(
                                        top: AppSpacing.xs),
                                    child: Text(t('jobs.photo_required'),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall)),
                              if (_locationAllowed)
                                CheckboxListTile(
                                    value: _locationConsent,
                                    onChanged: _busy
                                        ? null
                                        : (value) => setState(() =>
                                            _locationConsent = value ?? false),
                                    title: Text(t('jobs.location_consent')),
                                    subtitle:
                                        Text(t('jobs.location_optional'))),
                              const SizedBox(height: AppSpacing.md),
                              FilledButton.icon(
                                  onPressed:
                                      _busy || _captureBusy ? null : _submit,
                                  icon: const Icon(Icons.send_outlined),
                                  label: Text(t('jobs.submit'))),
                            ],
                            const SizedBox(height: 24),
                            Text(t('jobs.submission_history'),
                                style: Theme.of(context).textTheme.titleLarge),
                            for (final entry
                                in job['submissions'] as List<dynamic>? ?? [])
                              Card(
                                  child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                '${t('jobs.actual_hours')}: ${entry['actual_hours']} · ${t('jobs.status_${entry['review_status']}')}'),
                                            Text(displayTimestamp(
                                                entry['submitted_at'])),
                                            if ((entry['review_reason']
                                                        as String? ??
                                                    '')
                                                .isNotEmpty)
                                              Text(
                                                  '${t('jobs.review_reason')}: ${entry['review_reason']}'),
                                            Wrap(children: [
                                              for (final photo
                                                  in entry['photos']
                                                          as List<dynamic>? ??
                                                      [])
                                                TextButton.icon(
                                                    onPressed: () => _showPhoto(
                                                        photo['id'] as String),
                                                    icon:
                                                        const Icon(Icons.photo),
                                                    label: Text(
                                                        t('jobs.view_photo')))
                                            ]),
                                          ]))),
                            const SizedBox(height: 20),
                            Text(t('jobs.history'),
                                style: Theme.of(context).textTheme.titleLarge),
                            for (final entry
                                in job['transitions'] as List<dynamic>? ?? [])
                              ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                      '${entry['from_status'] == null ? '—' : t('jobs.status_${entry['from_status']}')} → ${t('jobs.status_${entry['to_status']}')}'),
                                  subtitle: Text(
                                      '${displayTimestamp(entry['created_at'])}\n${t('jobs.actor')}: ${entry['actor']}')),
                          ])));
            }),
      ));

  Future<void> _showPhoto(String id) async {
    try {
      final bytes =
          await ref.read(jobsRepositoryProvider).photo(widget.jobId, id);
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (context) => Dialog(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                Flexible(child: InteractiveViewer(child: Image.memory(bytes))),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(t('jobs.close')))
              ])));
    } catch (_) {
      if (mounted) setState(() => _error = t('jobs.load_error'));
    }
  }
}
