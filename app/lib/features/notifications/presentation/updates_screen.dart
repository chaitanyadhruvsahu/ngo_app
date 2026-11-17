import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ngo_app/core/theme/app_theme.dart';
import 'package:ngo_app/core/theme/workspace.dart';
import 'package:ngo_app/features/notifications/data/notifications_repository.dart';
import 'package:ngo_app/features/notifications/presentation/notifications_screen.dart';

class UpdatesScreen extends ConsumerStatefulWidget {
  const UpdatesScreen({super.key, this.admin = false});
  final bool admin;
  @override
  ConsumerState<UpdatesScreen> createState() => _UpdatesState();
}

class _UpdatesState extends ConsumerState<UpdatesScreen> {
  List<Map<String, dynamic>>? rows;
  String? error;
  int filter = 0;
  bool busy = false, loading = false;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    load();
    timer = Timer.periodic(const Duration(seconds: 30), (_) => load());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    if (loading) return;
    loading = true;
    try {
      final result = await ref
          .read(notificationsRepositoryProvider)
          .pages(widget.admin ? '/admin/notifications' : '/notifications/mine');
      if (mounted) {
        setState(() {
          rows = result;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = ux(
            context,
            'Couldn’t load updates. Please try again.',
            'अपडेट लोड नहीं हुए। फिर कोशिश करें।'));
      }
    } finally {
      loading = false;
    }
  }

