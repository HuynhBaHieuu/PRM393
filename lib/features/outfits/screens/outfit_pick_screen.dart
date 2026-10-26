import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/core/widgets/layout.dart';
import 'package:all_fits/core/widgets/option_sheets.dart';
import 'package:all_fits/data/models/outfit_create_mode.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/outfit_flows.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_query.dart';
import 'package:all_fits/features/wardrobe/widgets/clothing_grid.dart';
import 'package:all_fits/features/wardrobe/widgets/wardrobe_filter_sheet.dart';
import 'package:all_fits/features/wardrobe/widgets/wardrobe_toolbar.dart';

/// Fits' "Add outfit": tick pieces first, pick how to put them together
/// (Collage, Dressing Room or AI Try On), then "Next →".
class OutfitPickScreen extends StatefulWidget {
  const OutfitPickScreen({
    super.key,
    this.initialItemIds = const [],
    this.planDate,
  });

  final List<String> initialItemIds;

  /// The planner day the new outfit is for, if opened from the planner.
  final DateTime? planDate;

  @override
  State<OutfitPickScreen> createState() => _OutfitPickScreenState();
}

class _OutfitPickScreenState extends State<OutfitPickScreen> {
  WardrobeQuery _query = const WardrobeQuery();
  late final List<String> _selected = [...widget.initialItemIds];
  late OutfitCreateMode _mode = context.read<SettingsController>().outfitMode;
  late DateTime? _planDate = widget.planDate;

  void _toggle(String id) => setState(
    () => _selected.contains(id) ? _selected.remove(id) : _selected.add(id),
  );

  Future<void> _openFilters() async {
    final wardrobe = context.read<WardrobeController>();
    final result = await showWardrobeFilterSheet(
      context,
      query: _query,
      brands: wardrobe.brands,
      materials: wardrobe.materials,
    );
    if (result != null) setState(() => _query = result);
  }

