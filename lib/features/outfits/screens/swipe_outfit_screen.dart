import 'dart:math' as math;
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
import 'package:all_fits/data/models/outfit_board.dart';
import 'package:all_fits/data/models/outfit_create_mode.dart';
import 'package:all_fits/data/models/outfit_slot.dart';
import 'package:all_fits/features/outfits/outfit_flows.dart';
import 'package:all_fits/features/outfits/screens/outfit_builder_screen.dart';
import 'package:all_fits/features/outfits/widgets/board_decorations.dart';
import 'package:all_fits/features/outfits/widgets/sticker_art.dart';
import 'package:all_fits/features/premium/premium_flows.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';

class SwipeOutfitArgs {
  const SwipeOutfitArgs({
    this.initialItemIds = const [],
    this.planDate,
    this.hair,
  });

  /// Pieces each row starts on, e.g. those picked in "Add outfit".
  final List<String> initialItemIds;

  /// The day the new outfit is planned on, if any.
  final DateTime? planDate;

  /// Hair worn on the collage, put on the mannequin.
  final (Hairstyle, HairColor)? hair;
}

/// Fits' Dressing Room: one row of pieces per slot (tops, bottoms, shoes
/// by default) swiped over a mannequin. Tapping or swiping a row opens its
/// tray; "Next" goes to the outfit's details to name and save it.
class SwipeOutfitScreen extends StatefulWidget {
  const SwipeOutfitScreen({super.key, this.args = const SwipeOutfitArgs()});

  final SwipeOutfitArgs args;

  /// Rows from head to toe, each placed over its part of the mannequin:
  /// top and bottom edge, and the widest a piece may be, all as fractions
  /// of the mannequin's height (see [_MannequinPainter]).
  static const Map<OutfitSlot, ({double top, double bottom, double width})>
  rows = {
    OutfitSlot.accessories: (top: 0, bottom: 0.075, width: 0.12),
    OutfitSlot.outerwear: (top: 0.12, bottom: 0.56, width: 0.38),
    OutfitSlot.top: (top: 0.12, bottom: 0.52, width: 0.32),
    OutfitSlot.dress: (top: 0.12, bottom: 0.82, width: 0.34),
    OutfitSlot.bottom: (top: 0.48, bottom: 0.93, width: 0.22),
    OutfitSlot.shoes: (top: 0.875, bottom: 1, width: 0.24),
  };

  /// Rows that overlap are stacked like clothes are worn: later ones on top,
  /// and the top one takes the swipe where they overlap.
  static const List<OutfitSlot> _layers = [
    OutfitSlot.shoes,
    OutfitSlot.bottom,
    OutfitSlot.dress,
    OutfitSlot.top,
    OutfitSlot.outerwear,
    OutfitSlot.accessories,
  ];

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
  final Set<OutfitSlot> _seeded = {};
  final math.Random _random = math.Random();
  OutfitSlot? _active;

  /// The row being edited, with its tray open; null shows the tools.
  bool _trayOpen = false;

  /// Rows the app is scrolling itself, which don't open the tray.
  final Set<OutfitSlot> _scrolling = {};

  // Fits' "Hair & Body", kept for the rest of the session.
  static bool _showHair = true;
  static bool _showBody = true;
  static Hairstyle _hairstyle = Hairstyle.short;
  static HairColor _hairColor = HairColor.black;

  @override
  void initState() {
    super.initState();
    // Show the rows of the pieces the user started with.
    final wardrobe = context.read<WardrobeController>();
    for (final item in wardrobe.itemsByIds(widget.args.initialItemIds)) {
      _shown.add(OutfitSlot.forCategory(item.category));
    }
    // Hair from the collage comes along.
    if (widget.args.hair case (final style, final color)?) {
      _showHair = true;
      _hairstyle = style;
      _hairColor = color;
    }
  }

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
        () => PageController(
          viewportFraction: 0.62,
          initialPage: _loops * count + (_picks[slot] ?? 0) % count,
        ),
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
        if (_active == slot) _trayOpen = false;
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

