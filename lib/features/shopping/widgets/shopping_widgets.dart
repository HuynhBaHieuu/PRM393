import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/extensions/model_presentation.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/models/shopping_item.dart';

enum _TileAction { edit, addToWardrobe, viewInWardrobe, copyLink, delete }

/// One row of the shopping list, with a checkbox to tick it off.
class ShoppingItemTile extends StatelessWidget {
  const ShoppingItemTile({
    super.key,
    required this.item,
    required this.currencySymbol,
    required this.inWardrobe,
    required this.onTap,
    required this.onPurchasedChanged,
    required this.onAddToWardrobe,
    required this.onViewInWardrobe,
    required this.onDelete,
  });

  final ShoppingItem item;
  final String currencySymbol;

  /// Whether the wardrobe piece made from this purchase still exists.
  final bool inWardrobe;
  final VoidCallback onTap;
  final ValueChanged<bool> onPurchasedChanged;
  final VoidCallback onAddToWardrobe;
  final VoidCallback onViewInWardrobe;
  final VoidCallback onDelete;

  String get _details {
    final price = item.price;
    return [
      item.category.singularLabel,
      ?item.brand,
      if (price != null) AppFormatters.price(price, currencySymbol),
    ].join(' · ');
  }

  void _onAction(BuildContext context, _TileAction action) {
    switch (action) {
      case _TileAction.edit:
        onTap();
      case _TileAction.addToWardrobe:
        onAddToWardrobe();
      case _TileAction.viewInWardrobe:
        onViewInWardrobe();
      case _TileAction.copyLink:
        Clipboard.setData(ClipboardData(text: item.link!));
        context.showSnack('Link copied');
      case _TileAction.delete:
        onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    final bought = item.isPurchased;
    final purchasedAt = item.purchasedAt;

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              AppSpacing.sm,
              0,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Checkbox(
                  value: bought,
                  onChanged: (value) => onPurchasedChanged(value ?? false),
                ),
                Container(
                  width: AppSizes.thumbSm,
                  height: AppSizes.thumbSm,
                  color: palette.surfaceMuted,
                  child: Icon(
                    item.category.icon,
                    color: item.color?.swatch ?? palette.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium?.copyWith(
                          decoration: bought
                              ? TextDecoration.lineThrough
                              : null,
                          color: bought ? palette.textSecondary : null,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        _details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall,
                      ),
                      if (bought && purchasedAt != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          inWardrobe
                              ? 'Bought ${AppFormatters.shortDate(purchasedAt)}'
                                    ' · In your wardrobe'
                              : 'Bought ${AppFormatters.shortDate(purchasedAt)}',
                          style: text.bodySmall?.copyWith(
                            color: inWardrobe ? palette.success : null,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (!bought && item.priority != ShoppingPriority.medium) ...[
                  const SizedBox(width: AppSpacing.xs),
                  TagLabel(
                    item.priority.label,
                    inverted: item.priority == ShoppingPriority.high,
                  ),
                ],
                PopupMenuButton<_TileAction>(
                  tooltip: 'More',
                  onSelected: (action) => _onAction(context, action),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: _TileAction.edit,
                      child: Text('Edit'),
                    ),
                    if (inWardrobe)
                      const PopupMenuItem(
                        value: _TileAction.viewInWardrobe,
                        child: Text('View in wardrobe'),
                      )
                    else
                      const PopupMenuItem(
                        value: _TileAction.addToWardrobe,
                        child: Text('Add to wardrobe'),
                      ),
                    if (item.link != null)
                      const PopupMenuItem(
                        value: _TileAction.copyLink,
                        child: Text('Copy link'),
                      ),
                    const PopupMenuItem(
                      value: _TileAction.delete,
                      child: Text('Remove'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const Divider(indent: AppSpacing.page, endIndent: AppSpacing.page),
      ],
    );
  }
}
