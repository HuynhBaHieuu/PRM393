import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/outfit.dart';
import 'package:all_fits/data/models/season.dart';
import 'package:all_fits/data/models/weather.dart';

/// Turns a weather report into styling advice and outfit picks.
class WeatherAdvice {
  const WeatherAdvice(this.report);

  final WeatherReport report;

  static const double _coldBelow = 10;
  static const double _coolBelow = 18;
  static const double _hotFrom = 26;
  static const int _rainLikelyFrom = 50;

  bool get isCold => report.temperature < _coldBelow;

  bool get isHot => report.temperature >= _hotFrom;

  bool get isWet =>
      report.condition.isWet || report.rainChance >= _rainLikelyFrom;

  bool get needsOuterwear =>
      isWet || report.temperature < _coolBelow || report.low < _coldBelow;

  /// Seasons whose clothes suit today's temperature.
  Set<Season> get seasons {
    final t = report.temperature;
    if (t < _coldBelow) return {Season.winter, Season.autumn};
    if (t < _coolBelow) return {Season.autumn, Season.spring};
    if (t < _hotFrom) return {Season.spring, Season.summer};
    return {Season.summer};
  }

  String get summary {
    if (isWet && isCold) return 'Cold and wet. Layer up and grab a coat.';
    if (isWet) return 'Rain is likely. Bring a jacket.';
    if (isCold) return 'It’s cold today. Layer up with outerwear.';
    if (isHot) return 'A hot one. Keep it light and breathable.';
    if (needsOuterwear) return 'Cool today. A light layer will help.';
    return 'Mild weather. Most of your wardrobe works today.';
  }

  /// Outfits that suit today, best first. [itemsOf] resolves an outfit's
  /// pieces. Outfits with no matching signals are left out.
  List<Outfit> pickOutfits(
    Iterable<Outfit> outfits,
    List<ClothingItem> Function(Outfit outfit) itemsOf, {
    int limit = 3,
  }) {
    final scored = <(Outfit, int)>[];
    for (final outfit in outfits) {
      final items = itemsOf(outfit);
      if (items.isEmpty) continue;
      final score = _score(outfit, items);
      if (score > 0) scored.add((outfit, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return [for (final (outfit, _) in scored.take(limit)) outfit];
  }

  int _score(Outfit outfit, List<ClothingItem> items) {
    final suitable = seasons;
    var score = 0;
    int seasonScore(List<Season> tagged) {
      if (tagged.isEmpty) return 0;
      return tagged.any(suitable.contains) ? 1 : -1;
    }

    score += seasonScore(outfit.seasons) * 2;
    for (final item in items) {
      score += seasonScore(item.seasons);
    }
    final hasOuterwear = items.any(
      (item) => item.category == ClothingCategory.outerwear,
    );
    if (needsOuterwear && hasOuterwear) score += 2;
    if (needsOuterwear && !hasOuterwear) score -= 1;
    if (isHot && hasOuterwear) score -= 2;
    return score;
  }
}
