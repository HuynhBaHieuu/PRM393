import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/extensions/model_presentation.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/core/widgets/color_swatch.dart';
import 'package:all_fits/core/widgets/detail_rows.dart';
import 'package:all_fits/data/models/social.dart';
import 'package:all_fits/features/social/social_controller.dart';
import 'package:all_fits/features/social/social_flows.dart';
import 'package:all_fits/features/social/widgets/comments_sheet.dart';
import 'package:all_fits/features/social/widgets/social_widgets.dart';
import 'package:all_fits/core/l10n/l10n.dart';

/// Someone's piece, as Fits' "Your piece" page: the photo, likes, comments
/// and how many people added it, its owner, its details, and "Add to your
/// wardrobe". Pops with the piece as it was left.
class PublicPieceScreen extends StatefulWidget {
  const PublicPieceScreen({super.key, required this.entry});

  /// The counts may be missing (e.g. opened from an outfit); they are
  /// fetched again on open.
  final CommunityItem entry;

  @override
  State<PublicPieceScreen> createState() => _PublicPieceScreenState();
}

class _PublicPieceScreenState extends State<PublicPieceScreen> {
  late CommunityItem _entry = widget.entry;

  /// False while the counts load, and when the piece is no longer shared.
  bool _shared = false;
  bool _liking = false;
  bool _adding = false;

  static const double _photoHeight = 360;

  SocialController get _social => context.read<SocialController>();

