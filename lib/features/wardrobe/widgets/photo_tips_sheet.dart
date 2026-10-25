import 'package:flutter/material.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';

/// "How to get best results": which photos the AI and the background
/// remover read best, shown once before the first photo, like Fits. The
/// examples are the app's own sample photos.
Future<void> showPhotoTipsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHeader(title: 'How to get best results'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'When adding your clothes, pick online shop images for '
                    'best results or snap your clothes on a flat surface.',
                    style: sheetContext.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _Example(
                    asset: 'assets/sample/cutouts/black-tee.webp',
                    emoji: '😍',
                    label: 'Shop photo',
                    aspectRatio: 2,
                    cutout: true,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _Example(
                          asset: 'assets/sample/beige-chinos.jpg',
                          emoji: '🙂',
                          label: 'Flat surface',
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _Example(
                          asset: 'assets/sample/balenciaga-hoodie.jpg',
                          emoji: '😕',
                          label: 'Worn, busy background',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Got it 👌'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Example extends StatelessWidget {
  const _Example({
    required this.asset,
    required this.emoji,
    required this.label,
    this.aspectRatio = 1,
    this.cutout = false,
  });

  final String asset;
  final String emoji;
  final String label;
  final double aspectRatio;

  /// A background-removed piece, shown whole on the muted surface.
  final bool cutout;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: palette.surfaceMuted,
                  child: Padding(
                    padding: EdgeInsets.all(cutout ? AppSpacing.md : 0),
                    child: Image.asset(
                      asset,
                      fit: cutout ? BoxFit.contain : BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  left: AppSpacing.sm,
                  top: AppSpacing.sm,
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: palette.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 22)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          textAlign: TextAlign.center,
          style: context.textTheme.bodyMedium?.copyWith(
            color: palette.textSecondary,
          ),
        ),
      ],
    );
  }
}
