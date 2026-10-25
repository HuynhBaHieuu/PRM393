import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/features/home/screens/home_screen.dart';
import 'package:all_fits/navigation/closet_screen.dart';

enum AppTab { home, profile }

/// Tabs inside the Profile closet. Planner and Insights open from icons
/// above them, as in Fits.
enum ClosetTab {
  clothes('Clothes'),
  outfits('Outfits'),
  collections('Collections');

  const ClosetTab(this.label);

  final String label;
}

/// Selected bottom-navigation tab and closet tab, shared so any screen can
/// switch sections.
class ShellController extends ChangeNotifier {
  AppTab _tab = AppTab.home;
  ClosetTab _closetTab = ClosetTab.clothes;

  AppTab get tab => _tab;
  ClosetTab get closetTab => _closetTab;

  void select(AppTab tab) {
    if (tab == _tab) return;
    _tab = tab;
    notifyListeners();
  }

  /// Switches to the Profile tab and shows [tab] inside it.
  void openCloset(ClosetTab tab) {
    _tab = AppTab.profile;
    _closetTab = tab;
    notifyListeners();
  }

  /// Records a swipe between closet tabs without rebuilding listeners.
  void syncClosetTab(ClosetTab tab) => _closetTab = tab;
}

/// Root layout: Home and Profile behind a bottom bar with a central add button.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellController>();
    final tab = shell.tab;

    return PopScope(
      // Back from Profile returns home before leaving the app.
      canPop: tab == AppTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) shell.select(AppTab.home);
      },
      child: Scaffold(
        body: IndexedStack(
          index: tab.index,
          children: const [HomeScreen(), ClosetScreen()],
        ),
        bottomNavigationBar: AppBottomBar(
          tab: tab,
          onSelect: shell.select,
          onAdd: () => _showCreateSheet(context),
        ),
      ),
    );
  }
}

/// Home, a central "+" button and Profile.
class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    super.key,
    required this.tab,
    required this.onSelect,
    required this.onAdd,
  });

  final AppTab tab;
  final ValueChanged<AppTab> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: AppSizes.navBarHeight,
          child: Row(
            children: [
              _NavItem(
                label: 'Home',
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                selected: tab == AppTab.home,
                onTap: () => onSelect(AppTab.home),
              ),
              Expanded(
                child: Center(
                  child: IconButton.filled(
                    tooltip: 'Create',
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded, size: 28),
                    style: IconButton.styleFrom(
                      fixedSize: const Size.square(AppSizes.navAddButtonSize),
                      backgroundColor: palette.ink,
                      foregroundColor: palette.onInk,
                    ),
                  ),
                ),
              ),
              _NavItem(
                label: 'Profile',
                icon: Icons.person_outline_rounded,
                selectedIcon: Icons.person_rounded,
                selected: tab == AppTab.profile,
                onTap: () => onSelect(AppTab.profile),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = selected ? palette.ink : palette.textTertiary;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: InkResponse(
          onTap: onTap,
          radius: AppSizes.navBarHeight / 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? selectedIcon : icon, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: context.textTheme.labelMedium?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the central "+" button can create.
Future<void> _showCreateSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      void go(VoidCallback action) {
        Navigator.of(sheetContext).pop();
        action();
      }

      return SafeArea(
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
            children: [
              _SwipeOption(
                onTap: () => go(() => AppNavigator.swipeOutfit(context)),
              ),
              const SizedBox(height: AppSpacing.sm),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                mainAxisSpacing: AppSpacing.sm,
                crossAxisSpacing: AppSpacing.sm,
                childAspectRatio: 1.6,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _CreateOption(
                    icon: Icons.checkroom_outlined,
                    label: 'Add clothes',
                    onTap: () => go(() => AppNavigator.addClothing(context)),
                  ),
                  _CreateOption(
                    icon: Icons.style_outlined,
                    label: 'Create outfit',
                    onTap: () => go(() => AppNavigator.createOutfit(context)),
                  ),
                  _CreateOption(
                    icon: Icons.auto_awesome_outlined,
                    label: 'AI Stylist',
                    onTap: () => go(() => AppNavigator.stylist(context)),
                  ),
                  _CreateOption(
                    icon: Icons.calendar_today_outlined,
                    label: 'Plan outfit',
                    onTap: () => go(() => AppNavigator.planner(context)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// The headline option: build a look by swiping tops, bottoms and shoes.
class _SwipeOption extends StatelessWidget {
  const _SwipeOption({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    return Material(
      color: palette.ink,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(Icons.swipe_outlined, color: palette.onInk),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Swipe outfit',
                      style: text.titleMedium?.copyWith(color: palette.onInk),
                    ),
                    Text(
                      'Swipe tops, bottoms and shoes to find a look',
                      style: text.bodySmall?.copyWith(
                        color: palette.onInk.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: palette.onInk),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateOption extends StatelessWidget {
  const _CreateOption({
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
    return Material(
      color: palette.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: AppSizes.iconLg),
            const SizedBox(height: AppSpacing.xs),
            Text(label, style: context.textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}
