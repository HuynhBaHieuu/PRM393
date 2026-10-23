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

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const padded = EdgeInsets.symmetric(horizontal: AppSpacing.page);
    final online = context.select<SocialController?, bool>((s) => s != null);
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
