import 'package:flutter/material.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/widgets/layout.dart';
import 'package:all_fits/core/widgets/section_header.dart';
import 'package:all_fits/features/home/widgets/home_greeting.dart';
import 'package:all_fits/features/home/widgets/home_sections.dart';
import 'package:all_fits/features/home/widgets/today_outfit_section.dart';
import 'package:all_fits/features/home/widgets/weather_section.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const padded = EdgeInsets.symmetric(horizontal: AppSpacing.page);
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: const [
          ResponsiveCenter(child: HomeGreeting()),
          SizedBox(height: AppSpacing.xl),
          ResponsiveCenter(
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
          SizedBox(height: AppSpacing.xl),
          RecentlyAddedSection(),
          SizedBox(height: AppSpacing.xl),
          ResponsiveCenter(child: WeatherSection()),
          SizedBox(height: AppSpacing.xl),
          RecentlyWornSection(),
        ],
      ),
    );
  }
}
