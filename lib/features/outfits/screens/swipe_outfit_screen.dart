import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/constants/app_durations.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/core/widgets/selectable_pill.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/clothing_subcategory.dart';
import 'package:all_fits/data/models/outfit_slot.dart';
import 'package:all_fits/features/outfits/screens/outfit_builder_screen.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';

/// Builds a look by swiping one row of pieces per slot (tops, bottoms,
/// shoes by default) over a mannequin, then hands the picks to the outfit
/// builder to name and save.
class SwipeOutfitScreen extends StatefulWidget {
  const SwipeOutfitScreen({super.key});

  /// Rows from top to bottom, with each row's share of the height.
  static const Map<OutfitSlot, int> rows = {
    OutfitSlot.accessories: 2,
    OutfitSlot.outerwear: 4,
    OutfitSlot.top: 4,
    OutfitSlot.dress: 6,
    OutfitSlot.bottom: 5,
    OutfitSlot.shoes: 2,
  };

  /// Rows shown until the user turns others on.
  static const Set<OutfitSlot> defaultRows = {
    OutfitSlot.top,
    OutfitSlot.bottom,
    OutfitSlot.shoes,
  };

  @override
  State<SwipeOutfitScreen> createState() => _SwipeOutfitScreenState();
}

class _SwipeOutfitScreenState extends State<SwipeOutfitScreen> {
  /// Rows repeat this many times in each direction, so swiping feels endless.
  static const int _loops = 1000;

  final Map<OutfitSlot, PageController> _controllers = {};
  final Map<OutfitSlot, int> _picks = {};
  final Set<OutfitSlot> _shown = {...SwipeOutfitScreen.defaultRows};
  final Map<OutfitSlot, ClothingSubcategory> _filters = {};
  OutfitSlot? _active;

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  PageController _controllerFor(OutfitSlot slot, int count) =>
      _controllers.putIfAbsent(
        slot,
        () =>
            PageController(viewportFraction: 0.62, initialPage: _loops * count),
      );

