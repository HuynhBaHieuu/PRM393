import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/local/image_picker_service.dart';
import 'package:all_fits/data/models/outfit_create_mode.dart';
import 'package:all_fits/features/outfits/outfit_ideas.dart';
import 'package:all_fits/features/outfits/outfit_layout.dart';
import 'package:all_fits/features/outfits/screens/outfit_pick_screen.dart';
import 'package:all_fits/features/outfits/widgets/outfit_canvas.dart';
import 'package:all_fits/features/shared/closet_actions.dart';
import 'package:all_fits/features/try_on/try_on_flows.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/features/weather/controllers/weather_controller.dart';

/// Ways to start an outfit, shared by Home and "Add outfit".
abstract final class OutfitFlows {
  /// Turns the chosen pieces into an outfit the way [mode] says. Resolves
  /// to true once an outfit was saved.
  static Future<bool> build(
    BuildContext context, {
    required OutfitCreateMode mode,
    required List<String> itemIds,
    DateTime? planDate,
  }) async {
    final navigator = Navigator.of(context);
    final bool saved;
    switch (mode) {
      case OutfitCreateMode.collage:
        saved = await AppNavigator.composeOutfit(
          context,
          itemIds: itemIds,
          planDate: planDate,
        );
      case OutfitCreateMode.dressingRoom:
        saved = await AppNavigator.swipeOutfit(
          context,
          initialItemIds: itemIds,
        );
      case OutfitCreateMode.tryOn:
        await TryOnFlows.start(context, itemIds: itemIds);
        saved = false;
    }
    // Close "Add outfit" once its outfit exists.
    if (saved && navigator.canPop()) navigator.pop(true);
    return saved;
  }

  /// Fits' "Select how to create outfits" sheet.
  static Future<OutfitCreateMode?> chooseMode(
    BuildContext context, {
    required OutfitCreateMode current,
  }) {
    return showModalBottomSheet<OutfitCreateMode>(
      context: context,
      isScrollControlled: true,
      builder: (_) => OutfitModeSheet(current: current),
    );
  }

  /// An outfit selfie: a photo of the user wearing the outfit, saved as the
  /// outfit's picture, with the pieces optionally tagged.
  static Future<bool> selfie(BuildContext context, {DateTime? planDate}) async {
    final picker = context.read<ImagePickerService>();
    var source = ImagePickSource.gallery;
    if (picker.supportsCamera) {
      final chosen = await showModalBottomSheet<ImagePickSource>(
        context: context,
        builder: (sheetContext) => SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHeader(title: 'Take a photo of your outfit'),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a selfie'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImagePickSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from library'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImagePickSource.gallery),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      );
      if (chosen == null) return false;
      source = chosen;
    }
    final String? path;
    try {
      path = await picker.pickImage(source);
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
      return false;
    }
    if (path == null || !context.mounted) return false;
    return AppNavigator.composeOutfit(
      context,
      photoFile: path,
      planDate: planDate,
    );
  }

  /// Today's ideas from [OutfitIdeas]; empty when the wardrobe can't make
  /// a full look yet.
  static List<OutfitIdea> todaysIdeas(BuildContext context, {int count = 3}) {
    final wardrobe = context.read<WardrobeController>();
    final weather = context.read<WeatherController>().report;
    return OutfitIdeas.generate(
      wardrobe.activeItems,
      day: context.read<ClosetActions>().today,
      weather: weather,
      count: count,
    );
  }

  /// Shows today's ideas; resolves to the pieces of the one tapped.
  static Future<List<String>?> pickSuggestion(BuildContext context) {
    final ideas = todaysIdeas(context, count: 6);
    if (ideas.isEmpty) {
      context.showSnack('Add tops, bottoms and shoes to get suggestions.');
      return Future.value();
    }
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHeader(title: 'Suggestions'),
            SizedBox(
              height: 300,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                itemCount: ideas.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AppSpacing.sm),
                itemBuilder: (context, index) => SizedBox(
                  width: 190,
                  child: IdeaCard(
                    idea: ideas[index],
                    onTap: () =>
                        Navigator.of(sheetContext).pop(ideas[index].itemIds),
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

/// A white card with an idea's collage and its caption below.
class IdeaCard extends StatelessWidget {
  const IdeaCard({super.key, required this.idea, required this.onTap});

  final OutfitIdea idea;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: palette.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: OutfitCanvas(
                items: idea.items,
                layout: OutfitLayout.worn(idea.items),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(
              idea.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
