import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/constants/app_durations.dart';
import 'package:all_fits/core/widgets/garment_placeholder.dart';
import 'package:all_fits/data/local/image_storage_service.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/sample/sample_data.dart';

/// Displays a clothing photo, falling back to an illustrated placeholder
/// when there is no photo or the file can't be read.
class ClothingImage extends StatelessWidget {
  const ClothingImage({
    super.key,
    required this.item,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.decodeWidth,
  });

  final ClothingItem item;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// Logical width hint used to decode a smaller bitmap for thumbnails.
  final double? decodeWidth;

  @override
  Widget build(BuildContext context) {
    final image = _buildImage(context);
    final radius = borderRadius;
    return radius == null
        ? image
        : ClipRRect(borderRadius: radius, child: image);
  }

  Widget _buildImage(BuildContext context) {
    final reference = item.imagePath;
    final path = reference == null
        ? null
        : context.read<ImageStorageService>().resolvePath(reference);
    final samplePhoto = reference == null ? SampleData.photoFor(item.id) : null;
    final ImageProvider provider;
    if (path != null) {
      provider = FileImage(File(path));
    } else if (samplePhoto != null) {
      provider = AssetImage(samplePhoto);
    } else {
      return GarmentPlaceholder(category: item.category, color: item.color);
    }

    final width = decodeWidth;
    final cacheWidth = width == null
        ? null
        : (width * MediaQuery.devicePixelRatioOf(context)).round();
    return Image(
      image: ResizeImage.resizeIfNeeded(cacheWidth, null, provider),
      fit: fit,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: AppDurations.medium,
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (context, error, stackTrace) => GarmentPlaceholder(
        category: item.category,
        color: item.color,
        showBrokenImage: true,
      ),
    );
  }
}
