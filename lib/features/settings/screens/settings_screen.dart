import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/validators.dart';
import 'package:all_fits/core/widgets/app_dialogs.dart';
import 'package:all_fits/core/widgets/layout.dart';
import 'package:all_fits/core/widgets/option_sheets.dart';
import 'package:all_fits/data/local/reminder_service.dart';
import 'package:all_fits/data/models/app_settings.dart';
import 'package:all_fits/data/models/user_account.dart';
import 'package:all_fits/features/auth/auth_flows.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/settings/widgets/settings_section.dart';
import 'package:all_fits/features/shared/closet_actions.dart';
import 'package:all_fits/features/shared/closet_flows.dart';
import 'package:all_fits/features/social/social_controller.dart';
import 'package:all_fits/features/try_on/try_on_controller.dart';
import 'package:all_fits/features/try_on/try_on_flows.dart';
import 'package:all_fits/features/wardrobe/controllers/auto_detect_controller.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';

/// Fits' one-page settings: Rate / Share, then Your wardrobe, Community
/// and the app's own settings, each a list of rows.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const int _maxCurrencyLength = 4;

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

  Future<void> _rate(BuildContext context) async {
    final stars = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Enjoying ${AppConfig.appName}?'),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                tooltip: '$i stars',
                onPressed: () => Navigator.of(dialogContext).pop(i),
                icon: const Icon(Icons.star_border_rounded, size: 32),
              ),
          ],
        ),
      ),
    );
    if (stars != null && context.mounted) {
      context.showSnack('Thanks for rating ${AppConfig.appName}!');
    }
  }

  Future<void> _shareApp(BuildContext context) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'I plan my outfits with ${AppConfig.appName}. Give it a try!',
        ),
      );
    } catch (error) {
      if (context.mounted) context.showErrorSnack(error);
    }
  }

  Future<void> _email(BuildContext context, String subject) async {
    final url = Uri(
      scheme: 'mailto',
      query: 'subject=${Uri.encodeComponent(subject)}',
    );
    if (!await launchUrl(url) && context.mounted) {
      context.showSnack('No email app found.');
    }
  }

  Future<void> _resync(BuildContext context) async {
    final closet = context.read<ClosetActions>();
    await ClosetFlows.guard(
      context,
      closet.reloadAll,
      successMessage: 'Wardrobe re-synced',
    );
  }

  Future<void> _toggleSampleData(BuildContext context) async {
    final closet = context.read<ClosetActions>();
    if (!closet.hasSampleData) {
      await ClosetFlows.guard(
        context,
        closet.loadSampleData,
        successMessage: 'Sample wardrobe added',
      );
      return;
    }
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
      closet.removeSampleData,
      successMessage: 'Sample data removed',
    );
  }

  Future<void> _showAccount(BuildContext context) {
    final email = context.read<AppUser>().email;
    final settings = context.read<SettingsController>();
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        void go(Future<void> Function() action) {
          Navigator.of(sheetContext).pop();
          action();
        }

        final palette = sheetContext.palette;
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  'Account',
                  textAlign: TextAlign.center,
                  style: sheetContext.textTheme.titleLarge,
                ),
              ),
              Divider(height: 1, color: palette.border),
              Container(
                margin: const EdgeInsets.all(AppSpacing.page),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mail_outline_rounded),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(email, style: sheetContext.textTheme.bodyLarge),
                          Text(
                            settings.displayName.isEmpty
                                ? 'You’re signed in.'
                                : 'Signed in as ${settings.displayName}.',
                            style: sheetContext.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SheetActionTile(
                icon: Icons.badge_outlined,
                label: 'Change name',
                onTap: () => go(() => _editName(context)),
              ),
              SheetActionTile(
                icon: Icons.logout_rounded,
                label: 'Log out',
                onTap: () => go(() => AuthFlows.signOut(context)),
              ),
              SheetActionTile(
                icon: Icons.delete_outline_rounded,
                label: 'Delete all my data',
                onTap: () => go(() => _eraseAll(context)),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editName(BuildContext context) async {
    final settings = context.read<SettingsController>();
    final value = await showTextInputDialog(
      context,
      title: 'Your name',
      initialValue: settings.displayName,
      hint: 'e.g. Alex Morgan',
      maxLength: Validators.maxNameLength,
    );
    if (value == null || !context.mounted) return;
    await ClosetFlows.guard(
      context,
      () => settings.updateProfile(displayName: value),
    );
  }

  Future<void> _eraseAll(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete all your data?',
      message:
          'Every clothing item, photo, outfit and plan will be permanently '
          'deleted. This can’t be undone.',
      confirmLabel: 'Delete everything',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final closet = context.read<ClosetActions>();
    await ClosetFlows.guard(
      context,
      closet.eraseAllData,
      successMessage: 'All data deleted',
    );
  }

  /// A sheet of radio-style choices, as Fits uses for "App starts in".
  Future<T?> _choose<T>(
    BuildContext context, {
    required List<(T value, IconData icon, String label, String? hint)> options,
    required T current,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (value, icon, label, hint) in options)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                  vertical: AppSpacing.xxs,
                ),
                leading: Icon(icon),
                title: Text(label, style: sheetContext.textTheme.titleMedium),
                subtitle: hint == null ? null : Text(hint),
                trailing: RoundCheck(checked: value == current),
                onTap: () => Navigator.of(sheetContext).pop(value),
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStart(BuildContext context, SettingsController s) async {
    final profile = await _choose<bool>(
      context,
      current: s.startsInProfile,
      options: const [
        (
          false,
          Icons.home_outlined,
          'Home',
          'Open the app on the home tab by default',
        ),
        (
          true,
          Icons.person_outline_rounded,
          'Profile',
          'Open the app on the profile tab by default',
        ),
      ],
    );
    if (profile == null || !context.mounted) return;
    await ClosetFlows.guard(context, () => s.setStartsInProfile(profile));
  }

  Future<void> _pickDisplay(BuildContext context, SettingsController s) async {
    final theme = await _choose<ThemePreference>(
      context,
      current: s.settings.themePreference,
      options: [
        for (final pref in ThemePreference.values)
          (
            pref,
            switch (pref) {
              ThemePreference.light => Icons.light_mode_outlined,
              ThemePreference.dark => Icons.dark_mode_outlined,
              ThemePreference.system => Icons.brightness_auto_outlined,
            },
            pref.label,
            null,
          ),
      ],
    );
    if (theme == null || !context.mounted) return;
    await ClosetFlows.guard(context, () => s.setThemePreference(theme));
  }

  Future<void> _pickLanguage(BuildContext context) async {
    await _choose<String>(
      context,
      current: 'en',
      options: const [
        ('en', Icons.language_rounded, 'English', 'All Fits is in English'),
      ],
    );
  }

  Future<void> _showCredits(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.page),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('AI credits', style: sheetContext.textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Each AI try-on picture costs 1 credit. Premium adds '
                'credits every month; the AI stylist chat and AI detection '
                'have their own daily and monthly allowances.',
                style: sheetContext.textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  AppNavigator.premium(context);
                },
                child: const Text('Get more with Premium'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showGuidelines(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Community guidelines'),
        content: const Text(
          'Be kind. Share your own outfits and photos only. No nudity, '
          'hate or harassment. Don’t spam people with outfits they didn’t '
          'ask for. Report or block anyone who breaks these rules.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final wardrobe = context.watch<WardrobeController>();
    final closet = context.read<ClosetActions>();
    final social = context.watch<SocialController?>();
    final detector = context.watch<AutoDetectController>();
    final tryOn = context.select<TryOnController, bool>((t) => t.isAvailable);
    final archived = wardrobe.archivedItems.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxl),
        children: [
          ResponsiveCenter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.md,
                    AppSpacing.page,
                    0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TopTile(
                          icon: Icons.star_border_rounded,
                          label: 'Rate the app',
                          onTap: () => _rate(context),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _TopTile(
                          icon: Icons.ios_share_rounded,
                          label: 'Share the app',
                          onTap: () => _shareApp(context),
                        ),
                      ),
                    ],
                  ),
                ),
                SettingsSection(
                  title: 'Your wardrobe',
                  children: [
                    SettingsRow(
                      icon: Icons.pie_chart_outline_rounded,
                      label: 'Insights',
                      onTap: () => AppNavigator.insights(context),
                    ),
                    SettingsRow(
                      icon: Icons.favorite_border_rounded,
                      label: 'Favorites',
                      onTap: () => AppNavigator.favorites(context),
                    ),
                    SettingsRow(
                      icon: Icons.inventory_2_outlined,
                      label: 'Archive',
                      value: archived == 0 ? null : '$archived',
                      onTap: () => AppNavigator.archived(context),
                    ),
                    SettingsRow(
                      icon: Icons.paid_outlined,
                      label: 'Currency',
                      value: settings.currencySymbol,
                      onTap: () => _editCurrency(context, settings),
                    ),
                    SettingsRow(
                      icon: Icons.cloud_sync_outlined,
                      label: 'Re-sync wardrobe',
                      onTap: () => _resync(context),
                    ),
                    SettingsRow(
                      icon: closet.hasSampleData
                          ? Icons.layers_clear_outlined
                          : Icons.auto_awesome_motion_outlined,
                      label: closet.hasSampleData
                          ? 'Remove sample data'
                          : 'Load sample wardrobe',
                      onTap: () => _toggleSampleData(context),
                    ),
                  ],
                ),
                if (social != null)
                  SettingsSection(
                    title: 'Community',
                    children: [
                      SettingsRow(
                        icon: Icons.lock_outline_rounded,
                        label: 'Account privacy',
                        value: social.me == null
                            ? null
                            : social.me!.isPrivate
                            ? 'Private'
                            : 'Public',
                        onTap: () => AppNavigator.editProfile(context),
                      ),
                      SettingsRow(
                        icon: Icons.people_outline_rounded,
                        label: 'Styled together',
                        value: social.unansweredStyledCount == 0
                            ? null
                            : '${social.unansweredStyledCount} new',
                        onTap: () => AppNavigator.styledTogether(context),
                      ),
                      SettingsRow(
                        icon: Icons.lightbulb_outline_rounded,
                        label: 'Feature requests',
                        onTap: () => _email(
                          context,
                          '${AppConfig.appName} feature request',
                        ),
                      ),
                      SettingsRow(
                        icon: Icons.block_rounded,
                        label: 'Blocked users',
                        onTap: () => AppNavigator.blockedUsers(context),
                      ),
                      SettingsRow(
                        icon: Icons.volunteer_activism_outlined,
                        label: 'Guidelines',
                        onTap: () => _showGuidelines(context),
                      ),
                    ],
                  ),
                SettingsSection(
                  title: AppConfig.appName,
                  children: [
                    SettingsRow(
                      icon: Icons.star_border_rounded,
                      label: settings.isPremium
                          ? 'All Fits Premium'
                          : 'Upgrade to Premium',
                      value: settings.plan.label,
                      onTap: () => AppNavigator.premium(context),
                    ),
                    SettingsRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Account',
                      onTap: () => _showAccount(context),
                    ),
                    SettingsRow(
                      icon: Icons.language_rounded,
                      label: 'Language',
                      value: 'English',
                      onTap: () => _pickLanguage(context),
                    ),
                    SettingsRow(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Contact us',
                      onTap: () =>
                          _email(context, '${AppConfig.appName} feedback'),
                    ),
                    if (tryOn) ...[
                      SettingsRow(
                        icon: Icons.toll_outlined,
                        label: 'AI credits',
                        value: TryOnFlows.creditsLabel(context),
                        onTap: () => _showCredits(context),
                      ),
                      SettingsRow(
                        icon: Icons.accessibility_new_rounded,
                        label: 'Try on profile',
                        onTap: () => AppNavigator.tryOnProfile(context),
                      ),
                    ],
                    if (detector.isAvailable)
                      SettingsSwitchRow(
                        icon: Icons.auto_awesome_outlined,
                        label: 'AI detection',
                        subtitle: switch (detector.left(settings.plan)) {
                          null => 'Fill in new clothes from their photo',
                          final left =>
                            '$left of ${AppConfig.freeDetectionsPerMonth} '
                                'free detections left this month',
                        },
                        // Turning it on here counts as agreeing to send
                        // photos to the AI service.
                        value: detector.enabled && detector.consented,
                        onChanged: (on) => ClosetFlows.guard(
                          context,
                          () => on
                              ? detector.consent()
                              : detector.setEnabled(false),
                        ),
                      ),
                    SettingsRow(
                      icon: Icons.smartphone_rounded,
                      label: 'App starts in',
                      value: settings.startsInProfile ? 'Profile' : 'Home',
                      onTap: () => _pickStart(context, settings),
                    ),
                    SettingsRow(
                      icon: Icons.dark_mode_outlined,
                      label: 'Display',
                      value: settings.settings.themePreference.label,
                      onTap: () => _pickDisplay(context, settings),
                    ),
                    SettingsRow(
                      icon: Icons.alarm_rounded,
                      label: 'Daily reminders',
                      value: settings.dailyReminder ? 'On' : 'Off',
                      onTap: () => AppNavigator.dailyReminders(context),
                    ),
                    SettingsRow(
                      icon: Icons.info_outline_rounded,
                      label: 'Licenses & photo credits',
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

class _TopTile extends StatelessWidget {
  const _TopTile({
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Column(
            children: [
              Icon(icon, size: AppSizes.iconLg),
              const SizedBox(height: AppSpacing.sm),
              Text(label, style: context.textTheme.titleSmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fits' "Daily reminders" page: one switch.
class DailyRemindersScreen extends StatefulWidget {
  const DailyRemindersScreen({super.key});

  @override
  State<DailyRemindersScreen> createState() => _DailyRemindersScreenState();
}

class _DailyRemindersScreenState extends State<DailyRemindersScreen> {
  bool _busy = false;

  Future<void> _toggle(bool on) async {
    final settings = context.read<SettingsController>();
    final reminders = context.read<ReminderService>();
    setState(() => _busy = true);
    try {
      if (on) {
        final allowed = await reminders.enableDaily();
        if (!allowed) {
          if (mounted) {
            context.showSnack(
              'Allow notifications for ${AppConfig.appName} to get reminders.',
            );
          }
          return;
        }
      } else {
        await reminders.disableDaily();
      }
      await settings.setDailyReminder(on);
    } catch (error) {
      if (mounted) context.showErrorSnack(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final on = context.select<SettingsController, bool>((s) => s.dailyReminder);
    return Scaffold(
      appBar: AppBar(title: const Text('Daily reminders')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.page),
        children: [
          Material(
            color: palette.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              title: Text(
                'Daily reminder',
                style: context.textTheme.titleMedium,
              ),
              value: on,
              onChanged: _busy ? null : _toggle,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Text(
              'Get a reminder to log your outfit of the day.',
              style: context.textTheme.bodyMedium?.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
