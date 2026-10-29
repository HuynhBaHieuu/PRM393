import 'dart:io';

import 'package:flutter/material.dart';

import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/constants/app_durations.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/extensions/model_presentation.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/core/widgets/option_sheets.dart';
import 'package:all_fits/core/widgets/selectable_pill.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/local/image_picker_service.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/clothing_photo.dart';
import 'package:all_fits/features/wardrobe/controllers/clothing_draft.dart';

/// What to add as an extra photo: what it shows and where it comes from.
typedef ExtraPhotoRequest = ({PhotoKind kind, ImagePickSource source});

/// Asks what the new photo shows, then whether to take or choose it.
Future<ExtraPhotoRequest?> showAddPhotoSheet(
  BuildContext context, {
  required bool supportsCamera,
  PhotoKind initialKind = PhotoKind.back,
}) => showModalBottomSheet<ExtraPhotoRequest>(
  context: context,
  isScrollControlled: true,
  builder: (_) =>
      _AddPhotoSheet(supportsCamera: supportsCamera, initialKind: initialKind),
);

/// Lets the user say what an extra photo shows.
Future<PhotoKind?> showPhotoKindSheet(
  BuildContext context,
  PhotoKind current,
) async {
  final picked = await showMultiSelectSheet<PhotoKind>(
    context,
    title: 'This photo shows',
    single: true,
    options: PhotoKind.values,
    selected: {current},
    labelOf: (k) => k.label,
    leadingOf: (k) => Icon(k.icon),
  );
  return picked?.firstOrNull;
}

/// The kind most worth adding next: the first one the piece lacks.
PhotoKind suggestedPhotoKind(Iterable<PhotoKind> taken) {
  const order = [PhotoKind.back, PhotoKind.detail, PhotoKind.tag];
  final have = taken.toSet();
  return order.firstWhere(
    (k) => !have.contains(k),
    orElse: () => PhotoKind.other,
  );
}

class _AddPhotoSheet extends StatefulWidget {
  const _AddPhotoSheet({
    required this.supportsCamera,
    required this.initialKind,
  });

  final bool supportsCamera;
  final PhotoKind initialKind;

  @override
  State<_AddPhotoSheet> createState() => _AddPhotoSheetState();
}

class _AddPhotoSheetState extends State<_AddPhotoSheet> {
  late PhotoKind _kind = widget.initialKind;

