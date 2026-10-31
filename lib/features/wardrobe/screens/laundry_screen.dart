import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/layout.dart';
import 'package:all_fits/core/widgets/option_sheets.dart';
import 'package:all_fits/core/widgets/section_header.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/laundry_status.dart';
import 'package:all_fits/features/shared/closet_flows.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/features/wardrobe/widgets/clothing_grid.dart';

/// The laundry basket: pieces in the hamper and in the wash. Worn pieces
/// land here on their own (see [ClothingItem.afterWear]) and stay out of
/// outfit ideas until they are marked clean.
class LaundryScreen extends StatelessWidget {
  const LaundryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeController>();
    final items = wardrobe.laundryItems;
    final hamper = [
      for (final item in items)
        if (item.laundry == LaundryStatus.dirty) item,
    ];
    final washing = [
      for (final item in items)
        if (item.laundry == LaundryStatus.washing) item,
    ];
    final insets = pageInsets(context.screenSize.width);

    return Scaffold(
      appBar: AppBar(title: const Text('Laundry')),
      body: items.isEmpty
          ? const AppEmptyState(
              icon: Icons.local_laundry_service_outlined,
              title: 'Nothing to wash',
              message:
                  'Pieces you wear go in the hamper on their own: tops after '
                  'one wear, bottoms after three. They’re left out of outfit '
                  'ideas until they’re clean again.',
            )
          : CustomScrollView(
              slivers: [
                if (hamper.isNotEmpty) ...[
                  _header(
                    context,
                    title: 'In the hamper',
                    count: hamper.length,
                    actionLabel: 'Start a wash',
                    onAction: () => _move(
                      context,
                      hamper,
                      LaundryStatus.washing,
                      message: 'Washing ${_pieces(hamper.length)}',
                    ),
                  ),
                  _grid(context, hamper, insets),
                ],
                if (washing.isNotEmpty) ...[
                  _header(
                    context,
                    title: 'In the wash',
                    count: washing.length,
                    actionLabel: 'All clean',
                    onAction: () => _move(
                      context,
                      washing,
                      LaundryStatus.clean,
                      message: '${_pieces(washing.length)} back in rotation',
                    ),
                  ),
                  _grid(context, washing, insets),
                ],
                const SliverToBoxAdapter(
                  child: SizedBox(height: AppSpacing.xxl),
                ),
              ],
            ),
    );
  }

  static String _pieces(int count) => AppFormatters.count(count, 'piece');

  Widget _header(
    BuildContext context, {
    required String title,
    required int count,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.md,
          bottom: AppSpacing.xs,
        ),
        child: SectionHeader(
          title: '$title  $count',
          actionLabel: actionLabel,
          onAction: onAction,
        ),
      ),
    );
  }

  Widget _grid(
    BuildContext context,
    List<ClothingItem> items,
    EdgeInsets insets,
  ) {
    return SliverPadding(
      padding: insets.copyWith(bottom: AppSpacing.md),
      sliver: ClothingSliverGrid(
        items: items,
        onTap: (item) => _openActions(context, item),
      ),
    );
  }

  Future<void> _openActions(BuildContext context, ClothingItem item) async {
    final next = await showModalBottomSheet<LaundryStatus?>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.laundry != LaundryStatus.clean)
                SheetActionTile(
                  icon: Icons.check_circle_outline_rounded,
                  label: 'Mark clean',
                  onTap: () =>
                      Navigator.of(sheetContext).pop(LaundryStatus.clean),
                ),
              if (item.laundry == LaundryStatus.dirty)
                SheetActionTile(
                  icon: Icons.local_laundry_service_outlined,
                  label: 'Put in the wash',
                  onTap: () =>
                      Navigator.of(sheetContext).pop(LaundryStatus.washing),
                ),
              if (item.laundry == LaundryStatus.washing)
                SheetActionTile(
                  icon: Icons.shopping_basket_outlined,
                  label: 'Back to the hamper',
                  onTap: () =>
                      Navigator.of(sheetContext).pop(LaundryStatus.dirty),
                ),
              SheetActionTile(
                icon: Icons.open_in_new_rounded,
                label: 'Open ${item.name}',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  AppNavigator.clothingDetail(context, item.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
    if (next == null || !context.mounted) return;
    await _move(context, [item], next, message: '${item.name}: ${next.label}');
  }

  /// Moves [items] to [status], with an undo on the snack bar.
  static Future<void> _move(
    BuildContext context,
    List<ClothingItem> items,
    LaundryStatus status, {
    required String message,
  }) async {
    final wardrobe = context.read<WardrobeController>();
    var previous = const <ClothingItem>[];
    final done = await ClosetFlows.guard(
      context,
      () async => previous = await wardrobe.setLaundry([
        for (final item in items) item.id,
      ], status),
    );
    if (!done || !context.mounted) return;
    context.showSnack(
      message,
      actionLabel: 'Undo',
      onAction: () =>
          ClosetFlows.guard(context, () => wardrobe.restoreLaundry(previous)),
    );
  }
}
