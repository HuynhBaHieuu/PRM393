import 'package:flutter/material.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/constants/app_durations.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';

/// Selectable chip: ink when selected, a soft grey fill otherwise.
class SelectablePill extends StatelessWidget {
  const SelectablePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  static const double _height = 36;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final foreground = selected ? palette.onInk : palette.ink;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: AnimatedContainer(
            duration: AppDurations.fast,
            height: _height,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: selected ? palette.ink : palette.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: AppSpacing.xs),
                ],
                Text(
                  label,
                  style: context.textTheme.labelLarge?.copyWith(
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A wrapping group of [SelectablePill]s for enum-like options.
class PillGroup<T> extends StatelessWidget {
  const PillGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onToggle,
    this.leadingOf,
  });

  final List<T> options;
  final Set<T> selected;
  final String Function(T option) labelOf;
  final ValueChanged<T> onToggle;
  final Widget? Function(T option)? leadingOf;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final option in options)
          SelectablePill(
            label: labelOf(option),
            selected: selected.contains(option),
            leading: leadingOf?.call(option),
            onTap: () => onToggle(option),
          ),
      ],
    );
  }
}

/// A single horizontally scrolling row of pills.
class PillBar extends StatelessWidget {
  const PillBar({
    super.key,
    required this.pills,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.page),
  });

  final List<Widget> pills;
  final EdgeInsetsGeometry padding;

  static const double _height = 36;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: pills.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (_, index) => pills[index],
      ),
    );
  }
}
