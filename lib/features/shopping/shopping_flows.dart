import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/app_dialogs.dart';
import 'package:all_fits/data/models/shopping_item.dart';
import 'package:all_fits/features/shared/closet_flows.dart';
import 'package:all_fits/features/shopping/controllers/shopping_controller.dart';
import 'package:all_fits/features/wardrobe/controllers/clothing_draft.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';

/// Shopping list UI flows: each combines dialogs, a [ShoppingController]
/// call and user feedback.
abstract final class ShoppingFlows {
  /// Ticks an item off (or back onto) the list. Ticking off offers to add
  /// the piece to the wardrobe straight away.
  static Future<void> setPurchased(
    BuildContext context,
    ShoppingItem item, {
    required bool purchased,
  }) async {
    // Ticking moves the tile to the other tab, unmounting [context] before
    // the snackbar action can run; the navigator's context outlives it.
    final stableContext = Navigator.of(context).context;
    try {
      await context.read<ShoppingController>().setPurchased(
        item.id,
        purchased: purchased,
      );
      if (!context.mounted) return;
      if (purchased && item.wardrobeItemId == null) {
        context.showSnack(
          'Marked as bought',
          actionLabel: 'Add to wardrobe',
          onAction: () {
            if (stableContext.mounted) addToWardrobe(stableContext, item);
          },
        );
      } else {
        context.showSnack(purchased ? 'Marked as bought' : 'Back on your list');
      }
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
    }
  }

  /// Opens the add-clothing form prefilled from [item], then links the new
  /// wardrobe piece back to it.
  static Future<void> addToWardrobe(
    BuildContext context,
    ShoppingItem item,
  ) async {
    final shopping = context.read<ShoppingController>();
    final wardrobeItemId = await AppNavigator.addClothing(
      context,
      initial: ClothingDraft(
        name: item.name,
        category: item.category,
        color: item.color,
        brand: item.brand,
        price: item.price,
        notes: item.notes,
      ),
    );
    if (wardrobeItemId == null || !context.mounted) return;
    await ClosetFlows.guard(
      context,
      () => shopping.linkToWardrobe(item.id, wardrobeItemId),
    );
  }

  /// True when [item] has a wardrobe piece that still exists.
  static bool isInWardrobe(BuildContext context, ShoppingItem item) {
    final id = item.wardrobeItemId;
    return id != null &&
        context.read<WardrobeController>().itemById(id) != null;
  }

  static Future<bool> deleteItem(
    BuildContext context,
    ShoppingItem item,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove from list?',
      message: '“${item.name}” will be removed from your shopping list.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return false;
    try {
      await context.read<ShoppingController>().deleteItem(item.id);
      if (context.mounted) context.showSnack('Removed from your list');
      return true;
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
      return false;
    }
  }

  static Future<void> clearPurchased(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Clear bought items?',
      message:
          'Bought items will be removed from this list. '
          'Pieces you added to your wardrobe stay there.',
      confirmLabel: 'Clear',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await ClosetFlows.guard(
      context,
      context.read<ShoppingController>().clearPurchased,
      successMessage: 'Bought items cleared',
    );
  }
}
