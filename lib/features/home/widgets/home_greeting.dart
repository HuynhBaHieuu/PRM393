import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/section_header.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/shared/closet_actions.dart';
import 'package:all_fits/navigation/app_navigation.dart';

class HomeGreeting extends StatelessWidget {
  const HomeGreeting({super.key});

  @override
  Widget build(BuildContext context) {
    final name = context.select<SettingsController, String>(
      (s) => s.displayName,
    );
    final today = context.read<ClosetActions>().today;
    final now = DateTime.now();
    final text = context.textTheme;
    final firstName = name.split(' ').first;
    final greeting = AppFormatters.greeting(now);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.lg,
        AppSpacing.page,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(AppFormatters.longDate(today)),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  firstName.isEmpty ? greeting : '$greeting, $firstName',
                  style: text.displaySmall,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'What are you wearing today?',
                  style: text.bodyLarge?.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          _AvatarButton(initials: AppFormatters.initials(name)),
        ],
      ),
    );
  }
}

class _AvatarButton extends StatelessWidget {
  const _AvatarButton({required this.initials});

  final String initials;

  static const double _size = 44;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: 'Open profile',
      child: InkWell(
        onTap: () => context.read<ShellController>().select(AppTab.profile),
        customBorder: const CircleBorder(),
        child: Container(
          width: _size,
          height: _size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: palette.surfaceMuted,
            shape: BoxShape.circle,
          ),
          child: initials.isEmpty
              ? const Icon(Icons.person_outline_rounded)
              : Text(initials, style: context.textTheme.titleSmall),
        ),
      ),
    );
  }
}
