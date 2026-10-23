import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/layout.dart';
import 'package:all_fits/features/collections/collection_flows.dart';
import 'package:all_fits/features/collections/controllers/collection_controller.dart';
import 'package:all_fits/features/collections/widgets/collection_cards.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';

/// The Collections tab of the Profile closet.
class CollectionsScreen extends StatelessWidget {
  const CollectionsScreen({super.key});

  static Future<void> _create(BuildContext context) async {
    final created = await CollectionFlows.create(context);
    if (created != null && context.mounted) {
      await AppNavigator.collectionDetail(context, created.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final collections = context.watch<CollectionController>().collections;
    final limit = context.select<SettingsController, int?>(
      (s) => s.plan.collectionLimit,
    );
    final insets = pageInsets(context.screenSize.width);

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
          if (collections.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                icon: Icons.collections_bookmark_outlined,
                title: 'No collections yet',
                message:
                    'Group pieces and outfits your way, like “Beach trip”, '
                    '“Work” or “Wishlist”.',
                actionLabel: 'New collection',
                onAction: () => _create(context),
              ),
            )
          else ...[
            SliverPadding(
              padding: insets,
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        limit == null
                            ? AppFormatters.count(
                                collections.length,
                                'collection',
                              )
                            : '${collections.length} of $limit collections '
                                  'on Free',
                        style: context.textTheme.bodySmall,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _create(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('New collection'),
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
            SliverPadding(
              padding: insets.copyWith(bottom: AppSpacing.xl),
              sliver: CollectionSliverGrid(
                collections: collections,
                onTap: (collection) =>
                    AppNavigator.collectionDetail(context, collection.id),
                onLongPress: (collection) =>
                    CollectionFlows.showActions(context, collection),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
