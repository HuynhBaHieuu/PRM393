import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/layout.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/widgets/outfit_cards.dart';
import 'package:all_fits/features/shared/closet_flows.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/features/wardrobe/widgets/clothing_grid.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeController>();
    final outfits = context.watch<OutfitController>();
    final items = wardrobe.favoriteItems;
    final looks = outfits.favorites;
    final insets = pageInsets(context.screenSize.width);
    const emptyMessage = 'Tap the heart on any piece or look to save it here.';

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Favorites'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Clothes (${items.length})'),
              Tab(text: 'Outfits (${looks.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            items.isEmpty
                ? const AppEmptyState(
                    icon: Icons.favorite_border_rounded,
                    title: 'No favorites yet',
                    message: emptyMessage,
                  )
                : CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: insets.copyWith(
                          top: AppSpacing.lg,
                          bottom: AppSpacing.xl,
                        ),
                        sliver: ClothingSliverGrid(
                          items: items,
                          onTap: (item) =>
                              AppNavigator.clothingDetail(context, item.id),
                          onFavorite: (item) => ClosetFlows.guard(
                            context,
                            () => wardrobe.toggleFavorite(item.id),
                          ),
                        ),
                      ),
                    ],
                  ),
            looks.isEmpty
                ? const AppEmptyState(
                    icon: Icons.favorite_border_rounded,
                    title: 'No favorites yet',
                    message: emptyMessage,
                  )
                : CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: insets.copyWith(
                          top: AppSpacing.lg,
                          bottom: AppSpacing.xl,
                        ),
                        sliver: OutfitSliverGrid(
                          outfits: looks,
                          onTap: (outfit) =>
                              AppNavigator.outfitDetail(context, outfit.id),
                          onFavorite: (outfit) => ClosetFlows.guard(
                            context,
                            () => outfits.toggleFavorite(outfit.id),
                          ),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
