import 'package:flutter/material.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/selectable_pill.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/models/outfit_board.dart';
import 'package:all_fits/data/models/outfit_placement.dart';
import 'package:all_fits/features/outfits/widgets/sticker_art.dart';
import 'package:all_fits/core/l10n/l10n.dart';

/// What a sticker shows: its drawing, emoji or hairstyle. Fills its box,
/// kept square.
class StickerView extends StatelessWidget {
  const StickerView({super.key, required this.sticker});

  final OutfitSticker sticker;

  @override
  Widget build(BuildContext context) {
    final hairstyle = sticker.hairstyle;
    final art = sticker.art;
    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: hairstyle != null
            ? HairView(style: hairstyle, color: sticker.hairColor)
            : art != null
            ? CustomPaint(
                painter: StickerArtPainter(art: art, ink: sticker.ink.color),
                size: Size.infinite,
              )
            : FittedBox(
                child: Text(
                  sticker.emoji ?? '',
                  style: const TextStyle(fontSize: 64, height: 1.1),
                ),
              ),
      ),
    );
  }
}

class HairView extends StatelessWidget {
  const HairView({super.key, required this.style, required this.color});

  final Hairstyle style;
  final HairColor color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: HairPainter(style: style, color: color.color),
    size: Size.infinite,
  );
}

/// Fits' Stickers sheet: tabs for hair and each kind of sticker, a grid,
/// and a colour row for those that can be tinted. Resolves to the picked
/// sticker (its placement is a placeholder), or null.
///
/// Without [premium], only free stickers can be picked; tapping another
/// calls [onLocked].
Future<OutfitSticker?> showStickerSheet(
  BuildContext context, {
  required bool premium,
  required VoidCallback onLocked,
}) {
  return showModalBottomSheet<OutfitSticker>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _StickerSheet(premium: premium, onLocked: onLocked),
  );
}

/// Where a picked sticker goes until the board places it.
const OutfitPlacement _unplaced = OutfitPlacement(
  itemId: '',
  x: 0.5,
  y: 0.5,
  width: 0.2,
  height: 0.2,
);

class _StickerSheet extends StatefulWidget {
  const _StickerSheet({required this.premium, required this.onLocked});

  final bool premium;
  final VoidCallback onLocked;

  @override
  State<_StickerSheet> createState() => _StickerSheetState();
}

class _StickerSheetState extends State<_StickerSheet> {
  StickerCategory _tab = StickerCategory.hair;
  HairColor _hairColor = HairColor.black;
  StickerInk _ink = StickerInk.black;

