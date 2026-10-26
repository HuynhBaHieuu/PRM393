import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/layout.dart';
import 'package:all_fits/core/widgets/selectable_pill.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/features/insights/insights_data.dart';
import 'package:all_fits/features/insights/widgets/insight_widgets.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/planner/controllers/planner_controller.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/shared/closet_actions.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/features/wardrobe/widgets/wardrobe_toolbar.dart';

/// Fits' Insights: a donut by category, color, brand or season, the
/// wardrobe's value, and wear figures. Free shows categories, value and
/// usage; Premium unlocks the rest, as Fits Pro does.
class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  InsightDimension _dimension = InsightDimension.categories;
  ClothingCategory? _category;
  ClothingCategory? _usageCategory;

  void _upgrade() => AppNavigator.premium(context);

  void _openItem(String id) => AppNavigator.clothingDetail(context, id);

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeController>();
    final data = InsightsData(
      items: wardrobe.allItems,
      outfits: context.watch<OutfitController>().outfits,
      entries: context.watch<PlannerController>().entries,
      today: context.read<ClosetActions>().today,
    );
    final settings = context.watch<SettingsController>();
    final premium = settings.isPremium;
    final currency = settings.currencySymbol;
    String price(double value) => AppFormatters.price(value, currency);

    if (data.active.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Wardrobe Insights')),
        body: AppEmptyState(
          icon: Icons.pie_chart_outline_rounded,
          title: 'Nothing to analyze yet',
          message: 'Add clothes and log outfits to see your statistics.',
          actionLabel: 'Add Clothing',
          onAction: () => AppNavigator.addClothing(context),
        ),
      );
    }

    final dimension = premium ? _dimension : InsightDimension.categories;
    final palette = Theme.of(context).brightness == Brightness.dark
        ? insightSeriesDark
        : insightSeriesLight;
    final slices = data.slices(
      dimension,
      category: dimension == InsightDimension.categories ? _category : null,
    );
    final donut = [
      for (final (i, s) in slices.indexed)
        DonutSlice(
          label: s.label,
          value: s.count,
          color: s.color?.swatch ?? palette[i % palette.length],
        ),
    ];
    final pieces = slices.fold<int>(0, (sum, s) => sum + s.count);
    final usage = data.usage(category: _usageCategory);

    Widget locked(Widget child) =>
        premium ? child : LockedInsight(onUpgrade: _upgrade);

    return Scaffold(
      appBar: AppBar(title: const Text('Wardrobe Insights')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          PillBar(
            pills: [
              for (final d in InsightDimension.values)
                SelectablePill(
                  label: d.label,
                  selected: d == dimension,
                  leading: premium || d == InsightDimension.categories
                      ? null
                      : Icon(
                          Icons.star_border_rounded,
                          size: AppSizes.iconSm,
                          color: context.palette.ink,
                        ),
                  onTap: () => premium || d == InsightDimension.categories
                      ? setState(() => _dimension = d)
                      : _upgrade(),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: DonutChart(
              slices: donut,
              title: AppFormatters.count(pieces, 'piece'),
              subtitle:
                  'in ${slices.length} ${InsightsData.groupNoun(dimension)}',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (dimension == InsightDimension.categories) ...[
            ClothesToolbarChips(
              category: _category,
              onCategory: (c) => setState(() => _category = c),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          ResponsiveCenter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DonutLegend(slices: donut),
                  const SizedBox(height: AppSpacing.xl),
                  FigurePair(
                    figures: [
                      (
                        Icons.payments_outlined,
                        price(data.wardrobeValue),
                        'Wardrobe value',
                      ),
                      (
                        Icons.checkroom_outlined,
                        price(data.averagePrice),
                        'Average item price',
                      ),
                    ],
                  ),
                  InsightSection(
                    title: 'Highest price',
                    premiumBadge: true,
                    child: locked(
                      InsightItemStrip(
                        items: [for (final r in data.highestPrice) r.$1],
                        captionOf: (item) => price(item.price ?? 0),
                        onTap: (item) => _openItem(item.id),
                        emptyText: 'Add prices to your clothes to see this.',
                      ),
                    ),
                  ),
                  InsightSection(
                    title: 'Cost per wear',
                    premiumBadge: true,
                    child: locked(
                      _RankedStrip(
                        ranked: data.costPerWear,
                        caption: (v) => '${price(v)} / wear',
                        onTap: _openItem,
                        emptyText: 'Add prices to your clothes to see this.',
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _UsageCard(
                    usage: usage,
                    category: _usageCategory,
                    onCategory: (c) => setState(() => _usageCategory = c),
                  ),
                  InsightSection(
                    title: 'Worn last month',
                    premiumBadge: true,
                    child: locked(
                      _RankedStrip(
                        ranked: data.wornLastMonth,
                        caption: (v) => '${v.round()}×',
                        onTap: _openItem,
                        emptyText: 'Nothing worn in the last 30 days.',
                      ),
                    ),
                  ),
                  InsightSection(
                    title: 'Worn overall',
                    premiumBadge: true,
                    child: locked(
                      _RankedStrip(
                        ranked: data.wornOverall,
                        caption: (v) => '${v.round()}×',
                        onTap: _openItem,
                        emptyText: 'Mark outfits as worn to see this.',
                      ),
                    ),
                  ),
                  InsightSection(
                    title: 'Never worn',
                    premiumBadge: true,
                    child: locked(
                      InsightItemStrip(
                        items: data.neverWorn,
                        onTap: (item) => _openItem(item.id),
                        emptyText: 'You have worn every piece. Nice!',
                      ),
                    ),
                  ),
                  InsightSection(
                    title: 'Recently added',
                    child: InsightItemStrip(
                      items: data.recentlyAdded,
                      onTap: (item) => _openItem(item.id),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankedStrip extends StatelessWidget {
  const _RankedStrip({
    required this.ranked,
    required this.caption,
    required this.onTap,
    required this.emptyText,
  });

  final List<RankedItem> ranked;
  final String Function(double value) caption;
  final ValueChanged<String> onTap;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final values = {for (final (item, value) in ranked) item.id: value};
    return InsightItemStrip(
      items: [for (final r in ranked) r.$1],
      captionOf: (item) => caption(values[item.id] ?? 0),
      onTap: (item) => onTap(item.id),
      emptyText: emptyText,
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({
    required this.usage,
    required this.category,
    required this.onCategory,
  });

  final double usage;
  final ClothingCategory? category;
  final ValueChanged<ClothingCategory?> onCategory;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    final percent = (usage * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Wardrobe usage',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text('$percent%', style: text.headlineSmall),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: UsageBar(value: usage),
          ),
          const SizedBox(height: AppSpacing.md),
          ClothesToolbarChips(
            category: category,
            onCategory: onCategory,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              'You’re using $percent% of your wardrobe',
              style: text.bodyLarge?.copyWith(color: palette.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
