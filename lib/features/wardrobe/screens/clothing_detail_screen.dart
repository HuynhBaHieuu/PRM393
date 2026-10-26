import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/extensions/model_presentation.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/utils/validators.dart';
import 'package:all_fits/core/widgets/app_dialogs.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/core/widgets/color_swatch.dart';
import 'package:all_fits/core/widgets/detail_rows.dart';
import 'package:all_fits/core/widgets/feedback_views.dart';
import 'package:all_fits/core/widgets/layout.dart';
import 'package:all_fits/core/widgets/option_sheets.dart';
import 'package:all_fits/core/widgets/selection_tray.dart';
import 'package:all_fits/data/local/image_picker_service.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_color.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/clothing_subcategory.dart';
import 'package:all_fits/data/models/season.dart';
import 'package:all_fits/features/collections/collection_flows.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/shared/closet_flows.dart';
import 'package:all_fits/features/stylist/screens/stylist_screen.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';

/// What the detail screen opens with: a piece, and the pieces around it in
/// the list it was opened from (for the ‹ › buttons).
class ClothingDetailArgs {
  const ClothingDetailArgs(this.itemId, {this.siblings = const []});

  final String itemId;
  final List<String> siblings;
}

/// Fits' piece page: the cut-out with ‹ › to step through the closet, and
/// every detail editable in place.
class ClothingDetailScreen extends StatefulWidget {
  const ClothingDetailScreen({
    super.key,
    required this.itemId,
    this.siblings = const [],
  });

  final String itemId;
  final List<String> siblings;

  @override
  State<ClothingDetailScreen> createState() => _ClothingDetailScreenState();
}

enum _PhotoAction { camera, gallery, cutout }

class _ClothingDetailScreenState extends State<ClothingDetailScreen> {
  late String _id = widget.itemId;
  bool _busy = false;

  static const double _imageHeightFactor = 0.42;

  WardrobeController get _wardrobe => context.read<WardrobeController>();

  Future<void> _patch(ClothingItem Function(ClothingItem item) change) =>
      ClosetFlows.guard(context, () => _wardrobe.patchItem(_id, change));

  /// The neighbour [step] places away in the list this page came from.
  String? _neighbour(int step) {
    final ids = widget.siblings;
    final index = ids.indexOf(_id);
    if (index < 0) return null;
    final next = index + step;
    if (next < 0 || next >= ids.length) return null;
    return ids[next];
  }

  Future<void> _rename(ClothingItem item) async {
    final name = await showTextInputDialog(
      context,
      title: 'Name',
      initialValue: item.name,
      maxLength: Validators.maxNameLength,
    );
    if (name == null || name.isEmpty || name == item.name) return;
    await _patch((i) => i.copyWith(name: name));
  }

  Future<void> _pickCategory(ClothingItem item) async {
    final category = await showMultiSelectSheet<ClothingCategory>(
      context,
      title: 'Category',
      single: true,
      options: ClothingCategory.values,
      selected: {item.category},
      labelOf: (c) => c.singularLabel,
      leadingOf: (c) => Icon(c.icon),
    );
    final chosen = category?.firstOrNull;
    if (chosen == null || !mounted) return;
    final types = ClothingSubcategory.of(chosen);
    ClothingSubcategory? type;
    if (types.isNotEmpty) {
      final picked = await showMultiSelectSheet<ClothingSubcategory>(
        context,
        title: 'Type',
        single: true,
        options: types,
        selected: {
          ?(item.subcategory?.category == chosen ? item.subcategory : null),
        },
        labelOf: (s) => s.label,
      );
      if (picked == null) return;
      type = picked.firstOrNull;
    }
    await _patch((i) => i.copyWith(category: chosen, subcategory: type));
  }

  Future<void> _pickBrand(ClothingItem item) async {
    final brands = {..._wardrobe.brands, ...AppConfig.suggestedBrands}.toList();
    const other = '+ Other brand';
    final picked = await showMultiSelectSheet<String>(
      context,
      title: 'Brand',
      single: true,
      options: [other, ...brands],
      selected: {?item.brand},
      labelOf: (b) => b,
    );
    if (picked == null || !mounted) return;
    var brand = picked.firstOrNull;
    if (brand == other) {
      brand = await showTextInputDialog(
        context,
        title: 'Brand',
        initialValue: item.brand ?? '',
        maxLength: Validators.maxNameLength,
      );
      if (brand == null) return;
    }
    await _patch(
      (i) => i.copyWith(brand: brand == null || brand.isEmpty ? null : brand),
    );
  }

