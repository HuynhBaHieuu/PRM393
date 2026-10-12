import 'package:flutter/material.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';

/// Friendly placeholder for empty sections, with an optional call to action.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  /// Smaller variant for use inside page sections.
  final bool compact;

  static const double _iconCircle = 88;
  static const double _compactIconCircle = 60;
  static const double _maxWidth = 320;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    final circle = compact ? _compactIconCircle : _iconCircle;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: compact ? AppSpacing.lg : AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: circle,
                height: circle,
                decoration: BoxDecoration(
                  color: palette.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: compact ? AppSizes.iconLg : AppSizes.iconXl,
                  color: palette.textSecondary,
                ),
              ),
              SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: compact ? text.titleLarge : text.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: palette.textSecondary),
              ),
              if (actionLabel != null && onAction != null) ...[
                SizedBox(height: compact ? AppSpacing.md : AppSpacing.lg),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
              if (secondaryActionLabel != null &&
                  onSecondaryAction != null) ...[
                const SizedBox(height: AppSpacing.xs),
                TextButton(
                  onPressed: onSecondaryAction,
                  child: Text(secondaryActionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
