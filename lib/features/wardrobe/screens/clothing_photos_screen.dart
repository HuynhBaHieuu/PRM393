import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/extensions/model_presentation.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/core/widgets/feedback_views.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/features/wardrobe/widgets/extra_photos.dart';

/// What the photo viewer opens with: a piece, and which of its photos to
/// show first (0 is the main photo, then its extra photos in order).
class ClothingPhotosArgs {
  const ClothingPhotosArgs(this.itemId, {this.initialIndex = 0});

  final String itemId;
  final int initialIndex;
}

/// Every photo of a piece full screen, to swipe through and zoom into.
class ClothingPhotosScreen extends StatefulWidget {
  const ClothingPhotosScreen({
    super.key,
    required this.itemId,
    this.initialIndex = 0,
  });

  final String itemId;
  final int initialIndex;

  @override
  State<ClothingPhotosScreen> createState() => _ClothingPhotosScreenState();
}

class _ClothingPhotosScreenState extends State<ClothingPhotosScreen> {
  late int _index = widget.initialIndex;
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex,
  );

  static const double _maxZoom = 4;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Null stands for the main photo.
  static List<String?> _photosOf(ClothingItem item) => [
    null,
    for (final photo in item.extraPhotos) photo.path,
  ];

  static String _labelOf(ClothingItem item, int index) =>
      index == 0 ? 'Main photo' : item.extraPhotos[index - 1].kind.label;

  void _jumpTo(int index) => _pages.animateToPage(
    index,
    duration: const Duration(milliseconds: 250),
    curve: Curves.easeOut,
  );

  @override
  Widget build(BuildContext context) {
    final item = context.watch<WardrobeController>().itemById(widget.itemId);
    if (item == null) {
      return const NotFoundView(
        title: 'Item not found',
        message: 'This item is no longer in your wardrobe.',
      );
    }
    final photos = _photosOf(item);
    final index = _index.clamp(0, photos.length - 1);
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: Text(_labelOf(item, index)),
        actions: [
          Center(
            child: Text(
              '${index + 1} / ${photos.length}',
              style: context.textTheme.bodyMedium?.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.page),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: photos.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => InteractiveViewer(
                maxScale: _maxZoom,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: ClothingImage(
                    key: ValueKey(photos[i] ?? item.imagePath),
                    item: item,
                    photo: photos[i],
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
          if (photos.length > 1)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Center(
                  child: PhotoStrip(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.page,
                    ),
                    thumbs: [
                      for (var i = 0; i < photos.length; i++)
                        PhotoThumb(
                          image: ClothingImage(
                            item: item,
                            photo: photos[i],
                            decodeWidth: PhotoThumb.width,
                          ),
                          label: i == 0 ? 'Main' : _labelOf(item, i),
                          icon: i == 0
                              ? Icons.star_outline_rounded
                              : item.extraPhotos[i - 1].kind.icon,
                          selected: i == index,
                          onTap: () => _jumpTo(i),
                        ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
