import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/app_dialogs.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/local/image_picker_service.dart';
import 'package:all_fits/data/local/image_storage_service.dart';
import 'package:all_fits/data/models/try_on.dart';
import 'package:all_fits/data/remote/ai_stylist_service.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/try_on/try_on_controller.dart';

/// What the try-on screen opens with: pieces to try on, or a saved picture.
class TryOnArgs {
  const TryOnArgs({
    this.itemIds = const [],
    this.outfitId,
    this.resultId,
    this.wearer = TryOnWearer.me,
  });

  final List<String> itemIds;
  final String? outfitId;
  final TryOnWearer wearer;

  /// A saved picture to show, with the pieces and settings it was made with.
  final String? resultId;
}

abstract final class TryOnFlows {
  /// Opens the try-on screen for [itemIds] (or the clothes picker when
  /// empty). The first time, the try-on profile explains how it works and
  /// asks for consent before any photo is sent.
  static Future<void> start(
    BuildContext context, {
    List<String> itemIds = const [],
    String? outfitId,
  }) async {
    final tryOn = context.read<TryOnController>();
    if (!tryOn.isAvailable) {
      context.showSnack('AI try-on needs a Gemini API key in assets/env.json.');
      return;
    }
    await tryOn.load();
    if (!context.mounted) return;
    var wearer = tryOn.profile.hasPhoto ? TryOnWearer.me : TryOnWearer.model;
    if (!tryOn.profile.consented) {
      final chosen = await AppNavigator.tryOnProfile(context, onboarding: true);
      if (chosen == null || !context.mounted) return;
      wearer = chosen;
    }
    final args = TryOnArgs(
      itemIds: itemIds,
      outfitId: outfitId,
      wearer: wearer,
    );
    // Without pieces, choosing them is the first step, as in Fits.
    await (itemIds.isEmpty
        ? AppNavigator.tryOnClothes(context, args)
        : AppNavigator.tryOn(context, args));
  }

  /// Shows a saved picture on the try-on screen.
  static Future<void> open(BuildContext context, TryOnResult result) =>
      AppNavigator.tryOn(
        context,
        TryOnArgs(
          itemIds: result.itemIds,
          outfitId: result.outfitId,
          resultId: result.id,
          wearer: result.wearer,
        ),
      );

  /// Asks for a photo from the camera or library and stores it; resolves to
  /// its reference.
  static Future<String?> pickPhoto(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    final picker = context.read<ImagePickerService>();
    final source = await showModalBottomSheet<ImagePickSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(title), subtitle: Text(message)),
            if (picker.supportsCamera)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Camera'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImagePickSource.camera),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Library'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(ImagePickSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return null;
    try {
      final path = await picker.pickImage(source);
      if (path == null || !context.mounted) return null;
      return await context.read<ImageStorageService>().saveImage(path);
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
      return null;
    }
  }

  /// Saves the picture to the phone's gallery.
  static Future<void> save(BuildContext context, TryOnResult result) async {
    final images = context.read<ImageStorageService>();
    try {
      final bytes = await AiStylistService.readImage(
        images.resolvePath(result.photo) ?? result.photo,
      );
      if (bytes == null) throw const FileSystemException('Unreadable');
      if (!await Gal.hasAccess(toAlbum: true) &&
          !await Gal.requestAccess(toAlbum: true)) {
        if (context.mounted) {
          context.showSnack('Allow photo access to save the picture.');
        }
        return;
      }
      await Gal.putImageBytes(
        Uint8List.fromList(bytes),
        album: AppConfig.appName,
        name: 'tryon_${result.id}',
      );
      if (context.mounted) context.showSnack('Saved to your photos');
    } catch (_) {
      if (context.mounted) context.showSnack('The picture could not be saved.');
    }
  }

  static Future<void> share(BuildContext context, TryOnResult result) async {
    final images = context.read<ImageStorageService>();
    try {
      final bytes = await AiStylistService.readImage(
        images.resolvePath(result.photo) ?? result.photo,
      );
      if (bytes == null) throw const FileSystemException('Unreadable');
      final extension = switch (AiStylistService.mimeOf(bytes)) {
        'image/png' => 'png',
        'image/webp' => 'webp',
        _ => 'jpg',
      };
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/tryon_${result.id}.$extension');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'AI try-on made with ${AppConfig.appName}',
        ),
      );
    } catch (_) {
      if (context.mounted) {
        context.showSnack('The picture could not be shared.');
      }
    }
  }

  /// Resolves to true when the user deleted [result].
  static Future<bool> delete(BuildContext context, TryOnResult result) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete this picture?',
      message: 'The try-on picture is removed from All Fits.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return false;
    try {
      await context.read<TryOnController>().delete(result.id);
      return true;
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
      return false;
    }
  }

  /// Explains that no credits are left, and offers Premium on Free.
  static Future<void> showNoCredits(BuildContext context) {
    final premium = context.read<SettingsController>().isPremium;
    final now = DateTime.now();
    final renewal = DateTime(now.year, now.month + 1);
    final text = context.textTheme;
    final palette = context.palette;
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            0,
            AppSpacing.page,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHeader(title: 'No AI credits left'),
              Text(
                premium
                    ? 'Premium makes '
                          '${AppFormatters.count(AppConfig.premiumTryOnsPerMonth, 'try-on picture')} '
                          'a month. New credits arrive on '
                          '${AppFormatters.shortDate(renewal)}.'
                    : 'You’ve used your free try-on. Premium makes '
                          '${AppFormatters.count(AppConfig.premiumTryOnsPerMonth, 'try-on picture')} '
                          'a month. A credit is only used when a picture '
                          'comes back.',
                style: text.bodyMedium?.copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (!premium) ...[
                FilledButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    AppNavigator.premium(context);
                  },
                  child: const Text('See Premium'),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: Text(premium ? 'OK' : 'Not now'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "3 AI credits" / "1 free try-on".
  static String creditsLabel(BuildContext context) {
    final plan = context.watch<SettingsController>().plan;
    final left = context.watch<TryOnController>().creditsLeft(plan);
    if (!plan.isPremium && left > 0) {
      return AppFormatters.count(left, 'free try-on');
    }
    return AppFormatters.count(left, 'AI credit');
  }
}
