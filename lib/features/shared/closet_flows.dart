import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/date_helpers.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/app_dialogs.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/outfit.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/widgets/outfit_cards.dart';
import 'package:all_fits/features/shared/closet_actions.dart';

/// UI flows shared by several screens: each combines dialogs, a
/// [ClosetActions] call and user feedback. They return true on success.
abstract final class ClosetFlows {
  /// Asks for a date and plans [outfitId] on it.
  static Future<bool> planOutfit(BuildContext context, String outfitId) async {
    final closet = context.read<ClosetActions>();
    final today = closet.today;
    final date = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today,
      lastDate: DateHelpers.addDays(today, AppConfig.plannerRangeDays),
      helpText: 'Plan outfit for',
      confirmText: 'Plan',
    );
    if (date == null || !context.mounted) return false;
    return planOutfitOn(context, outfitId, date);
  }

  static Future<bool> planOutfitOn(
    BuildContext context,
    String outfitId,
    DateTime date,
  ) async {
    try {
      await context.read<ClosetActions>().planOutfit(outfitId, date);
      if (context.mounted) {
        context.showSnack(
          'Planned for ${AppFormatters.relativeDay(date).toLowerCase()}',
        );
      }
      return true;
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
      return false;
    }
  }

  /// Lets the user choose an outfit, then plans it for [date].
  static Future<bool> pickAndPlan(BuildContext context, DateTime date) async {
    final outfitId = await _pickOutfit(context, 'Plan an outfit');
    if (outfitId == null || !context.mounted) return false;
    return planOutfitOn(context, outfitId, date);
  }

  /// Lets the user choose an outfit, then logs it as worn on [date].
  static Future<bool> pickAndMarkWorn(
    BuildContext context,
    DateTime date,
  ) async {
    final outfitId = await _pickOutfit(context, 'What did you wear?');
    if (outfitId == null || !context.mounted) return false;
    return markWorn(context, outfitId, date: date);
  }

  static Future<bool> markWorn(
    BuildContext context,
    String outfitId, {
    DateTime? date,
  }) async {
    try {
      final result = await context.read<ClosetActions>().markWorn(
        outfitId,
        date: date,
      );
      if (context.mounted) {
        context.showSnack(
          result == WearResult.alreadyWorn
              ? 'Already marked as worn'
              : 'Marked as worn',
        );
      }
      return result == WearResult.marked;
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
      return false;
    }
  }

  /// Confirms, then permanently deletes [item] and removes it from outfits.
  static Future<bool> deleteItem(
    BuildContext context,
    ClothingItem item,
  ) async {
    final usedIn = context.read<OutfitController>().outfitsUsingItem(item.id);
    final message = usedIn.isEmpty
        ? 'This will permanently remove “${item.name}” and its photo.'
        : '“${item.name}” is used in '
              '${AppFormatters.count(usedIn.length, 'outfit')}. It will be '
              'removed from ${usedIn.length == 1 ? 'it' : 'them'} too.';
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete item?',
      message: message,
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return false;
    try {
      await context.read<ClosetActions>().deleteItemPermanently(item.id);
      if (context.mounted) context.showSnack('Item deleted');
      return true;
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
      return false;
    }
  }

  /// Confirms, then deletes [outfit] together with its calendar entries.
  static Future<bool> deleteOutfit(BuildContext context, Outfit outfit) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete outfit?',
      message:
          '“${outfit.name}” will be removed along with its plans. '
          'Your clothes stay in your wardrobe.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return false;
    try {
      await context.read<ClosetActions>().deleteOutfit(outfit.id);
      if (context.mounted) context.showSnack('Outfit deleted');
      return true;
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
      return false;
    }
  }

  static Future<String?> _pickOutfit(BuildContext context, String title) {
    return showOutfitPickerSheet(
      context,
      title: title,
      outfits: context.read<OutfitController>().outfits,
      onCreateOutfit: () => AppNavigator.createOutfit(context),
    );
  }

  /// Runs a simple action, reporting failures in a snackbar.
  static Future<void> guard(
    BuildContext context,
    Future<void> Function() action, {
    String? successMessage,
  }) async {
    try {
      await action();
      if (successMessage != null && context.mounted) {
        context.showSnack(successMessage);
      }
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
    }
  }
}
