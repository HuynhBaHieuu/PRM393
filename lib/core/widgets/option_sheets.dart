import 'package:flutter/material.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';

/// Fits' sheet layout: a centered title over a divider, scrolling content,
/// and a footer with a grey secondary button and a black "Done".
class OptionSheetFrame extends StatelessWidget {
  const OptionSheetFrame({
    super.key,
    required this.children,
    required this.onDone,
    this.title,
    this.secondaryLabel,
    this.onSecondary,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.page,
      AppSpacing.md,
      AppSpacing.page,
      AppSpacing.md,
    ),
  });

  final String? title;
  final List<Widget> children;
  final VoidCallback onDone;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final EdgeInsetsGeometry padding;

  static const double _maxHeightFraction = 0.85;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final maxHeight = MediaQuery.sizeOf(context).height * _maxHeightFraction;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(title!, style: context.textTheme.titleLarge),
            ),
            Divider(height: 1, color: palette.border),
          ],
          Flexible(
            child: SingleChildScrollView(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
          Divider(height: 1, color: palette.border),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.md,
                AppSpacing.page,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  if (secondaryLabel != null)
                    FilledButton(
                      onPressed: onSecondary,
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.surfaceMuted,
                        foregroundColor: palette.ink,
                      ),
                      child: Text(secondaryLabel!),
                    ),
                  const Spacer(),
                  FilledButton(onPressed: onDone, child: const Text('Done')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Section title used inside [OptionSheetFrame].
class OptionSheetLabel extends StatelessWidget {
  const OptionSheetLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg, bottom: AppSpacing.sm),
      child: Text(text, style: context.textTheme.titleMedium),
    );
  }
}

/// Full-width outlined pill that opens a picker, e.g. "Select brands". Shows
/// the current choice when there is one.
class SelectFieldButton extends StatelessWidget {
  const SelectFieldButton({
    super.key,
    required this.placeholder,
    required this.onTap,
    this.value,
  });

  final String placeholder;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSizes.compactButtonHeight + 8),
        side: BorderSide(color: palette.border, width: 1.5),
        shape: const StadiumBorder(),
        backgroundColor: palette.surface,
        foregroundColor: palette.ink,
      ),
      child: Text(
        value ?? placeholder,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// A list of options with round check marks, as in Fits' season and
/// category pickers. Resolves to the new selection, or null when dismissed.
Future<Set<T>?> showMultiSelectSheet<T>(
  BuildContext context, {
  required List<T> options,
  required Set<T> selected,
  required String Function(T option) labelOf,
  Widget? Function(T option)? leadingOf,
  String? title,
  bool single = false,
}) {
  return showModalBottomSheet<Set<T>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _MultiSelectSheet<T>(
      options: options,
      selected: selected,
      labelOf: labelOf,
      leadingOf: leadingOf,
      title: title,
      single: single,
    ),
  );
}

class _MultiSelectSheet<T> extends StatefulWidget {
  const _MultiSelectSheet({
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.single,
    this.leadingOf,
    this.title,
  });

  final List<T> options;
  final Set<T> selected;
  final String Function(T option) labelOf;
  final Widget? Function(T option)? leadingOf;
  final String? title;
  final bool single;

  @override
  State<_MultiSelectSheet<T>> createState() => _MultiSelectSheetState<T>();
}

class _MultiSelectSheetState<T> extends State<_MultiSelectSheet<T>> {
  late final Set<T> _selected = {...widget.selected};

  void _toggle(T option) {
    setState(() {
      if (widget.single) {
        final wasSelected = _selected.contains(option);
        _selected.clear();
        if (!wasSelected) _selected.add(option);
      } else if (!_selected.remove(option)) {
        _selected.add(option);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return OptionSheetFrame(
      title: widget.title,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      secondaryLabel: 'Clear selection',
      onSecondary: () => setState(_selected.clear),
      onDone: () => Navigator.of(context).pop(_selected),
      children: [
        for (final option in widget.options)
          ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.page,
            ),
            leading: widget.leadingOf?.call(option),
            title: Text(widget.labelOf(option)),
            trailing: RoundCheck(checked: _selected.contains(option)),
            onTap: () => _toggle(option),
          ),
      ],
    );
  }
}

/// Fits' round check: an empty grey ring, or a black disc with a tick.
class RoundCheck extends StatelessWidget {
  const RoundCheck({super.key, required this.checked, this.size = 28});

  final bool checked;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked ? palette.ink : palette.surface.withValues(alpha: 0.7),
        border: checked
            ? null
            : Border.all(color: palette.textTertiary, width: 1.5),
      ),
      child: checked
          ? Icon(Icons.check_rounded, size: size * 0.65, color: palette.onInk)
          : null,
    );
  }
}

/// Emoji shown as a leading icon, e.g. a season's 🌱.
class EmojiIcon extends StatelessWidget {
  const EmojiIcon(this.emoji, {super.key, this.size = 22});

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) =>
      Text(emoji, style: TextStyle(fontSize: size, height: 1));
}
