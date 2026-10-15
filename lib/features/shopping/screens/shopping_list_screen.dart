import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/layout.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/models/shopping_item.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/shopping/controllers/shopping_controller.dart';
import 'package:all_fits/features/shopping/shopping_flows.dart';
import 'package:all_fits/features/shopping/widgets/shopping_widgets.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';

/// Pieces the user wants to buy, and the ones they've bought.
class ShoppingListScreen extends StatelessWidget {
  const ShoppingListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final shopping = context.watch<ShoppingController>();
    // Rebuild when wardrobe items change so "In your wardrobe" stays accurate.
    context.watch<WardrobeController>();
    final currency = context.select<SettingsController, String>(
      (s) => s.currencySymbol,
    );
    final toBuy = shopping.toBuy;
    final bought = shopping.purchased;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Shopping List'),
          actions: [
            if (bought.isNotEmpty)
              IconButton(
                tooltip: 'Clear bought items',
                icon: const Icon(Icons.playlist_remove_rounded),
                onPressed: () => ShoppingFlows.clearPurchased(context),
              ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: 'To buy (${toBuy.length})'),
              Tab(text: 'Bought (${bought.length})'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => AppNavigator.addShoppingItem(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add item'),
        ),
        body: Column(
          children: [
            ResponsiveCenter(
              child: StatPair(
                items: [
                  (
                    'To buy',
                    AppFormatters.price(shopping.toBuyTotal, currency),
                  ),
                  ('Spent', AppFormatters.price(shopping.spentTotal, currency)),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _ShoppingList(
                    items: toBuy,
                    currency: currency,
                    empty: AppEmptyState(
                      icon: Icons.shopping_bag_outlined,
                      title: 'Nothing on your list',
                      message:
                          'Add pieces you want to buy and tick them off '
                          'once you have them.',
                      actionLabel: 'Add item',
                      onAction: () => AppNavigator.addShoppingItem(context),
                    ),
                  ),
                  _ShoppingList(
                    items: bought,
                    currency: currency,
                    empty: const AppEmptyState(
                      icon: Icons.check_circle_outline_rounded,
                      title: 'Nothing bought yet',
                      message:
                          'Ticked-off items show up here, ready to add to '
                          'your wardrobe.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShoppingList extends StatelessWidget {
  const _ShoppingList({
    required this.items,
    required this.currency,
    required this.empty,
  });

  final List<ShoppingItem> items;
  final String currency;
  final Widget empty;

  // Keeps the last row clear of the floating action button.
  static const double _fabClearance = 96;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return empty;
    return ListView.builder(
      padding: const EdgeInsets.only(top: AppSpacing.xs, bottom: _fabClearance),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ResponsiveCenter(
          child: ShoppingItemTile(
            key: ValueKey(item.id),
            item: item,
            currencySymbol: currency,
            inWardrobe: ShoppingFlows.isInWardrobe(context, item),
            onTap: () => AppNavigator.editShoppingItem(context, item.id),
            onPurchasedChanged: (value) =>
                ShoppingFlows.setPurchased(context, item, purchased: value),
            onAddToWardrobe: () => ShoppingFlows.addToWardrobe(context, item),
            onViewInWardrobe: () =>
                AppNavigator.clothingDetail(context, item.wardrobeItemId!),
            onDelete: () => ShoppingFlows.deleteItem(context, item),
          ),
        );
      },
    );
  }
}
