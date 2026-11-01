import 'dart:math' as math;

import 'package:all_fits/data/models/clothing_color.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/outfit_slot.dart';
import 'package:all_fits/data/models/season.dart';
import 'package:all_fits/data/models/weather.dart';
import 'package:all_fits/features/weather/weather_advice.dart';

/// A look put together from the user's own pieces, with a short caption.
class OutfitIdea {
  const OutfitIdea({required this.items, required this.title});

  /// Head to toe: outerwear, top or dress, bottom, shoes, accessory.
  final List<ClothingItem> items;
  final String title;

  List<String> get itemIds => [for (final item in items) item.id];
}

/// Fits' "For today" and "Ideas for your newest pieces", made on the device:
/// pieces are mixed by slot, matched to the weather through their seasons
/// (see [WeatherAdvice]), and reshuffled each day. No AI call, so they cost
/// nothing.
abstract final class OutfitIdeas {
  static const double _warmFrom = 25;

  /// Up to [count] different looks for [day]. With [anchor], every look is
  /// built around that piece. Without [weather], the month picks the season.
  ///
  /// [usage] counts how often each piece is already used elsewhere (e.g. on
  /// other days of a week plan); the least used pieces are picked first.
  /// Looks whose [lookKey] is in [avoidLooks] are skipped, and [variant]
  /// reshuffles the same day.
  static List<OutfitIdea> generate(
    List<ClothingItem> wardrobe, {
    required DateTime day,
    WeatherReport? weather,
    ClothingItem? anchor,
    int count = 3,
    Map<String, int> usage = const {},
    Set<String> avoidLooks = const {},
    int variant = 0,
  }) {
    final advice = weather == null ? null : WeatherAdvice(weather);
    final seasons = advice?.seasons ?? {_seasonOf(day)};
    final bySlot = <OutfitSlot, List<ClothingItem>>{};
    for (final item in wardrobe) {
      if (item.isArchived) continue;
      bySlot
          .putIfAbsent(OutfitSlot.forCategory(item.category), () => [])
          .add(item);
    }
    // Prefer pieces tagged for the season; untagged pieces always fit.
    List<ClothingItem> pool(OutfitSlot slot) {
      final all = bySlot[slot] ?? const <ClothingItem>[];
      final fitting = all
          .where((i) => i.seasons.isEmpty || i.seasons.any(seasons.contains))
          .toList();
      return fitting.isEmpty ? all : fitting;
    }

    final anchorSlot = anchor == null
        ? null
        : OutfitSlot.forCategory(anchor.category);
    final random = math.Random(
      day.year * 400 +
          day.month * 32 +
          day.day +
          (anchor?.id.hashCode ?? 0) +
          variant * 7919,
    );
    final layered =
        advice?.needsOuterwear ??
        seasons.any((s) => s == Season.winter || s == Season.autumn);

    // Pieces already in an idea; others are tried first so the looks differ.
    final used = <String>{};
    int cost(ClothingItem item) =>
        (used.contains(item.id) ? _usedHere : 0) + (usage[item.id] ?? 0);
    ClothingItem? pick(OutfitSlot slot) {
      if (slot == anchorSlot) return anchor;
      final all = pool(slot);
      if (all.isEmpty) return null;
      final least = all.map(cost).reduce(math.min);
      final options = all.where((i) => cost(i) == least).toList();
      return options[random.nextInt(options.length)];
    }

    final ideas = <OutfitIdea>[];
    final seen = {...avoidLooks};
    for (
      var attempt = 0;
      attempt < count * 6 && ideas.length < count;
      attempt++
    ) {
      final canSeparates =
          pool(OutfitSlot.top).isNotEmpty && pool(OutfitSlot.bottom).isNotEmpty;
      final freshDress = pool(OutfitSlot.dress)
          .any((dress) => !used.contains(dress.id));
      final useDress =
          anchorSlot == OutfitSlot.dress ||
          (anchorSlot != OutfitSlot.top &&
              anchorSlot != OutfitSlot.bottom &&
              pool(OutfitSlot.dress).isNotEmpty &&
              (!canSeparates || (freshDress && random.nextInt(4) == 0)));
      final items = <ClothingItem>[
        if (layered || anchorSlot == OutfitSlot.outerwear)
          ?pick(OutfitSlot.outerwear),
        if (useDress)
          ?pick(OutfitSlot.dress)
        else ...[
          ?pick(OutfitSlot.top),
          ?pick(OutfitSlot.bottom),
        ],
        ?pick(OutfitSlot.shoes),
        if (anchorSlot == OutfitSlot.accessories || random.nextBool())
          ?pick(OutfitSlot.accessories),
      ];
      final slots = {for (final i in items) OutfitSlot.forCategory(i.category)};
      final complete =
          slots.contains(OutfitSlot.dress) ||
          (slots.contains(OutfitSlot.top) && slots.contains(OutfitSlot.bottom));
      if (!complete) continue;
      if (!seen.add(lookKey(items.map((i) => i.id)))) continue;
      used.addAll(items.map((i) => i.id));
      ideas.add(
        OutfitIdea(
          items: items,
          title: _title(items, weather?.high, layered, random),
        ),
      );
    }
    return ideas;
  }

  /// The same for any order of the same pieces.
  static String lookKey(Iterable<String> itemIds) =>
      (itemIds.toList()..sort()).join(',');

  /// Outweighs any [generate] usage count: a piece already in one of this
  /// call's ideas comes last.
  static const int _usedHere = 1000;

  static Season _seasonOf(DateTime day) {
    return switch (day.month) {
      12 || 1 || 2 => Season.winter,
      3 || 4 || 5 => Season.spring,
      6 || 7 || 8 => Season.summer,
      _ => Season.autumn,
    };
  }

  static const List<String> _moods = [
    'Relaxed',
    'Easy',
    'Sharp',
    'Clean',
    'Laid-back',
    'Classic',
  ];

  /// e.g. "Relaxed layers in black and navy", "Sleek all-black streetwear".
  static String _title(
    List<ClothingItem> items,
    double? temperature,
    bool layered,
    math.Random random,
  ) {
    final colors = <ClothingColor>[];
    for (final item in items) {
      final color = item.color;
      if (color != null && !colors.contains(color)) colors.add(color);
    }
    final noun = layered
        ? 'layers'
        : temperature == null
        ? 'streetwear fit'
        : temperature >= _warmFrom
        ? 'warm-weather fit'
        : 'everyday fit';
    String name(ClothingColor c) => c.isMulti ? 'color' : c.label.toLowerCase();
    if (colors.length == 1) {
      return 'Sleek all-${name(colors.first)} $noun';
    }
    final mood = _moods[random.nextInt(_moods.length)];
    if (colors.length >= 2) {
      return '$mood $noun in ${name(colors[0])} and ${name(colors[1])}';
    }
    return '$mood $noun';
  }
}