  Future<void> _pickColor(ClothingItem item) async {
    final picked = await showMultiSelectSheet<ClothingColor>(
      context,
      title: 'Color',
      single: true,
      options: ClothingColor.values,
      selected: {?item.color},
      labelOf: (c) => c.label,
      leadingOf: (c) => ColorSwatchDot(color: c, size: 26),
    );
    if (picked == null) return;
    await _patch((i) => i.copyWith(color: picked.firstOrNull));
  }

  Future<void> _pickMaterials(ClothingItem item) async {
    const other = '+ Other material';
    final options = {
      ...AppConfig.suggestedMaterials,
      ..._wardrobe.materials,
      ...item.materials,
    }.toList();
    final picked = await showMultiSelectSheet<String>(
      context,
      title: 'Materials',
      options: [...options, other],
      selected: item.materials.toSet(),
      labelOf: (m) => m,
    );
    if (picked == null || !mounted) return;
    final materials = [
      for (final m in options)
        if (picked.contains(m)) m,
    ];
    if (picked.contains(other)) {
      final typed = await showTextInputDialog(
        context,
        title: 'Material',
        hint: 'e.g. Velvet',
        maxLength: Validators.maxNameLength,
      );
      if (typed != null && typed.isNotEmpty) materials.add(typed);
    }
    await _patch((i) => i.copyWith(materials: materials));
  }

  Future<void> _pickSeasons(ClothingItem item) async {
    final picked = await showMultiSelectSheet<Season>(
      context,
      options: Season.values,
      selected: item.seasons.toSet(),
      labelOf: (s) => s.label,
      leadingOf: (s) => EmojiIcon(s.emoji, size: 28),
    );
    if (picked == null) return;
    await _patch(
      (i) => i.copyWith(seasons: Season.values.where(picked.contains).toList()),
    );
  }

