import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/extensions/model_presentation.dart';
import 'package:all_fits/core/utils/validators.dart';
import 'package:all_fits/core/widgets/app_dialogs.dart';
import 'package:all_fits/core/widgets/feedback_views.dart';
import 'package:all_fits/core/widgets/selectable_pill.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/occasion.dart';
import 'package:all_fits/data/models/outfit_board.dart';
import 'package:all_fits/data/models/outfit_create_mode.dart';
import 'package:all_fits/data/models/outfit_slot.dart';
import 'package:all_fits/data/models/season.dart';
import 'package:all_fits/features/outfits/controllers/outfit_builder_controller.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/outfit_flows.dart';
import 'package:all_fits/features/outfits/widgets/board_decorations.dart';
import 'package:all_fits/features/outfits/widgets/builder_widgets.dart';
import 'package:all_fits/features/outfits/widgets/item_picker_sheet.dart';
import 'package:all_fits/features/outfits/widgets/outfit_canvas.dart';
import 'package:all_fits/features/outfits/widgets/outfit_cover.dart';
import 'package:all_fits/features/premium/premium_flows.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/shared/closet_actions.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/navigation/app_navigation.dart';

class OutfitBuilderArgs {
  const OutfitBuilderArgs({
    this.outfitId,
    this.initialItemIds = const [],
    this.photoFile,
    this.planDate,
    this.hair,
    this.canSwitchMode = false,
    this.detailsOnly = false,
  });

  /// Outfit to edit; null creates a new outfit.
  final String? outfitId;

  /// Pieces to start a new outfit with.
  final List<String> initialItemIds;

  /// A just-taken outfit selfie (a temporary file) for a new outfit.
  final String? photoFile;

  /// Plans the new outfit on this day once it is saved.
  final DateTime? planDate;

  /// Hair worn in the Dressing Room, put on the new outfit too.
  final (Hairstyle, HairColor)? hair;

  /// Offers Fits' "Switch mode"; picking another mode closes the screen
  /// with an [OutfitModeSwitch].
  final bool canSwitchMode;

  /// Opens straight on the details, as Fits does after the Dressing Room.
  final bool detailsOnly;
}

/// Fits' collage board, then "Next" to the outfit's details and Save. An
/// outfit selfie skips the board: its details come with the photo.
class OutfitBuilderScreen extends StatefulWidget {
  const OutfitBuilderScreen({super.key, required this.args});

  final OutfitBuilderArgs args;

  @override
  State<OutfitBuilderScreen> createState() => _OutfitBuilderScreenState();
}

class _OutfitBuilderScreenState extends State<OutfitBuilderScreen> {
  OutfitBuilderController? _builder;

  /// The outfit's selfie: just taken, or already stored.
  String? _photoFile;
  String? _photoRef;
  late final TextEditingController _name;
  late final TextEditingController _notes;
  final ValueNotifier<bool> _saving = ValueNotifier(false);
  bool _dirty = false;

  bool get _hasPhoto => _photoFile != null || _photoRef != null;

  @override
  void initState() {
    super.initState();
    final wardrobe = context.read<WardrobeController>();
    final outfitId = widget.args.outfitId;
    final outfit = outfitId == null
        ? null
        : context.read<OutfitController>().outfitById(outfitId);
    if (outfitId == null || outfit != null) {
      final builder = _builder = OutfitBuilderController(
        lookup: wardrobe.itemById,
        initial: outfit,
        initialItemIds: widget.args.initialItemIds,
        // A new collage starts as Fits': head to toe down the middle.
        dressed: outfit == null,
      );
      if (widget.args.hair case (final style, final color)?
          when outfit == null) {
        builder
          ..addHair(style, color)
          ..select(null);
      }
      builder.addListener(_markDirty);
    }
    _photoFile = widget.args.photoFile;
    _photoRef = outfit?.photoPath;
    _name = TextEditingController(text: outfit?.name)..addListener(_markDirty);
    _notes = TextEditingController(text: outfit?.notes)
      ..addListener(_markDirty);
  }

