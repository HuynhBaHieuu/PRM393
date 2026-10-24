import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/widgets/layout.dart';
import 'package:all_fits/core/widgets/section_header.dart';
import 'package:all_fits/features/home/widgets/home_greeting.dart';
import 'package:all_fits/features/home/widgets/home_sections.dart';
import 'package:all_fits/features/home/widgets/today_outfit_section.dart';
import 'package:all_fits/features/home/widgets/weather_section.dart';
import 'package:all_fits/features/social/social_controller.dart';
import 'package:all_fits/features/social/widgets/discover_section.dart';
import 'package:all_fits/features/try_on/try_on_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const padded = EdgeInsets.symmetric(horizontal: AppSpacing.page);
    final online = context.select<SocialController?, bool>((s) => s != null);
    final tryOn = context.select<TryOnController, bool>((t) => t.isAvailable);
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          const ResponsiveCenter(child: HomeGreeting()),
          const SizedBox(height: AppSpacing.xl),
          const ResponsiveCenter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(title: 'Today’s outfit'),
                SizedBox(height: AppSpacing.md),
                Padding(padding: padded, child: TodayOutfitSection()),
                SizedBox(height: AppSpacing.lg),
                Padding(padding: padded, child: QuickActions()),
              ],
            ),
          ),
          if (tryOn)
            const ResponsiveCenter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.sm,
                  AppSpacing.page,
                  0,
                ),
                child: TryOnShortcut(),
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          const RecentlyAddedSection(),
          if (online) ...[
            const SizedBox(height: AppSpacing.xl),
            const ResponsiveCenter(child: DiscoverSection()),
          ],
          const SizedBox(height: AppSpacing.xl),
          const ResponsiveCenter(child: WeatherSection()),
          const SizedBox(height: AppSpacing.xl),
          const RecentlyWornSection(),
        ],
      ),
    );
  }
}
