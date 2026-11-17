import 'dart:math' as math;
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ngo_app/core/i18n/language_menu.dart';
import 'package:ngo_app/core/theme/app_theme.dart';
import 'package:ngo_app/features/auth/application/auth_controller.dart';

String ux(BuildContext context, String en, String hi) =>
    context.locale.languageCode == 'hi' ? hi : en;

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.light = false, this.compact = false});
  final bool light, compact;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: light ? AppColors.lime : AppColors.primary,
                borderRadius: BorderRadius.circular(13)),
            child: Icon(Icons.spa_rounded,
                size: 24,
                color: light ? AppColors.primaryVariant : AppColors.lime)),
        if (!compact) ...[
          const SizedBox(width: 11),
          Text('saath',
              style: TextStyle(
                  fontSize: 27,
                  letterSpacing: -1.3,
                  fontWeight: FontWeight.w700,
                  color: light ? Colors.white : AppColors.onSurface))
        ],
      ]);
}

class WorkspaceShell extends ConsumerWidget {
  const WorkspaceShell({super.key, required this.child, required this.path});
  final Widget child;
  final String path;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = path.startsWith('/admin');
    final desktop = MediaQuery.sizeOf(context).width >= 1040;
    final destinations = admin
        ? [
            (
              Icons.space_dashboard_outlined,
              ux(context, 'Overview', 'अवलोकन'),
              '/admin'
            ),
            (
              Icons.people_outline_rounded,
              ux(context, 'People', 'टीम'),
              '/admin/fellows'
            ),
            (
              Icons.work_outline_rounded,
              ux(context, desktop ? 'Work & jobs' : 'Work', 'कार्य'),
              '/admin/jobs'
            ),
            (
              Icons.insights_outlined,
              ux(context, desktop ? 'Impact & reports' : 'Impact', 'प्रभाव'),
              '/admin/reports'
            ),
            (
              Icons.notifications_none_rounded,
              ux(context, 'Updates', 'अपडेट'),
              '/admin/notifications'
            )
          ]
        : [
            (
              Icons.space_dashboard_outlined,
              ux(context, 'My day', 'मेरा दिन'),
              '/onboarding'
            ),
            (
              Icons.work_outline_rounded,
              ux(context, 'My work', 'मेरा काम'),
              '/jobs'
            ),
            (
              Icons.people_outline_rounded,
              ux(context, 'Volunteers', 'स्वयंसेवक'),
              '/volunteers'
            ),
            (
              Icons.person_outline_rounded,
              ux(context, 'My profile', 'मेरी प्रोफ़ाइल'),
              '/profile'
            )
          ];
    var selected = 0;
    for (var i = 1; i < destinations.length; i++) {
      if (path.startsWith(destinations[i].$3)) selected = i;
    }
    final extras = admin
        ? <(IconData, String, String)>[]
        : [
            (
              Icons.folder_outlined,
              ux(context, 'Documents', 'दस्तावेज़'),
              '/documents'
            ),
            (
              Icons.notifications_none_rounded,
              ux(context, 'Updates', 'अपडेट'),
              '/notifications'
            )
          ];
    Widget navItem((IconData, String, String) item, bool active) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Material(
            color: active ? AppColors.lime : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.go(item.$3),
                child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 15),
                    child: Row(children: [
                      Icon(item.$1,
                          size: 21,
                          color: active
                              ? AppColors.primaryVariant
                              : Colors.white70),
                      const SizedBox(width: 13),
                      Expanded(
                          child: Text(item.$2,
                              style: TextStyle(
                                  color: active
                                      ? AppColors.primaryVariant
                                      : Colors.white70,
                                  fontSize: 14,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w500))),
                      if (active)
                        const Icon(Icons.arrow_forward_rounded,
                            size: 15, color: AppColors.primaryVariant),
                    ])))));
    return Scaffold(
      body: Row(children: [
        if (desktop)
          Container(
              width: 238,
              color: AppColors.primaryVariant,
              child: SafeArea(
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                                padding: EdgeInsets.only(left: 12),
                                child: BrandMark(light: true)),
                            const SizedBox(height: 9),
                            Padding(
                                padding: const EdgeInsets.only(left: 12),
                                child: Text(
                                    ux(context, 'PEOPLE. PURPOSE. PROGRESS.',
                                        'साथ मिलकर, आगे बढ़ें।'),
                                    style: const TextStyle(
                                        fontSize: 9,
                                        letterSpacing: 1.5,
                                        color: Color(0xFFAAC4AC)))),
                            const SizedBox(height: 44),
                            Padding(
                                padding:
                                    const EdgeInsets.only(left: 16, bottom: 17),
                                child: Text(
                                    ux(context, 'YOUR WORKSPACE',
                                        'आपका कार्यक्षेत्र'),
                                    style: const TextStyle(
                                        color: Color(0xFF92AD9B),
                                        fontSize: 10,
                                        letterSpacing: 1.6))),
                            for (var i = 0; i < destinations.length; i++)
                              navItem(
                                  destinations[i],
                                  i == selected &&
                                      !extras.any((x) => x.$3 == path)),
                            for (final item in extras)
                              navItem(item, item.$3 == path),
                            const Spacer(),
                            Container(
                                padding: const EdgeInsets.all(17),
                                decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: .06),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white12)),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.favorite_border_rounded,
                                          color: AppColors.lime, size: 24),
                                      const SizedBox(height: 12),
                                      Text(
                                          ux(
                                              context,
                                              'Small actions.\nLasting change.',
                                              'छोटे प्रयास।\nस्थायी बदलाव।'),
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 18,
                                              height: 1.3,
                                              fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 9),
                                      Text(
                                          ux(
                                              context,
                                              'A little more connected, every day.',
                                              'हर दिन, थोड़ा और जुड़ें।'),
                                          style: const TextStyle(
                                              color: Color(0xFFAAC4AC),
                                              fontSize: 12)),
                                    ])),
                            const SizedBox(height: 18),
                            TextButton.icon(
                                onPressed: () => ref
                                    .read(authControllerProvider.notifier)
                                    .logout(),
                                icon:
                                    const Icon(Icons.logout_rounded, size: 18),
                                label:
                                    Text(ux(context, 'Sign out', 'साइन आउट')),
                                style: TextButton.styleFrom(
                                    foregroundColor: Colors.white70)),
                          ])))),
        Expanded(
            child: Column(children: [
          Container(
              height: desktop ? 80 : 68,
              padding: EdgeInsets.symmetric(horizontal: desktop ? 36 : 18),
              decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(bottom: BorderSide(color: AppColors.line))),
              child: SafeArea(
                  bottom: false,
                  child: Row(children: [
                    if (!desktop)
                      const BrandMark()
                    else ...[
                      Text(ux(context, 'Workspace', 'कार्यक्षेत्र'),
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 13)),
                      const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(Icons.chevron_right,
                              size: 16, color: AppColors.muted)),
                      Text(destinations[selected].$2,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                    const Spacer(),
                    if (desktop)
                      Text(DateFormat('EEE, d MMM').format(DateTime.now()),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted)),
                    const SizedBox(width: 12),
                    const LanguageMenu(),
                    IconButton(
                        tooltip: ux(context, 'Updates', 'अपडेट'),
                        onPressed: () => context.go(
                            admin ? '/admin/notifications' : '/notifications'),
                        icon: const Icon(Icons.notifications_none_rounded,
                            size: 22)),
                    if (!desktop)
                      PopupMenuButton<String>(
                          tooltip: ux(context, 'More options', 'अन्य विकल्प'),
                          icon: const Icon(Icons.more_horiz),
                          onSelected: (value) {
                            if (value == 'logout') {
                              ref
                                  .read(authControllerProvider.notifier)
                                  .logout();
                            } else {
                              context.go(value);
                            }
                          },
                          itemBuilder: (_) => [
                                for (final item in extras)
                                  PopupMenuItem(
                                      value: item.$3, child: Text(item.$2)),
                                PopupMenuItem(
                                    value: 'logout',
                                    child: Text(
                                        ux(context, 'Sign out', 'साइन आउट')))
                              ])
                    else
                      Container(
                          margin: const EdgeInsets.only(left: 16),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: AppColors.lime.withValues(alpha: .4),
                              borderRadius: BorderRadius.circular(12)),
                          child: Text(admin ? 'NGO' : 'ME',
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w700))),
                  ]))),
          Expanded(child: Semantics(container: true, child: child)),
        ])),
      ]),
      bottomNavigationBar: desktop
          ? null
          : NavigationBar(
              height: 72,
              selectedIndex: selected,
              onDestinationSelected: (i) => context.go(destinations[i].$3),
              destinations: [
                  for (final item in destinations)
                    NavigationDestination(icon: Icon(item.$1), label: item.$2)
                ]),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title,
      {super.key, this.subtitle, this.action, this.onAction});
  final String title;
  final String? subtitle, action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                style: const TextStyle(color: AppColors.muted, fontSize: 13))
          ]
        ])),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ]));
}

