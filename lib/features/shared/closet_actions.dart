import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/utils/date_helpers.dart';
import 'package:all_fits/core/utils/id_generator.dart';
import 'package:all_fits/data/models/outfit_calendar_entry.dart';
import 'package:all_fits/data/sample/sample_data.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/planner/controllers/planner_controller.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';

enum WearResult { marked, alreadyWorn }

/// Operations that span several controllers, keeping wardrobe items,
/// outfits and the calendar consistent with each other.
class ClosetActions {
  ClosetActions({
    required this.wardrobe,
    required this.outfits,
    required this.planner,
    IdGenerator idGenerator = const UuidIdGenerator(),
    this._clock = systemClock,
  }) : _ids = idGenerator;

  final WardrobeController wardrobe;
  final OutfitController outfits;
  final PlannerController planner;
  final IdGenerator _ids;
  final Clock _clock;

  DateTime get today => DateHelpers.dateOnly(_clock());

  /// Records that [outfitId] was worn on [date] (defaults to today):
  /// updates the calendar plus outfit and item wear statistics.
  Future<WearResult> markWorn(String outfitId, {DateTime? date}) async {
    final day = DateHelpers.dateOnly(date ?? _clock());
    final outfit = outfits.outfitById(outfitId);
    if (outfit == null) {
      throw const NotFoundException('This outfit no longer exists.');
    }
    if (day.isAfter(today)) {
      throw const ValidationException(
        'Outfits can only be marked as worn for today or earlier.',
      );
    }

    final plan = planner.dayPlan(day);
    final worn = plan.worn;
    if (worn != null && worn.outfitId == outfitId) {
      return WearResult.alreadyWorn;
    }
    // One worn outfit per day: replacing it reverses the previous wear.
    if (worn != null) await unmarkWorn(worn);

    final planned = plan.planned;
    final entry = planned != null && planned.outfitId == outfitId
        ? planned.copyWith(status: CalendarEntryStatus.worn)
        : OutfitCalendarEntry(
            id: _ids.next(),
            date: day,
            outfitId: outfitId,
            status: CalendarEntryStatus.worn,
          );
    await planner.saveEntry(entry);
    await outfits.recordWear(outfitId, day);
    await wardrobe.recordWear(outfit.itemIds, day);
    return WearResult.marked;
  }

  /// Removes a worn entry and reverses the wear statistics it added.
  Future<void> unmarkWorn(OutfitCalendarEntry entry) async {
    await planner.removeEntry(entry.id);
    final outfit = outfits.outfitById(entry.outfitId);
    if (outfit == null) return;

    final remaining = planner.wornEntries;
    await outfits.revertWear(
      outfit.id,
      lastWornAt: remaining
          .where((e) => e.outfitId == outfit.id)
          .map((e) => e.date)
          .firstOrNull,
    );

    final lastWornByItem = <String, DateTime?>{};
    for (final itemId in outfit.itemIds) {
      lastWornByItem[itemId] = remaining
          .where(
            (e) =>
                outfits.outfitById(e.outfitId)?.itemIds.contains(itemId) ??
                false,
          )
          .map((e) => e.date)
          .firstOrNull;
    }
    await wardrobe.revertWear(lastWornByItem);
  }

  Future<OutfitCalendarEntry> planOutfit(String outfitId, DateTime date) {
    if (outfits.outfitById(outfitId) == null) {
      throw const NotFoundException('This outfit no longer exists.');
    }
    return planner.planOutfit(date, outfitId);
  }

  /// Deletes an item and removes it from every outfit that used it.
  Future<void> deleteItemPermanently(String itemId) async {
    await outfits.removeItemReferences(itemId);
    await wardrobe.deleteItem(itemId);
  }

  /// Deletes an outfit along with its plans and wear entries.
  Future<void> deleteOutfit(String outfitId) async {
    await planner.removeEntriesForOutfit(outfitId);
    await outfits.deleteOutfit(outfitId);
  }

  bool get hasSampleData =>
      wardrobe.allItems.any((item) => SampleData.isSampleId(item.id));

  Future<void> loadSampleData() async {
    final now = _clock();
    await wardrobe.importItems(SampleData.items(now));
    await outfits.importOutfits(SampleData.outfits(now));
    for (final (daysAgo, outfitId) in SampleData.wearHistory) {
      await markWorn(outfitId, date: DateHelpers.addDays(today, -daysAgo));
    }
    for (final (daysAhead, outfitId) in SampleData.plans) {
      final date = DateHelpers.addDays(today, daysAhead);
      if (planner.dayPlan(date).planned == null) {
        await planner.planOutfit(date, outfitId);
      }
    }
  }

  Future<void> removeSampleData() async {
    final outfitIds = outfits.outfits
        .map((o) => o.id)
        .where(SampleData.isSampleId)
        .toList();
    for (final id in outfitIds) {
      await deleteOutfit(id);
    }
    final itemIds = wardrobe.allItems
        .map((i) => i.id)
        .where(SampleData.isSampleId)
        .toList();
    for (final id in itemIds) {
      await outfits.removeItemReferences(id);
    }
    await wardrobe.deleteItems(itemIds);
  }

  Future<void> eraseAllData() async {
    await planner.clearAll();
    await outfits.clearAll();
    await wardrobe.clearAll();
  }
}
