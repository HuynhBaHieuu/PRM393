import 'package:all_fits/core/l10n/l10n.dart';
import 'package:all_fits/core/utils/date_helpers.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/outfit.dart';
import 'package:all_fits/data/models/weather.dart';
import 'package:all_fits/features/outfits/outfit_ideas.dart';
import 'package:all_fits/features/planner/controllers/planner_controller.dart';

/// What the "Today" home screen widget shows.
enum TodayWidgetState {
  /// Today's outfit was marked as worn.
  worn,

  /// An outfit is planned for today and can be marked as worn.
  planned,

  /// Nothing planned: a look made from the wardrobe for today's weather.
  idea,

  /// Nothing planned and too few clothes for an idea.
  empty,
}

/// Everything the home screen widget needs, worked out from the closet.
/// Kept free of Flutter so it can be tested on its own.
class TodayWidgetData {
  const TodayWidgetData({
    required this.state,
    required this.day,
    required this.title,
    required this.subtitle,
    this.weather,
    this.outfit,
    this.items = const [],
  });

  /// Picks today's outfit: the worn one, else the planned one, else the first
  /// outfit idea for [weather].
  factory TodayWidgetData.from({
    required DateTime today,
    required DayPlan plan,
    required Outfit? Function(String id) outfitById,
    required List<ClothingItem> Function(Iterable<String> ids) itemsByIds,
    required List<ClothingItem> wardrobe,
    WeatherReport? weather,
  }) {
    final day = DateHelpers.dateOnly(today);
    final weatherLine = weather == null ? null : describeWeather(weather);
    final entry = plan.primary;
    final outfit = entry == null ? null : outfitById(entry.outfitId);
    if (outfit != null) {
      final items = itemsByIds(outfit.itemIds);
      return TodayWidgetData(
        state: plan.worn != null
            ? TodayWidgetState.worn
            : TodayWidgetState.planned,
        day: day,
        title: outfit.name,
        subtitle: _pieces(items),
        weather: weatherLine,
        outfit: outfit,
        items: items,
      );
    }
    final ideas = OutfitIdeas.generate(
      wardrobe,
      day: day,
      weather: weather,
      count: 1,
    );
    if (ideas.isNotEmpty) {
      final idea = ideas.first;
      return TodayWidgetData(
        state: TodayWidgetState.idea,
        day: day,
        title: idea.title,
        subtitle: _pieces(idea.items),
        weather: weatherLine,
        items: idea.items,
      );
    }
    return TodayWidgetData(
      state: TodayWidgetState.empty,
      day: day,
      title: tr('Nothing planned today'),
      subtitle: tr('Add tops, bottoms and shoes to get a look every day.'),
      weather: weatherLine,
    );
  }

  final TodayWidgetState state;
  final DateTime day;
  final String title;
  final String subtitle;

  /// "☀️ 29° · Da Nang", or null before the weather has loaded.
  final String? weather;

  /// The saved outfit; null for an idea or when empty.
  final Outfit? outfit;

  /// The pieces drawn on the widget, head to toe.
  final List<ClothingItem> items;

  bool get hasPicture => items.isNotEmpty || outfit?.photoPath != null;

  /// The small label above the title.
  String get heading => switch (state) {
    TodayWidgetState.worn => tr('Worn today'),
    TodayWidgetState.planned => tr('Planned for today'),
    TodayWidgetState.idea => tr('Idea for today'),
    TodayWidgetState.empty => tr('Today'),
  };

  /// The button under the title; null when there is nothing to do.
  String? get actionLabel => switch (state) {
    TodayWidgetState.worn => null,
    TodayWidgetState.planned => tr('Mark as worn'),
    TodayWidgetState.idea => tr('Save this look'),
    TodayWidgetState.empty => tr('Add clothes'),
  };

  /// What the button does, as a link the app opens; see [TodayWidgetLink].
  Uri? get actionLink => switch (state) {
    TodayWidgetState.worn => null,
    TodayWidgetState.planned => TodayWidgetLink.wear(outfit!.id),
    TodayWidgetState.idea => TodayWidgetLink.compose([
      for (final item in items) item.id,
    ]),
    TodayWidgetState.empty => TodayWidgetLink.addClothes,
  };

  /// What tapping the rest of the widget opens.
  Uri get openLink => outfit == null
      ? TodayWidgetLink.home
      : TodayWidgetLink.outfit(outfit!.id);

  /// The values handed to the Android widget. The day lets the widget tell
  /// a stale outfit from today's when the app hasn't run since midnight;
  /// it then shows the "open" text, in the app's language rather than the
  /// phone's.
  Map<String, String?> toWidgetValues() => {
    'today_day': DateHelpers.toKey(day),
    'today_state': state.name,
    'today_heading': heading,
    'today_title': title,
    'today_subtitle': subtitle,
    'today_weather': weather,
    'today_action': actionLabel,
    'today_action_link': actionLink?.toString(),
    'today_open_link': openLink.toString(),
    'today_open_heading': tr('Today'),
    'today_open_title': tr('Open All Fits to see today’s outfit'),
  };

  /// What the widget shows once the user has signed out.
  static Map<String, String?> get signedOutValues => {
    'today_day': null,
    'today_state': 'signedOut',
    'today_heading': 'All Fits',
    'today_title': tr('Sign in to see today’s outfit'),
    'today_subtitle': null,
    'today_weather': null,
    'today_action': null,
    'today_action_link': null,
    'today_open_link': null,
  };

  /// Changes whenever the widget would look different, so it is only
  /// redrawn when needed.
  String get signature => [
    ...toWidgetValues().values,
    outfit?.updatedAt.toIso8601String(),
    for (final item in items) '${item.id}@${item.updatedAt}',
  ].join('|');

  static String describeWeather(WeatherReport report) =>
      '${_weatherEmoji(report.condition)} ${report.temperature.round()}° · '
      '${report.location.name}';

  static String _weatherEmoji(WeatherCondition condition) =>
      switch (condition) {
        WeatherCondition.clear => '☀️',
        WeatherCondition.cloudy => '☁️',
        WeatherCondition.fog => '🌫️',
        WeatherCondition.rain => '🌧️',
        WeatherCondition.snow => '❄️',
        WeatherCondition.storm => '⛈️',
      };

  static String _pieces(List<ClothingItem> items) =>
      items.isEmpty ? tr('No pieces') : items.map((i) => i.name).join(' · ');
}

/// Links the widget opens the app with. Only the app reads them.
abstract final class TodayWidgetLink {
  static const String scheme = 'allfits';
  static const String host = 'widget';

  static final Uri home = Uri(scheme: scheme, host: host, path: '/home');
  static final Uri addClothes = Uri(
    scheme: scheme,
    host: host,
    path: '/add-clothes',
  );

  static Uri outfit(String id) => Uri(
    scheme: scheme,
    host: host,
    path: '/outfit',
    queryParameters: {'id': id},
  );

  static Uri wear(String outfitId) => Uri(
    scheme: scheme,
    host: host,
    path: '/wear',
    queryParameters: {'id': outfitId},
  );

  static Uri compose(List<String> itemIds) => Uri(
    scheme: scheme,
    host: host,
    path: '/compose',
    queryParameters: {'items': itemIds.join(',')},
  );
}
