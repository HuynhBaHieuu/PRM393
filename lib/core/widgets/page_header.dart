import 'package:flutter/material.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';

/// Large editorial title used at the top of each main tab.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.page,
      AppSpacing.md,
      AppSpacing.page,
      AppSpacing.md,
    ),
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.headlineLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(subtitle!, style: text.bodySmall),
                ],
              ],
            ),
          ),
          for (final action in actions) ...[
            const SizedBox(width: AppSpacing.xs),
            action,
          ],
        ],
      ),
    );
  }
}

/// Circular outlined icon button used in page headers.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.filled = false,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  /// Filled ink style for the primary action (e.g. add).
  final bool filled;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final button = IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: AppSizes.icon),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(AppSizes.headerActionSize),
        backgroundColor: filled ? palette.ink : palette.surface,
        foregroundColor: filled ? palette.onInk : palette.ink,
        side: filled ? null : BorderSide(color: palette.border),
      ),
    );
    if (badgeCount <= 0) return button;
    return Badge(
      label: Text('$badgeCount'),
      backgroundColor: palette.accent,
      textColor: palette.onInk,
      offset: const Offset(-2, 2),
      child: button,
    );
  }
}
