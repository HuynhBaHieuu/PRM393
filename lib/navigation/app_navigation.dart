import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/features/home/screens/home_screen.dart';
import 'package:all_fits/features/outfits/screens/outfits_screen.dart';
import 'package:all_fits/features/planner/screens/planner_screen.dart';
import 'package:all_fits/features/profile/screens/profile_screen.dart';
import 'package:all_fits/features/wardrobe/screens/wardrobe_screen.dart';

enum AppTab {
  home('Home', Icons.home_outlined, Icons.home_rounded),
  wardrobe('Wardrobe', Icons.checkroom_outlined, Icons.checkroom_rounded),
  outfits('Outfits', Icons.style_outlined, Icons.style_rounded),
  planner('Planner', Icons.calendar_today_outlined, Icons.calendar_today),
  profile('Profile', Icons.person_outline_rounded, Icons.person_rounded);

  const AppTab(this.label, this.icon, this.selectedIcon);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// Selected bottom-navigation tab, shared so any screen can switch tabs.
class ShellController extends ChangeNotifier {
  AppTab _tab = AppTab.home;

  AppTab get tab => _tab;

  void select(AppTab tab) {
    if (tab == _tab) return;
    _tab = tab;
    notifyListeners();
  }
}

/// Root layout: the five main sections behind a bottom navigation bar.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellController>();
    final tab = shell.tab;

    return PopScope(
      // Back from another tab returns home before leaving the app.
      canPop: tab == AppTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) shell.select(AppTab.home);
      },
      child: Scaffold(
        body: IndexedStack(
          index: tab.index,
          children: const [
            HomeScreen(),
            WardrobeScreen(),
            OutfitsScreen(),
            PlannerScreen(),
            ProfileScreen(),
          ],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: context.palette.border)),
          ),
          child: NavigationBar(
            selectedIndex: tab.index,
            onDestinationSelected: (index) =>
                shell.select(AppTab.values[index]),
            destinations: [
              for (final tab in AppTab.values)
                NavigationDestination(
                  icon: Icon(tab.icon),
                  selectedIcon: Icon(tab.selectedIcon),
                  label: tab.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
