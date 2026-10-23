import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/section_header.dart';
import 'package:all_fits/data/models/social.dart';
import 'package:all_fits/features/social/social_controller.dart';
import 'package:all_fits/features/social/widgets/social_widgets.dart';

/// Home's "Discover": the newest public outfits, with who posted them.
class DiscoverSection extends StatefulWidget {
  const DiscoverSection({super.key});

  static const int _shown = 4;

  @override
  State<DiscoverSection> createState() => _DiscoverSectionState();
}

class _DiscoverSectionState extends State<DiscoverSection> {
  late Future<List<FeedPost>> _posts = _fetch();

  Future<List<FeedPost>> _fetch() async {
    final posts = await context.read<SocialController>().repository.feed(
      FeedFilter.latest,
    );
    return posts.take(DiscoverSection._shown).toList();
  }

  Future<void> _open(FeedPost post) async {
    if (await AppNavigator.publicOutfit(context, post) && mounted) {
      setState(() => _posts = _fetch());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Discover',
          subtitle: 'Outfits from the community',
          actionLabel: 'See all',
          onAction: () async {
            await AppNavigator.discover(context);
            if (mounted) setState(() => _posts = _fetch());
          },
        ),
        const SizedBox(height: AppSpacing.md),
        FutureBuilder<List<FeedPost>>(
          future: _posts,
          builder: (context, snapshot) {
            final posts = snapshot.data;
            if (posts == null || posts.isEmpty) {
              final message = snapshot.hasError
                  ? 'Couldn’t load Discover.'
                  : posts == null
                  ? 'Loading…'
                  : 'No outfits shared yet. Make one public from its page.';
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                child: Text(
                  message,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              );
            }
            return CustomScrollView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  sliver: OutfitCardSliverGrid(
                    itemCount: posts.length,
                    itemBuilder: (context, index) => SocialOutfitCard(
                      items: posts[index].orderedItems,
                      layout: posts[index].outfit.layout,
                      owner: posts[index].owner,
                      onTap: () => _open(posts[index]),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