  Future<void> _pickPlanDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: _planDate ?? today,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Plan this outfit for',
    );
    if (date != null) setState(() => _planDate = date);
  }

  Future<void> _pickMode() async {
    final mode = await OutfitFlows.chooseMode(context, current: _mode);
    if (mode != null) setState(() => _mode = mode);
  }

  Future<void> _selfie() async {
    final navigator = Navigator.of(context);
    final saved = await OutfitFlows.selfie(context, planDate: _planDate);
    if (saved) navigator.pop(true);
  }

  Future<void> _suggestions() async {
    final ids = await OutfitFlows.pickSuggestion(context);
    if (ids != null) {
      setState(
        () => _selected
          ..clear()
          ..addAll(ids),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeController>();
    final counts = context.watch<OutfitController>().itemOutfitCounts;
    final results = _query.apply(wardrobe.activeItems, outfitCounts: counts);
    _selected.removeWhere((id) => wardrobe.itemById(id) == null);
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add outfit'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: _planDate == null
                ? 'Plan for a day'
                : 'Planned for ${AppFormatters.shortDate(_planDate!)}',
            onPressed: _pickPlanDate,
            icon: Badge(
              isLabelVisible: _planDate != null,
              backgroundColor: palette.ink,
              smallSize: 8,
              child: const Icon(Icons.edit_calendar_outlined),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.xs,
                AppSpacing.page,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _BigOption(
                      icon: Icons.accessibility_new_rounded,
                      label: 'Selfie',
                      onTap: _selfie,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _BigOption(
                      icon: Icons.auto_awesome_outlined,
                      label: 'Suggestions',
                      onTap: _suggestions,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ClothesToolbar(
              category: _query.category,
              onCategory: (c) =>
                  setState(() => _query = _query.copyWith(category: c)),
              onFilter: _openFilters,
              filterCount: _query.sheetFilterCount,
            ),
          ),
          if (wardrobe.activeItems.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                icon: Icons.checkroom_outlined,
                title: 'Your wardrobe is empty',
                message: 'Add clothes to put outfits together.',
                actionLabel: 'Add clothes',
                onAction: () => AppNavigator.addClothing(context),
              ),
            )
          else if (results.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                icon: Icons.search_off_rounded,
                title: 'No clothes match your filters',
                message: 'Change your filters and try again',
                actionLabel: 'Clear filters',
                onAction: () => setState(() => _query = _query.cleared()),
              ),
            )
          else
            SliverPadding(
              padding: pageInsets(context.screenSize.width)
                  .copyWith(top: AppSpacing.sm, bottom: AppSpacing.xl),
              sliver: ClothingSliverGrid(
                items: results,
                checkable: true,
                isSelected: (item) => _selected.contains(item.id),
                onTap: (item) => _toggle(item.id),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _selected.isEmpty
          ? null
          : _PickTray(
              selected: _selected,
              mode: _mode,
              onRemove: _toggle,
              onMode: _pickMode,
              onNext: () => OutfitFlows.build(
                context,
                mode: _mode,
                itemIds: List.of(_selected),
                planDate: _planDate,
              ),
            ),
    );
  }
}

class _BigOption extends StatelessWidget {
  const _BigOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            children: [
              Icon(icon, size: AppSizes.iconLg),
              const SizedBox(height: AppSpacing.xs),
              Text(label, style: context.textTheme.titleSmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// "N selected", the chosen pieces with ×, the mode and "Next →".
class _PickTray extends StatelessWidget {
  const _PickTray({
    required this.selected,
    required this.mode,
    required this.onRemove,
    required this.onMode,
    required this.onNext,
  });

  final List<String> selected;
  final OutfitCreateMode mode;
  final ValueChanged<String> onRemove;
  final VoidCallback onMode;
  final VoidCallback onNext;

  static const double _thumb = 76;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final items = context.watch<WardrobeController>().itemsByIds(selected);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.md,
            AppSpacing.page,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${items.length} selected',
                style: context.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: _thumb,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return SizedBox.square(
                      dimension: _thumb,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: palette.surface,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.md,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.xs),
                                child: ClothingImage(
                                  item: item,
                                  cutout: true,
                                  fit: BoxFit.contain,
                                  decodeWidth: _thumb,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: -6,
                            right: -6,
                            child: Semantics(
                              button: true,
                              label: 'Remove ${item.name}',
                              child: GestureDetector(
                                onTap: () => onRemove(item.id),
                                child: CircleAvatar(
                                  radius: 13,
                                  backgroundColor: palette.textSecondary,
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: palette.onInk,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: onMode,
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.unfold_more_rounded),
                    label: Text(mode.label),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.border,
                      foregroundColor: palette.ink,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: onNext,
                    iconAlignment: IconAlignment.end,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fits' "Select how to create outfits" cards.
class OutfitModeSheet extends StatefulWidget {
  const OutfitModeSheet({super.key, required this.current});

  final OutfitCreateMode current;

  @override
  State<OutfitModeSheet> createState() => _OutfitModeSheetState();
}

class _OutfitModeSheetState extends State<OutfitModeSheet> {
  bool _editingDefault = false;

  static IconData _iconOf(OutfitCreateMode mode) => switch (mode) {
    OutfitCreateMode.collage => Icons.dashboard_outlined,
    OutfitCreateMode.dressingRoom => Icons.swipe_outlined,
    OutfitCreateMode.tryOn => Icons.auto_awesome_outlined,
  };

  Future<void> _choose(OutfitCreateMode mode) async {
    if (_editingDefault) {
      await context.read<SettingsController>().setOutfitMode(mode);
      if (mounted) setState(() => _editingDefault = false);
      return;
    }
    Navigator.of(context).pop(mode);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    final defaultMode = context.watch<SettingsController>().outfitMode;
    final checked = _editingDefault ? defaultMode : widget.current;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _editingDefault
                ? 'Select your default mode'
                : 'Select how to create outfits',
            style: text.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(height: 1, color: palette.border),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.page),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final mode in OutfitCreateMode.values) ...[
                  if (mode.index > 0) const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _choose(mode),
                      child: Column(
                        children: [
                          AspectRatio(
                            aspectRatio: 0.75,
                            child: Container(
                              decoration: BoxDecoration(
                                color: palette.surfaceMuted,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.lg,
                                ),
                                border: Border.all(
                                  color: mode == checked
                                      ? palette.ink
                                      : palette.border,
                                  width: mode == checked ? 3 : 1.5,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Icon(
                                      _iconOf(mode),
                                      size: AppSizes.iconXl + 8,
                                    ),
                                  ),
                                  if (mode == checked)
                                    const Positioned(
                                      top: AppSpacing.xs,
                                      left: AppSpacing.xs,
                                      child: RoundCheck(checked: true),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            mode.label,
                            textAlign: TextAlign.center,
                            style: text.titleSmall,
                          ),
                          if (mode == defaultMode)
                            Text('Default', style: text.bodySmall),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => setState(() => _editingDefault = !_editingDefault),
            style: OutlinedButton.styleFrom(
              shape: const StadiumBorder(),
              backgroundColor: palette.surface,
              side: BorderSide(color: palette.border, width: 1.5),
            ),
            child: Text(_editingDefault ? 'Cancel' : 'Edit default mode'),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}
