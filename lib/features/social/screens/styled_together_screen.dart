import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/app_dialogs.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/feedback_views.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/models/social.dart';
import 'package:all_fits/features/outfits/widgets/outfit_canvas.dart';
import 'package:all_fits/features/social/social_controller.dart';
import 'package:all_fits/features/social/social_flows.dart';
import 'package:all_fits/features/social/widgets/social_widgets.dart';
import 'package:all_fits/features/wardrobe/widgets/clothing_tile.dart';

/// Fits' "Styled together": outfits others made for you, and by you.
class StyledTogetherScreen extends StatelessWidget {
  const StyledTogetherScreen({super.key, this.showByYou = false});

  final bool showByYou;

  @override
  Widget build(BuildContext context) {
    final social = context.watch<SocialController>();
    return DefaultTabController(
      length: 2,
      initialIndex: showByYou ? 1 : 0,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Styled together'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'For you'),
              Tab(text: 'By you'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _StyledGrid(
              outfits: social.styledForMe,
              emptyMessage: 'Ask friends to create outfits for you',
            ),
            _StyledGrid(
              outfits: social.styledByMe,
              emptyMessage: 'You haven’t created any outfits for friends yet',
            ),
          ],
        ),
      ),
    );
  }
}

class _StyledGrid extends StatelessWidget {
  const _StyledGrid({required this.outfits, required this.emptyMessage});

  final List<StyledOutfit> outfits;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final social = context.read<SocialController>();
    return RefreshIndicator(
      onRefresh: social.load,
      child: outfits.isEmpty
          ? ListView(
              children: [
                AppEmptyState(
                  icon: Icons.style_outlined,
                  title: 'No outfits',
                  message: emptyMessage,
                  actionLabel: 'Find friends',
                  onAction: () => AppNavigator.userSearch(context),
                ),
              ],
            )
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(AppSpacing.page),
                  sliver: OutfitCardSliverGrid(
                    withCaption: true,
                    itemCount: outfits.length,
                    itemBuilder: (context, index) {
                      final styled = outfits[index];
                      final who = styled.incoming
                          ? 'From ${styled.other.username}'
                          : 'For ${styled.other.username}';
                      final state = switch (styled.status) {
                        StyledStatus.pending =>
                          styled.incoming ? 'New' : 'Sent',
                        StyledStatus.saved => 'Saved',
                        StyledStatus.dismissed => 'Sent',
                      };
                      return SocialOutfitCard(
                        items: styled.orderedItems,
                        layout: styled.layout,
                        owner: styled.other,
                        caption: '$who · $state',
                        onTap: () =>
                            AppNavigator.styledOutfit(context, styled.id),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

/// One outfit made for or by the user.
class StyledOutfitScreen extends StatefulWidget {
  const StyledOutfitScreen({super.key, required this.styledId});

  final String styledId;

  @override
  State<StyledOutfitScreen> createState() => _StyledOutfitScreenState();
}

class _StyledOutfitScreenState extends State<StyledOutfitScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) context.showErrorSnack(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(StyledOutfit styled) async {
    final navigator = Navigator.of(context);
    final confirmed = await showConfirmDialog(
      context,
      title: 'Are you sure?',
      message: 'Deleting this outfit cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _run(() async {
      await context.read<SocialController>().deleteStyledOutfit(styled.id);
      navigator.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final styled = context.watch<SocialController>().styledById(
      widget.styledId,
    );
    if (styled == null) {
      return const NotFoundView(
        title: 'Outfit not found',
        message: 'This outfit was deleted.',
      );
    }
    final palette = context.palette;
    final text = context.textTheme;
    final items = styled.orderedItems;
    final social = context.read<SocialController>();

    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.xxl,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.maxPreviewWidth,
              ),
              child: AspectRatio(
                aspectRatio: AppSizes.outfitImageAspect,
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(color: palette.border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    child: OutfitCanvas(items: items, layout: styled.layout),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          InkWell(
            onTap: () => SocialFlows.openProfile(context, styled.other.userId),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  UserAvatar(
                    name: styled.other.name,
                    url: styled.other.avatarUrl,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      styled.incoming
                          ? 'Created by ${styled.other.username}'
                          : 'Created for ${styled.other.username}',
                      style: text.titleMedium,
                    ),
                  ),
                  Text(
                    AppFormatters.relativeDay(styled.createdAt),
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          if (styled.message != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: palette.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Text(styled.message!, style: text.bodyLarge),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (styled.incoming && styled.isPending)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            final navigator = Navigator.of(context);
                            await social.answerStyledOutfit(
                              styled.id,
                              StyledStatus.dismissed,
                            );
                            navigator.pop();
                          }),
                    child: const Text('Dismiss'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _run(
                            () => SocialFlows.saveStyledOutfit(context, styled),
                          ),
                    child: const Text('Save to my outfits'),
                  ),
                ),
              ],
            )
          else if (styled.incoming && styled.status == StyledStatus.saved)
            const Center(
              child: TagLabel(
                'Saved to your outfits',
                icon: Icons.check_rounded,
              ),
            )
          else if (!styled.incoming)
            OutlinedButton(
              onPressed: _busy ? null : () => _delete(styled),
              child: const Text('Delete'),
            ),
          const SizedBox(height: AppSpacing.xl),
          Text('Clothes in outfit', style: text.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: AppSizes.recentItemWidth / AppSizes.clothingImageAspect,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) => SizedBox(
                width: AppSizes.recentItemWidth,
                child: ClothingTile(
                  item: items[index],
                  decodeWidth: AppSizes.recentItemWidth,
                  onTap: () => SocialFlows.showPiece(context, items[index]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
