import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/models/outfit_slot.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/features/wardrobe/widgets/clothing_grid.dart';

/// Lets the user pick wardrobe items for one outfit slot, or from the whole
/// wardrobe when [slot] is null.
///
/// In multi-select mode resolves to the full selection for the slot; in
/// [single] mode (replacing a piece) resolves to a one-element list.
/// Resolves to null when dismissed.
Future<List<String>?> showItemPickerSheet(
  BuildContext context, {
  required OutfitSlot? slot,
  Set<String> selected = const {},
  bool single = false,
  VoidCallback? onAddClothing,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ItemPickerSheet(
      slot: slot,
      initialSelection: selected,
      single: single,
      onAddClothing: onAddClothing,
    ),
  );
}

class _ItemPickerSheet extends StatefulWidget {
  const _ItemPickerSheet({
    required this.slot,
    required this.initialSelection,
    required this.single,
    this.onAddClothing,
  });

  final OutfitSlot? slot;
  final Set<String> initialSelection;
  final bool single;
  final VoidCallback? onAddClothing;

  @override
  State<_ItemPickerSheet> createState() => _ItemPickerSheetState();
}

class _ItemPickerSheetState extends State<_ItemPickerSheet> {
  late final Set<String> _selected = {...widget.initialSelection};

  void _toggle(String id) {
    if (widget.single) {
      Navigator.of(context).pop([id]);
      return;
    }
    setState(
      () => _selected.contains(id) ? _selected.remove(id) : _selected.add(id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slot = widget.slot;
    final items = context
        .watch<WardrobeController>()
        .activeItems
        .where((item) => slot?.categories.contains(item.category) ?? true)
        .toList();
    final what = slot?.label.toLowerCase() ?? 'pieces';
    final title = widget.single ? 'Replace $what' : 'Choose $what';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          SheetHeader(title: title),
          Expanded(
            child: items.isEmpty
                ? SingleChildScrollView(
                    controller: scrollController,
                    child: AppEmptyState(
                      compact: true,
                      icon: Icons.checkroom_outlined,
                      title: 'Nothing here yet',
                      message:
                          'Add $what to your wardrobe to use them in '
                          'outfits.',
                      actionLabel: widget.onAddClothing == null
                          ? null
                          : 'Add Clothing',
                      onAction: widget.onAddClothing == null
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              widget.onAddClothing!();
                            },
                    ),
                  )
                : CustomScrollView(
                    controller: scrollController,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.page,
                          0,
                          AppSpacing.page,
                          AppSpacing.xl,
                        ),
                        sliver: ClothingSliverGrid(
                          items: items,
                          isSelected: (item) => _selected.contains(item.id),
                          onTap: (item) => _toggle(item.id),
                        ),
                      ),
                    ],
                  ),
          ),
          if (!widget.single && items.isNotEmpty)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.sm,
                  AppSpacing.page,
                  AppSpacing.md,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () =>
                        Navigator.of(context).pop(_selected.toList()),
                    child: Text(
                      _selected.isEmpty
                          ? 'Done'
                          : 'Done · ${AppFormatters.count(items.where((i) => _selected.contains(i.id)).length, 'piece')}',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
