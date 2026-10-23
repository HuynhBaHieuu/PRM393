import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/layout.dart';
import 'package:all_fits/core/widgets/selectable_pill.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/models/occasion.dart';
import 'package:all_fits/data/models/outfit.dart';
import 'package:all_fits/features/collections/collection_flows.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/widgets/outfit_cards.dart';
import 'package:all_fits/features/shared/closet_flows.dart';

/// Filter for the outfits grid: all, favorites, or one occasion.
/// Instances compare by value so the selected pill can be matched.
sealed class _OutfitFilter {
  const _OutfitFilter();

  bool matches(Outfit outfit);
}

class _AllFilter extends _OutfitFilter {
  const _AllFilter();

  @override
  bool matches(Outfit outfit) => true;
}

class _FavoritesFilter extends _OutfitFilter {
  const _FavoritesFilter();

  @override
  bool matches(Outfit outfit) => outfit.isFavorite;
}

class _OccasionFilter extends _OutfitFilter {
  const _OccasionFilter(this.occasion);

  final Occasion occasion;

  @override
  bool matches(Outfit outfit) => outfit.occasion == occasion;

  @override
  bool operator ==(Object other) =>
      other is _OccasionFilter && other.occasion == occasion;

  @override
  int get hashCode => occasion.hashCode;
}

class OutfitsScreen extends StatefulWidget {
  const OutfitsScreen({super.key});

  @override
  State<OutfitsScreen> createState() => _OutfitsScreenState();
}

class _OutfitsScreenState extends State<OutfitsScreen> {
  _OutfitFilter _filter = const _AllFilter();

  Future<void> _showActions(Outfit outfit) async {
    final outfits = context.read<OutfitController>();
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(title: outfit.name),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                AppNavigator.editOutfit(context, outfit.id);
              },
            ),
            ListTile(
              leading: Icon(
                outfit.isFavorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
              ),
              title: Text(
                outfit.isFavorite ? 'Remove from favorites' : 'Favorite',
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                ClosetFlows.guard(
                  context,
                  () => outfits.toggleFavorite(outfit.id),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.collections_bookmark_outlined),
              title: const Text('Add to collection'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                CollectionFlows.addOutfit(context, outfit.id);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: context.palette.danger,
              ),
              title: Text(
                'Delete',
                style: TextStyle(color: context.palette.danger),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                ClosetFlows.deleteOutfit(context, outfit);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<OutfitController>();
    final all = controller.outfits;
    final occasions = Occasion.values
        .where((o) => all.any((outfit) => outfit.occasion == o))
        .toList();
    // Fall back to "All" if the selected occasion no longer exists.
    final filter =
        _filter is _OccasionFilter &&
            !occasions.contains((_filter as _OccasionFilter).occasion)
        ? const _AllFilter()
        : _filter;
    final visible = all.where(filter.matches).toList();
    final insets = pageInsets(context.screenSize.width);

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
          if (all.isNotEmpty)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  children: [
                    for (final option in <_OutfitFilter>[
                      const _AllFilter(),
                      const _FavoritesFilter(),
                      ...occasions.map(_OccasionFilter.new),
                    ]) ...[
                      SelectablePill(
                        label: switch (option) {
                          _AllFilter() => 'All',
                          _FavoritesFilter() => 'Favorites',
                          _OccasionFilter(:final occasion) => occasion.label,
                        },
                        selected: option == filter,
                        onTap: () => setState(() => _filter = option),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                  ],
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
          if (all.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                icon: Icons.style_outlined,
                title: 'No outfits yet',
                message: 'Create your first look.',
                actionLabel: 'Create Outfit',
                onAction: () => AppNavigator.createOutfit(context),
              ),
            )
          else if (visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                icon: Icons.favorite_border_rounded,
                title: 'Nothing here',
                message: filter is _FavoritesFilter
                    ? 'Tap the heart on a look to save it as a favorite.'
                    : 'No outfits match this filter.',
                actionLabel: 'Show all',
                onAction: () => setState(() => _filter = const _AllFilter()),
              ),
            )
          else
            SliverPadding(
              padding: insets.copyWith(bottom: AppSpacing.xl),
              sliver: OutfitSliverGrid(
                outfits: visible,
                onTap: (outfit) =>
                    AppNavigator.outfitDetail(context, outfit.id),
                onFavorite: (outfit) => ClosetFlows.guard(
                  context,
                  () => controller.toggleFavorite(outfit.id),
                ),
                onLongPress: _showActions,
              ),
            ),
        ],
      ),
    );
  }
}
