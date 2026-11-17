import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ngo_app/core/theme/app_theme.dart';
import 'package:ngo_app/core/theme/responsive_widgets.dart';
import 'package:ngo_app/core/theme/workspace.dart';
import 'package:ngo_app/features/admin/application/admin_providers.dart';
import 'package:ngo_app/features/jobs/application/jobs_providers.dart';
import 'package:ngo_app/features/profile/application/profile_controller.dart';

final overviewJobsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, bool>((ref, admin) async {
  ref.watch(workRevisionProvider);
  final repo = ref.watch(jobsRepositoryProvider);
  return Future.wait([
    repo.list(mine: !admin),
    repo.list(mine: !admin, status: 'submitted'),
    repo.list(mine: !admin, status: 'approved')
  ]);
});

class WorkspaceOverview extends ConsumerWidget {
  const WorkspaceOverview({super.key, this.admin = false});
  final bool admin;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(overviewJobsProvider(admin));
    final profile =
        admin ? null : ref.watch(profileControllerProvider).asData?.value;
    final fellows = admin ? ref.watch(fellowListProvider).asData?.value : null;
    final data = jobs.asData?.value;
    final rows =
        (data?[0]['results'] as List? ?? []).cast<Map<String, dynamic>>();
    final pending =
        (data?[1]['results'] as List? ?? []).cast<Map<String, dynamic>>();
    final total = data?[0]['count'] as int?;
    final approved = data?[2]['count'] as int?;
    final awaiting = data?[1]['count'] as int?;
    final name = profile?.fullName.trim().split(' ').first ?? '';
    final ready = profile != null &&
        profile.isComplete &&
        profile.onboardingStep == 'active';
    final workPath = admin ? '/admin/jobs' : '/jobs';
    final hPadding = MediaQuery.sizeOf(context).width > 800 ? 36.0 : 20.0;
    return Scaffold(
        body: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(overviewJobsProvider(admin));
              if (admin) ref.invalidate(fellowListProvider);
              await ref.read(overviewJobsProvider(admin).future);
            },
            child: ListView(
                padding: EdgeInsets.fromLTRB(hPadding, 30, hPadding, 32),
                children: [
                  LayoutBuilder(
                      builder: (context, box) => Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(
                                          ux(
                                              context,
                                              admin
                                                  ? 'THE BIG PICTURE'
                                                  : 'MAKE TODAY MATTER',
                                              admin
                                                  ? 'एक नज़र में'
                                                  : 'आज कुछ अच्छा करें'),
                                          style: const TextStyle(
                                              fontSize: 10,
                                              letterSpacing: 1.8,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.muted)),
                                      const SizedBox(height: 9),
                                      Text(
                                          admin
                                              ? ux(
                                                  context,
                                                  'Good work starts here.',
                                                  'अच्छे काम की शुरुआत यहाँ से।')
                                              : ux(
                                                  context,
                                                  name.isEmpty
                                                      ? 'A little progress, every day.'
                                                      : 'Good to see you, $name.',
                                                  name.isEmpty
                                                      ? 'हर दिन, थोड़ी तरक्की।'
                                                      : '$name, आपका स्वागत है।'),
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineLarge
                                              ?.copyWith(
                                                  fontSize: box.maxWidth < 600
                                                      ? 29
                                                      : 36)),
                                      const SizedBox(height: 9),
                                      Text(
                                          ux(
                                              context,
                                              admin
                                                  ? 'Your people, their progress, and what needs a little attention.'
                                                  : 'Your work, your community, and the next small step forward.',
                                              admin
                                                  ? 'आपकी टीम, उनकी प्रगति, और ज़रूरी काम।'
                                                  : 'आपका काम, आपका समुदाय और अगला कदम।'),
                                          style: const TextStyle(
                                              color: AppColors.muted,
                                              fontSize: 14)),
                                    ])),
                                if (box.maxWidth > 720) ...[
                                  const SizedBox(width: 20),
                                  FilledButton.icon(
                                      onPressed: () => context.push(
                                          admin ? '/admin/jobs/new' : '/jobs'),
                                      icon: Icon(
                                          admin
                                              ? Icons.add
                                              : Icons.arrow_forward_rounded,
                                          size: 18),
                                      label: Text(ux(
                                          context,
                                          admin
                                              ? 'Assign work'
                                              : 'View my work',
                                          admin
                                              ? 'कार्य सौंपें'
                                              : 'मेरा काम देखें')))
                                ],
                              ])),
                  const SizedBox(height: 28),
                  Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                          color: AppColors.primaryVariant,
                          borderRadius: BorderRadius.circular(24)),
                      child: LayoutBuilder(
                          builder: (context, box) => Stack(children: [
                                if (box.maxWidth > 620)
                                  Positioned(
                                      right: 15,
                                      top: -22,
                                      child: Opacity(
                                          opacity: .85,
                                          child: GrowthArtwork(
                                              size: box.maxWidth > 900
                                                  ? 265
                                                  : 220))),
                                Padding(
                                    padding: const EdgeInsets.all(28),
                                    child: SizedBox(
                                        width: box.maxWidth > 620
                                            ? box.maxWidth * .62
                                            : double.infinity,
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(children: [
                                                Container(
                                                    width: 6,
                                                    height: 6,
                                                    decoration:
                                                        const BoxDecoration(
                                                            color:
                                                                AppColors.lime,
                                                            shape: BoxShape
                                                                .circle)),
                                                const SizedBox(width: 8),
                                                Text(
                                                    ux(
                                                        context,
                                                        'CONNECTED BY PURPOSE',
                                                        'एक उद्देश्य, एक साथ'),
                                                    style: const TextStyle(
                                                        color: AppColors.lime,
                                                        fontSize: 9,
                                                        letterSpacing: 1.7,
                                                        fontWeight:
                                                            FontWeight.w600))
                                              ]),
                                              const SizedBox(height: 16),
                                              Text(
                                                  ux(
                                                      context,
                                                      admin
                                                          ? 'Every effort deserves\nto move forward.'
                                                          : 'Your next step makes\na real difference.',
                                                      admin
                                                          ? 'हर प्रयास को\nआगे बढ़ने दें।'
                                                          : 'आपका हर कदम\nबदलाव लाता है।'),
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 29,
                                                      height: 1.18,
                                                      letterSpacing: -.7,
                                                      fontWeight:
                                                          FontWeight.w500)),
                                              const SizedBox(height: 14),
                                              Text(
                                                  ux(
                                                      context,
                                                      admin
                                                          ? 'Keep work moving. Support your fellows.\nSee the difference you’re making together.'
                                                          : 'Pick up an assignment, share your progress,\nand stay connected with your team.',
                                                      admin
                                                          ? 'कार्य आगे बढ़ाएँ। साथियों का साथ दें।\nमिलकर किए काम का असर देखें।'
                                                          : 'कार्य चुनें, अपनी प्रगति साझा करें\nऔर टीम से जुड़े रहें।'),
                                                  style: const TextStyle(
                                                      color: Color(0xFFBECEBF),
                                                      fontSize: 13,
                                                      height: 1.6)),
                                              const SizedBox(height: 19),
                                              FilledButton.icon(
                                                  style: FilledButton.styleFrom(
                                                      backgroundColor:
                                                          AppColors.lime,
                                                      foregroundColor: AppColors
                                                          .primaryVariant,
                                                      minimumSize:
                                                          const Size(0, 44)),
                                                  onPressed: () => context.go(
                                                      admin && (awaiting ?? 0) > 0
                                                          ? '$workPath?status=submitted'
                                                          : workPath),
                                                  icon: const Icon(Icons.arrow_forward_rounded,
                                                      size: 17),
                                                  label: Text(ux(
                                                      context,
                                                      admin && (awaiting ?? 0) > 0
                                                          ? 'Open review queue'
                                                          : 'Explore your work',
                                                      admin ? 'कार्य देखें' : 'अपना काम देखें'))),
                                            ]))),
                              ]))),
                  const SizedBox(height: 24),
                  ResponsiveColumns(children: [
                    MetricCard(
                        label: ux(
                            context,
                            admin ? 'Fellows connected' : 'Your assignments',
                            admin ? 'जुड़े साथी' : 'आपके कार्य'),
                        value: admin
                            ? '${fellows?.length ?? '—'}'
                            : '${total ?? '—'}',
                        icon: admin ? Icons.people_outline : Icons.work_outline,
                        note: ux(
                            context,
                            admin
                                ? 'People behind the progress'
                                : 'Everything in one place',
                            admin ? 'प्रगति के पीछे लोग' : 'सब कुछ एक जगह')),
                    MetricCard(
                        label: ux(
                            context, 'Awaiting review', 'समीक्षा की प्रतीक्षा'),
                        value: '${awaiting ?? '—'}',
                        icon: Icons.fact_check_outlined,
                        note: ux(
                            context,
                            admin
                                ? 'Ready for your attention'
                                : 'Your team will take a look',
                            admin
                                ? 'आपकी समीक्षा के लिए तैयार'
                                : 'आपकी टीम समीक्षा करेगी'),
                        accent: const Color(0xFF8B642C)),
                    MetricCard(
                        label: ux(context, 'Work completed', 'पूर्ण कार्य'),
                        value: '${approved ?? '—'}',
                        icon: Icons.check_circle_outline,
                        note: ux(context, 'Reviewed and approved',
                            'समीक्षित और स्वीकृत')),
                    MetricCard(
                        label: ux(
                            context,
                            admin
                                ? 'Active assignments'
                                : 'Work to move forward',
                            admin ? 'सक्रिय कार्य' : 'आगे बढ़ाने वाले कार्य'),
                        value: total == null
                            ? '—'
                            : '${total - (approved ?? 0) - (awaiting ?? 0)}',
                        icon: Icons.trending_up,
                        note: ux(context, 'The next opportunity to help',
                            'मदद का अगला अवसर'),
                        accent: AppColors.secondary),
                  ]),
                  const SizedBox(height: 30),
                  LayoutBuilder(builder: (context, box) {
                    final main = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeading(
                              ux(
                                  context,
                                  admin
                                      ? 'A little attention goes a long way'
                                      : 'Your work, at a glance',
                                  admin
                                      ? 'आपकी समीक्षा, उनकी प्रगति'
                                      : 'आपके काम की एक झलक'),
                              subtitle: ux(
                                  context,
                                  admin
                                      ? 'Submissions ready for your review.'
                                      : 'Open an assignment to see what’s next.',
                                  admin
                                      ? 'समीक्षा के लिए तैयार कार्य।'
                                      : 'अगला कदम जानने के लिए कार्य खोलें।'),
                              action: ux(context, 'View all', 'सभी देखें'),
                              onAction: () => context.go(admin
                                  ? '$workPath?status=submitted'
                                  : workPath)),
                          if (jobs.isLoading) const LinearProgressIndicator(),
                          if (jobs.hasError)
                            QuietState(
                                title: ux(context, 'Couldn’t load your work',
                                    'काम लोड नहीं हुआ'),
                                message: ux(context, 'Please try again.',
                                    'फिर कोशिश करें।'),
                                action: ux(context, 'Retry', 'पुनः प्रयास'),
                                onAction: () =>
                                    ref.invalidate(overviewJobsProvider(admin)))
                          else if ((admin ? pending : rows).isEmpty &&
                              !jobs.isLoading)
                            QuietState(
                                title: ux(
                                    context,
                                    admin
                                        ? 'You’re all caught up'
                                        : 'A fresh start',
                                    admin
                                        ? 'सभी समीक्षाएँ पूरी हैं'
                                        : 'नई शुरुआत'),
                                message: ux(
                                    context,
                                    admin
                                        ? 'New submissions will appear here.'
                                        : 'Your assignments will appear here when your team assigns work.',
                                    admin
                                        ? 'नए कार्य यहाँ दिखेंगे।'
                                        : 'टीम द्वारा सौंपे गए कार्य यहाँ दिखेंगे।'))
                          else
                            for (final job in (admin ? pending : rows).take(4))
                              JobTile(
                                  job: job,
                                  admin: admin,
                                  onTap: () =>
                                      context.push('$workPath/${job['id']}')),
                          if (!admin && !ready)
                            Padding(
                                padding: const EdgeInsets.only(top: 14),
                                child: SurfacePanel(
                                    color:
                                        AppColors.peach.withValues(alpha: .45),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              ux(
                                                  context,
                                                  'Let’s finish your introduction',
                                                  'अपना परिचय पूरा करें'),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium),
                                          const SizedBox(height: 8),
                                          Text(ux(
                                              context,
                                              'A few profile details help your team get to know you.',
                                              'प्रोफ़ाइल पूरी करने से टीम आपको बेहतर जान सकेगी।')),
                                          TextButton.icon(
                                              onPressed: () =>
                                                  context.go('/profile'),
                                              icon: const Icon(
                                                  Icons.arrow_forward,
                                                  size: 16),
                                              label: Text(ux(
                                                  context,
                                                  'Complete profile',
                                                  'प्रोफ़ाइल पूरी करें'))),
                                        ]))),
                        ]);
                    final side = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeading(ux(context, 'Made for your everyday',
                              'आपके रोज़मर्रा के लिए')),
                          SurfacePanel(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Icon(
                                    admin
                                        ? Icons.insights_rounded
                                        : Icons.folder_open_rounded,
                                    color: AppColors.primary,
                                    size: 27),
                                const SizedBox(height: 17),
                                Text(
                                    ux(
                                        context,
                                        admin
                                            ? 'See your collective impact'
                                            : 'Your essentials, together',
                                        admin
                                            ? 'मिलकर किए काम का असर'
                                            : 'आपकी ज़रूरी चीज़ें, एक साथ'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium),
                                const SizedBox(height: 8),
                                Text(
                                    ux(
                                        context,
                                        admin
                                            ? 'Explore progress across blocks, people and approved work.'
                                            : 'Keep documents and volunteer details close at hand.',
                                        admin
                                            ? 'क्षेत्र, टीम और स्वीकृत कार्यों की प्रगति देखें।'
                                            : 'दस्तावेज़ और स्वयंसेवकों की जानकारी साथ रखें।'),
                                    style: const TextStyle(
                                        color: AppColors.muted, fontSize: 13)),
                                const SizedBox(height: 16),
                                _QuickLink(
                                    icon: admin
                                        ? Icons.bar_chart
                                        : Icons.description_outlined,
                                    title: ux(
                                        context,
                                        admin
                                            ? 'Open impact report'
                                            : 'My documents',
                                        admin
                                            ? 'प्रभाव रिपोर्ट खोलें'
                                            : 'मेरे दस्तावेज़'),
                                    onTap: () => context.go(admin
                                        ? '/admin/reports'
                                        : '/documents')),
                                if (!admin)
                                  _QuickLink(
                                      icon: Icons.groups_outlined,
                                      title: ux(context, 'My volunteers',
                                          'मेरे स्वयंसेवक'),
                                      onTap: () => context.go('/volunteers')),
                                if (!admin && ready)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: StatusBadge(
                                          label: ux(context, 'All set',
                                              'सब तैयार है'),
                                          complete: true)),
                              ])),
                          const SizedBox(height: 16),
                          SurfacePanel(
                              color: const Color(0xFFEAF0DF),
                              padding: 20,
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                        Icons.notifications_active_outlined,
                                        color: AppColors.primary,
                                        size: 23),
                                    const SizedBox(height: 12),
                                    Text(
                                        ux(
                                            context,
                                            'One less thing to remember.',
                                            'याद रखने की एक चीज़ कम।'),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    const SizedBox(height: 8),
                                    Text(
                                        ux(
                                            context,
                                            'Job reminders arrive automatically: when work is assigned, a day before it’s due, on the due date, and once if overdue.',
                                            'कार्य मिलने पर, अंतिम तिथि से एक दिन पहले, उस दिन और देरी होने पर एक बार सूचनाएँ मिलेंगी।'),
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.muted,
                                            height: 1.6)),
                                  ])),
                        ]);
                    return box.maxWidth >= 850
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Expanded(flex: 7, child: main),
                                const SizedBox(width: 26),
                                Expanded(flex: 4, child: side)
                              ])
                        : Column(
                            children: [main, const SizedBox(height: 24), side]);
                  }),
                ])));
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink(
      {required this.icon, required this.title, required this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 19, color: AppColors.primary),
      title: Text(title,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.arrow_forward, size: 16),
      onTap: onTap);
}