  Future<void> _editPrice(ClothingItem item, String currency) async {
    final text = await showTextInputDialog(
      context,
      title: 'Price',
      initialValue: item.price == null
          ? ''
          : item.price!.toStringAsFixed(
              item.price! == item.price!.roundToDouble() ? 0 : 2,
            ),
      prefixText: currency,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
    if (text == null) return;
    final cleaned = text.replaceAll(',', '');
    final price = cleaned.isEmpty ? null : double.tryParse(cleaned);
    if (cleaned.isNotEmpty && (price == null || price < 0)) {
      if (mounted) context.showSnack('Enter a price, e.g. 45 or 45.50');
      return;
    }
    await _patch((i) => i.copyWith(price: price));
  }

  Future<void> _pickPurchaseDate(ClothingItem item) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: item.purchaseDate ?? now,
      firstDate: DateTime(1990),
      lastDate: now,
    );
    if (date == null) return;
    await _patch((i) => i.copyWith(purchaseDate: date));
  }

  Future<void> _editNote(ClothingItem item) async {
    final note = await showTextInputDialog(
      context,
      title: 'Note',
      initialValue: item.notes ?? '',
      hint: 'Add a note...',
      maxLength: Validators.maxNotesLength,
      multiline: true,
    );
    if (note == null) return;
    await _patch((i) => i.copyWith(notes: note.isEmpty ? null : note));
  }

  Future<void> _editPhoto(ClothingItem item) async {
    final picker = context.read<ImagePickerService>();
    final action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (picker.supportsCamera)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a new photo'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_PhotoAction.camera),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose a new photo'),
              onTap: () => Navigator.of(sheetContext).pop(_PhotoAction.gallery),
            ),
            if (item.imagePath != null)
              ListTile(
                leading: const Icon(Icons.auto_fix_high_outlined),
                title: const Text('Remove background again'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_PhotoAction.cutout),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    try {
      if (action == _PhotoAction.cutout) {
        setState(() => _busy = true);
        final done = await _wardrobe.redoCutout(_id);
        if (mounted && !done) {
          context.showSnack('The background couldn’t be removed.');
        }
        return;
      }
      final path = await picker.pickImage(
        action == _PhotoAction.camera
            ? ImagePickSource.camera
            : ImagePickSource.gallery,
      );
      if (path == null || !mounted) return;
      setState(() => _busy = true);
      await _wardrobe.replacePhoto(_id, path);
    } catch (error) {
      if (mounted) context.showErrorSnack(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setArchived(ClothingItem item, {required bool archived}) async {
    final wardrobe = _wardrobe;
    final done = await ClosetFlows.guard(
      context,
      () => wardrobe.setArchived(item.id, archived: archived),
    );
    if (!done || !mounted) return;
    context.showSnack(
      archived ? 'Moved to archive' : 'Restored to your wardrobe',
      actionLabel: 'Undo',
      onAction: () => ClosetFlows.guard(
        context,
        () => wardrobe.setArchived(item.id, archived: !archived),
      ),
    );
  }

  Future<void> _delete(ClothingItem item) async {
    final navigator = Navigator.of(context);
    final deleted = await ClosetFlows.deleteItem(context, item);
    if (deleted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final item = context.watch<WardrobeController>().itemById(_id);
    if (item == null) {
      return const NotFoundView(
        title: 'Item not found',
        message: 'This item is no longer in your wardrobe.',
      );
    }
    final usedIn = context.select<OutfitController, int>(
      (o) => o.outfitsUsingItem(_id).length,
    );
    final currency = context.select<SettingsController, String>(
      (s) => s.currencySymbol,
    );
    final palette = context.palette;
    final text = context.textTheme;
    final size = context.screenSize;
    final previous = _neighbour(-1);
    final next = _neighbour(1);
    final hint = palette.textSecondary;

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          SizedBox(
            height: size.height * _imageHeightFactor,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                    ),
                    child: ClothingImage(
                      key: ValueKey(item.cutoutPath ?? item.imagePath),
                      item: item,
                      cutout: true,
                      fit: BoxFit.contain,
                      decodeWidth: size.width,
                    ),
                  ),
                ),
                if (_busy) const Positioned.fill(child: AppLoadingView()),
                if (previous != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _StepButton(
                      icon: Icons.chevron_left_rounded,
                      tooltip: 'Previous piece',
                      onTap: () => setState(() => _id = previous),
                    ),
                  ),
                if (next != null)
                  Align(
                    alignment: Alignment.centerRight,
                    child: _StepButton(
                      icon: Icons.chevron_right_rounded,
                      tooltip: 'Next piece',
                      onTap: () => setState(() => _id = next),
                    ),
                  ),
              ],
            ),
          ),
          ResponsiveCenter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      IconButton(
                        tooltip: item.isFavorite ? 'Unfavorite' : 'Favorite',
                        onPressed: () => ClosetFlows.guard(
                          context,
                          () => _wardrobe.toggleFavorite(item.id),
                        ),
                        icon: Icon(
                          item.isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: AppSizes.iconLg,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Ask the AI stylist',
                        onPressed: () => AppNavigator.stylist(
                          context,
                          launch: StylistLaunch(
                            prompt: 'What can I wear with my ${item.name}?',
                            itemIds: [item.id],
                          ),
                        ),
                        icon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: AppSizes.iconLg,
                        ),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _busy ? null : () => _editPhoto(item),
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('Edit'),
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.surfaceMuted,
                          foregroundColor: palette.ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  InkWell(
                    onTap: () => _rename(item),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(item.name, style: text.titleLarge),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Icon(Icons.edit_outlined, color: hint),
                        ],
                      ),
                    ),
                  ),
                  if (item.isArchived) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _ArchivedBanner(
                      onRestore: () => _setArchived(item, archived: false),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  DetailGroup(
                    children: [
                      DetailRow(
                        icon: Icons.format_list_bulleted_rounded,
                        leading: Icon(item.category.icon, color: hint),
                        label:
                            item.subcategory?.label ??
                            item.category.singularLabel,
                        onTap: () => _pickCategory(item),
                      ),
                      DetailRow(
                        icon: Icons.verified_outlined,
                        label: item.brand,
                        placeholder: 'Add brand',
                        onTap: () => _pickBrand(item),
                      ),
                      DetailRow(
                        icon: Icons.water_drop_outlined,
                        leading: item.color == null
                            ? null
                            : ColorSwatchDot(color: item.color!, size: 26),
                        label: item.color?.label,
                        placeholder: 'Add color',
                        onTap: () => _pickColor(item),
                      ),
                      DetailRow(
                        icon: Icons.layers_outlined,
                        label: item.materials.isEmpty
                            ? null
                            : item.materials.join(', '),
                        placeholder: 'Add materials',
                        onTap: () => _pickMaterials(item),
                      ),
                      DetailRow(
                        icon: Icons.wb_sunny_outlined,
                        // Emoji only once several seasons would not fit.
                        label: item.seasons.isEmpty
                            ? null
                            : item.seasons
                                  .map(
                                    (s) => item.seasons.length > 2
                                        ? s.emoji
                                        : '${s.emoji} ${s.label}',
                                  )
                                  .join('  '),
                        placeholder: 'Add season',
                        onTap: () => _pickSeasons(item),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DetailGroup(
                    children: [
                      IntrinsicHeight(
                        child: Row(
                          children: [
                            Expanded(
                              child: DetailRow(
                                icon: Icons.paid_outlined,
                                label: item.price == null
                                    ? null
                                    : AppFormatters.price(
                                        item.price!,
                                        currency,
                                      ),
                                placeholder: 'Price',
                                chevron: false,
                                onTap: () => _editPrice(item, currency),
                              ),
                            ),
                            VerticalDivider(width: 1, color: palette.border),
                            Expanded(
                              child: DetailRow(
                                icon: Icons.event_available_outlined,
                                label: item.purchaseDate == null
                                    ? null
                                    : AppFormatters.shortDate(
                                        item.purchaseDate!,
                                      ),
                                placeholder: 'Purchase date',
                                chevron: false,
                                onTap: () => _pickPurchaseDate(item),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DetailGroup(
                    children: [
                      DetailRow(
                        icon: Icons.edit_note_rounded,
                        label: item.notes,
                        placeholder: 'Add a note...',
                        chevron: false,
                        multiline: true,
                        onTap: () => _editNote(item),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DetailGroup(
                    children: [
                      DetailRow(
                        icon: Icons.checkroom_outlined,
                        label: 'Create outfit',
                        onTap: item.isArchived
                            ? null
                            : () => AppNavigator.createOutfit(
                                context,
                                initialItemIds: [item.id],
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DetailGroup(
                    children: [
                      DetailSwitchRow(
                        icon: Icons.visibility_off_outlined,
                        label: 'Hide in my profile',
                        value: item.hideInProfile,
                        onChanged: (value) =>
                            _patch((i) => i.copyWith(hideInProfile: value)),
                      ),
                      DetailSwitchRow(
                        icon: Icons.do_not_touch_outlined,
                        label: 'Don’t let others add this item',
                        value: item.noStyling,
                        onChanged: (value) =>
                            _patch((i) => i.copyWith(noStyling: value)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(
                        child: TrayAction(
                          icon: Icons.bookmark_border_rounded,
                          label: 'Add to collection',
                          onTap: () => CollectionFlows.addItem(context, _id),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: TrayAction(
                          icon: Icons.download_rounded,
                          label: 'Save image',
                          onTap: () => ClosetFlows.saveItemImage(context, item),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: TrayAction(
                          icon: item.isArchived
                              ? Icons.unarchive_outlined
                              : Icons.inventory_2_outlined,
                          label: item.isArchived ? 'Restore' : 'Archive',
                          onTap: () =>
                              _setArchived(item, archived: !item.isArchived),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: TrayAction(
                          icon: Icons.delete_outline_rounded,
                          label: 'Delete',
                          onTap: () => _delete(item),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    '${AppFormatters.wearCount(item.wearCount)} · '
                    'in ${AppFormatters.count(usedIn, 'outfit')}',
                    textAlign: TextAlign.center,
                    style: text.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Added on ${AppFormatters.weekdayName(item.createdAt).substring(0, 3)}, '
                    '${AppFormatters.monthName(item.createdAt)} '
                    '${item.createdAt.day}, ${item.createdAt.year}',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(color: hint),
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

/// Round grey ‹ / › over the photo.
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon),
        style: IconButton.styleFrom(
          backgroundColor: palette.surfaceMuted.withValues(alpha: 0.9),
          foregroundColor: palette.ink,
        ),
      ),
    );
  }
}

class _ArchivedBanner extends StatelessWidget {
  const _ArchivedBanner({required this.onRestore});

  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined, size: AppSizes.iconSm),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(child: Text('This item is archived')),
          TextButton(onPressed: onRestore, child: const Text('Restore')),
        ],
      ),
    );
  }
}
