import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/data/models/stylist_persona.dart';
import 'package:all_fits/features/home/screens/home_screen.dart';
import 'package:all_fits/features/stylist/stylist_store.dart';
import 'package:all_fits/features/stylist/widgets/stylist_widgets.dart';
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

/// What the central "+" button can create: Fits' three rows.
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
              _CreateRow(
                leading: const Icon(Icons.checkroom_outlined, size: 30),
                label: 'Add clothes',
                onTap: () => go(() => _showAddClothesSheet(context)),
              ),
              const SizedBox(height: AppSpacing.sm),
              _CreateRow(
                leading: const Icon(Icons.dry_cleaning_outlined, size: 30),
                label: 'Create outfit',
                onTap: () => go(() => AppNavigator.createOutfit(context)),
              ),
              const SizedBox(height: AppSpacing.sm),
              _CreateRow(
                leading: Builder(
                  builder: (context) => StylistAvatar(
                    persona: context.select<StylistStore, StylistPersona>(
                      (s) => s.persona,
                    ),
                  ),
                ),
                label: 'Chat with AI stylist',
                onTap: () => go(() => AppNavigator.stylist(context)),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// "Add clothes": from a photo, or from a shop's product link.
Future<void> _showAddClothesSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      void go({required bool fromLink}) {
        Navigator.of(sheetContext).pop();
        AppNavigator.addClothing(context, fromLink: fromLink);
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
              _CreateRow(
                leading: const Icon(Icons.photo_camera_outlined, size: 30),
                label: 'From a photo',
                onTap: () => go(fromLink: false),
              ),
              const SizedBox(height: AppSpacing.sm),
              _CreateRow(
                leading: const Icon(Icons.link_rounded, size: 30),
                label: 'From a web link',
                onTap: () => go(fromLink: true),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// A large grey row with a leading icon and a chevron.
class _CreateRow extends StatelessWidget {
  const _CreateRow({
    required this.leading,
    required this.label,
    required this.onTap,
  });

  final Widget leading;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surfaceMuted,
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: Row(
            children: [
              SizedBox(width: 36, child: Center(child: leading)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(label, style: context.textTheme.titleMedium),
              ),
              Icon(Icons.chevron_right_rounded, color: palette.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
