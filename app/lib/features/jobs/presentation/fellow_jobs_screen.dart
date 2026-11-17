import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ngo_app/core/theme/workspace.dart';
import 'package:ngo_app/core/theme/app_theme.dart';
import 'package:ngo_app/features/jobs/application/jobs_providers.dart';

class FellowJobsScreen extends ConsumerStatefulWidget {
  const FellowJobsScreen({super.key});
  @override
  ConsumerState<FellowJobsScreen> createState() => _JobsState();
}

class _JobsState extends ConsumerState<FellowJobsScreen> {
  late Future<Map<String, dynamic>> jobs;
  String? status;
  int page = 1;
  @override
  void initState() {
    super.initState();
    load();
  }

  void load() => jobs = ref
      .read(jobsRepositoryProvider)
      .list(mine: true, status: status, page: page);
  void reload() => setState(load);
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar:
            AppBar(title: Text(ux(context, 'My work', 'मेरा काम')), actions: [
          IconButton(
              onPressed: reload,
              tooltip: ux(context, 'Refresh', 'ताज़ा करें'),
              icon: const Icon(Icons.refresh))
        ]),
        body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        ux(context, 'Small steps. Meaningful progress.',
                            'छोटे कदम। सार्थक प्रगति।'),
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 7),
                    Text(
                        ux(
                            context,
                            'Everything you’re working on, from first step to final review.',
                            'पहले कदम से अंतिम समीक्षा तक, आपके सभी कार्य।'),
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 13)),
                    const SizedBox(height: 20),
                    SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(children: [
                          for (final item in <(String?, String, String)>[
                            (null, 'All work', 'सभी'),
                            ('assigned', 'To do', 'करना है'),
                            ('in_progress', 'In progress', 'प्रगति में'),
                            ('submitted', 'In review', 'समीक्षाधीन'),
                            ('approved', 'Completed', 'पूर्ण'),
                            ('rejected', 'Needs changes', 'बदलाव ज़रूरी')
                          ])
                            Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                    label: Text(ux(context, item.$2, item.$3)),
                                    selected: status == item.$1,
                                    onSelected: (_) => setState(() {
                                          status = item.$1;
                                          page = 1;
                                          load();
                                        }))),
                        ])),
                  ])),
          Expanded(
              child: FutureBuilder<Map<String, dynamic>>(
                  future: jobs,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return QuietState(
                          title: ux(context, 'Couldn’t load your work',
                              'कार्य लोड नहीं हुए'),
                          message: ux(
                              context, 'Please try again.', 'फिर कोशिश करें।'),
                          action: ux(context, 'Retry', 'पुनः प्रयास'),
                          onAction: reload);
                    }
                    final data = snap.data!;
                    final rows =
                        (data['results'] as List).cast<Map<String, dynamic>>();
                    return Column(children: [
                      Expanded(
                          child: RefreshIndicator(
                              onRefresh: () async {
                                reload();
                                await jobs;
                              },
                              child: ListView(
                                  padding:
                                      const EdgeInsets.fromLTRB(24, 8, 24, 24),
                                  children: [
                                    if (rows.isEmpty)
                                      QuietState(
                                          title: ux(
                                              context,
                                              'A clear space for what’s next',
                                              'अगले काम के लिए तैयार'),
                                          message: ux(
                                              context,
                                              'Assignments in this stage will appear here.',
                                              'इस स्थिति के कार्य यहाँ दिखेंगे।'),
                                          icon: Icons.work_outline),
                                    for (final job in rows)
                                      JobTile(
                                          job: job,
                                          onTap: () async {
                                            await context
                                                .push('/jobs/${job['id']}');
                                            if (mounted) reload();
                                          }),
                                  ]))),
                      if (page > 1 || data['next'] != null)
                        Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                  tooltip: ux(
                                      context, 'Previous page', 'पिछला पृष्ठ'),
                                  onPressed: page > 1
                                      ? () => setState(() {
                                            page--;
                                            load();
                                          })
                                      : null,
                                  icon: const Icon(Icons.chevron_left)),
                              Text('$page'),
                              IconButton(
                                  tooltip:
                                      ux(context, 'Next page', 'अगला पृष्ठ'),
                                  onPressed: data['next'] != null
                                      ? () => setState(() {
                                            page++;
                                            load();
                                          })
                                      : null,
                                  icon: const Icon(Icons.chevron_right))
                            ]),
                    ]);
                  })),
        ]),
      );
}