class SurfacePanel extends StatelessWidget {
  const SurfacePanel(
      {super.key,
      required this.child,
      this.padding = 24,
      this.color = AppColors.surface});
  final Widget child;
  final double padding;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.line)),
      child: child);
}

class MetricCard extends StatelessWidget {
  const MetricCard(
      {super.key,
      required this.label,
      required this.value,
      required this.icon,
      required this.note,
      this.accent = AppColors.primary});
  final String label, value, note;
  final IconData icon;
  final Color accent;
  @override
  Widget build(BuildContext context) => SurfacePanel(
      padding: 20,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(label,
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 13))),
          Icon(icon, color: accent, size: 21)
        ]),
        const SizedBox(height: 17),
        Text(value,
            style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w600,
                letterSpacing: -1.4,
                height: 1.1)),
        const SizedBox(height: 9),
        Text(note, style: TextStyle(fontSize: 11, color: accent)),
      ]));
}

class ResponsiveColumns extends StatelessWidget {
  const ResponsiveColumns(
      {super.key,
      required this.children,
      this.columns = 4,
      this.breakpoint = 680});
  final List<Widget> children;
  final int columns;
  final double breakpoint;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final count = box.maxWidth >= breakpoint
            ? columns
            : (box.maxWidth >= 300 && columns > 2 ? 2 : 1);
        return Wrap(spacing: 16, runSpacing: 16, children: [
          for (final child in children)
            SizedBox(
                width: (box.maxWidth - (count - 1) * 16) / count, child: child)
        ]);
      });
}

