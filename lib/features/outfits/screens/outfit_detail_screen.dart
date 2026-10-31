import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/extensions/model_presentation.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/utils/validators.dart';
import 'package:all_fits/core/widgets/app_dialogs.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/core/widgets/detail_rows.dart';
import 'package:all_fits/core/widgets/feedback_views.dart';
import 'package:all_fits/core/widgets/layout.dart';
import 'package:all_fits/core/widgets/option_sheets.dart';
import 'package:all_fits/core/widgets/selection_tray.dart';
import 'package:all_fits/data/local/image_picker_service.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/occasion.dart';
import 'package:all_fits/data/models/outfit.dart';
import 'package:all_fits/data/models/outfit_calendar_entry.dart';
import 'package:all_fits/data/models/season.dart';
import 'package:all_fits/features/collections/collection_flows.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/widgets/outfit_cover.dart';
import 'package:all_fits/features/planner/controllers/planner_controller.dart';
import 'package:all_fits/features/shared/closet_actions.dart';
import 'package:all_fits/features/shared/closet_flows.dart';
import 'package:all_fits/features/social/social_controller.dart';
import 'package:all_fits/features/social/social_flows.dart';
import 'package:all_fits/features/stylist/screens/stylist_screen.dart';
import 'package:all_fits/features/try_on/try_on_controller.dart';
import 'package:all_fits/features/try_on/try_on_flows.dart';
import 'package:all_fits/features/try_on/widgets/try_on_widgets.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';

/// Fits' outfit page: the picture on a large card, then the pieces and
/// every detail editable in place, and Duplicate / Add to collection /
/// Delete / More at the bottom.
class OutfitDetailScreen extends StatelessWidget {
  const OutfitDetailScreen({super.key, required this.outfitId});

  final String outfitId;

  static const double _cardAspect = 0.66;

  Future<void> _patch(
    BuildContext context,
    Outfit Function(Outfit outfit) change,
  ) => ClosetFlows.guard(
    context,
    () => context.read<OutfitController>().patchOutfit(outfitId, change),
  );

  Future<void> _rename(BuildContext context, Outfit outfit) async {
    final name = await showTextInputDialog(
      context,
      title: 'Caption',
      initialValue: outfit.name,
      maxLength: Validators.maxNameLength,
    );
    if (name == null || name.isEmpty || !context.mounted) return;
    await _patch(context, (o) => o.copyWith(name: name));
  }

  Future<void> _pickOccasion(BuildContext context, Outfit outfit) async {
    final picked = await showMultiSelectSheet<Occasion>(
      context,
      single: true,
      options: Occasion.values,
      selected: {?outfit.occasion},
      labelOf: (o) => o.label,
      leadingOf: (o) => Icon(o.icon),
    );
    if (picked == null || !context.mounted) return;
    await _patch(context, (o) => o.copyWith(occasion: picked.firstOrNull));
  }

  Future<void> _pickSeasons(BuildContext context, Outfit outfit) async {
    final picked = await showMultiSelectSheet<Season>(
      context,
      options: Season.values,
      selected: outfit.seasons.toSet(),
      labelOf: (s) => s.label,
      leadingOf: (s) => EmojiIcon(s.emoji, size: 28),
    );
    if (picked == null || !context.mounted) return;
    await _patch(
      context,
      (o) => o.copyWith(seasons: Season.values.where(picked.contains).toList()),
    );
  }

  Future<void> _editNote(BuildContext context, Outfit outfit) async {
    final note = await showTextInputDialog(
      context,
      title: 'Note',
      initialValue: outfit.notes ?? '',
      hint: 'Add a note...',
      maxLength: Validators.maxNotesLength,
      multiline: true,
    );
    if (note == null || !context.mounted) return;
    await _patch(context, (o) => o.copyWith(notes: note.isEmpty ? null : note));
  }

