import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ngo_app/core/theme/app_theme.dart';
import 'package:ngo_app/core/theme/responsive_widgets.dart';
import 'package:ngo_app/core/theme/workspace.dart';
import 'package:ngo_app/features/admin/application/admin_providers.dart';
import 'package:ngo_app/features/reporting/block_filter.dart';

class FellowDirectoryScreen extends ConsumerStatefulWidget {
  const FellowDirectoryScreen({super.key});
  @override
  ConsumerState<FellowDirectoryScreen> createState() => _DirectoryState();
}

class _DirectoryState extends ConsumerState<FellowDirectoryScreen> {
  int? block;
  String search = '';
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar:
            AppBar(title: Text(ux(context, 'People & fellows', 'टीम और साथी'))),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          SectionHeading(
              ux(context, 'People make the difference.',
                  'लोग ही बदलाव लाते हैं।'),
              subtitle: ux(
                  context,
                  'Get to know your fellows and help them move forward.',
                  'साथियों को जानें और आगे बढ़ने में उनका साथ दें।')),
          Wrap(spacing: 16, runSpacing: 16, children: [
            SizedBox(
                width: 360,
                child: TextField(
                    onChanged: (value) =>
                        setState(() => search = value.toLowerCase()),
                    decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: ux(context, 'Search by name or email',
                            'नाम या ईमेल से खोजें')))),
            BlockFilter(
                value: block,
                onChanged: (value) => setState(() => block = value))
          ]),
          const SizedBox(height: 24),
          ref.watch(filteredFellowListProvider(block)).when(
              loading: () => const LinearProgressIndicator(),
              error: (e, s) => QuietState(
                  title: ux(context, 'Couldn’t load fellows',
                      'साथियों की सूची लोड नहीं हुई'),
                  message: ux(context, 'Please try again.', 'फिर कोशिश करें।'),
                  action: ux(context, 'Retry', 'पुनः प्रयास'),
                  onAction: () =>
                      ref.invalidate(filteredFellowListProvider(block))),
              data: (fellows) {
                final visible = fellows
                    .where((f) => '${f.fullName} ${f.email}'
                        .toLowerCase()
                        .contains(search))
                    .toList();
                return Column(children: [
                  if (visible.isEmpty)
                    QuietState(
                        title: ux(context, 'No matches yet', 'कोई परिणाम नहीं'),
                        message: ux(context, 'Try another name or block.',
                            'दूसरा नाम या क्षेत्र चुनें।'),
                        icon: Icons.people_outline),
                  for (final f in visible)
                    Card(
                        child: ListTile(
                            contentPadding: const EdgeInsets.all(18),
                            leading: CircleAvatar(
                                backgroundColor:
                                    AppColors.lime.withValues(alpha: .5),
                                foregroundColor: AppColors.primary,
                                child: Text(
                                    (f.fullName.isEmpty ? f.email : f.fullName)
                                        .substring(0, 1)
                                        .toUpperCase())),
                            title: Text(
                                f.fullName.isEmpty ? f.email : f.fullName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Padding(
                                padding: const EdgeInsets.only(top: 7),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(f.email,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.muted)),
                                      const SizedBox(height: 8),
                                      StatusBadge(
                                          label: ux(
                                              context,
                                              f.onboardingStep == 'active'
                                                  ? 'All set'
                                                  : 'Getting started',
                                              f.onboardingStep == 'active'
                                                  ? 'सब तैयार है'
                                                  : 'शुरुआत में'),
                                          complete:
                                              f.onboardingStep == 'active')
                                    ])),
                            trailing: const Icon(Icons.arrow_forward, size: 18),
                            onTap: () =>
                                context.push('/admin/fellows/${f.id}'))),
                ]);
              }),
        ]),
      );
}
