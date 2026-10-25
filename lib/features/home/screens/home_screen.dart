import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/layout.dart';
import 'package:all_fits/features/home/widgets/home_header.dart';
import 'package:all_fits/features/home/widgets/home_sections.dart';
import 'package:all_fits/features/stylist/stylist_store.dart';

/// Fits' Home: shortcuts and today's ideas first, then the closet's recent
/// and unworn pieces, ending with "Come back tomorrow for new ideas."
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // "Get started" and "Find an outfit" read the stylist's usage.
    context.read<StylistStore>().load();
  }

  @override
  Widget build(BuildContext context) {
    const padded = EdgeInsets.symmetric(horizontal: AppSpacing.page);
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const ResponsiveCenter(child: HomeTopBar()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
              children: [
                const StoryRow(),
                const SizedBox(height: AppSpacing.md),
                const ResponsiveCenter(
                  child: Padding(padding: padded, child: GetStartedCard()),
                ),
                const SizedBox(height: AppSpacing.md),
                const ResponsiveCenter(
                  child: Padding(padding: padded, child: FindOutfitBar()),
                ),
                const SizedBox(height: AppSpacing.lg),
                const ResponsiveCenter(child: QuickTiles()),
                const ForTodaySection(),
                const AiStylistSection(),
                const RecentOutfitsSection(),
                const RecentlyAddedSection(),
                const NotYetWornSection(),
                const NewestIdeasSection(),
                const TryOnBackgroundsSection(),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Come back tomorrow for new ideas.',
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
