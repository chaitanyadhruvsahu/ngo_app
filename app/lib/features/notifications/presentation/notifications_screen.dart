import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:ngo_app/core/theme/workspace.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ngo_app/core/api/api_exception.dart';
import 'package:ngo_app/core/i18n/translator.dart';
import 'package:ngo_app/features/notifications/data/notifications_repository.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key, this.admin = false});
  final bool admin;
  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsState();
}

class _NotificationsState extends ConsumerState<NotificationsScreen> {
  List<Map<String, dynamic>>? rows;
  String? error;
  var month = DateTime(DateTime.now().year, DateTime.now().month);
  bool busy = false;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
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
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.userMessage);
    }
  }

  Future<void> mark(String id, bool dismiss) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await ref
          .read(notificationsRepositoryProvider)
          .mark(id, dismiss: dismiss);
      await load();
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.userMessage);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.locale.languageCode == 'hi' ? 'hi' : 'en';
    final visible = (rows ?? []).where((row) {
      final date = DateTime.parse(row['scheduled_time'] as String).toLocal();
      return date.year == month.year && date.month == month.month;
    }).toList()
      ..sort((a, b) => (a['scheduled_time'] as String)
          .compareTo(b['scheduled_time'] as String));
    return Scaffold(
      appBar: AppBar(title: Text(t('notifications.title')), actions: [
        IconButton(
            tooltip: t('notifications.refresh'),
            onPressed: load,
            icon: const Icon(Icons.refresh))
      ]),
      floatingActionButton: widget.admin
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                        builder: (_) => const NotificationCreateScreen()));
                if (created == true) load();
              },
              icon: const Icon(Icons.add),
              label: Text(t('notifications.create')))
          : null,
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconButton(
                      tooltip: t('notifications.previous'),
                      onPressed: () => setState(
                          () => month = DateTime(month.year, month.month - 1)),
                      icon: const Icon(Icons.chevron_left)),
                  Flexible(
                      child: Text(
                          DateFormat.yMMMM(context.locale.toString())
                              .format(month),
                          style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(
                      tooltip: t('notifications.next'),
                      onPressed: () => setState(
                          () => month = DateTime(month.year, month.month + 1)),
                      icon: const Icon(Icons.chevron_right)),
                ]),
                if (error != null)
                  Padding(
                      padding: const EdgeInsets.all(16), child: Text(error!)),
                if (rows == null && error == null)
                  const CircularProgressIndicator(),
                if (rows != null && visible.isEmpty)
                  Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(t('notifications.empty'))),
                Expanded(
                    child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final row = visible[index];
                          final date =
                              DateTime.parse(row['scheduled_time'] as String)
                                  .toLocal();
                          return Card(
                              child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            DateFormat.yMMMEd(
                                                    context.locale.toString())
                                                .add_jm()
                                                .format(date),
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleSmall),
                                        Text(t('notifications.${row['type']}')),
                                        Text(row['title_$language'] as String,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleLarge),
                                        const SizedBox(height: 8),
                                        Text(row['body_$language'] as String),
                                        if (widget.admin)
                                          Text(row['delivered_at'] == null
                                              ? t('notifications.scheduled')
                                              : t('notifications.delivered')),
                                        if (!widget.admin)
                                          Wrap(spacing: 8, children: [
                                            if (row['read_at'] == null)
                                              TextButton(
                                                  onPressed: busy
                                                      ? null
                                                      : () => mark(
                                                          row['id'] as String,
                                                          false),
                                                  child: Text(t(
                                                      'notifications.mark_read'))),
                                            if (row['dismissed_at'] == null)
                                              TextButton(
                                                  onPressed: busy
                                                      ? null
                                                      : () => mark(
                                                          row['id'] as String,
                                                          true),
                                                  child: Text(t(
                                                      'notifications.dismiss')))
                                            else
                                              Text(
                                                  t('notifications.dismissed')),
                                            if (row['read_at'] != null &&
                                                row['dismissed_at'] == null)
                                              Text(t('notifications.read')),
                                          ]),
                                      ])));
                        })),
              ]))),
    );
  }
}

class NotificationCreateScreen extends ConsumerStatefulWidget {
  const NotificationCreateScreen({super.key});
  @override
  ConsumerState<NotificationCreateScreen> createState() => _CreateState();
}

class _CreateState extends ConsumerState<NotificationCreateScreen> {
  final form = GlobalKey<FormState>();
  final fields = {
    for (final key in ['title_en', 'body_en']) key: TextEditingController()
  };
  List<Map<String, dynamic>>? people, blocks;
  String type = 'training', target = 'block';
  String? targetId, error;
  int reminder = 0;
  bool scheduleLater = false;
  DateTime? scheduled = DateTime.now();
  bool saving = false;
  @override
  void initState() {
    super.initState();
    loadTargets();
  }

