import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/data/local/image_storage_service.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/outfit.dart';
import 'package:all_fits/features/outfits/widgets/outfit_canvas.dart';

/// An outfit's picture: its selfie when it has one, otherwise the collage.
class OutfitCover extends StatelessWidget {
  const OutfitCover({super.key, required this.outfit, required this.items});

  final Outfit outfit;
  final List<ClothingItem> items;

  @override
  Widget build(BuildContext context) {
    final photo = outfit.photoPath;
    if (photo == null) {
      return OutfitCanvas(items: items, layout: outfit.layout);
    }
    return OutfitPhoto(reference: photo);
  }
}

/// A stored outfit selfie, or a just-taken one when [file] is set.
class OutfitPhoto extends StatelessWidget {
  const OutfitPhoto({super.key, this.reference, this.file});

  /// Storage reference resolved by [ImageStorageService].
  final String? reference;

  /// A local file that isn't stored yet.
  final String? file;

  @override
  Widget build(BuildContext context) {
    final path =
        file ??
        context.read<ImageStorageService>().resolvePath(reference ?? '');
    if (path == null) return const ColoredBox(color: Colors.black12);
    final ImageProvider provider = path.startsWith('https://')
        ? NetworkImage(path)
        : FileImage(File(path));
    return Image(
      image: provider,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black12),
    );
  }
}
