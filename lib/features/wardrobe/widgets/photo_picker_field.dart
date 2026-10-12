import 'dart:io';

import 'package:flutter/material.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/constants/app_durations.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/local/image_picker_service.dart';
import 'package:all_fits/data/models/clothing_item.dart';

/// Photo area of the clothing form. Shows the newly picked photo, else the
/// item's current photo, else a prompt to add one.
class PhotoPickerField extends StatelessWidget {
  const PhotoPickerField({
    super.key,
    required this.onPick,
    required this.supportsCamera,
    this.newImagePath,
    this.existingItem,
    this.errorText,
  });

  final String? newImagePath;
  final ClothingItem? existingItem;
  final ValueChanged<ImagePickSource> onPick;
  final bool supportsCamera;
  final String? errorText;

  static const double _maxWidth = 320;

  bool get _hasImage => newImagePath != null || existingItem?.imagePath != null;

  Future<void> _chooseSource(BuildContext context) async {
    if (!supportsCamera) {
      onPick(ImagePickSource.gallery);
      return;
    }
    final source = await showModalBottomSheet<ImagePickSource>(
      context: context,
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetHeader(title: 'Add a photo'),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImagePickSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(ImagePickSource.camera),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (source != null) onPick(source);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = BorderRadius.circular(AppRadius.xl);
    final hasError = errorText != null;

    return Column(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: AspectRatio(
              aspectRatio: AppSizes.clothingImageAspect,
              child: AnimatedContainer(
                duration: AppDurations.fast,
                decoration: BoxDecoration(
                  color: palette.surfaceMuted,
                  borderRadius: radius,
                  border: Border.all(
                    color: hasError ? palette.danger : palette.border,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: _hasImage
                      ? _ImagePreview(
                          newImagePath: newImagePath,
                          existingItem: existingItem,
                          onChange: () => _chooseSource(context),
                        )
                      : _EmptyPrompt(
                          supportsCamera: supportsCamera,
                          onPick: onPick,
                        ),
                ),
              ),
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            errorText!,
            style: context.textTheme.bodySmall?.copyWith(color: palette.danger),
          ),
        ],
      ],
    );
  }
}

class _ImagePreview extends StatelessWidget {
  const _ImagePreview({
    required this.newImagePath,
    required this.existingItem,
    required this.onChange,
  });

  final String? newImagePath;
  final ClothingItem? existingItem;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final path = newImagePath;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (path != null)
          Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: palette.textTertiary,
              ),
            ),
          )
        else
          ClothingImage(item: existingItem!),
        Positioned(
          right: AppSpacing.sm,
          bottom: AppSpacing.sm,
          child: FilledButton.icon(
            onPressed: onChange,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, AppSizes.compactButtonHeight),
              backgroundColor: palette.surface,
              foregroundColor: palette.ink,
            ),
            icon: const Icon(
              Icons.photo_camera_outlined,
              size: AppSizes.iconSm,
            ),
            label: const Text('Change'),
          ),
        ),
      ],
    );
  }
}

class _EmptyPrompt extends StatelessWidget {
  const _EmptyPrompt({required this.supportsCamera, required this.onPick});

  final bool supportsCamera;
  final ValueChanged<ImagePickSource> onPick;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    return InkWell(
      onTap: () => onPick(ImagePickSource.gallery),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_a_photo_outlined,
              size: AppSizes.iconXl,
              color: palette.textSecondary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Add a photo', style: text.titleLarge),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'A clear photo on a plain background works best.',
              textAlign: TextAlign.center,
              style: text.bodySmall,
            ),
            const SizedBox(height: AppSpacing.lg),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                OutlinedButton.icon(
                  onPressed: () => onPick(ImagePickSource.gallery),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, AppSizes.compactButtonHeight),
                    backgroundColor: palette.surface,
                  ),
                  icon: const Icon(
                    Icons.photo_library_outlined,
                    size: AppSizes.iconSm,
                  ),
                  label: const Text('Gallery'),
                ),
                if (supportsCamera)
                  OutlinedButton.icon(
                    onPressed: () => onPick(ImagePickSource.camera),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, AppSizes.compactButtonHeight),
                      backgroundColor: palette.surface,
                    ),
                    icon: const Icon(
                      Icons.photo_camera_outlined,
                      size: AppSizes.iconSm,
                    ),
                    label: const Text('Camera'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
