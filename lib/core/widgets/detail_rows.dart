import 'package:flutter/material.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';

/// Grey rounded card holding rows split by thin lines.
class DetailGroup extends StatelessWidget {
  const DetailGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: palette.border),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One tappable detail: an icon, the value (or a grey placeholder) and ›.
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.icon,
    required this.onTap,
    this.label,
    this.placeholder,
    this.leading,
    this.chevron = true,
    this.multiline = false,
  });

  final IconData icon;
  final String? label;
  final String? placeholder;
  final Widget? leading;
  final VoidCallback? onTap;
  final bool chevron;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final empty = label == null;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Icon(icon, color: palette.ink),
            const SizedBox(width: AppSpacing.md),
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpacing.sm),
            ],
            Expanded(
              child: Text(
                label ?? placeholder ?? '',
                maxLines: multiline ? 6 : 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodyLarge?.copyWith(
                  color: empty ? palette.textSecondary : palette.ink,
                ),
              ),
            ),
            if (chevron) Icon(Icons.chevron_right_rounded, color: palette.ink),
          ],
        ),
      ),
    );
  }
}

class DetailSwitchRow extends StatelessWidget {
  const DetailSwitchRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: context.palette.ink),
      title: Text(label),
      value: value,
      onChanged: onChanged,
    );
  }
}
