import 'package:flutter/material.dart';

import 'package:ngo_app/core/theme/app_theme.dart';

/// Keeps long forms readable on desktop without reducing mobile touch space.
class PageContent extends StatelessWidget {
  const PageContent({super.key, required this.child, this.maxWidth = 1040});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}

class ActionCard extends StatelessWidget {
  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(icon,
                      color: Theme.of(context).colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: AppSpacing.xs),
                      Text(description,
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      );
}

class ActionGrid extends StatelessWidget {
  const ActionGrid({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 850
              ? 3
              : constraints.maxWidth >= 560
                  ? 2
                  : 1;
          const gap = AppSpacing.md;
          final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: AppSpacing.sm,
            children: [
              for (final child in children) SizedBox(width: width, child: child)
            ],
          );
        },
      );
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, this.complete = false});

  final String label;
  final bool complete;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        child: Chip(
          avatar: Icon(
              complete ? Icons.check_circle_outline : Icons.info_outline,
              size: 18),
          label: Text(label),
          visualDensity: VisualDensity.compact,
        ),
      );
}