  void _pick(ImagePickSource source) =>
      Navigator.of(context).pop((kind: _kind, source: source));

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.md,
          bottom: AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHeader(title: 'Add a photo'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Show the back, the stitching or the care label so you '
                    'remember every detail of this piece.',
                    style: context.textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  LabeledSection(
                    label: 'This photo shows',
                    child: PillGroup<PhotoKind>(
                      options: PhotoKind.values,
                      selected: {_kind},
                      labelOf: (k) => k.label,
                      leadingOf: (k) => Icon(
                        k.icon,
                        size: 16,
                        color: k == _kind ? palette.onInk : palette.ink,
                      ),
                      onToggle: (k) => setState(() => _kind = k),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Expanded(
                        child: widget.supportsCamera
                            ? OutlinedButton.icon(
                                onPressed: () => _pick(ImagePickSource.gallery),
                                icon: const Icon(
                                  Icons.photo_library_outlined,
                                  size: AppSizes.iconSm,
                                ),
                                label: const Text('Gallery'),
                              )
                            : FilledButton.icon(
                                onPressed: () => _pick(ImagePickSource.gallery),
                                icon: const Icon(
                                  Icons.photo_library_outlined,
                                  size: AppSizes.iconSm,
                                ),
                                label: const Text('Choose from gallery'),
                              ),
                      ),
                      if (widget.supportsCamera) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _pick(ImagePickSource.camera),
                            icon: const Icon(
                              Icons.photo_camera_outlined,
                              size: AppSizes.iconSm,
                            ),
                            label: const Text('Camera'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small photo with what it shows written underneath.
class PhotoThumb extends StatelessWidget {
  const PhotoThumb({
    super.key,
    required this.image,
    required this.label,
    this.icon,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.onRemove,
  });

  final Widget image;
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Shows a small × in the corner.
  final VoidCallback? onRemove;

  static const double width = 64;
  static const double height = width / AppSizes.clothingImageAspect;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(AppRadius.sm);
    return Semantics(
      button: onTap != null,
      selected: selected,
      label: label,
      child: SizedBox(
        width: width,
        child: Column(
          children: [
            GestureDetector(
              onTap: onTap,
              onLongPress: onLongPress,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: AppDurations.fast,
                    width: width,
                    height: height,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.sm + 2),
                      border: Border.all(
                        color: selected ? palette.ink : palette.border,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: radius,
                      child: ColoredBox(
                        color: palette.surfaceMuted,
                        child: image,
                      ),
                    ),
                  ),
                  if (onRemove != null)
                    Positioned(
                      top: -6,
                      right: -6,
                      child: _RemoveButton(label: label, onTap: onRemove!),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 12, color: palette.textSecondary),
                  const SizedBox(width: 2),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: selected ? palette.ink : palette.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: 'Remove $label photo',
      child: Material(
        color: palette.ink,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Icon(Icons.close_rounded, size: 14, color: palette.onInk),
          ),
        ),
      ),
    );
  }
}

/// The empty tile at the end of a photo strip.
class AddPhotoThumb extends StatelessWidget {
  const AddPhotoThumb({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(AppRadius.sm + 2);
    return SizedBox(
      width: PhotoThumb.width,
      child: Column(
        children: [
          Material(
            color: palette.surfaceMuted,
            borderRadius: radius,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: Container(
                width: PhotoThumb.width,
                height: PhotoThumb.height,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: palette.border),
                ),
                child: Icon(
                  Icons.add_a_photo_outlined,
                  color: palette.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Add',
            style: context.textTheme.labelSmall?.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// A horizontally scrolling row of [PhotoThumb]s and an [AddPhotoThumb].
class PhotoStrip extends StatelessWidget {
  const PhotoStrip({
    super.key,
    required this.thumbs,
    this.onAdd,
    this.padding = EdgeInsets.zero,
  });

  final List<Widget> thumbs;

  /// Null hides the add tile, e.g. once the limit is reached.
  final VoidCallback? onAdd;
  final EdgeInsetsGeometry padding;

  // Room for the × that sticks out of the top corner.
  static const double _overhang = 6;
  static const double height = PhotoThumb.height + 24 + _overhang;

  @override
  Widget build(BuildContext context) {
    final tiles = [...thumbs, if (onAdd != null) AddPhotoThumb(onTap: onAdd!)];
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        // Lets a parent center a short strip.
        shrinkWrap: true,
        padding: padding.add(const EdgeInsets.only(top: _overhang)),
        clipBehavior: Clip.none,
        itemCount: tiles.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, index) => tiles[index],
      ),
    );
  }
}

/// "More photos" in the clothing form.
class ExtraPhotosField extends StatelessWidget {
  const ExtraPhotosField({
    super.key,
    required this.photos,
    required this.onAdd,
    required this.onRemove,
    required this.onChangeKind,
    this.existingItem,
  });

  final List<ExtraPhotoDraft> photos;

  /// Needed to show photos the piece already has.
  final ClothingItem? existingItem;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onChangeKind;

  Widget _imageOf(ExtraPhotoDraft photo) {
    final path = photo.newPath;
    if (path != null) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        cacheWidth: 200,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image_outlined),
      );
    }
    return ClothingImage(
      item: existingItem!,
      photo: photo.reference,
      decodeWidth: PhotoThumb.width,
    );
  }

  @override
  Widget build(BuildContext context) {
    final full = photos.length >= AppConfig.maxExtraPhotos;
    return LabeledSection(
      label: 'More photos',
      trailing: Text(
        '${photos.length}/${AppConfig.maxExtraPhotos}',
        style: context.textTheme.bodySmall,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (photos.isEmpty) ...[
            Text(
              'Optional: the back, stitching details, the care label…',
              style: context.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          PhotoStrip(
            onAdd: full ? null : onAdd,
            thumbs: [
              for (var i = 0; i < photos.length; i++)
                PhotoThumb(
                  image: _imageOf(photos[i]),
                  label: photos[i].kind.label,
                  icon: photos[i].kind.icon,
                  onTap: () => onChangeKind(i),
                  onRemove: () => onRemove(i),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