  /// Opens [slot]'s tray, as tapping or swiping its row does.
  void _edit(OutfitSlot slot) => setState(() {
    _active = slot;
    _trayOpen = true;
  });

  /// Scrolls [slot]'s row the short way round to the piece at [index].
  Future<void> _scrollTo(OutfitSlot slot, int index, int count) async {
    final controller = _controllers[slot];
    if (controller == null || !controller.hasClients) return;
    final page = controller.page!.round();
    _scrolling.add(slot);
    await controller.animateToPage(
      page - page % count + index,
      duration: AppDurations.slow,
      curve: Curves.easeOutCubic,
    );
    _scrolling.remove(slot);
  }

  /// Fits' "Shuffle": another piece in every row, or just in [only].
  void _shuffle(
    Map<OutfitSlot, List<ClothingItem>> bySlot, {
    OutfitSlot? only,
  }) {
    for (final MapEntry(key: slot, value: pieces) in bySlot.entries) {
      if (only != null && slot != only) continue;
      if (pieces.length < 2) continue;
      final current = (_picks[slot] ?? 0) % pieces.length;
      var next = _random.nextInt(pieces.length - 1);
      if (next >= current) next++;
      _scrollTo(slot, next, pieces.length);
    }
  }

  Future<void> _next(List<ClothingItem> picks) async {
    final navigator = Navigator.of(context);
    // Fits goes from the Dressing Room straight to the outfit's details.
    final saved = await navigator.pushNamed<Object?>(
      AppRoutes.outfitBuilder,
      arguments: OutfitBuilderArgs(
        initialItemIds: [for (final item in picks) item.id],
        planDate: widget.args.planDate,
        hair: _showHair ? (_hairstyle, _hairColor) : null,
        detailsOnly: true,
      ),
    );
    // The builder already switched to the Outfits tab; close the room too.
    if (saved == true) navigator.pop(true);
  }

  Future<void> _switchMode(List<ClothingItem> picks) async {
    final mode = await OutfitFlows.chooseMode(
      context,
      current: OutfitCreateMode.dressingRoom,
    );
    if (mode == null || mode == OutfitCreateMode.dressingRoom || !mounted) {
      return;
    }
    Navigator.of(context).pop(
      OutfitModeSwitch(
        mode,
        itemIds: [for (final item in picks) item.id],
        hair: _showHair ? (_hairstyle, _hairColor) : null,
      ),
    );
  }

