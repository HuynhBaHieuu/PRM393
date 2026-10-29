import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/outfit.dart';
import 'package:all_fits/data/models/trip.dart';

/// One piece to pack, and on how many days of the trip it is worn.
class PackingLine {
  const PackingLine({
    required this.item,
    required this.days,
    required this.packed,
  });

  final ClothingItem item;
  final int days;
  final bool packed;
}

/// Everything to put in the suitcase for a [Trip], worked out from the
/// outfits planned on its days. A piece worn on several days is listed
/// once, with the number of days. Outfits or pieces deleted since are
/// left out.
class PackingList {
  factory PackingList.of(
    Trip trip, {
    required Outfit? Function(String id) outfitById,
    required ClothingItem? Function(String id) itemById,
  }) {
    final daysByItem = <String, int>{};
    for (final day in trip.days) {
      final outfitId = trip.outfitOn(day);
      final outfit = outfitId == null ? null : outfitById(outfitId);
      if (outfit == null) continue;
      for (final itemId in outfit.itemIds.toSet()) {
        daysByItem[itemId] = (daysByItem[itemId] ?? 0) + 1;
      }
    }
    final packed = trip.packedItemIds.toSet();
    final lines = [
      for (final MapEntry(key: id, value: days) in daysByItem.entries)
        if (itemById(id) case final item?)
          PackingLine(item: item, days: days, packed: packed.contains(id)),
    ];
    // Category order, then in the order the pieces are first worn.
    final order = {for (final (i, line) in lines.indexed) line.item.id: i};
    lines.sort((a, b) {
      final byCategory = a.item.category.index.compareTo(b.item.category.index);
      return byCategory != 0
          ? byCategory
          : order[a.item.id]!.compareTo(order[b.item.id]!);
    });
    return PackingList._(trip, List.unmodifiable(lines));
  }

  const PackingList._(this.trip, this.lines);

  /// Heading for the things typed in, apart from the "Other" category.
  static const String extrasTitle = 'Also pack';

  final Trip trip;
  final List<PackingLine> lines;

  List<PackingExtra> get extras => trip.extras;

  /// Pieces by category, in the categories' own order.
  Map<ClothingCategory, List<PackingLine>> get byCategory {
    final groups = <ClothingCategory, List<PackingLine>>{};
    for (final line in lines) {
      (groups[line.item.category] ??= []).add(line);
    }
    return groups;
  }

  int get total => lines.length + extras.length;

  int get packedCount =>
      lines.where((l) => l.packed).length +
      extras.where((e) => e.packed).length;

  bool get isEmpty => total == 0;

  /// Days of the trip that have an outfit that still exists.
  int plannedDays(Outfit? Function(String id) outfitById) =>
      trip.days.where((day) {
        final id = trip.outfitOn(day);
        return id != null && outfitById(id) != null;
      }).length;

  /// Plain text for notes or a message, ticks included.
  String toText() {
    final buffer = StringBuffer()
      ..writeln(trip.name)
      ..writeln(
        '${AppFormatters.shortDate(trip.startDate)} – '
        '${AppFormatters.shortDate(trip.endDate)}',
      );
    for (final MapEntry(key: category, value: group) in byCategory.entries) {
      buffer
        ..writeln()
        ..writeln(category.label);
      for (final line in group) {
        final days = line.days > 1 ? ' (${line.days} days)' : '';
        buffer.writeln('${_box(line.packed)} ${line.item.name}$days');
      }
    }
    if (extras.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln(extrasTitle);
      for (final extra in extras) {
        buffer.writeln('${_box(extra.packed)} ${extra.label}');
      }
    }
    return buffer.toString().trimRight();
  }

  static String _box(bool packed) => packed ? '☑' : '☐';
}