  /// Starts [slot]'s row over at its first piece, e.g. after its pieces
  /// changed. The row's old controller is disposed once it is detached.
  void _reset(OutfitSlot slot) {
    _picks.remove(slot);
    final old = _controllers.remove(slot);
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  /// Rows the user has on, or every row when none of those has pieces.
  List<OutfitSlot> _visible(Iterable<OutfitSlot> available) {
    final shown = available.where(_shown.contains).toList();
    return shown.isEmpty ? available.toList() : shown;
  }

  void _toggleRow(Iterable<OutfitSlot> available, OutfitSlot slot, bool on) {
    setState(() {
      final visible = _visible(available);
      _shown
        ..clear()
        ..addAll(visible);
      if (on) {
        _shown.add(slot);
      } else {
        _shown.remove(slot);
      }
      _reset(slot);
    });
  }

  void _filter(OutfitSlot slot, ClothingSubcategory? subcategory) {
    setState(() {
      if (subcategory == null) {
        _filters.remove(slot);
      } else {
        _filters[slot] = subcategory;
      }
      _active = slot;
      _reset(slot);
    });
  }

  /// Scrolls [slot]'s row the short way round to the piece at [index].
  void _jumpTo(OutfitSlot slot, int index, int count) {
    setState(() => _active = slot);
    final controller = _controllers[slot]!;
    final page = controller.page!.round();
    controller.animateToPage(
      page - page % count + index,
      duration: AppDurations.slow,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _next(List<ClothingItem> picks) async {
    final navigator = Navigator.of(context);
    final saved = await navigator.pushNamed<Object?>(
      AppRoutes.outfitBuilder,
      arguments: OutfitBuilderArgs(
        initialItemIds: [for (final item in picks) item.id],
      ),
    );
    // The builder already switched to the Outfits tab; close the swiper too.
    if (saved == true) navigator.pop();
  }

  Future<void> _editRows(Map<OutfitSlot, List<ClothingItem>> available) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final visible = _visible(available.keys);
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final MapEntry(key: slot, value: pieces)
                    in available.entries)
                  SwitchListTile(
                    title: Text(slot.categories.first.label),
                    subtitle: Text(
                      '${pieces.length} ${pieces.length == 1 ? 'piece' : 'pieces'}',
                    ),
                    value: visible.contains(slot),
                    // At least one row stays on.
                    onChanged: visible.length == 1 && visible.contains(slot)
                        ? null
                        : (on) {
                            _toggleRow(available.keys, slot, on);
                            setSheetState(() {});
                          },
                  ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = context.watch<WardrobeController>().activeItems;
    final available = {
      for (final slot in SwipeOutfitScreen.rows.keys)
        slot: [
          for (final item in items)
            if (OutfitSlot.forCategory(item.category) == slot) item,
        ],
    }..removeWhere((_, pieces) => pieces.isEmpty);

    if (available.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Swipe outfit')),
        body: AppEmptyState(
          icon: Icons.swipe_outlined,
          title: 'Nothing to swipe yet',
          message: 'Add tops, bottoms or shoes to start swiping looks.',
          actionLabel: 'Add clothes',
          onAction: () => AppNavigator.addClothing(context),
        ),
      );
    }

    final bySlot = {
      for (final slot in _visible(available.keys))
        slot: _filtered(available[slot]!, _filters[slot]),
    };
    final active = bySlot.containsKey(_active) ? _active! : bySlot.keys.first;
    final picks = [
      for (final MapEntry(key: slot, value: pieces) in bySlot.entries)
        pieces[(_picks[slot] ?? 0) % pieces.length],
    ];
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Swipe outfit'),
        actions: [
          IconButton(
            tooltip: 'Rows',
            onPressed: () => _editRows(available),
            icon: const Icon(Icons.layers_outlined),
          ),
          IconButton.filled(
            tooltip: 'Next',
            onPressed: () => _next(picks),
            icon: const Icon(Icons.arrow_forward_rounded),
            // The app bar would otherwise tint the arrow black on black.
            style: IconButton.styleFrom(
              backgroundColor: palette.ink,
              foregroundColor: palette.onInk,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ExcludeSemantics(
                  child: CustomPaint(
                    painter: _MannequinPainter(
                      body: palette.border,
                      hair: Color.lerp(
                        palette.border,
                        palette.textTertiary,
                        0.5,
                      )!,
                    ),
                  ),
                ),
                Column(
                  children: [
                    for (final MapEntry(key: slot, value: pieces)
                        in bySlot.entries)
                      Expanded(
                        // Keeps each row's state with its slot as rows come
                        // and go; a new filter starts the row afresh.
                        key: ValueKey((slot, _filters[slot])),
                        flex: SwipeOutfitScreen.rows[slot]!,
                        child: _SwipeRow(
                          items: pieces,
                          controller: _controllerFor(slot, pieces.length),
                          onChanged: (index) => setState(() {
                            _picks[slot] = index;
                            _active = slot;
                          }),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          _PieceTray(
            slots: bySlot.keys.toList(),
            active: active,
            subcategories: _subcategoriesOf(available[active]!),
            filter: _filters[active],
            items: bySlot[active]!,
            picked: (_picks[active] ?? 0) % bySlot[active]!.length,
            onSlot: (slot) => setState(() => _active = slot),
            onFilter: (subcategory) => _filter(active, subcategory),
            onPick: (index) => _jumpTo(active, index, bySlot[active]!.length),
          ),
        ],
      ),
    );
  }

  /// [pieces] of [subcategory], or all of them when there are none.
  static List<ClothingItem> _filtered(
    List<ClothingItem> pieces,
    ClothingSubcategory? subcategory,
  ) {
    if (subcategory == null) return pieces;
    final matching = [
      for (final item in pieces)
        if (item.subcategory == subcategory) item,
    ];
    return matching.isEmpty ? pieces : matching;
  }

  /// The subcategories to filter [pieces] by, or none when filtering by
  /// them would not narrow the row.
  static List<ClothingSubcategory> _subcategoriesOf(List<ClothingItem> pieces) {
    final kinds = {for (final item in pieces) item.subcategory};
    if (kinds.length < 2) return const [];
    return ClothingSubcategory.values.where(kinds.contains).toList();
  }
}

/// One endlessly looping row. Neighbours shrink, fade and blur sideways.
class _SwipeRow extends StatelessWidget {
  const _SwipeRow({
    required this.items,
    required this.controller,
    required this.onChanged,
  });

  final List<ClothingItem> items;
  final PageController controller;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: controller,
      onPageChanged: (page) => onChanged(page % items.length),
      itemBuilder: (context, page) {
        final item = items[page % items.length];
        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            final position =
                controller.hasClients && controller.position.haveDimensions
                ? controller.page!
                : controller.initialPage.toDouble();
            final distance = (position - page).abs().clamp(0.0, 1.0);
            return Opacity(
              opacity: 1 - distance * 0.55,
              child: Transform.scale(
                scale: 1 - distance * 0.2,
                child: ImageFiltered(
                  enabled: distance > 0.02,
                  imageFilter: ImageFilter.blur(
                    sigmaX: distance * 8,
                    sigmaY: distance * 1.5,
                  ),
                  child: child,
                ),
              ),
            );
          },
          child: Semantics(
            label: item.name,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: ClothingImage.hasCutout(item)
                  ? ClothingImage(
                      item: item,
                      cutout: true,
                      fit: BoxFit.contain,
                      decodeWidth: 320,
                    )
                  // A photo with its background reads as a card, not as a
                  // piece on the mannequin.
                  : Center(
                      child: AspectRatio(
                        aspectRatio: AppSizes.clothingImageAspect,
                        child: ClothingImage(
                          item: item,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          decodeWidth: 320,
                        ),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// A plain figure behind the rows, so the pieces read as one look.
class _MannequinPainter extends CustomPainter {
  const _MannequinPainter({required this.body, required this.hair});

  final Color body;
  final Color hair;

  @override
  void paint(Canvas canvas, Size size) {
    // Every measure is a fraction of the height, centred horizontally.
    final h = size.height;
    final cx = size.width / 2;
    Offset at(double x, double y) => Offset(cx + x * h, y * h);
    final fill = Paint()..color = body;
    Paint limb(double width) => Paint()
      ..color = body
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width * h;

    // Hair, with the face drawn over its lower part.
    canvas.drawOval(
      Rect.fromCenter(center: at(0, 0.058), width: 0.085 * h, height: 0.1 * h),
      Paint()..color = hair,
    );
    canvas.drawOval(
      Rect.fromCenter(center: at(0, 0.072), width: 0.068 * h, height: 0.08 * h),
      fill,
    );
    canvas.drawRect(Rect.fromPoints(at(-0.017, 0.1), at(0.017, 0.145)), fill);

    final torso = Path()
      ..moveTo(cx - 0.03 * h, 0.135 * h)
      ..quadraticBezierTo(cx - 0.1 * h, 0.14 * h, cx - 0.105 * h, 0.175 * h)
      ..lineTo(cx - 0.085 * h, 0.3 * h)
      ..quadraticBezierTo(cx - 0.07 * h, 0.38 * h, cx - 0.075 * h, 0.42 * h)
      ..lineTo(cx - 0.09 * h, 0.5 * h)
      ..lineTo(cx + 0.09 * h, 0.5 * h)
      ..lineTo(cx + 0.075 * h, 0.42 * h)
      ..quadraticBezierTo(cx + 0.07 * h, 0.38 * h, cx + 0.085 * h, 0.3 * h)
      ..lineTo(cx + 0.105 * h, 0.175 * h)
      ..quadraticBezierTo(cx + 0.1 * h, 0.14 * h, cx + 0.03 * h, 0.135 * h)
      ..close();
    canvas.drawPath(torso, fill);

    for (final side in const [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(cx + side * 0.098 * h, 0.18 * h)
          ..lineTo(cx + side * 0.122 * h, 0.33 * h)
          ..lineTo(cx + side * 0.128 * h, 0.47 * h),
        limb(0.032),
      );
      canvas.drawLine(at(side * 0.047, 0.5), at(side * 0.05, 0.71), limb(0.08));
      canvas.drawLine(
        at(side * 0.05, 0.71),
        at(side * 0.047, 0.92),
        limb(0.05),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: at(side * 0.058, 0.945),
          width: 0.065 * h,
          height: 0.035 * h,
        ),
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(_MannequinPainter old) =>
      old.body != body || old.hair != hair;
}

/// Bottom sheet-style tray: a pill per row, the active row's subcategories
/// and its pieces.
class _PieceTray extends StatelessWidget {
  const _PieceTray({
    required this.slots,
    required this.active,
    required this.subcategories,
    required this.filter,
    required this.items,
    required this.picked,
    required this.onSlot,
    required this.onFilter,
    required this.onPick,
  });

  final List<OutfitSlot> slots;
  final OutfitSlot active;
  final List<ClothingSubcategory> subcategories;
  final ClothingSubcategory? filter;
  final List<ClothingItem> items;
  final int picked;
  final ValueChanged<OutfitSlot> onSlot;
  final ValueChanged<ClothingSubcategory?> onFilter;
  final ValueChanged<int> onPick;

  static const double _thumbWidth = 64;
  static const double _thumbHeight = 76;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 20)],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: palette.border,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            PillBar(
              pills: [
                for (final slot in slots)
                  SelectablePill(
                    label: slot.categories.first.label,
                    selected: slot == active,
                    onTap: () => onSlot(slot),
                  ),
              ],
            ),
            if (subcategories.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              PillBar(
                pills: [
                  _SubcategoryChip(
                    label: 'All',
                    selected: filter == null,
                    onTap: () => onFilter(null),
                  ),
                  for (final subcategory in subcategories)
                    _SubcategoryChip(
                      label: subcategory.label,
                      selected: subcategory == filter,
                      onTap: () => onFilter(subcategory),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: _thumbHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                itemCount: items.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.xs),
                itemBuilder: (context, index) => Semantics(
                  button: true,
                  selected: index == picked,
                  label: items[index].name,
                  child: GestureDetector(
                    onTap: () => onPick(index),
                    child: AnimatedContainer(
                      duration: AppDurations.fast,
                      width: _thumbWidth,
                      padding: const EdgeInsets.all(AppSpacing.xxs),
                      decoration: BoxDecoration(
                        color: palette.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: index == picked
                              ? palette.ink
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: ClothingImage(
                        item: items[index],
                        cutout: true,
                        fit: BoxFit.contain,
                        decodeWidth: _thumbWidth,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

/// A subcategory filter: outlined, so it reads as a level below the row
/// pills above it.
class _SubcategoryChip extends StatelessWidget {
  const _SubcategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: AnimatedContainer(
            duration: AppDurations.fast,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: selected ? palette.ink : palette.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Text(
              label,
              style: context.textTheme.labelMedium?.copyWith(
                color: selected ? palette.ink : palette.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
