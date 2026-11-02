import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/app_dialogs.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/social.dart';
import 'package:all_fits/features/collections/collection_flows.dart';
import 'package:all_fits/features/collections/controllers/collection_controller.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/controllers/outfit_draft.dart';
import 'package:all_fits/features/premium/premium_flows.dart';
import 'package:all_fits/features/shared/closet_flows.dart';
import 'package:all_fits/features/social/social_controller.dart';
import 'package:all_fits/features/wardrobe/controllers/clothing_draft.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/navigation/app_navigation.dart';
import 'package:all_fits/core/l10n/l10n.dart';

/// Community actions shared by several screens. Copy follows Fits.
abstract final class SocialFlows {
  // Sent to the server in English; shown translated.
  static const List<String> reportReasons = [
    'Spam',
    'Nudity or sexual content',
    'Hate speech or symbols',
    'Bullying or harassment',
    'Someone else’s photos',
    'Something else',
  ];

  /// Opens [userId]'s profile, or the Profile tab for the signed-in user.
  static void openProfile(BuildContext context, String userId) {
    if (context.read<SocialController>().me?.userId == userId) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      context.read<ShellController>().select(AppTab.profile);
      return;
    }
    AppNavigator.userProfile(context, userId);
  }

  /// True when the user has a profile, otherwise offers to create one.
  static Future<bool> requireProfile(BuildContext context) async {
    if (context.read<SocialController>().hasProfile) return true;
    final create = await showConfirmDialog(
      context,
      title: tr('Create your profile'),
      message: tr(
        'Pick a username first. It’s how people find you, follow you '
        'and see what you share.',
      ),
      confirmLabel: tr('Create profile'),
    );
    if (create && context.mounted) await AppNavigator.editProfile(context);
    return context.mounted && context.read<SocialController>().hasProfile;
  }

  static Future<void> shareProfile(BuildContext context, String username) =>
      SharePlus.instance.share(
        ShareParams(
          text: tr(
            'My username is @{0} on {1}. Search for it to see my closet.',
            [username, AppConfig.appName],
          ),
        ),
      );

  /// Fits' "…" sheet: copy the username, report, and block or unblock.
  static Future<void> showProfileMenu(
    BuildContext context,
    ProfileSummary summary, {
    VoidCallback? onChanged,
  }) {
    final profile = summary.profile;
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        void run(Future<void> Function() action) {
          Navigator.of(sheetContext).pop();
          action();
        }

        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetAction(
                icon: Icons.link_rounded,
                label: tr('Copy username'),
                onTap: () => run(() async {
                  await Clipboard.setData(
                    ClipboardData(text: '@${profile.username}'),
                  );
                  if (context.mounted) {
                    context.showSnack(tr('Username copied to clipboard'));
                  }
                }),
              ),
              _SheetAction(
                icon: Icons.error_outline_rounded,
                label: tr('Report'),
                onTap: () => run(() => report(context, profile)),
              ),
              _SheetAction(
                icon: Icons.block_rounded,
                label: summary.blockedByMe ? tr('Unblock') : tr('Block'),
                onTap: () => run(() async {
                  final changed = summary.blockedByMe
                      ? await unblock(context, profile)
                      : await block(context, profile);
                  if (changed) onChanged?.call();
                }),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }

  /// Report and Block for a Community outfit.
  static Future<void> showPostMenu(
    BuildContext context,
    FeedPost post, {
    VoidCallback? onBlocked,
  }) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      void run(Future<void> Function() action) {
        Navigator.of(sheetContext).pop();
        action();
      }

      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetAction(
              icon: Icons.error_outline_rounded,
              label: tr('Report'),
              onTap: () => run(
                () => report(context, post.owner, outfitId: post.outfit.id),
              ),
            ),
            _SheetAction(
              icon: Icons.block_rounded,
              label: tr('Block {0}', [post.owner.username]),
              onTap: () => run(() async {
                if (await block(context, post.owner)) onBlocked?.call();
              }),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      );
    },
  );

  static Future<void> report(
    BuildContext context,
    SocialProfile profile, {
    String? outfitId,
  }) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(title: tr('Why are you reporting this?')),
            for (final reason in reportReasons)
              ListTile(
                title: Text(tr(reason)),
                onTap: () => Navigator.of(sheetContext).pop(reason),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (reason == null || !context.mounted) return;
    try {
      await context.read<SocialController>().repository.report(
        profile.userId,
        reason: reason,
        outfitId: outfitId,
      );
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(tr('Thank you for your report!')),
          content: Text(
            tr('We will look into your report and take appropriate action.'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(tr('OK')),
            ),
          ],
        ),
      );
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
    }
  }

  static Future<bool> block(BuildContext context, SocialProfile profile) async {
    final confirmed = await showConfirmDialog(
      context,
      title: tr('Block {0}?', [profile.username]),
      message: tr(
        'They will not get notified that you blocked them. They won’t be '
        'able to follow you or make outfits for you, and you won’t see '
        'their outfits on Discover. You can unblock users in your account.',
      ),
      confirmLabel: tr('Block'),
      destructive: true,
    );
    if (!confirmed || !context.mounted) return false;
    try {
      await context.read<SocialController>().block(profile.userId);
      if (context.mounted) context.showSnack(tr('User blocked'));
      return true;
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
      return false;
    }
  }

  static Future<bool> unblock(
    BuildContext context,
    SocialProfile profile,
  ) async {
    try {
      await context.read<SocialController>().unblock(profile.userId);
      if (context.mounted) {
        context.showSnack(tr('{0} unblocked', [profile.username]));
      }
      return true;
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
      return false;
    }
  }

  static Future<bool> unfollow(
    BuildContext context,
    SocialProfile profile,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: tr('Unfollow {0}?', [profile.username]),
      message: profile.isPrivate
          ? tr(
              'Their account is private. You’ll need to ask again to see '
              'their closet.',
            )
          : tr('Their outfits won’t show under Following anymore.'),
      confirmLabel: tr('Unfollow'),
      destructive: true,
    );
    if (!confirmed || !context.mounted) return false;
    try {
      await context.read<SocialController>().unfollow(profile.userId);
      return true;
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
      return false;
    }
  }

  static Future<bool> removeFollower(
    BuildContext context,
    SocialProfile profile,
  ) async {
    final confirmed = await showConfirmDialog(
      context,
      title: tr('Remove follower?'),
      message: tr('Are you sure you want to remove this follower?'),
      confirmLabel: tr('Remove'),
      destructive: true,
    );
    if (!confirmed || !context.mounted) return false;
    try {
      await context.read<SocialController>().removeFollower(profile.userId);
      return true;
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
      return false;
    }
  }

  /// Copies an outfit someone made for the user into their own outfits.
  /// Pieces deleted since are left out.
  static Future<void> saveStyledOutfit(
    BuildContext context,
    StyledOutfit styled,
  ) async {
    final wardrobe = context.read<WardrobeController>();
    final outfits = context.read<OutfitController>();
    final social = context.read<SocialController>();
    final itemIds = styled.itemIds
        .where((id) => wardrobe.itemById(id) != null)
        .toList();
    try {
      if (itemIds.isEmpty) {
        throw NotFoundException(
          tr('These pieces are no longer in your wardrobe.'),
        );
      }
      final outfit = await outfits.createOutfit(
        OutfitDraft(
          name: styled.name ?? tr('Styled by {0}', [styled.other.username]),
          itemIds: itemIds,
          notes: styled.message,
          layout: styled.layout
              .where((p) => itemIds.contains(p.itemId))
              .toList(),
        ),
      );
      await social.answerStyledOutfit(styled.id, StyledStatus.saved);
      if (context.mounted) {
        context.showSnack(
          tr('Saved to your outfits'),
          actionLabel: tr('View'),
          onAction: () => AppNavigator.outfitDetail(context, outfit.id),
        );
      }
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
    }
  }

  /// Opens a piece from [owner]'s closet, as Fits' "Your piece" page.
  static Future<CommunityItem?> openPiece(
    BuildContext context,
    SocialProfile owner,
    ClothingItem item,
  ) => AppNavigator.publicPiece(
    context,
    CommunityItem(owner: owner, item: item),
  );

  /// Fits' ⌄ next to "Add to your wardrobe": the main wardrobe, or the
  /// wardrobe plus a collection. Resolves to true once the piece is added.
  static Future<bool> chooseWardrobeTarget(
    BuildContext context,
    CommunityItem entry,
  ) async {
    final collections = context.read<CollectionController>().collections;
    const main = '';
    const create = '+';
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final text = sheetContext.textTheme;
        final palette = sheetContext.palette;
        Widget box(Widget child) => Container(
          width: AppSizes.thumbLg,
          height: AppSizes.thumbLg,
          decoration: BoxDecoration(
            color: palette.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: child,
        );
        return SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                  vertical: AppSpacing.xxs,
                ),
                leading: box(
                  Icon(Icons.checkroom_outlined, color: palette.ink),
                ),
                title: Text(tr('Main wardrobe'), style: text.titleMedium),
                onTap: () => Navigator.of(sheetContext).pop(main),
              ),
              const Divider(
                indent: AppSpacing.page,
                endIndent: AppSpacing.page,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.xs,
                  AppSpacing.page,
                  AppSpacing.xs,
                ),
                child: Text(
                  tr('Collections'),
                  style: text.titleMedium?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                  vertical: AppSpacing.xxs,
                ),
                leading: box(Icon(Icons.add_rounded, color: palette.ink)),
                title: Text(
                  tr('Create new collection'),
                  style: text.titleMedium,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(sheetContext).pop(create),
              ),
              for (final collection in collections)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                    vertical: AppSpacing.xxs,
                  ),
                  leading: box(
                    Icon(Icons.bookmark_border_rounded, color: palette.ink),
                  ),
                  title: Text(collection.name, style: text.titleMedium),
                  subtitle: Text(
                    AppFormatters.count(collection.itemIds.length, 'piece'),
                  ),
                  trailing: const Icon(Icons.add_circle_outline_rounded),
                  onTap: () => Navigator.of(sheetContext).pop(collection.id),
                ),
            ],
          ),
        );
      },
    );
    if (chosen == null || !context.mounted) return false;
    final item = await addToWardrobe(context, entry);
    if (item == null || chosen == main || !context.mounted) return item != null;
    if (chosen == create) {
      await CollectionFlows.create(context, itemIds: [item.id]);
    } else {
      final collection = context.read<CollectionController>().collectionById(
        chosen,
      );
      if (collection != null) {
        await ClosetFlows.guard(
          context,
          () => context.read<CollectionController>().setItemMembership(
            item.id,
            {chosen},
          ),
          successMessage: tr('Added to “{0}”', [collection.name]),
        );
      }
    }
    return true;
  }

  /// Copies someone's piece into the user's wardrobe: its photo (uploaded
  /// again, so it stays if they delete theirs), name, category, color,
  /// seasons and brand. Resolves to the new piece, or null.
  static Future<ClothingItem?> addToWardrobe(
    BuildContext context,
    CommunityItem entry,
  ) async {
    if (!PremiumFlows.canAddClothing(context)) {
      await PremiumFlows.showWardrobeLimit(context);
      return null;
    }
    final wardrobe = context.read<WardrobeController>();
    final social = context.read<SocialController>();
    final piece = entry.item;
    final photo = [
      piece.imagePath,
      piece.cutoutPath,
    ].firstWhere((p) => p?.startsWith('https://') ?? false, orElse: () => null);
    context.showSnack(tr('Adding to your wardrobe…'));
    File? download;
    try {
      if (photo == null) {
        throw StorageException(tr('This piece has no photo to copy.'));
      }
      download = await _download(photo);
      final added = await wardrobe.addItem(
        ClothingDraft(
          name: piece.name,
          category: piece.category,
          subcategory: piece.subcategory,
          color: piece.color,
          seasons: piece.seasons,
          brand: piece.brand,
          newImagePath: download.path,
        ),
      );
      try {
        await social.repository.recordItemCopy(entry);
      } catch (_) {
        // Only the counter misses it; the piece is in the wardrobe.
      }
      if (context.mounted) {
        context.showSnack(
          tr('Added to your wardrobe'),
          actionLabel: tr('View'),
          onAction: () => AppNavigator.clothingDetail(context, added.id),
        );
      }
      return added;
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
      return null;
    } finally {
      try {
        await download?.delete();
      } on FileSystemException {
        // A leftover temp file is harmless.
      }
    }
  }

  static Future<File> _download(String url) async {
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(Uri.parse(url))).close();
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw StorageException(tr('The photo could not be downloaded.'));
      }
      final extension = url.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/community_${DateTime.now().microsecondsSinceEpoch}'
        '.$extension',
      );
      await response.pipe(file.openWrite());
      return file;
    } on SocketException {
      throw StorageException(tr('The photo could not be downloaded.'));
    } finally {
      client.close();
    }
  }
}

/// Icon in a grey circle and a label, as in Fits' bottom sheets.
class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.page,
        vertical: AppSpacing.xxs,
      ),
      leading: Container(
        width: AppSizes.thumbSm,
        height: AppSizes.thumbSm,
        decoration: BoxDecoration(
          color: palette.surfaceMuted,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: palette.ink),
      ),
      title: Text(label, style: context.textTheme.titleMedium),
    );
  }
}
