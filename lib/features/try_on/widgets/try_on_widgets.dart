import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/local/image_storage_service.dart';
import 'package:all_fits/data/models/try_on.dart';

/// A photo kept in image storage, or [placeholder] when there is none or it
/// can't be loaded.
class StoredPhoto extends StatelessWidget {
  const StoredPhoto({
    super.key,
    required this.reference,
    this.fit = BoxFit.cover,
    this.decodeWidth,
    this.placeholder,
  });

  final String? reference;
  final BoxFit fit;

  /// Logical width hint used to decode a smaller bitmap for thumbnails.
  final double? decodeWidth;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final fallback =
        placeholder ??
        ColoredBox(
          color: context.palette.surfaceMuted,
          child: Icon(
            Icons.image_outlined,
            color: context.palette.textTertiary,
          ),
        );
    final reference = this.reference;
    final path = reference == null
        ? null
        : context.read<ImageStorageService>().resolvePath(reference);
    if (path == null) return fallback;
    final width = decodeWidth;
    return Image(
      image: ResizeImage.resizeIfNeeded(
        width == null
            ? null
            : (width * MediaQuery.devicePixelRatioOf(context)).round(),
        null,
        path.startsWith('https://')
            ? NetworkImage(path)
            : FileImage(File(path)),
      ),
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

/// A grey figure drawn wider for bigger sizes and taller for longer legs.
class BodySilhouette extends StatelessWidget {
  const BodySilhouette({super.key, required this.type, required this.size});

  final BodyType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final width = switch (type.size) {
      BodySize.s => 0.82,
      BodySize.m => 1.0,
      BodySize.l => 1.22,
    };
    final height = switch (type.legs) {
      LegLength.regular => 1.0,
      LegLength.short => 0.92,
      LegLength.long => 1.08,
    };
    return Transform(
      alignment: Alignment.bottomCenter,
      transform: Matrix4.diagonal3Values(width, height, 1),
      child: Icon(
        type.gender == BodyGender.female
            ? Icons.woman_rounded
            : Icons.man_rounded,
        size: size,
        color: context.palette.textTertiary,
      ),
    );
  }
}

/// Picks one of the 18 body types; resolves to the choice.
Future<BodyType?> showBodyTypeSheet(BuildContext context, BodyType? current) {
  return showModalBottomSheet<BodyType>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, scrollController) => ListView(
        controller: scrollController,
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: [
          const SheetHeader(title: 'Body type'),
          for (final gender in BodyGender.values) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.sm,
                AppSpacing.page,
                AppSpacing.xs,
              ),
              child: Text(
                gender.label,
                style: sheetContext.textTheme.titleMedium,
              ),
            ),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              mainAxisSpacing: AppSpacing.xs,
              crossAxisSpacing: AppSpacing.xs,
              childAspectRatio: 0.62,
              children: [
                for (final size in BodySize.values)
                  for (final legs in LegLength.values)
                    _BodyTypeTile(
                      type: BodyType(gender, size, legs),
                      selected: current == BodyType(gender, size, legs),
                      onTap: () =>
                          Navigator.of(sheetContext)
                              .pop(BodyType(gender, size, legs)),
                    ),
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

class _BodyTypeTile extends StatelessWidget {
  const _BodyTypeTile({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final BodyType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    final legs = type.legs.label;
    return Semantics(
      button: true,
      selected: selected,
      label: [type.size.label, ?legs].join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? palette.ink : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: Center(child: BodySilhouette(type: type, size: 120)),
              ),
              Text(type.size.label, style: text.titleMedium),
              SizedBox(
                height: 22,
                child: legs == null
                    ? null
                    : Text(
                        legs,
                        style: text.bodySmall?.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small dark pill over a picture, e.g. "Costs 1 AI credit".
class OverlayPill extends StatelessWidget {
  const OverlayPill({super.key, required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = context.textTheme.labelMedium?.copyWith(color: Colors.white);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs + 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: Colors.white),
              const SizedBox(width: AppSpacing.xxs),
            ],
            Text(text, style: style),
          ],
        ),
      ),
    );
  }
}