  Future<void> mark(String id, {bool dismiss = false}) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await ref
          .read(notificationsRepositoryProvider)
          .mark(id, dismiss: dismiss);
      await load();
    } catch (_) {
      if (mounted) {
        setState(
            () => error = ux(context, 'Please try again.', 'फिर कोशिश करें।'));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode == 'hi' ? 'hi' : 'en';
    final visible = (rows ?? [])
        .where((r) =>
            r['cancelled_at'] == null &&
            (filter == 0 ||
                (filter == 1
                    ? r['source_job'] != null
                    : r['source_job'] == null)))
        .toList()
      ..sort((a, b) =>
          '${b['scheduled_time']}'.compareTo('${a['scheduled_time']}'));
    return Scaffold(
        appBar: AppBar(title: Text(ux(context, 'Updates', 'अपडेट')), actions: [
          IconButton(
              onPressed: load,
              tooltip: ux(context, 'Refresh', 'ताज़ा करें'),
              icon: const Icon(Icons.refresh))
        ]),
        floatingActionButton: widget.admin
            ? FloatingActionButton.extended(
                onPressed: () async {
                  final sent = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                          builder: (_) => const NotificationCreateScreen()));
                  if (sent == true) load();
                },
                icon: const Icon(Icons.edit_note_rounded),
                label: Text(ux(context, 'Send announcement', 'घोषणा भेजें')))
            : null,
        body: RefreshIndicator(
            onRefresh: load,
            child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 100),
                children: [
                  SurfacePanel(
                      color: const Color(0xFFEAF0DF),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.notifications_active_outlined,
                                color: AppColors.primary),
                            const SizedBox(width: 16),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(
                                      ux(
                                          context,
                                          'Reminders that take care of themselves.',
                                          'अनुस्मारक, अपने आप।'),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  const SizedBox(height: 7),
                                  Text(
                                      ux(
                                          context,
                                          'Assignments and deadlines trigger job updates automatically. Send announcements for news, training and events.',
                                          'कार्य और अंतिम तिथि के अनुस्मारक अपने आप आते हैं। समाचार, प्रशिक्षण और कार्यक्रमों के लिए घोषणा भेजें।'),
                                      style: const TextStyle(
                                          color: AppColors.muted,
                                          fontSize: 13)),
                                ]))
                          ])),
                  const SizedBox(height: 24),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (var i = 0; i < 3; i++)
                      ChoiceChip(
                          selected: filter == i,
                          onSelected: (_) => setState(() => filter = i),
                          label: Text([
                            ux(context, 'All updates', 'सभी अपडेट'),
                            ux(context, 'Job activity', 'कार्य अपडेट'),
                            ux(context, 'Announcements', 'घोषणाएँ')
                          ][i]))
                  ]),
                  const SizedBox(height: 22),
                  if (error != null)
                    Text(error!,
                        style: const TextStyle(color: AppColors.error)),
                  if (rows == null && error == null)
                    const LinearProgressIndicator(),
                  if (rows != null && visible.isEmpty)
                    QuietState(
                        title:
                            ux(context, 'A quiet moment', 'अभी कोई अपडेट नहीं'),
                        message: ux(context, 'New updates will appear here.',
                            'नए अपडेट यहाँ दिखेंगे।'),
                        icon: Icons.notifications_none_rounded),
                  for (final row in visible)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: SurfacePanel(
                            child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                      color: row['source_job'] != null
                                          ? AppColors.lime
                                              .withValues(alpha: .45)
                                          : AppColors.peach
                                              .withValues(alpha: .6),
                                      borderRadius: BorderRadius.circular(13)),
                                  child: Icon(
                                      row['source_job'] != null
                                          ? Icons.work_outline
                                          : Icons.campaign_outlined,
                                      size: 22,
                                      color: AppColors.primary)),
                              const SizedBox(width: 16),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(
                                        ux(
                                            context,
                                            row['source_job'] != null
                                                ? 'AUTOMATIC JOB UPDATE'
                                                : 'FROM YOUR TEAM',
                                            row['source_job'] != null
                                                ? 'स्वचालित कार्य अपडेट'
                                                : 'आपकी टीम से'),
                                        style: const TextStyle(
                                            fontSize: 9,
                                            letterSpacing: 1.3,
                                            color: AppColors.muted)),
                                    const SizedBox(height: 7),
                                    Text(
                                        '${(row['title_$lang']?.toString().trim().isNotEmpty ?? false) ? row['title_$lang'] : row['title_en']}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    const SizedBox(height: 8),
                                    Text(
                                        '${(row['body_$lang']?.toString().trim().isNotEmpty ?? false) ? row['body_$lang'] : row['body_en']}',
                                        style: const TextStyle(
                                            color: AppColors.muted,
                                            fontSize: 13)),
                                    const SizedBox(height: 12),
                                    Wrap(
                                        spacing: 14,
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                              DateFormat('d MMM · h:mm a')
                                                  .format(DateTime.parse(
                                                          '${row['scheduled_time']}')
                                                      .toLocal()),
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.muted)),
                                          if (row['source_job'] != null)
                                            TextButton(
                                                onPressed: () => context.push(
                                                    '${widget.admin ? '/admin/jobs' : '/jobs'}/${row['source_job']}'),
                                                child: Text(ux(
                                                    context,
                                                    'Open job',
                                                    'कार्य खोलें'))),
                                          if (!widget.admin &&
                                              row['read_at'] == null)
                                            TextButton(
                                                onPressed: busy
                                                    ? null
                                                    : () =>
                                                        mark('${row['id']}'),
                                                child: Text(ux(
                                                    context,
                                                    'Mark as read',
                                                    'पढ़ा हुआ चिह्नित करें'))),
                                          if (!widget.admin &&
                                              row['dismissed_at'] == null)
                                            TextButton(
                                                onPressed: busy
                                                    ? null
                                                    : () => mark('${row['id']}',
                                                        dismiss: true),
                                                child: Text(ux(context,
                                                    'Dismiss', 'हटाएँ'))),
                                          if (!widget.admin &&
                                              row['dismissed_at'] != null)
                                            Text(
                                                ux(context, 'Dismissed',
                                                    'हटाया गया'),
                                                style: const TextStyle(
                                                    color: AppColors.muted,
                                                    fontSize: 11)),
                                          if (!widget.admin &&
                                              row['read_at'] != null &&
                                              row['dismissed_at'] == null)
                                            Text(
                                                ux(context, 'Read', 'पढ़ा गया'),
                                                style: const TextStyle(
                                                    color: AppColors.primary,
                                                    fontSize: 11)),
                                          if (widget.admin)
                                            Text(
                                                ux(
                                                    context,
                                                    row['delivered_at'] == null
                                                        ? 'Scheduled'
                                                        : 'Delivered',
                                                    row['delivered_at'] == null
                                                        ? 'निर्धारित'
                                                        : 'भेजा गया'),
                                                style: const TextStyle(
                                                    color: AppColors.primary,
                                                    fontSize: 11)),
                                        ]),
                                  ])),
                            ]))),
                ])));
  }
}