  void _pick(OutfitSticker sticker) {
    if (!widget.premium && !sticker.isFree) {
      widget.onLocked();
      return;
    }
    Navigator.of(context).pop(sticker);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          const SizedBox(height: AppSpacing.md),
          PillBar(
            pills: [
              for (final tab in StickerCategory.values)
                SelectablePill(
                  label: tab.label,
                  selected: tab == _tab,
                  onTap: () => setState(() => _tab = tab),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(child: _grid(scrollController)),
          if (_tab.tintable) ...[
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: _tab == StickerCategory.hair
                  ? ColorRow<HairColor>(
                      options: HairColor.values,
                      selected: _hairColor,
                      colorOf: (c) => c.color,
                      labelOf: (c) => c.label,
                      onSelect: (c) => setState(() => _hairColor = c),
                    )
                  : ColorRow<StickerInk>(
                      options: StickerInk.values,
                      selected: _ink,
                      colorOf: (c) => c.color,
                      labelOf: (c) => c.label,
                      onSelect: (c) => setState(() => _ink = c),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _grid(ScrollController controller) {
    final tiles = switch (_tab) {
      StickerCategory.hair => [
        for (final style in Hairstyle.values)
          _StickerTile(
            label: style.label,
            locked: !widget.premium && !style.isFree,
            onTap: () => _pick(
              OutfitSticker(
                placement: _unplaced,
                hairstyle: style,
                hairColor: _hairColor,
              ),
            ),
            child: HairView(style: style, color: _hairColor),
          ),
      ],
      StickerCategory.emoji => [
        for (final emoji in boardStickerEmoji)
          _StickerTile(
            label: emoji,
            locked: false,
            onTap: () =>
                _pick(OutfitSticker(placement: _unplaced, emoji: emoji)),
            child: FittedBox(
              child: Text(emoji, style: const TextStyle(fontSize: 48)),
            ),
          ),
      ],
      final category => [
        for (final art in StickerArt.of(category))
          _StickerTile(
            label: art.name,
            locked: !widget.premium && !art.free,
            onTap: () =>
                _pick(OutfitSticker(placement: _unplaced, art: art, ink: _ink)),
            child: CustomPaint(
              painter: StickerArtPainter(art: art, ink: _ink.color),
              size: Size.infinite,
            ),
          ),
      ],
    };
    return GridView.count(
      controller: controller,
      crossAxisCount: 3,
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.xl,
      ),
      children: tiles,
    );
  }
}

class _StickerTile extends StatelessWidget {
  const _StickerTile({
    required this.label,
    required this.locked,
    required this.onTap,
    required this.child,
  });

  final String label;
  final bool locked;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: locked ? tr('{0}, Premium', [label]) : label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Stack(
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xs),
                child: Opacity(opacity: locked ? 0.45 : 1, child: child),
              ),
            ),
            if (locked)
              Positioned(
                right: 2,
                top: 2,
                child: Icon(
                  Icons.lock_rounded,
                  size: 16,
                  color: palette.textSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A row of colour dots, as at the bottom of Fits' Stickers sheet.
class ColorRow<T> extends StatelessWidget {
  const ColorRow({
    super.key,
    required this.options,
    required this.selected,
    required this.colorOf,
    required this.labelOf,
    required this.onSelect,
  });

  final List<T> options;
  final T selected;
  final Color Function(T option) colorOf;
  final String Function(T option) labelOf;
  final ValueChanged<T> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: BoardColorDot.size + 8 + AppSpacing.md * 2,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.page,
          vertical: AppSpacing.md,
        ),
        children: [
          for (final option in options)
            BoardColorDot(
              color: colorOf(option),
              label: labelOf(option),
              selected: option == selected,
              onTap: () => onSelect(option),
            ),
        ],
      ),
    );
  }
}

/// Every hairstyle in [color], for the Dressing Room's "Change hair style".
class HairGrid extends StatelessWidget {
  const HairGrid({
    super.key,
    required this.color,
    required this.selected,
    required this.premium,
    required this.onSelect,
    required this.onLocked,
  });

  final HairColor color;
  final Hairstyle? selected;
  final bool premium;
  final ValueChanged<Hairstyle> onSelect;
  final VoidCallback onLocked;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
      children: [
        for (final style in Hairstyle.values)
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: style == selected ? palette.ink : Colors.transparent,
                width: 2,
              ),
            ),
            child: _StickerTile(
              label: style.label,
              locked: !premium && !style.isFree,
              onTap: !premium && !style.isFree
                  ? onLocked
                  : () => onSelect(style),
              child: HairView(style: style, color: color),
            ),
          ),
      ],
    );
  }
}

/// The board colours; resolves to the picked one, or null.
Future<BoardBackground?> showBackgroundSheet(
  BuildContext context,
  BoardBackground current,
) {
  return showModalBottomSheet<BoardBackground>(
    context: context,
    builder: (sheetContext) {
      final palette = sheetContext.palette;
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetHeader(title: tr('Background')),
            ColorRow<BoardBackground>(
              options: BoardBackground.values,
              selected: current,
              colorOf: (b) => b.color ?? palette.surface,
              labelOf: (b) => b.label,
              onSelect: (b) => Navigator.of(sheetContext).pop(b),
            ),
          ],
        ),
      );
    },
  );
}

/// Round colour choice with a ring when [selected].
class BoardColorDot extends StatelessWidget {
  const BoardColorDot({
    super.key,
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const double size = 36;

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: onTap,
          radius: size / 2 + 4,
          child: Container(
            width: size + 8,
            height: size + 8,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? palette.ink : Colors.transparent,
                width: 2,
              ),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: palette.border),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
