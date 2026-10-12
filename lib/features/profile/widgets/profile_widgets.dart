import 'package:flutter/material.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/formatters.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.name,
    required this.username,
    required this.onEdit,
    this.email,
  });

  final String name;
  final String username;
  final String? email;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    final initials = AppFormatters.initials(name);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xl,
        AppSpacing.page,
        0,
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: AppSizes.avatar / 2,
            backgroundColor: palette.surfaceMuted,
            foregroundColor: palette.ink,
            child: initials.isEmpty
                ? Icon(
                    Icons.person_outline_rounded,
                    size: AppSizes.iconXl,
                    color: palette.textSecondary,
                  )
                : Text(initials, style: text.headlineMedium),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            name.isEmpty ? 'Your name' : name,
            style: text.headlineMedium?.copyWith(
              color: name.isEmpty ? palette.textTertiary : palette.ink,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            username.isEmpty ? 'Add a username' : '@$username',
            style: text.bodyMedium?.copyWith(color: palette.textSecondary),
          ),
          if (email != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(email!, style: text.bodySmall),
          ],
          const SizedBox(height: AppSpacing.md),
          OutlinedButton(
            onPressed: onEdit,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, AppSizes.compactButtonHeight),
            ),
            child: const Text('Edit profile'),
          ),
        ],
      ),
    );
  }
}

class ProfileStatsRow extends StatelessWidget {
  const ProfileStatsRow({super.key, required this.stats});

  final List<(int value, String label)> stats;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: palette.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0) VerticalDivider(color: palette.border, width: 1),
              Expanded(
                child: Column(
                  children: [
                    Text('${stats[i].$1}', style: text.headlineSmall),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(stats[i].$2.toUpperCase(), style: text.labelSmall),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ProfileMenuTile extends StatelessWidget {
  const ProfileMenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailingText,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle!),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailingText != null)
                Text(trailingText!, style: context.textTheme.bodySmall),
              Icon(Icons.chevron_right_rounded, color: palette.textTertiary),
            ],
          ),
          onTap: onTap,
        ),
        const Divider(indent: AppSpacing.page, endIndent: AppSpacing.page),
      ],
    );
  }
}