  @override
  void dispose() {
    _builder?.dispose();
    _name.dispose();
    _notes.dispose();
    _saving.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  Future<void> _pickForSlot(OutfitSlot slot) async {
    final builder = _builder!;
    final result = await showItemPickerSheet(
      context,
      slot: slot,
      selected: builder.idsInSlot(slot).toSet(),
      onAddClothing: () => AppNavigator.addClothing(context),
    );
    if (result != null) builder.setSlotSelection(slot, result);
  }

  Future<void> _replace(ClothingItem item) async {
    final result = await showItemPickerSheet(
      context,
      slot: OutfitSlot.forCategory(item.category),
      selected: {item.id},
      single: true,
    );
    if (result != null && result.isNotEmpty) {
      _builder!.replaceItem(item.id, result.first);
    }
  }

  /// Fits' "Add clothes": the whole wardrobe, with the outfit's pieces
  /// ticked.
  Future<void> _addClothes() async {
    final builder = _builder!;
    final result = await showItemPickerSheet(
      context,
      slot: null,
      selected: builder.itemIds.toSet(),
      onAddClothing: () => AppNavigator.addClothing(context),
    );
    if (result != null) builder.setItems(result);
  }

  Future<void> _switchMode() async {
    final builder = _builder!;
    final mode = await OutfitFlows.chooseMode(
      context,
      current: OutfitCreateMode.collage,
    );
    if (mode == null || mode == OutfitCreateMode.collage || !mounted) return;
    Navigator.of(
      context,
    ).pop(OutfitModeSwitch(mode, itemIds: builder.itemIds, hair: builder.hair));
  }

  void _openDetails() {
    final builder = _builder!;
    if (builder.isEmpty) {
      context.showSnack('Add at least one piece to your outfit.');
      return;
    }
    builder.select(null);
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => _details()));
  }

  Widget _details() => _OutfitDetails(
    builder: _builder!,
    name: _name,
    notes: _notes,
    saving: _saving,
    onSave: _save,
  );

  Future<void> _save() async {
    final builder = _builder!;
    if (_saving.value) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (builder.isEmpty && !_hasPhoto) {
      context.showSnack('Add at least one piece to your outfit.');
      return;
    }
    final outfits = context.read<OutfitController>();
    final closet = context.read<ClosetActions>();
    final shell = context.read<ShellController>();
    final navigator = Navigator.of(context);
    final route = ModalRoute.of(context);
    final draft = builder.buildDraft(
      name: _name.text,
      fallbackName: 'Outfit ${outfits.outfits.length + 1}',
      notes: _notes.text,
      newPhotoPath: _photoFile,
      keepsPhoto: _photoFile == null && _photoRef != null,
    );
    _saving.value = true;
    try {
      final editingId = builder.editingId;
      if (editingId == null) {
        final outfit = await outfits.createOutfit(draft);
        final planDate = widget.args.planDate;
        if (planDate != null) await closet.planOutfit(outfit.id, planDate);
        shell.openCloset(ClosetTab.outfits);
      } else {
        await outfits.updateOutfit(editingId, draft);
      }
      _dirty = false;
      // Close the details first, then the board. `true` tells the caller
      // (e.g. "Add outfit") the outfit was saved.
      if (route != null) navigator.popUntil((r) => r == route);
      navigator.pop(true);
      if (mounted) context.showSnack('“${draft.name}” saved');
    } catch (error) {
      _saving.value = false;
      if (mounted) context.showErrorSnack(error);
    }
  }

  Future<void> _confirmDiscard() async {
    final discard = await showConfirmDialog(
      context,
      title: 'Discard outfit?',
      message: 'Your changes to this outfit will be lost.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
      destructive: true,
    );
    if (discard && mounted) {
      setState(() => _dirty = false);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final builder = _builder;
    if (builder == null) {
      return const NotFoundView(
        title: 'Outfit not found',
        message: 'This outfit no longer exists.',
      );
    }
    final Widget page;
    if (_hasPhoto) {
      page = _selfie(builder);
    } else if (widget.args.detailsOnly) {
      page = _details();
    } else {
      page = _CollageStage(
        builder: builder,
        canSwitchMode: widget.args.canSwitchMode,
        onClose: () => Navigator.of(context).maybePop(),
        onNext: _openDetails,
        onAddClothes: _addClothes,
        onSwitchMode: _switchMode,
      );
    }
    return PopScope(
      canPop: !_dirty || _saving.value,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: page,
    );
  }

  /// An outfit selfie: the photo, then its details with the pieces tagged.
  Widget _selfie(OutfitBuilderController builder) {
    // Rebuild when wardrobe items change (e.g. a piece added from a sheet).
    final wardrobe = context.watch<WardrobeController>();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(builder.isEditing ? 'Edit outfit' : 'New outfit'),
        actions: [
          ValueListenableBuilder(
            valueListenable: _saving,
            builder: (context, saving, _) => TextButton(
              onPressed: saving ? null : _save,
              child: const Text('Save'),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([builder, _saving]),
        builder: (context, _) => _BuilderForm(
          builder: builder,
          items: wardrobe.itemsByIds(builder.itemIds),
          name: _name,
          notes: _notes,
          saving: _saving.value,
          tagPieces: true,
          onPickSlot: _pickForSlot,
          onReplace: _replace,
          onSave: _save,
          header: _PhotoPreview(
            file: _photoFile,
            reference: _photoRef,
            onRemove: () => setState(() {
              _photoFile = null;
              _photoRef = null;
              _dirty = true;
            }),
          ),
        ),
      ),
    );
  }
}

/// Fits' collage: the board on black, back and Next over it, and the tools
/// below.
class _CollageStage extends StatelessWidget {
  const _CollageStage({
    required this.builder,
    required this.canSwitchMode,
    required this.onClose,
    required this.onNext,
    required this.onAddClothes,
    required this.onSwitchMode,
  });

  final OutfitBuilderController builder;
  final bool canSwitchMode;
  final VoidCallback onClose;
  final VoidCallback onNext;
  final VoidCallback onAddClothes;
  final VoidCallback onSwitchMode;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final wardrobe = context.watch<WardrobeController>();
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: ListenableBuilder(
            listenable: builder,
            builder: (context, _) {
              final items = wardrobe.itemsByIds(builder.itemIds);
              return Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xs,
                        AppSpacing.xs,
                        AppSpacing.xs,
                        0,
                      ),
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: AppSizes.outfitImageAspect,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                OutfitCanvas(
                                  items: items,
                                  layout: builder.layout,
                                  onChanged: builder.setLayout,
                                  background: builder.background,
                                  stickers: builder.stickers,
                                  onStickersChanged: builder.setStickers,
                                  selectedId: builder.selectedId,
                                  onSelected: builder.select,
                                ),
                                if (items.isEmpty)
                                  IgnorePointer(
                                    child: Center(
                                      child: Text(
                                        'Tap Add clothes to start',
                                        style: context.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: palette.textSecondary,
                                            ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  top: AppSpacing.sm,
                                  left: AppSpacing.sm,
                                  child: _RoundButton(
                                    tooltip: 'Close',
                                    icon: Icons.chevron_left_rounded,
                                    onTap: onClose,
                                  ),
                                ),
                                Positioned(
                                  top: AppSpacing.sm,
                                  right: AppSpacing.sm,
                                  child: NextPill(onTap: onNext),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    child: _BoardTools(
                      builder: builder,
                      canSwitchMode: canSwitchMode,
                      onAddClothes: onAddClothes,
                      onSwitchMode: onSwitchMode,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Fits' black "Next →" pill.
class NextPill extends StatelessWidget {
  const NextPill({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Tooltip(
      message: 'Next',
      child: Material(
        color: palette.ink,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Next',
                  style: context.textTheme.titleSmall?.copyWith(
                    color: palette.onInk,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: AppSizes.iconSm,
                  color: palette.onInk,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A translucent round button over the board.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
      ),
    );
  }
}

/// The outfit selfie in place of the collage.
class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({required this.onRemove, this.file, this.reference});

  final String? file;
  final String? reference;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.maxPreviewWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: AppSizes.outfitImageAspect,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                child: OutfitPhoto(file: file, reference: reference),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onRemove,
                child: const Text('Use a collage instead'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fits' "New outfit": a preview of the board, the details, and Save.
class _OutfitDetails extends StatelessWidget {
  const _OutfitDetails({
    required this.builder,
    required this.name,
    required this.notes,
    required this.saving,
    required this.onSave,
  });

  final OutfitBuilderController builder;
  final TextEditingController name;
  final TextEditingController notes;
  final ValueNotifier<bool> saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final wardrobe = context.watch<WardrobeController>();
    return Scaffold(
      appBar: AppBar(
        title: Text(builder.isEditing ? 'Edit outfit' : 'New outfit'),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([builder, saving]),
        builder: (context, _) {
          final items = wardrobe.itemsByIds(builder.itemIds);
          return _BuilderForm(
            builder: builder,
            items: items,
            name: name,
            notes: notes,
            saving: saving.value,
            tagPieces: false,
            onSave: onSave,
            header: _BoardPreview(builder: builder, items: items),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.sm,
            AppSpacing.page,
            AppSpacing.md,
          ),
          child: ValueListenableBuilder(
            valueListenable: saving,
            builder: (context, busy, _) => FilledButton(
              onPressed: busy ? null : onSave,
              child: busy
                  ? SizedBox.square(
                      dimension: AppSizes.iconSm,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: palette.onInk,
                      ),
                    )
                  : const Text('Save outfit'),
            ),
          ),
        ),
      ),
    );
  }
}

/// The finished board as a card, above the details.
class _BoardPreview extends StatelessWidget {
  const _BoardPreview({required this.builder, required this.items});

  final OutfitBuilderController builder;
  final List<ClothingItem> items;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.55,
        child: AspectRatio(
          aspectRatio: AppSizes.outfitImageAspect,
          child: Container(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: OutfitCanvas(
              items: items,
              layout: builder.layout,
              background: builder.background,
              stickers: builder.stickers,
            ),
          ),
        ),
      ),
    );
  }
}

/// Fits' board tools: Add clothes, Stickers, Background and Switch mode,
/// or, while a piece or sticker is selected, what can be done to it.
class _BoardTools extends StatelessWidget {
  const _BoardTools({
    required this.builder,
    required this.canSwitchMode,
    required this.onAddClothes,
    required this.onSwitchMode,
  });

  final OutfitBuilderController builder;
  final bool canSwitchMode;
  final VoidCallback onAddClothes;
  final VoidCallback onSwitchMode;

  Future<void> _addSticker(BuildContext context) async {
    final picked = await showStickerSheet(
      context,
      premium: context.read<SettingsController>().plan.isPremium,
      onLocked: () => PremiumFlows.showStickerLimit(context),
    );
    if (picked != null) builder.addSticker(picked);
  }

  Future<void> _pickBackground(BuildContext context) async {
    final picked = await showBackgroundSheet(context, builder.background);
    if (picked != null) builder.setBackground(picked);
  }

  @override
  Widget build(BuildContext context) {
    if (builder.selectedId == null) {
      return Row(
        children: [
          for (final (icon, label, onTap) in [
            (Icons.checkroom_outlined, 'Add clothes', onAddClothes),
            (
              Icons.sticky_note_2_outlined,
              'Stickers',
              () => _addSticker(context),
            ),
            (
              Icons.water_drop_outlined,
              'Background',
              () => _pickBackground(context),
            ),
            if (canSwitchMode)
              (Icons.swap_horiz_rounded, 'Switch mode', onSwitchMode),
          ])
            Expanded(
              child: BoardToolTile(icon: icon, label: label, onTap: onTap),
            ),
        ],
      );
    }
    final sticker = builder.selectedSticker;
    final locked = builder.selectedLocked;
    return SizedBox(
      height: BoardToolTile.height,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          BoardToolTile(
            icon: Icons.chevron_left_rounded,
            label: 'Done',
            onTap: () => builder.select(null),
          ),
          if (sticker != null)
            BoardToolTile(
              icon: Icons.copy_rounded,
              label: 'Duplicate',
              onTap: builder.duplicateSelected,
            ),
          BoardToolTile(
            icon: Icons.flip_rounded,
            label: 'Flip',
            onTap: locked ? null : builder.flipSelected,
          ),
          if (builder.selectedBehind)
            BoardToolTile(
              icon: Icons.flip_to_front_rounded,
              label: 'Bring to front',
              onTap: builder.bringSelectedToFront,
            )
          else
            BoardToolTile(
              icon: Icons.flip_to_back_rounded,
              label: 'Send to back',
              onTap: builder.sendSelectedToBack,
            ),
          BoardToolTile(
            icon: locked ? Icons.lock_rounded : Icons.lock_open_rounded,
            label: locked ? 'Unlock' : 'Lock',
            onTap: builder.toggleLockSelected,
          ),
          BoardToolTile(
            icon: Icons.delete_outline_rounded,
            label: sticker != null ? 'Delete' : 'Remove',
            onTap: builder.deleteSelected,
          ),
        ],
      ),
    );
  }
}

/// A tile with an icon over its label, as in Fits' bottom bars: grey on
/// the collage's black, or [light] on white (the Dressing Room).
class BoardToolTile extends StatelessWidget {
  const BoardToolTile({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.light = false,
  });

  static const double height = 64;

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final Color color;
    if (light) {
      color = onTap == null ? palette.textTertiary : palette.ink;
    } else {
      color = Colors.white.withValues(alpha: onTap == null ? 0.4 : 1);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      child: Material(
        color: light
            ? palette.surfaceMuted
            : Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppRadius.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 72),
            child: SizedBox(
              height: height,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: color),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.labelMedium?.copyWith(
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BuilderForm extends StatelessWidget {
  const _BuilderForm({
    required this.builder,
    required this.items,
    required this.name,
    required this.notes,
    required this.saving,
    required this.tagPieces,
    required this.onSave,
    this.onPickSlot,
    this.onReplace,
    this.header,
  });

  final OutfitBuilderController builder;
  final List<ClothingItem> items;
  final TextEditingController name;
  final TextEditingController notes;
  final bool saving;

  /// The outfit is a selfie, so its pieces are tags picked here, and the
  /// form ends with its own Save button.
  final bool tagPieces;
  final VoidCallback onSave;
  final ValueChanged<OutfitSlot>? onPickSlot;
  final ValueChanged<ClothingItem>? onReplace;

  /// Shown above the form: the photo or the board.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.md,
        AppSpacing.page,
        AppSpacing.xxl,
      ),
      children: [
        if (header != null) ...[header!, const SizedBox(height: AppSpacing.xl)],
        if (tagPieces) ...[
          LabeledSection(
            label: 'Tag what you’re wearing',
            child: SlotSelector(
              countOf: (slot) => builder.idsInSlot(slot).length,
              onSelect: onPickSlot!,
            ),
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            LabeledSection(
              label: 'Your look',
              trailing: Text(
                'Drag to reorder',
                style: context.textTheme.bodySmall,
              ),
              child: CompositionList(
                items: items,
                onReorderItem: builder.reorder,
                onReplace: onReplace!,
                onRemove: (item) => builder.removeItem(item.id),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
        ],
        TextField(
          controller: name,
          maxLength: Validators.maxNameLength,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Outfit name',
            hintText: 'e.g. Weekend denim',
            counterText: '',
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        LabeledSection(
          label: 'Occasion',
          child: PillGroup<Occasion>(
            options: Occasion.values,
            selected: {?builder.occasion},
            labelOf: (o) => o.label,
            leadingOf: (o) => Icon(
              o.icon,
              size: 16,
              color: o == builder.occasion ? palette.onInk : palette.ink,
            ),
            onToggle: (o) =>
                builder.setOccasion(o == builder.occasion ? null : o),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        LabeledSection(
          label: 'Season',
          child: PillGroup<Season>(
            options: Season.values,
            selected: builder.seasons,
            labelOf: (s) => s.label,
            onToggle: builder.toggleSeason,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: notes,
          minLines: 2,
          maxLines: 5,
          maxLength: Validators.maxNotesLength,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Notes',
            hintText: 'Styling tips, where you wore it…',
            alignLabelWithHint: true,
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Favorite'),
          value: builder.isFavorite,
          onChanged: builder.setFavorite,
        ),
        if (tagPieces) ...[
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: saving ? null : onSave,
            child: saving
                ? SizedBox.square(
                    dimension: AppSizes.iconSm,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.onInk,
                    ),
                  )
                : const Text('Save Outfit'),
          ),
        ],
      ],
    );
  }
}