class GrowthArtwork extends StatelessWidget {
  const GrowthArtwork({super.key, this.size = 240});
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: size, height: size, child: CustomPaint(painter: _GrowthPainter()));
}

class _GrowthPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final center = Offset(s * .5, s * .52);
    final line = Paint()
      ..color = const Color(0xFFB4C5A3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final r in [.28, .41, .49]) {
      canvas.drawCircle(center, s * r, line);
    }
    final stem = Paint()
      ..color = AppColors.lime
      ..strokeWidth = s * .018
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(
        Path()
          ..moveTo(s * .50, s * .86)
          ..cubicTo(s * .43, s * .60, s * .62, s * .41, s * .49, s * .15),
        stem);
    for (var i = 0; i < 5; i++) {
      canvas.save();
      canvas.translate(
          s * (.49 + (i.isEven ? .015 : .04)), s * (.29 + i * .105));
      canvas.rotate(i.isEven ? -.65 : math.pi + .55);
      final leaf = Path()
        ..moveTo(0, 0)
        ..cubicTo(s * .03, -s * .19, s * .25, -s * .19, s * .25, -s * .10)
        ..cubicTo(s * .19, s * .03, s * .05, s * .06, 0, 0);
      canvas.drawPath(leaf,
          Paint()..color = i.isEven ? AppColors.lime : const Color(0xFF87AF83));
      canvas.restore();
    }
    for (final item in [(0.12, 0.37), (0.81, 0.26), (0.82, 0.78)]) {
      canvas.drawCircle(Offset(s * item.$1, s * item.$2), s * .028,
          Paint()..color = AppColors.peach);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class JobTile extends StatelessWidget {
  const JobTile(
      {super.key, required this.job, required this.onTap, this.admin = false});
  final Map<String, dynamic> job;
  final VoidCallback onTap;
  final bool admin;
  @override
  Widget build(BuildContext context) {
    final status = '${job['status']}';
    final color = status == 'approved'
        ? AppColors.primary
        : status == 'submitted'
            ? const Color(0xFF856126)
            : status == 'rejected'
                ? AppColors.error
                : const Color(0xFF54708C);
    final label = switch (status) {
      'assigned' => ux(context, 'To do', 'करना है'),
      'in_progress' => ux(context, 'In progress', 'प्रगति में'),
      'submitted' => ux(context, 'In review', 'समीक्षाधीन'),
      'approved' => ux(context, 'Completed', 'पूर्ण'),
      'rejected' => ux(context, 'Changes needed', 'बदलाव ज़रूरी'),
      _ => status
    };
    final deadline = DateTime.tryParse('${job['deadline']}');
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.line)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
                onTap: onTap,
                child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                  color: color.withValues(alpha: .09),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Icon(
                                  status == 'approved'
                                      ? Icons.check_rounded
                                      : Icons.work_outline_rounded,
                                  color: color,
                                  size: 21)),
                          const SizedBox(width: 15),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text('${job['title']}',
                                    style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 7),
                                Wrap(
                                    spacing: 12,
                                    runSpacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 9, vertical: 4),
                                          decoration: BoxDecoration(
                                              color:
                                                  color.withValues(alpha: .08),
                                              borderRadius:
                                                  BorderRadius.circular(6)),
                                          child: Text(label,
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: color))),
                                      Text(
                                          admin
                                              ? '${job['assigned_to_name'] ?? ''}'
                                              : '${job['expected_hours']} ${ux(context, 'hours', 'घंटे')}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.muted)),
                                      if (deadline != null)
                                        Text(
                                            '${ux(context, 'Due', 'अंतिम तिथि')} ${DateFormat('d MMM').format(deadline)}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.muted)),
                                    ]),
                              ])),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded,
                              size: 18, color: AppColors.muted),
                        ])))));
  }
}

class QuietState extends StatelessWidget {
  const QuietState(
      {super.key,
      required this.title,
      required this.message,
      this.icon = Icons.check_circle_outline,
      this.action,
      this.onAction});
  final String title, message;
  final IconData icon;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: AppColors.primary, size: 36),
        const SizedBox(height: 14),
        Text(title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted)),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ]));
}