  /// Fits' "Hair & Body": show or hide the hair and the body, and change
  /// the hairstyle.
  Future<void> _editHairAndBody() {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          void change(VoidCallback update) {
            setState(update);
            setSheetState(() {});
          }

          final palette = sheetContext.palette;
          return SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  title: const Text('Show hair'),
                  value: _showHair,
                  onChanged: (on) => change(() => _showHair = on),
                ),
                ListTile(
                  enabled: _showHair,
                  leading: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: palette.border),
                    ),
                    child: HairView(style: _hairstyle, color: _hairColor),
                  ),
                  title: const Text('Change hair style'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    await _pickHair();
                    setSheetState(() {});
                  },
                ),
                const Divider(height: AppSpacing.lg),
                SwitchListTile(
                  title: const Text('Show body'),
                  value: _showBody,
                  onChanged: (on) => change(() => _showBody = on),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Every hairstyle in the colour picked below it, as in Fits.
  Future<void> _pickHair() {
    final premium = context.read<SettingsController>().plan.isPremium;
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          void change(VoidCallback update) {
            setState(update);
            setSheetState(() {});
          }

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.8,
            maxChildSize: 0.95,
            builder: (context, scrollController) => Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: HairGrid(
                      color: _hairColor,
                      selected: _hairstyle,
                      premium: premium,
                      onSelect: (style) => change(() {
                        _hairstyle = style;
                        _showHair = true;
                      }),
                      onLocked: () => PremiumFlows.showStickerLimit(context),
                    ),
                  ),
                ),
                const Divider(height: 1),
                SafeArea(
                  top: false,
                  child: ColorRow<HairColor>(
                    options: HairColor.values,
                    selected: _hairColor,
                    colorOf: (c) => c.color,
                    labelOf: (c) => c.label,
                    onSelect: (c) => change(() => _hairColor = c),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Fits' "Clothes": which layers are worn.
  Future<void> _editRows(Map<OutfitSlot, List<ClothingItem>> available) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final visible = _visible(available.keys);
          return SafeArea(
            top: false,
            // Scrolls when a big closet has more rows than fit on screen.
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.page,
                    ),
                    child: Text('Clothes', style: context.textTheme.titleLarge),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      AppSpacing.xxs,
                      AppSpacing.page,
                      AppSpacing.sm,
                    ),
                    child: Text(
                      'Choose the layers you wear',
                      style: context.textTheme.bodySmall,
                    ),
                  ),
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
        appBar: AppBar(title: const Text('Dressing Room')),
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
    for (final MapEntry(key: slot, value: pieces) in bySlot.entries) {
      if (!_seeded.add(slot)) continue;
      final start = pieces.indexWhere(
        (p) => widget.args.initialItemIds.contains(p.id),
      );
      if (start > 0) _picks[slot] = start;
    }
    final active = bySlot.containsKey(_active) ? _active! : bySlot.keys.first;
    final trayOpen = _trayOpen && bySlot.containsKey(_active);
    final picks = [
      for (final MapEntry(key: slot, value: pieces) in bySlot.entries)
        pieces[(_picks[slot] ?? 0) % pieces.length],
    ];
    final palette = context.palette;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Padding(
                    // Clear of the back button and Next.
                    padding: const EdgeInsets.only(top: 56),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ExcludeSemantics(
                          child: CustomPaint(
                            painter: _MannequinPainter(
                              body: palette.border,
                              showBody: _showBody,
                              hair: _showHair
                                  ? HairPainter(
                                      style: _hairstyle,
                                      color: _hairColor.color,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final height = constraints.maxHeight;
                            return Stack(
                              children: [
                                for (final slot in SwipeOutfitScreen._layers)
                                  if (bySlot[slot] case final pieces?)
                                    Positioned(
                                      // Keeps each row's state with its slot
                                      // as rows come and go.
                                      key: ValueKey(slot),
                                      left: 0,
                                      right: 0,
                                      top:
                                          SwipeOutfitScreen.rows[slot]!.top *
                                          height,
                                      height:
                                          (SwipeOutfitScreen
                                                  .rows[slot]!
                                                  .bottom -
                                              SwipeOutfitScreen
                                                  .rows[slot]!
                                                  .top) *
                                          height,
                                      child: _SwipeRow(
                                        // A new filter starts the row afresh.
                                        key: ValueKey(_filters[slot]),
                                        items: pieces,
                                        pieceWidth:
                                            SwipeOutfitScreen
                                                .rows[slot]!
                                                .width *
                                            height,
                                        controller: _controllerFor(
                                          slot,
                                          pieces.length,
                                        ),
                                        onTap: () => _edit(slot),
                                        onChanged: (index) {
                                          _picks[slot] = index;
                                          if (_scrolling.contains(slot)) {
                                            setState(() {});
                                          } else {
                                            _edit(slot);
                                          }
                                        },
                                      ),
                                    ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: AppSpacing.xs,
                    left: AppSpacing.xs,
                    child: IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  ),
                  Positioned(
                    top: AppSpacing.xs,
                    right: AppSpacing.page,
                    child: NextPill(onTap: () => _next(picks)),
                  ),
                  if (trayOpen)
                    Positioned(
                      right: AppSpacing.page,
                      top: 80,
                      child: _RowActions(
                        onDone: () => setState(() => _trayOpen = false),
                        onShuffle: () => _shuffle(bySlot, only: active),
                        onHide: bySlot.length < 2
                            ? null
                            : () => _toggleRow(available.keys, active, false),
                      ),
                    ),
                ],
              ),
            ),
            if (trayOpen)
              _PieceTray(
                slots: bySlot.keys.toList(),
                active: active,
                subcategories: _subcategoriesOf(available[active]!),
                filter: _filters[active],
                items: bySlot[active]!,
                picked: (_picks[active] ?? 0) % bySlot[active]!.length,
                onSlot: (slot) => setState(() => _active = slot),
                onFilter: (subcategory) => _filter(active, subcategory),
                onPick: (index) =>
                    _scrollTo(active, index, bySlot[active]!.length),
              )
            else
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.sm,
                    AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      for (final (icon, label, onTap) in [
                        (
                          Icons.checkroom_outlined,
                          'Clothes',
                          () => _editRows(available),
                        ),
                        (
                          Icons.person_outline_rounded,
                          'Hair & Body',
                          _editHairAndBody,
                        ),
                        (
                          Icons.shuffle_rounded,
                          'Shuffle',
                          () => _shuffle(bySlot),
                        ),
                        (
                          Icons.swap_horiz_rounded,
                          'Switch mode',
                          () => _switchMode(picks),
                        ),
                      ])
                        Expanded(
                          child: BoardToolTile(
                            icon: icon,
                            label: label,
                            onTap: onTap,
                            light: true,
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

/// Fits' round buttons beside the row being edited: done, another piece,
/// and take the row off.
class _RowActions extends StatelessWidget {
  const _RowActions({
    required this.onDone,
    required this.onShuffle,
    required this.onHide,
  });

  final VoidCallback onDone;
  final VoidCallback onShuffle;
  final VoidCallback? onHide;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        IconButton.filled(
          tooltip: 'Done',
          onPressed: onDone,
          style: IconButton.styleFrom(
            backgroundColor: palette.ink,
            foregroundColor: palette.onInk,
            minimumSize: const Size.square(52),
          ),
          icon: const Icon(Icons.check_rounded),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final (icon, tooltip, onTap) in [
          (Icons.shuffle_rounded, 'Shuffle row', onShuffle),
          (Icons.delete_outline_rounded, 'Take off', onHide),
        ]) ...[
          IconButton.filledTonal(
            tooltip: tooltip,
            onPressed: onTap,
            style: IconButton.styleFrom(
              backgroundColor: palette.surfaceMuted,
              foregroundColor: palette.ink,
              minimumSize: const Size.square(52),
            ),
            icon: Icon(icon),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

/// One endlessly looping row. Neighbours shrink, fade and blur sideways.
class _SwipeRow extends StatelessWidget {
  const _SwipeRow({
    super.key,
    required this.items,
    required this.pieceWidth,
    required this.controller,
    required this.onTap,
    required this.onChanged,
  });

  final List<ClothingItem> items;

  /// The widest a piece is drawn, so it fits the mannequin.
  final double pieceWidth;
  final PageController controller;
  final VoidCallback onTap;
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
          // The whole page takes the tap, so it works before the photo
          // has loaded too.
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Semantics(
              label: item.name,
              child: Center(
                child: SizedBox(
                  width: pieceWidth,
                  child: ClothingImage.hasCutout(item)
                      ? ClothingImage(
                          item: item,
                          cutout: true,
                          fit: BoxFit.contain,
                          decodeWidth: 320,
                        )
                      // A photo with its background reads as a card, not as
                      // a piece on the mannequin.
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
            ),
          ),
        );
      },
    );
  }
}

/// A plain figure behind the rows, so the pieces read as one look.
class _MannequinPainter extends CustomPainter {
  const _MannequinPainter({
    required this.body,
    required this.showBody,
    this.hair,
  });

  final Color body;
  final bool showBody;

  /// Drawn on the head, sized to its face; null hides the hair.
  final HairPainter? hair;

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

    final hair = this.hair;
    if (hair != null) {
      // Sized so the hair's open face matches the head's.
      final side = 0.068 * h / HairPainter.face.width;
      final face = at(0, 0.072);
      canvas.save();
      canvas.translate(
        face.dx - HairPainter.face.center.dx * side,
        face.dy - HairPainter.face.center.dy * side,
      );
      hair.paint(canvas, Size.square(side));
      canvas.restore();
    }
    if (!showBody) return;

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
      old.body != body ||
      old.showBody != showBody ||
      old.hair?.style != hair?.style ||
      old.hair?.color != hair?.color;
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