  bool get _isMine => _social.me?.userId == _entry.owner.userId;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final fresh = await _social.repository.communityItem(
        _entry.owner.userId,
        _entry.item.id,
      );
      if (!mounted || fresh == null) return;
      setState(() {
        _entry = fresh;
        _shared = true;
      });
    } catch (_) {
      // The page still shows the piece; only the counts are missing.
    }
  }

  Future<void> _toggleLiked() async {
    if (_liking) return;
    if (!await SocialFlows.requireProfile(context) || !mounted) return;
    final before = _entry;
    final liked = !before.liked;
    setState(() {
      _liking = true;
      _entry = before.copyWith(
        liked: liked,
        likes: math.max(0, before.likes + (liked ? 1 : -1)),
      );
    });
    try {
      await _social.repository.setItemLiked(before, liked: liked);
    } catch (error) {
      if (!mounted) return;
      setState(
        () =>
            _entry = _entry.copyWith(liked: before.liked, likes: before.likes),
      );
      context.showErrorSnack(error);
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  Future<void> _openComments() async {
    final repository = _social.repository;
    final count = await CommentsSheet.show(
      context,
      ownerId: _entry.owner.userId,
      load: () => repository.itemComments(_entry),
      add: (body) => repository.addItemComment(_entry, body),
      delete: repository.deleteItemComment,
    );
    if (count != null && mounted) {
      setState(() => _entry = _entry.copyWith(comments: count));
    }
  }

  Future<void> _add({required bool choose}) async {
    if (_adding) return;
    setState(() => _adding = true);
    final added = choose
        ? await SocialFlows.chooseWardrobeTarget(context, _entry)
        : await SocialFlows.addToWardrobe(context, _entry) != null;
    if (!mounted) return;
    setState(() {
      _adding = false;
      if (added) _entry = _entry.copyWith(copies: _entry.copies + 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    final item = _entry.item;
    final owner = _entry.owner;
    final hint = palette.textSecondary;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_entry);
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
            if (!_isMine)
              IconButton(
                tooltip: tr('More'),
                onPressed: () => SocialFlows.showProfileMenu(
                  context,
                  ProfileSummary(profile: owner),
                ),
                icon: const Icon(Icons.more_horiz_rounded),
              ),
          ],
        ),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                0,
                AppSpacing.page,
                AppSpacing.xxl * 2,
              ),
              children: [
                SizedBox(
                  height: _photoHeight,
                  child: ClothingImage(
                    item: item,
                    cutout: true,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    if (_shared) ...[
                      CountButton(
                        tooltip: _entry.liked ? tr('Unlike') : tr('Like'),
                        icon: _entry.liked
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: _entry.liked ? palette.danger : null,
                        count: _entry.likes,
                        onPressed: _liking ? null : _toggleLiked,
                      ),
                      CountButton(
                        tooltip: tr('Comments'),
                        icon: Icons.chat_bubble_outline_rounded,
                        count: _entry.comments,
                        onPressed: _openComments,
                      ),
                      if (_entry.copies > 0)
                        CountButton(
                          tooltip: tr('Added to {0} wardrobes', [
                            _entry.copies,
                          ]),
                          icon: Icons.checkroom_outlined,
                          count: _entry.copies,
                          onPressed: null,
                        ),
                    ],
                    const Spacer(),
                    InkWell(
                      onTap: () =>
                          SocialFlows.openProfile(context, owner.userId),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xxs),
                        child: Row(
                          children: [
                            UserAvatar(name: owner.name, url: owner.avatarUrl),
                            const SizedBox(width: AppSpacing.sm),
                            Text(owner.username, style: text.titleMedium),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(item.name, style: text.titleLarge),
                const SizedBox(height: AppSpacing.md),
                DetailGroup(
                  children: [
                    DetailRow(
                      icon: Icons.format_list_bulleted_rounded,
                      leading: Icon(item.category.icon, color: hint),
                      label:
                          item.subcategory?.label ??
                          item.category.singularLabel,
                      chevron: false,
                      onTap: null,
                    ),
                    if (item.brand case final brand?)
                      DetailRow(
                        icon: Icons.verified_outlined,
                        label: brand,
                        chevron: false,
                        onTap: null,
                      ),
                    if (item.color case final color?)
                      DetailRow(
                        icon: Icons.water_drop_outlined,
                        leading: ColorSwatchDot(color: color, size: 26),
                        label: color.label,
                        chevron: false,
                        onTap: null,
                      ),
                    if (item.materials.isNotEmpty)
                      DetailRow(
                        icon: Icons.layers_outlined,
                        label: item.materials.join(', '),
                        chevron: false,
                        onTap: null,
                      ),
                    if (item.seasons.isNotEmpty)
                      DetailRow(
                        icon: Icons.wb_sunny_outlined,
                        label: item.seasons
                            .map((s) => '${s.emoji} ${s.label}')
                            .join('  ·  '),
                        multiline: true,
                        chevron: false,
                        onTap: null,
                      ),
                  ],
                ),
              ],
            ),
            if (!_isMine)
              Positioned(
                left: 0,
                right: 0,
                bottom: AppSpacing.md + MediaQuery.paddingOf(context).bottom,
                child: Center(
                  child: _AddToWardrobeButton(
                    busy: _adding,
                    onAdd: () => _add(choose: false),
                    onChoose: () => _add(choose: true),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Fits' black split pill: "Add to your wardrobe" | ⌄.
class _AddToWardrobeButton extends StatelessWidget {
  const _AddToWardrobeButton({
    required this.busy,
    required this.onAdd,
    required this.onChoose,
  });

  final bool busy;
  final VoidCallback onAdd;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = context.textTheme.titleMedium?.copyWith(color: palette.onInk);
    return Material(
      color: palette.ink,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      elevation: 6,
      child: SizedBox(
        height: AppSizes.buttonHeight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: busy ? null : onAdd,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Center(
                  child: busy
                      ? SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: palette.onInk,
                          ),
                        )
                      : Text(tr('Add to your wardrobe'), style: style),
                ),
              ),
            ),
            VerticalDivider(
              width: 1,
              color: palette.onInk.withValues(alpha: 0.3),
            ),
            InkWell(
              onTap: busy ? null : onChoose,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Tooltip(
                  message: tr('Add to a collection'),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: palette.onInk,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
