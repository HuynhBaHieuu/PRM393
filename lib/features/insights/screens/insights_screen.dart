import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/utils/adaptive_grid.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/color_swatch.dart';
import 'package:all_fits/core/widgets/layout.dart';
import 'package:all_fits/core/widgets/section_header.dart';
import 'package:all_fits/data/models/wardrobe_stats.dart';
import 'package:all_fits/features/insights/widgets/insight_widgets.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/planner/controllers/planner_controller.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  static const double _tileMinWidth = 150;
  static const double _tileHeight = 128;
  static const String _unspecified = 'Not set';

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeController>();
    final stats = WardrobeStats.compute(
      items: wardrobe.allItems,
      outfits: context.watch<OutfitController>().outfits,
      entries: context.watch<PlannerController>().entries,
    );
    final currency = context.select<SettingsController, String>(
      (s) => s.currencySymbol,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Wardrobe Insights')),
      body: stats.isEmpty
          ? AppEmptyState(
              icon: Icons.insights_outlined,
              title: 'Nothing to analyze yet',
              message: 'Add clothes and log outfits to see your statistics.',
              actionLabel: 'Add Clothing',
              onAction: () => AppNavigator.addClothing(context),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.sm,
                AppSpacing.page,
                AppSpacing.xxl,
              ),
              children: [
                ResponsiveCenter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Overview(stats: stats, currency: currency),
                      if (stats.mostWorn != null ||
                          stats.leastWorn != null) ...[
                        const SizedBox(height: AppSpacing.xl),
                        const SectionHeader(
                          title: 'Wear',
                          padding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        if (stats.mostWorn != null)
                          WearHighlightRow(
                            label: 'Most worn',
                            item: stats.mostWorn!,
                            onTap: () => AppNavigator.clothingDetail(
                              context,
                              stats.mostWorn!.id,
                            ),
                          ),
                        if (stats.leastWorn != null)
                          WearHighlightRow(
                            label: 'Least worn',
                            item: stats.leastWorn!,
                            onTap: () => AppNavigator.clothingDetail(
                              context,
                              stats.leastWorn!.id,
                            ),
                          ),
                      ],
                      if (stats.totalItems > 0) ...[
                        _Breakdown(
                          title: 'By category',
                          total: stats.totalItems,
                          rows: [
                            for (final b in stats.byCategory)
                              (b.key?.label ?? _unspecified, b.count, null),
                          ],
                        ),
                        _Breakdown(
                          title: 'By color',
                          total: stats.totalItems,
                          rows: [
                            for (final b in stats.byColor)
                              (
                                b.key?.label ?? _unspecified,
                                b.count,
                                b.key == null
                                    ? null
                                    : ColorSwatchDot(color: b.key!),
                              ),
                          ],
                        ),
                        _Breakdown(
                          title: 'By season',
                          subtitle: 'Items can belong to several seasons',
                          total: stats.totalItems,
                          rows: [
                            for (final b in stats.bySeason)
                              (b.key?.label ?? _unspecified, b.count, null),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.stats, required this.currency});

  final WardrobeStats stats;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      OverviewStatTile(
        label: 'Total items',
        value: '${stats.totalItems}',
        icon: Icons.checkroom_outlined,
      ),
      OverviewStatTile(
        label: 'Total outfits',
        value: '${stats.totalOutfits}',
        icon: Icons.style_outlined,
      ),
      OverviewStatTile(
        label: 'Wardrobe value',
        value: AppFormatters.price(stats.totalValue, currency),
        icon: Icons.sell_outlined,
      ),
      OverviewStatTile(
        label: 'Outfits worn',
        value: '${stats.timesWorn}',
        icon: Icons.event_available_outlined,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = AdaptiveGrid.columnsFor(
          constraints.maxWidth,
          minTileWidth: InsightsScreen._tileMinWidth,
          spacing: AppSpacing.sm,
        ).clamp(AdaptiveGrid.minColumns, tiles.length);
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio:
              (constraints.maxWidth / columns) /
              MediaQuery.textScalerOf(context)
                  .scale(InsightsScreen._tileHeight),
          children: tiles,
        );
      },
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({
    required this.title,
    required this.total,
    required this.rows,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final int total;
  final List<(String label, int count, Widget? leading)> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: title,
            subtitle: subtitle,
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final (label, count, leading) in rows)
            BreakdownBar(
              label: label,
              count: count,
              total: total,
              leading: leading,
            ),
        ],
      ),
    );
  }
}
