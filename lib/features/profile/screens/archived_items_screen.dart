import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/core/widgets/layout.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/features/shared/closet_flows.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/features/wardrobe/widgets/clothing_tile.dart';

class ArchivedItemsScreen extends StatelessWidget {
  const ArchivedItemsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = context.watch<WardrobeController>().archivedItems;
    return Scaffold(
      appBar: AppBar(title: const Text('Archived Items')),
      body: items.isEmpty
          ? const AppEmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No archived items',
              message:
                  'Archive pieces you rarely wear to keep your wardrobe '
                  'focused. They’ll be kept safe here.',
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.sm,
                AppSpacing.page,
                AppSpacing.xxl,
              ),
              itemCount: items.length + 1,
              separatorBuilder: (_, index) =>
                  index == 0 ? const SizedBox.shrink() : const Divider(),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(
                      'Archived items are hidden from your wardrobe and '
                      'outfit builder. Restore them any time.',
                      style: context.textTheme.bodySmall,
                    ),
                  );
                }
                return ResponsiveCenter(
                  child: _ArchivedRow(item: items[index - 1]),
                );
              },
            ),
    );
  }
}

class _ArchivedRow extends StatelessWidget {
  const _ArchivedRow({required this.item});

  final ClothingItem item;

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.read<WardrobeController>();
    final palette = context.palette;
    final text = context.textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => AppNavigator.clothingDetail(context, item.id),
            child: SizedBox(
              width: AppSizes.thumbLg,
              child: AspectRatio(
                aspectRatio: AppSizes.clothingImageAspect,
                child: ClothingImage(
                  item: item,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  decodeWidth: AppSizes.thumbLg,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: text.titleMedium),
                const SizedBox(height: 2),
                Text(ClothingTile.metaLine(item), style: text.bodySmall),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => ClosetFlows.guard(
                        context,
                        () => wardrobe.setArchived(item.id, archived: false),
                        successMessage: '${item.name} restored',
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(
                          0,
                          AppSizes.compactButtonHeight,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                      ),
                      icon: const Icon(
                        Icons.unarchive_outlined,
                        size: AppSizes.iconSm,
                      ),
                      label: const Text('Restore'),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    IconButton(
                      tooltip: 'Delete permanently',
                      onPressed: () => ClosetFlows.deleteItem(context, item),
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        color: palette.danger,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
