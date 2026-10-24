import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/core/widgets/selectable_pill.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/remote/ai_stylist_service.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';

/// The category chips above the clothes, as in Fits.
enum _Filter {
  all('All', {}),
  tops('Tops', {ClothingCategory.tops}),
  bottoms('Bottoms', {ClothingCategory.bottoms}),
  shoes('Shoes', {ClothingCategory.shoes}),
  outerwear('Outerwear', {ClothingCategory.outerwear}),
  fullBody('Full Body', {ClothingCategory.dresses}),
  accessories('Accessories', {
    ClothingCategory.accessories,
    ClothingCategory.bags,
  });

  const _Filter(this.label, this.categories);

  final String label;
  final Set<ClothingCategory> categories;

  bool matches(ClothingItem item) =>
      categories.isEmpty || categories.contains(item.category);
}

/// Picks up to [AiStylistService.maxTryOnPieces] pieces: category chips, a
/// grid with a ring on every piece, and a tray of the chosen ones with
/// "Next". Shared by the full-screen first step and the "Clothes" sheet.
class TryOnClothesPicker extends StatefulWidget {
  const TryOnClothesPicker({
    super.key,
    required this.initial,
    required this.onNext,
    this.scrollController,
  });

  final List<String> initial;
  final ValueChanged<List<String>> onNext;
  final ScrollController? scrollController;

  @override
  State<TryOnClothesPicker> createState() => _TryOnClothesPickerState();
}

class _TryOnClothesPickerState extends State<TryOnClothesPicker> {
  static const int _max = AiStylistService.maxTryOnPieces;
  static const double _trayThumb = 64;

  late final List<String> _selected = [...widget.initial];
  _Filter _filter = _Filter.all;

  void _toggle(ClothingItem item) {
    if (_selected.contains(item.id)) {
      setState(() => _selected.remove(item.id));
    } else if (_selected.length >= _max) {
      context.showSnack('Try on up to $_max pieces at a time.');
    } else {
      setState(() => _selected.add(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeController>();
    final items = wardrobe.activeItems.where(_filter.matches).toList();
    final chosen = wardrobe.itemsByIds(_selected);
    final palette = context.palette;
    final text = context.textTheme;

    return Column(
      children: [
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.page,
              vertical: AppSpacing.xs,
            ),
            itemCount: _Filter.values.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
            itemBuilder: (context, index) {
              final filter = _Filter.values[index];
              return SelectablePill(
                label: filter.label,
                selected: filter == _filter,
                onTap: () => setState(() => _filter = filter),
              );
            },
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? SingleChildScrollView(
                  controller: widget.scrollController,
                  child: const AppEmptyState(
                    compact: true,
                    icon: Icons.checkroom_outlined,
                    title: 'Nothing here yet',
                    message: 'Add clothes to your wardrobe to try them on.',
                  ),
                )
              : GridView.builder(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.md,
                    AppSpacing.xl,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 3 / 4,
                    crossAxisSpacing: AppSpacing.xs,
                    mainAxisSpacing: AppSpacing.xs,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _PieceTile(
                      item: item,
                      selected: _selected.contains(item.id),
                      onTap: () => _toggle(item),
                    );
                  },
                ),
        ),
        if (chosen.isNotEmpty)
          ColoredBox(
            color: palette.surfaceMuted,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.md,
                  AppSpacing.page,
                  AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: _trayThumb + AppSpacing.xs,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: chosen.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(width: AppSpacing.sm),
                        itemBuilder: (context, index) => _TrayThumb(
                          item: chosen[index],
                          size: _trayThumb,
                          onRemove: () => setState(
                            () => _selected.remove(chosen[index].id),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${chosen.length} selected',
                            style: text.titleMedium,
                          ),
                        ),
                        FilledButton(
                          onPressed: () => widget.onNext([
                            for (final item in chosen) item.id,
                          ]),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Next'),
                              SizedBox(width: AppSpacing.xs),
                              Icon(Icons.arrow_forward_rounded),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PieceTile extends StatelessWidget {
  const _PieceTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ClothingItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: item.name,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(
              opacity: selected ? 0.45 : 1,
              child: ClothingImage(
                item: item,
                cutout: true,
                fit: BoxFit.contain,
                decodeWidth: 120,
              ),
            ),
            Positioned(
              top: AppSpacing.xxs,
              right: AppSpacing.xxs,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? palette.ink : Colors.transparent,
                  border: Border.all(
                    color: selected ? palette.ink : palette.textTertiary,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? Icon(Icons.check_rounded, size: 18, color: palette.onInk)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A chosen piece; tapping it, or its ×, puts it back.
class _TrayThumb extends StatelessWidget {
  const _TrayThumb({
    required this.item,
    required this.size,
    required this.onRemove,
  });

  final ClothingItem item;
  final double size;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: 'Remove ${item.name}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onRemove,
        child: SizedBox(
          width: size + AppSpacing.xs,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                bottom: 0,
                child: Container(
                  width: size,
                  height: size,
                  padding: const EdgeInsets.all(AppSpacing.xxs),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: ClothingImage(
                    item: item,
                    cutout: true,
                    fit: BoxFit.contain,
                    decodeWidth: size,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.ink.withValues(alpha: 0.75),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: palette.onInk,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
