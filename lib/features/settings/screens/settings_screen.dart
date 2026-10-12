import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/validators.dart';
import 'package:all_fits/core/widgets/app_dialogs.dart';
import 'package:all_fits/core/widgets/layout.dart';
import 'package:all_fits/data/models/app_settings.dart';
import 'package:all_fits/data/models/user_account.dart';
import 'package:all_fits/features/auth/auth_flows.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/settings/widgets/settings_section.dart';
import 'package:all_fits/features/shared/closet_actions.dart';
import 'package:all_fits/features/shared/closet_flows.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const int _maxCurrencyLength = 4;

  Future<void> _editName(BuildContext context, SettingsController s) async {
    final value = await showTextInputDialog(
      context,
      title: 'Your name',
      initialValue: s.displayName,
      hint: 'e.g. Alex Morgan',
      maxLength: Validators.maxNameLength,
    );
    if (value == null || !context.mounted) return;
    await ClosetFlows.guard(context, () => s.updateProfile(displayName: value));
  }

  Future<void> _editUsername(BuildContext context, SettingsController s) async {
    final value = await showTextInputDialog(
      context,
      title: 'Username',
      initialValue: s.username,
      prefixText: '@',
      maxLength: Validators.maxNameLength,
    );
    if (value == null || !context.mounted) return;
    await ClosetFlows.guard(context, () => s.updateProfile(username: value));
  }

  Future<void> _editCurrency(BuildContext context, SettingsController s) async {
    final value = await showTextInputDialog(
      context,
      title: 'Currency symbol',
      initialValue: s.currencySymbol,
      hint: '\$, €, £, ₫…',
      maxLength: _maxCurrencyLength,
    );
    if (value == null || !context.mounted) return;
    await ClosetFlows.guard(context, () => s.setCurrencySymbol(value));
  }

  Future<void> _removeSampleData(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove sample data?',
      message:
          'The demo clothes and outfits will be deleted. '
          'Anything you added yourself is kept.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await ClosetFlows.guard(
      context,
      context.read<ClosetActions>().removeSampleData,
      successMessage: 'Sample data removed',
    );
  }

  Future<void> _eraseAll(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Erase all data?',
      message:
          'Every clothing item, photo, outfit and plan will be permanently '
          'deleted. This can’t be undone.',
      confirmLabel: 'Erase everything',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    await ClosetFlows.guard(
      context,
      context.read<ClosetActions>().eraseAllData,
      successMessage: 'All data erased',
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    // Rebuild when items change so the sample-data actions stay accurate.
    context.watch<WardrobeController>();
    final closet = context.read<ClosetActions>();
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          ResponsiveCenter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsSection(
                  title: 'Profile',
                  children: [
                    ListTile(
                      title: const Text('Name'),
                      subtitle: Text(
                        settings.displayName.isEmpty
                            ? 'Not set'
                            : settings.displayName,
                      ),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _editName(context, settings),
                    ),
                    ListTile(
                      title: const Text('Username'),
                      subtitle: Text(
                        settings.username.isEmpty
                            ? 'Not set'
                            : '@${settings.username}',
                      ),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () => _editUsername(context, settings),
                    ),
                  ],
                ),
                SettingsSection(
                  title: 'Account',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.mail_outline_rounded),
                      title: const Text('Email'),
                      subtitle: Text(context.read<AppUser>().email),
                    ),
                    ListTile(
                      leading: const Icon(Icons.logout_rounded),
                      title: const Text('Log out'),
                      onTap: () => AuthFlows.signOut(context),
                    ),
                  ],
                ),
                SettingsSection(
                  title: 'Appearance',
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.page,
                        vertical: AppSpacing.xs,
                      ),
                      child: SegmentedButton<ThemePreference>(
                        showSelectedIcon: false,
                        segments: [
                          for (final pref in ThemePreference.values)
                            ButtonSegment(value: pref, label: Text(pref.label)),
                        ],
                        selected: {settings.settings.themePreference},
                        onSelectionChanged: (selection) => ClosetFlows.guard(
                          context,
                          () => settings.setThemePreference(selection.first),
                        ),
                      ),
                    ),
                    ListTile(
                      title: const Text('Currency symbol'),
                      subtitle: const Text('Used for prices and value'),
                      trailing: Text(
                        settings.currencySymbol,
                        style: context.textTheme.titleMedium,
                      ),
                      onTap: () => _editCurrency(context, settings),
                    ),
                  ],
                ),
                SettingsSection(
                  title: 'Data',
                  footer:
                      'Your data is stored on this device and belongs to '
                      'this account only. Photos are kept in the app’s '
                      'private storage.',
                  children: [
                    if (closet.hasSampleData)
                      ListTile(
                        leading: const Icon(Icons.layers_clear_outlined),
                        title: const Text('Remove sample data'),
                        subtitle: const Text('Delete the demo wardrobe'),
                        onTap: () => _removeSampleData(context),
                      )
                    else
                      ListTile(
                        leading: const Icon(Icons.auto_awesome_outlined),
                        title: const Text('Load sample wardrobe'),
                        subtitle: const Text('Add demo clothes and outfits'),
                        onTap: () => ClosetFlows.guard(
                          context,
                          closet.loadSampleData,
                          successMessage: 'Sample wardrobe added',
                        ),
                      ),
                    ListTile(
                      leading: Icon(
                        Icons.delete_forever_outlined,
                        color: palette.danger,
                      ),
                      title: Text(
                        'Erase all data',
                        style: TextStyle(color: palette.danger),
                      ),
                      onTap: () => _eraseAll(context),
                    ),
                  ],
                ),
                SettingsSection(
                  title: 'About',
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline_rounded),
                      title: const Text('Licenses & photo credits'),
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: AppConfig.appName,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  '${AppConfig.appName} · Version 1.0',
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