  Future<void> _addPhoto(BuildContext context) async {
    final picker = context.read<ImagePickerService>();
    final outfits = context.read<OutfitController>();
    var source = ImagePickSource.gallery;
    if (picker.supportsCamera) {
      final chosen = await showModalBottomSheet<ImagePickSource>(
        context: context,
        builder: (sheetContext) => SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetActionTile(
                icon: Icons.photo_camera_outlined,
                label: 'Take a selfie',
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImagePickSource.camera),
              ),
              SheetActionTile(
                icon: Icons.photo_library_outlined,
                label: 'Choose from library',
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImagePickSource.gallery),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      );
      if (chosen == null) return;
      source = chosen;
    }
    try {
      final path = await picker.pickImage(source);
      if (path == null || !context.mounted) return;
      await outfits.setPhoto(outfitId, path);
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
    }
  }

  Future<void> _duplicate(BuildContext context) async {
    final outfits = context.read<OutfitController>();
    try {
      final copy = await outfits.duplicateOutfit(outfitId);
      if (!context.mounted) return;
      context.showSnack('Outfit duplicated');
      await AppNavigator.outfitDetail(context, copy.id);
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
    }
  }

  Future<void> _delete(BuildContext context, Outfit outfit) async {
    final navigator = Navigator.of(context);
    final deleted = await ClosetFlows.deleteOutfit(context, outfit);
    if (deleted) navigator.pop();
  }

  Future<void> _more(
    BuildContext context,
    Outfit outfit,
    List<ClothingItem> items,
  ) {
    final today = context.read<ClosetActions>().today;
    final tryOn = context.read<TryOnController>().isAvailable;
    final outfits = context.read<OutfitController>();
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        void go(Future<void> Function() action) {
          Navigator.of(sheetContext).pop();
          action();
        }

        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetActionTile(
                icon: Icons.check_rounded,
                label: 'Mark as worn today',
                onTap: () => go(
                  () => ClosetFlows.markWorn(context, outfitId, date: today),
                ),
              ),
              if (tryOn && items.isNotEmpty)
                SheetActionTile(
                  icon: Icons.auto_awesome_outlined,
                  label: 'Try on with AI',
                  onTap: () => go(
                    () => TryOnFlows.start(
                      context,
                      itemIds: [for (final item in items) item.id],
                      outfitId: outfitId,
                    ),
                  ),
                ),
              if (outfit.photoPath != null)
                SheetActionTile(
                  icon: Icons.hide_image_outlined,
                  label: 'Remove outfit photo',
                  onTap: () => go(
                    () => ClosetFlows.guard(
                      context,
                      () => outfits.setPhoto(outfitId, null),
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final outfits = context.watch<OutfitController>();
    final outfit = outfits.outfitById(outfitId);
    if (outfit == null) {
      return const NotFoundView(
        title: 'Outfit not found',
        message: 'This outfit no longer exists.',
      );
    }
    final items = context.watch<WardrobeController>().itemsByIds(
      outfit.itemIds,
    );
    final entries =
        context
            .watch<PlannerController>()
            .entries
            .where((e) => e.outfitId == outfitId)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final palette = context.palette;
    final text = context.textTheme;
    final lastWorn = outfit.lastWornAt;
    final types = <String>{
      for (final item in items)
        item.subcategory?.label ?? item.category.singularLabel,
    };

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
          children: [
            ResponsiveCenter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    AspectRatio(
                      aspectRatio: _cardAspect,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              OutfitCover(
                                outfit: outfit,
                                items: items,
                                worn: true,
                                padding: const EdgeInsets.all(AppSpacing.lg),
                              ),
                              Positioned(
                                left: AppSpacing.sm,
                                top: AppSpacing.sm,
                                child: IconButton(
                                  tooltip: 'Back',
                                  onPressed: () =>
                                      Navigator.of(context).maybePop(),
                                  icon: const Icon(Icons.chevron_left_rounded),
                                  style: IconButton.styleFrom(
                                    backgroundColor: palette.textTertiary
                                        .withValues(alpha: 0.8),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              if (outfit.photoPath == null)
                                Positioned(
                                  right: AppSpacing.sm,
                                  bottom: AppSpacing.sm,
                                  child: _AddPhotoTile(
                                    onTap: () => _addPhoto(context),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        IconButton(
                          tooltip: outfit.isFavorite
                              ? 'Unfavorite'
                              : 'Favorite',
                          onPressed: () => ClosetFlows.guard(
                            context,
                            () => outfits.toggleFavorite(outfit.id),
                          ),
                          icon: Icon(
                            outfit.isFavorite
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
                              prompt: 'What do you think of this outfit?',
                              itemIds: [for (final item in items) item.id],
                            ),
                          ),
                          icon: const Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: AppSizes.iconLg,
                          ),
                        ),
                        const Spacer(),
                        FilledButton.icon(
                          onPressed: () =>
                              AppNavigator.editOutfit(context, outfit.id),
                          icon: const Icon(Icons.image_outlined),
                          label: const Text('Edit'),
                          style: FilledButton.styleFrom(
                            backgroundColor: palette.surfaceMuted,
                            foregroundColor: palette.ink,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => _rename(context, outfit),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(outfit.name, style: text.titleLarge),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Icon(
                              Icons.edit_outlined,
                              color: palette.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Divider(height: AppSpacing.xl, color: palette.border),
                    Text(
                      'Clothes in outfit',
                      style: text.bodyMedium?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      height: 84,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final item in items)
                            _PieceThumb(
                              item: item,
                              onTap: () => AppNavigator.clothingDetail(
                                context,
                                item.id,
                                siblings: [for (final i in items) i.id],
                              ),
                            ),
                          _PieceThumb(
                            onTap: () =>
                                AppNavigator.editOutfit(context, outfit.id),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    DetailGroup(
                      children: [
                        DetailRow(
                          icon: Icons.format_list_bulleted_rounded,
                          label: types.isEmpty ? null : types.join(' · '),
                          placeholder: 'Add clothes',
                          onTap: () =>
                              AppNavigator.editOutfit(context, outfit.id),
                        ),
                        DetailRow(
                          icon: Icons.local_activity_outlined,
                          leading: outfit.occasion == null
                              ? null
                              : Icon(
                                  outfit.occasion!.icon,
                                  color: palette.textSecondary,
                                ),
                          label: outfit.occasion?.label,
                          placeholder: 'Add occasion',
                          onTap: () => _pickOccasion(context, outfit),
                        ),
                        DetailRow(
                          icon: Icons.wb_sunny_outlined,
                          label: outfit.seasons.isEmpty
                              ? null
                              : outfit.seasons
                                    .map((s) => '${s.emoji} ${s.label}')
                                    .join('  '),
                          placeholder: 'Add season',
                          onTap: () => _pickSeasons(context, outfit),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    DetailGroup(
                      children: [
                        DetailRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Schedule outfit',
                          onTap: () =>
                              ClosetFlows.planOutfit(context, outfit.id),
                        ),
                        if (entries.isNotEmpty || lastWorn != null)
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (entries.isNotEmpty)
                                  SizedBox(
                                    height: 84,
                                    child: ListView(
                                      scrollDirection: Axis.horizontal,
                                      children: [
                                        for (final entry in entries)
                                          _DateChip(entry: entry),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  lastWorn == null
                                      ? AppFormatters.wearCount(
                                          outfit.wearCount,
                                        )
                                      : '${AppFormatters.wearCount(outfit.wearCount)}'
                                            ' · last worn '
                                            '${AppFormatters.relativeDay(lastWorn).toLowerCase()}',
                                  style: text.bodyMedium?.copyWith(
                                    color: palette.textSecondary,
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
                          label: outfit.notes,
                          placeholder: 'Add a note...',
                          chevron: false,
                          multiline: true,
                          onTap: () => _editNote(context, outfit),
                        ),
                      ],
                    ),
                    if (context.watch<SocialController?>() case final social?)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.md),
                        child: DetailGroup(
                          children: [
                            _PublicSwitch(social: social, outfitId: outfit.id),
                          ],
                        ),
                      ),
                    _TryOnStrip(outfitId: outfit.id),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: TrayAction(
                            icon: Icons.copy_rounded,
                            label: 'Duplicate',
                            onTap: () => _duplicate(context),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: TrayAction(
                            icon: Icons.bookmark_border_rounded,
                            label: 'Add to collection',
                            onTap: () =>
                                CollectionFlows.addOutfit(context, outfit.id),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: TrayAction(
                            icon: Icons.delete_outline_rounded,
                            label: 'Delete',
                            onTap: () => _delete(context, outfit),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: TrayAction(
                            icon: Icons.more_horiz_rounded,
                            label: 'More',
                            onTap: () => _more(context, outfit, items),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Added on ${AppFormatters.weekdayName(outfit.createdAt).substring(0, 3)}, '
                      '${AppFormatters.monthName(outfit.createdAt)} '
                      '${outfit.createdAt.day}, ${outfit.createdAt.year}',
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small "Add photo" pill in the board's corner, kept clear of the pieces.
class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: 'Add outfit photo',
      child: Material(
        color: palette.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        elevation: 1,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + 2,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.add_a_photo_outlined,
                  size: AppSizes.iconSm,
                  color: palette.ink,
                ),
                const SizedBox(width: AppSpacing.xs),
                ExcludeSemantics(
                  child: Text(
                    'Add photo',
                    style: context.textTheme.labelMedium,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A piece in "Clothes in outfit", or "+" to add more when [item] is null.
class _PieceThumb extends StatelessWidget {
  const _PieceThumb({required this.onTap, this.item});

  final ClothingItem? item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final item = this.item;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Semantics(
        button: true,
        label: item?.name ?? 'Add clothes',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 84,
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: palette.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: item == null
                ? const Icon(Icons.add_rounded, size: AppSizes.iconLg)
                : ClothingImage(
                    item: item,
                    cutout: true,
                    fit: BoxFit.contain,
                    decodeWidth: 84,
                  ),
          ),
        ),
      ),
    );
  }
}

/// "Mon / 26 / Oct" for a day the outfit was worn or is planned.
class _DateChip extends StatelessWidget {
  const _DateChip({required this.entry});

  final OutfitCalendarEntry entry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    final date = entry.date;
    return Container(
      width: 72,
      margin: const EdgeInsets.only(right: AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            AppFormatters.weekdayName(date).substring(0, 3),
            style: text.bodySmall?.copyWith(color: palette.textSecondary),
          ),
          Text('${date.day}', style: text.titleLarge),
          Text(
            entry.isWorn ? AppFormatters.monthShort(date) : 'Planned',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// AI try-on pictures made from this outfit.
class _TryOnStrip extends StatelessWidget {
  const _TryOnStrip({required this.outfitId});

  final String outfitId;

  static const double _width = 96;

  @override
  Widget build(BuildContext context) {
    final results = context.watch<TryOnController>().resultsForOutfit(outfitId);
    if (results.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.lg),
        Text('AI try-on', style: context.textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: _width * 4 / 3,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: results.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
            itemBuilder: (context, index) => Semantics(
              button: true,
              label: 'Try-on picture ${index + 1}',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => TryOnFlows.open(context, results[index]),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: SizedBox(
                    width: _width,
                    child: StoredPhoto(
                      reference: results[index].photo,
                      decodeWidth: _width,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shares the outfit on Discover.
class _PublicSwitch extends StatelessWidget {
  const _PublicSwitch({required this.social, required this.outfitId});

  final SocialController social;
  final String outfitId;

  Future<void> _set(BuildContext context, bool posted) async {
    if (posted && !await SocialFlows.requireProfile(context)) return;
    if (!context.mounted) return;
    await ClosetFlows.guard(
      context,
      () => social.setPosted(outfitId, posted: posted),
      successMessage: posted ? 'Shared on Discover' : 'Removed from Discover',
    );
  }

  @override
  Widget build(BuildContext context) {
    return DetailSwitchRow(
      icon: Icons.public_rounded,
      label: 'Show on Discover',
      value: social.isPosted(outfitId),
      onChanged: (value) => _set(context, value),
    );
  }
}
