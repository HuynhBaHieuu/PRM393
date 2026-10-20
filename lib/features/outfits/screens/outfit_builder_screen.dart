import 'package:flutter/material.dart';
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
import 'package:all_fits/data/models/outfit_slot.dart';
import 'package:all_fits/data/models/season.dart';
import 'package:all_fits/features/outfits/controllers/outfit_builder_controller.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/widgets/builder_widgets.dart';
import 'package:all_fits/features/outfits/widgets/item_picker_sheet.dart';
import 'package:all_fits/features/outfits/widgets/outfit_canvas.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/navigation/app_navigation.dart';

class OutfitBuilderArgs {
  const OutfitBuilderArgs({this.outfitId, this.initialItemIds = const []});

  /// Outfit to edit; null creates a new outfit.
  final String? outfitId;

  /// Pieces to start a new outfit with.
  final List<String> initialItemIds;
}

class OutfitBuilderScreen extends StatefulWidget {
  const OutfitBuilderScreen({super.key, required this.args});

  final OutfitBuilderArgs args;

  @override
  State<OutfitBuilderScreen> createState() => _OutfitBuilderScreenState();
}

class _OutfitBuilderScreenState extends State<OutfitBuilderScreen> {
  OutfitBuilderController? _builder;
  late final TextEditingController _name;
  late final TextEditingController _notes;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final wardrobe = context.read<WardrobeController>();
    final outfitId = widget.args.outfitId;
    final outfit = outfitId == null
        ? null
        : context.read<OutfitController>().outfitById(outfitId);
    if (outfitId == null || outfit != null) {
      _builder = OutfitBuilderController(
        lookup: wardrobe.itemById,
        initial: outfit,
        initialItemIds: widget.args.initialItemIds,
      )..addListener(_markDirty);
    }
    _name = TextEditingController(text: outfit?.name)..addListener(_markDirty);
    _notes = TextEditingController(text: outfit?.notes)
      ..addListener(_markDirty);
  }

  @override
  void dispose() {
    _builder?.dispose();
    _name.dispose();
    _notes.dispose();
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

  Future<void> _save() async {
    final builder = _builder!;
    if (_saving) return;
    FocusScope.of(context).unfocus();
    if (builder.isEmpty) {
      context.showSnack('Add at least one piece to your outfit.');
      return;
    }
    final outfits = context.read<OutfitController>();
    final shell = context.read<ShellController>();
    final navigator = Navigator.of(context);
    final draft = builder.buildDraft(
      name: _name.text,
      fallbackName: 'Outfit ${outfits.outfits.length + 1}',
      notes: _notes.text,
    );
    setState(() => _saving = true);
    try {
      final editingId = builder.editingId;
      if (editingId == null) {
        await outfits.createOutfit(draft);
        shell.openCloset(ClosetTab.outfits);
      } else {
        await outfits.updateOutfit(editingId, draft);
      }
      _dirty = false;
      // `true` tells the caller (e.g. the swipe screen) the outfit was saved.
      navigator.pop(true);
      if (mounted) context.showSnack('“${draft.name}” saved');
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        context.showErrorSnack(error);
      }
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
    // Rebuild when wardrobe items change (e.g. a piece added from a sheet).
    final wardrobe = context.watch<WardrobeController>();

    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(builder.isEditing ? 'Edit outfit' : 'New outfit'),
          actions: [
            TextButton(
              onPressed: _saving ? null : _save,
              child: const Text('Save'),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ),
        body: ListenableBuilder(
          listenable: builder,
          builder: (context, _) {
            final items = wardrobe.itemsByIds(builder.itemIds);
            final preview = _Preview(builder: builder, items: items);
            return LayoutBuilder(
              builder: (context, constraints) {
                final wide =
                    constraints.maxWidth >= AppSizes.wideLayoutBreakpoint;
                final form = _BuilderForm(
                  builder: builder,
                  items: items,
                  name: _name,
                  notes: _notes,
                  saving: _saving,
                  onPickSlot: _pickForSlot,
                  onReplace: _replace,
                  onSave: _save,
                  header: wide ? null : preview,
                );
                if (!wide) return form;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: preview,
                      ),
                    ),
                    Expanded(child: form),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.builder, required this.items});

  final OutfitBuilderController builder;
  final List<ClothingItem> items;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final canvas = AspectRatio(
      aspectRatio: AppSizes.outfitImageAspect,
      child: items.isEmpty
              ? Container(
                  decoration: BoxDecoration(
                    color: palette.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(color: palette.border),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.style_outlined,
                        size: AppSizes.iconXl,
                        color: palette.textSecondary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Build your look',
                        style: context.textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Add pieces from your wardrobe below.',
                        textAlign: TextAlign.center,
                        style: context.textTheme.bodySmall,
                      ),
                    ],
                  ),
                )
              : DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    border: Border.all(color: palette.border),
                  ),
                  child: OutfitCanvas(
                    items: items,
                    layout: builder.layout,
                    onChanged: builder.setLayout,
                  ),
                ),
    );
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.maxPreviewWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            canvas,
            if (items.isNotEmpty)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Drag to move, pinch to resize and turn.',
                      style: context.textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: builder.layout.isEmpty
                        ? null
                        : builder.resetLayout,
                    child: const Text('Reset layout'),
                  ),
                ],
              ),
          ],
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
    required this.onPickSlot,
    required this.onReplace,
    required this.onSave,
    this.header,
  });

  final OutfitBuilderController builder;
  final List<ClothingItem> items;
  final TextEditingController name;
  final TextEditingController notes;
  final bool saving;
  final ValueChanged<OutfitSlot> onPickSlot;
  final ValueChanged<ClothingItem> onReplace;
  final VoidCallback onSave;

  /// Shown above the form on narrow layouts (the outfit preview).
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xs,
        AppSpacing.page,
        AppSpacing.xxl,
      ),
      children: [
        if (header != null) ...[header!, const SizedBox(height: AppSpacing.xl)],
        LabeledSection(
          label: 'Add pieces',
          child: SlotSelector(
            countOf: (slot) => builder.idsInSlot(slot).length,
            onSelect: onPickSlot,
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
              onReplace: onReplace,
              onRemove: (item) => builder.removeItem(item.id),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
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
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: saving || builder.isEmpty ? null : onSave,
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
    );
  }
}