  Future<void> loadTargets() async {
    try {
      final repo = ref.read(notificationsRepositoryProvider);
      final result = await Future.wait(
          [repo.pages('/admin/notifications/targets'), repo.blocks()]);
      if (mounted) {
        setState(() {
          people = result[0];
          blocks = result[1];
          error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.userMessage);
    }
  }

  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> pickDate() async {
    final date = await showDatePicker(
        context: context,
        initialDate: scheduled ?? DateTime.now(),
        firstDate: DateTime.now().subtract(const Duration(days: 1)),
        lastDate: DateTime.now().add(const Duration(days: 3650)));
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(scheduled ?? DateTime.now()));
    if (time != null && mounted) {
      setState(() => scheduled =
          DateTime(date.year, date.month, date.day, time.hour, time.minute));
    }
  }

  Future<void> save() async {
    if (saving) return;
    if (!form.currentState!.validate()) return;
    if (scheduled == null) {
      setState(() => error = t('notifications.choose_time'));
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await ref.read(notificationsRepositoryProvider).create({
        'type': type,
        'channel': 'in_app',
        'scheduled_time': (scheduleLater ? scheduled! : DateTime.now())
            .toUtc()
            .toIso8601String(),
        'remind_before': '${reminder ~/ 24} ${reminder % 24}:00:00',
        'target_$target': targetId,
        for (final entry in fields.entries) entry.key: entry.value.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => error = e.userMessage);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final targets = target == 'block' ? blocks : people;
    return Scaffold(
        appBar: AppBar(title: const Text('Send announcement')),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: Form(
                    key: form,
                    child:
                        ListView(padding: const EdgeInsets.all(24), children: [
                      const SectionHeading('Keep your team in the loop',
                          subtitle:
                              'Write once, in English. Job reminders are sent automatically.'),
                      SurfacePanel(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                            TextFormField(
                                controller: fields['title_en'],
                                maxLength: 200,
                                decoration: const InputDecoration(
                                    labelText: 'Title',
                                    hintText: 'e.g. Team meeting this Friday',
                                    counterText: ''),
                                validator: _requiredAnnouncement),
                            const SizedBox(height: 20),
                            TextFormField(
                                controller: fields['body_en'],
                                minLines: 4,
                                maxLines: 10,
                                maxLength: 4000,
                                decoration: const InputDecoration(
                                    labelText: 'Message',
                                    hintText:
                                        'What does your team need to know?',
                                    alignLabelWithHint: true),
                                validator: _requiredAnnouncement),
                          ])),
                      const SizedBox(height: 20),
                      SurfacePanel(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                            const SectionHeading('Who should receive it?'),
                            DropdownButtonFormField<String>(
                                initialValue: target,
                                decoration: const InputDecoration(
                                    labelText: 'Audience'),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'block', child: Text('A block')),
                                  DropdownMenuItem(
                                      value: 'user', child: Text('One person'))
                                ],
                                onChanged: saving
                                    ? null
                                    : (value) => setState(() {
                                          target = value!;
                                          targetId = null;
                                        })),
                            const SizedBox(height: 20),
                            if (targets == null && error == null)
                              const LinearProgressIndicator(),
                            DropdownButtonFormField<String>(
                                key: ValueKey(target),
                                initialValue: targetId,
                                isExpanded: true,
                                decoration: InputDecoration(
                                    labelText: target == 'block'
                                        ? 'Choose block'
                                        : 'Choose person'),
                                items: (targets ?? [])
                                    .map((row) => DropdownMenuItem(
                                        value: row['id'] as String,
                                        child: Text(
                                            target == 'block'
                                                ? 'Block ${row['number']}'
                                                : row['email'] as String,
                                            overflow: TextOverflow.ellipsis)))
                                    .toList(),
                                onChanged: saving || targets == null
                                    ? null
                                    : (value) =>
                                        setState(() => targetId = value),
                                validator: (value) => value == null
                                    ? 'Choose a recipient.'
                                    : null),
                          ])),
                      const SizedBox(height: 20),
                      SurfacePanel(
                          padding: 8,
                          child: ExpansionTile(
                              title: const Text('Timing & category'),
                              subtitle: Text(scheduleLater
                                  ? 'Scheduled announcement'
                                  : 'Send now · Training'),
                              childrenPadding: const EdgeInsets.all(16),
                              children: [
                                DropdownButtonFormField<String>(
                                    initialValue: type,
                                    decoration: const InputDecoration(
                                        labelText: 'Category'),
                                    items: ['training', 'event', 'deadline']
                                        .map((value) => DropdownMenuItem(
                                            value: value,
                                            child: Text(
                                                t('notifications.$value'))))
                                        .toList(),
                                    onChanged: saving
                                        ? null
                                        : (value) =>
                                            setState(() => type = value!)),
                                SwitchListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: const Text('Schedule for later'),
                                    value: scheduleLater,
                                    onChanged: saving
                                        ? null
                                        : (value) => setState(
                                            () => scheduleLater = value)),
                                if (scheduleLater)
                                  OutlinedButton.icon(
                                      onPressed: saving ? null : pickDate,
                                      icon: const Icon(Icons.calendar_month),
                                      label: Text(DateFormat.yMMMd()
                                          .add_jm()
                                          .format(scheduled!))),
                              ])),
                      if (error != null)
                        Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(error!,
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error))),
                      if (targets == null && error != null)
                        TextButton(
                            onPressed: loadTargets,
                            child: const Text('Retry loading recipients')),
                      const SizedBox(height: 24),
                      Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                              onPressed:
                                  saving || targets == null ? null : save,
                              icon: Icon(scheduleLater
                                  ? Icons.schedule
                                  : Icons.send_outlined),
                              label: Text(saving
                                  ? 'Sending…'
                                  : scheduleLater
                                      ? 'Schedule announcement'
                                      : 'Send announcement'))),
                      const SizedBox(height: 24),
                    ])))));
  }
}

String? _requiredAnnouncement(String? value) =>
    value == null || value.trim().isEmpty ? 'This field is required.' : null;
