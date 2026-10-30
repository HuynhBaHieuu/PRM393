import 'package:all_fits/core/utils/date_helpers.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/outfit_slot.dart';
import 'package:all_fits/data/models/weather.dart';
import 'package:all_fits/features/outfits/outfit_ideas.dart';

/// "Plan my week": a look for each day from the user's own pieces, spread
/// so the week repeats as little as possible. Built on [OutfitIdeas], so it
/// runs on the device and costs nothing.
abstract final class WeekPlanner {
  static const int length = 7;

  /// Reshuffles tried before a look that repeats another day is accepted.
  static const int _tries = 8;

  /// Pieces worn up to this many days before a day count as used that day,
  /// so the plan doesn't open with yesterday's clothes.
  static const int _recentDays = 2;

  /// The slots people notice repeating; shoes, bags and jackets can.
  static const Set<OutfitSlot> _mainSlots = {
    OutfitSlot.top,
    OutfitSlot.bottom,
    OutfitSlot.dress,
  };

  /// A look for [day] sharing as few pieces as possible with [others], the
  /// item ids of the week's other looks, and never the same look as one of
  /// them unless the wardrobe is too small. Each [variant] gives another
  /// look. Null when the wardrobe can't make a full look.
  static OutfitIdea? lookFor(
    List<ClothingItem> wardrobe, {
    required DateTime day,
    Iterable<List<String>> others = const [],
    WeatherReport? weather,
    int variant = 0,
  }) {
    final usage = <String, int>{};
    for (final item in wardrobe) {
      final worn = item.lastWornAt;
      if (worn == null) continue;
      final ago = DateHelpers.daysBetween(worn, day);
      if (ago >= 1 && ago <= _recentDays) usage[item.id] = 1;
    }
    for (final look in others) {
      for (final id in look) {
        usage[id] = (usage[id] ?? 0) + 1;
      }
    }
    final avoid = {for (final look in others) OutfitIdeas.lookKey(look)};
    OutfitIdea? attempt(int shuffle, Set<String> avoidLooks) =>
        OutfitIdeas.generate(
          wardrobe,
          day: day,
          weather: weather,
          count: 1,
          usage: usage,
          avoidLooks: avoidLooks,
          variant: shuffle,
        ).firstOrNull;

    for (var i = 0; i < _tries; i++) {
      final idea = attempt(variant * _tries + i, avoid);
      if (idea != null) return idea;
    }
    // Too few pieces for a new look: a repeat beats an empty day.
    return attempt(variant * _tries, const {});
  }

  /// A look for each of [days], in order; null where none can be made.
  /// [kept] are looks already on those days' planner that stay, so their
  /// pieces count as used.
  static List<OutfitIdea?> planWeek(
    List<ClothingItem> wardrobe, {
    required List<DateTime> days,
    Map<DateTime, WeatherReport> weather = const {},
    Iterable<List<String>> kept = const [],
    int variant = 0,
  }) {
    final looks = [...kept];
    final ideas = <OutfitIdea?>[];
    for (final day in days) {
      final idea = lookFor(
        wardrobe,
        day: day,
        others: looks,
        weather: weather[DateHelpers.dateOnly(day)],
        variant: variant,
      );
      ideas.add(idea);
      if (idea != null) looks.add(idea.itemIds);
    }
    return ideas;
  }

  /// How many tops, bottoms and dresses appear in more than one of [looks].
  static int repeats(Iterable<List<ClothingItem>> looks) {
    final counts = <String, int>{};
    for (final look in looks) {
      for (final item in look) {
        if (!_mainSlots.contains(OutfitSlot.forCategory(item.category))) {
          continue;
        }
        counts[item.id] = (counts[item.id] ?? 0) + 1;
      }
    }
    return counts.values.where((n) => n > 1).length;
  }
}
