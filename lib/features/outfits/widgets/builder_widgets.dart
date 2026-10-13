import 'package:flutter/material.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/outfit_slot.dart';

/// One tappable tile per outfit slot, showing how many pieces it holds.
class SlotSelector extends StatelessWidget {
  const SlotSelector({
    super.key,
    required this.countOf,
    required this.onSelect,
  });

  final int Function(OutfitSlot slot) countOf;
  final ValueChanged<OutfitSlot> onSelect;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final slot in OutfitSlot.values)
          Builder(
            builder: (context) {
              final count = countOf(slot);
              final active = count > 0;
              return ActionChip(
                onPressed: () => onSelect(slot),
                avatar: Icon(
                  active ? Icons.check_rounded : Icons.add_rounded,
                  size: AppSizes.iconSm,
                  color: active ? palette.onInk : palette.ink,
                ),
                label: Text(active ? '${slot.label} · $count' : slot.label),
                labelStyle: text.labelLarge?.copyWith(
                  color: active ? palette.onInk : palette.ink,
                ),
                backgroundColor: active ? palette.ink : palette.surface,
                side: BorderSide(color: active ? palette.ink : palette.border),
                shape: const RoundedRectangleBorder(),
              );
            },
          ),
      ],
    );
  }
}

/// Reorderable list of the pieces in an outfit, top to bottom.
class CompositionList extends StatelessWidget {
  const CompositionList({
    super.key,
    required this.items,
    required this.onReorderItem,
    required this.onReplace,
    required this.onRemove,
  });

  final List<ClothingItem> items;

  /// Receives the target index already adjusted for the removed item.
  final ReorderCallback onReorderItem;
  final ValueChanged<ClothingItem> onReplace;
  final ValueChanged<ClothingItem> onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: items.length,
      onReorderItem: onReorderItem,
      proxyDecorator: (child, index, animation) => Material(
        color: palette.surface,
        elevation: 4,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: child,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return _CompositionRow(
          key: ValueKey(item.id),
          index: index,
          item: item,
          onReplace: () => onReplace(item),
          onRemove: () => onRemove(item),
        );
      },
    );
  }
}

class _CompositionRow extends StatelessWidget {
  const _CompositionRow({
    super.key,
    required this.index,
    required this.item,
    required this.onReplace,
    required this.onRemove,
  });

  final int index;
  final ClothingItem item;
  final VoidCallback onReplace;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
                child: Icon(
                  Icons.drag_indicator_rounded,
                  color: palette.textTertiary,
                  semanticLabel: 'Drag to reorder',
                ),
              ),
            ),
            SizedBox.square(
              dimension: AppSizes.thumbMd,
              child: ClothingImage(
                item: item,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                decodeWidth: AppSizes.thumbMd,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: text.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    OutfitSlot.forCategory(item.category).label,
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Replace',
              icon: const Icon(Icons.swap_horiz_rounded),
              onPressed: onReplace,
            ),
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.close_rounded),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}
