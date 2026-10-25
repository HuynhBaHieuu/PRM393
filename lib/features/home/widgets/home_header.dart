import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/app_logo.dart';
import 'package:all_fits/data/models/stylist_persona.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/outfit_flows.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/social/social_controller.dart';
import 'package:all_fits/features/social/widgets/social_widgets.dart';
import 'package:all_fits/features/stylist/screens/stylist_screen.dart';
import 'package:all_fits/features/stylist/stylist_store.dart';
import 'package:all_fits/features/stylist/widgets/stylist_widgets.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';

/// Our wordmark, "Upgrade" for Free users, and the bell and search buttons.
class HomeTopBar extends StatelessWidget {
  const HomeTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final premium = context.select<SettingsController, bool>(
      (s) => s.isPremium,
    );
    final social = context.watch<SocialController?>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          const Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppWordmark(height: 26),
            ),
          ),
          if (!premium)
            FilledButton.icon(
              onPressed: () => AppNavigator.premium(context),
              icon: const Icon(Icons.auto_awesome_outlined, size: 18),
              label: const Text('Upgrade'),
              style: FilledButton.styleFrom(
                backgroundColor: palette.surfaceMuted,
                foregroundColor: palette.ink,
                minimumSize: const Size(0, AppSizes.compactButtonHeight),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              ),
            ),
          if (social != null) ...[
            NotificationBell(
              count: social.notificationCount,
              onPressed: () => AppNavigator.notifications(context),
            ),
            IconButton(
              tooltip: 'Search people',
              onPressed: () => AppNavigator.userSearch(context),
              icon: const Icon(Icons.search_rounded),
            ),
          ],
        ],
      ),
    );
  }
}

/// Fits' round shortcuts: Community, "Your OOTD" (an outfit selfie) and the
/// people you follow.
class StoryRow extends StatelessWidget {
  const StoryRow({super.key});

  static const double _size = 72;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final social = context.watch<SocialController?>();
    final name = context.select<SettingsController, String>(
      (s) => s.displayName,
    );
    final following = social?.following ?? const [];
    return SizedBox(
      height: _size + 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page - 4),
        children: [
          if (social != null)
            _Story(
              label: 'Community',
              onTap: () => AppNavigator.discover(context),
              child: CircleAvatar(
                radius: _size / 2,
                backgroundColor: palette.surfaceMuted,
                foregroundColor: palette.ink,
                child: const Icon(Icons.groups_outlined, size: 32),
              ),
            ),
          _Story(
            label: 'Your OOTD',
            onTap: () => OutfitFlows.selfie(context),
            child: Stack(
              children: [
                UserAvatar(
                  name: name.isEmpty ? '?' : name,
                  url: social?.me?.avatarUrl,
                  size: _size,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: palette.ink,
                      shape: BoxShape.circle,
                      border: Border.all(color: palette.surface, width: 2),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: palette.onInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final connection in following)
            _Story(
              label: connection.profile.username,
              onTap: () =>
                  AppNavigator.userProfile(context, connection.profile.userId),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.ink, width: 2),
                ),
                child: UserAvatar(
                  name: connection.profile.name,
                  url: connection.profile.avatarUrl,
                  size: _size - 10,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Story extends StatelessWidget {
  const _Story({required this.label, required this.onTap, required this.child});

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: StoryRow._size + 16,
          child: Column(
            children: [
              SizedBox.square(
                dimension: StoryRow._size,
                child: Center(child: child),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fits' "Get started" checklist; gone once every step is done.
class GetStartedCard extends StatelessWidget {
  const GetStartedCard({super.key});

  static const int _piecesGoal = 5;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    final pieces = context.select<WardrobeController, int>(
      (w) => w.activeItems.length,
    );
    final hasOutfit = context.select<OutfitController, bool>(
      (o) => o.outfits.isNotEmpty,
    );
    final trained = context.select<StylistStore, bool>(
      (s) => s.notes.isNotEmpty || s.chats.isNotEmpty,
    );
    final steps = [
      _Step('Create your account', null, done: true),
      _Step(
        'Train your AI stylist',
        'Tell your stylist what you like',
        done: trained,
        onTap: () => AppNavigator.stylist(context),
      ),
      _Step(
        'Add $_piecesGoal pieces',
        'Snap the clothes you wear most',
        done: pieces >= _piecesGoal,
        onTap: () => AppNavigator.addClothing(context),
      ),
      _Step(
        'Save your first outfit',
        'Choose or create a look for today',
        done: hasOutfit,
        onTap: () => AppNavigator.createOutfit(context),
      ),
    ];
    final done = steps.where((s) => s.done).length;
    if (done == steps.length) return const SizedBox.shrink();
    final next = steps.indexWhere((s) => !s.done);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox.square(
                dimension: 64,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: done / steps.length,
                      strokeWidth: 5,
                      color: palette.ink,
                      backgroundColor: palette.border,
                    ),
                    Center(
                      child: Text(
                        '$done/${steps.length}',
                        style: text.titleSmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Flexible(child: Text('Get started', style: text.titleLarge)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < steps.length; i++)
            _StepRow(
              step: steps[i],
              expanded: i == next,
              last: i == steps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _Step {
  _Step(this.title, this.subtitle, {required this.done, this.onTap});

  final String title;
  final String? subtitle;
  final bool done;
  final VoidCallback? onTap;
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.expanded,
    required this.last,
  });

  final _Step step;
  final bool expanded;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    return InkWell(
      onTap: step.done ? null : step.onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: step.done
                        ? CircleAvatar(
                            radius: 13,
                            backgroundColor: palette.ink,
                            child: Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: palette.onInk,
                            ),
                          )
                        : Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: palette.textSecondary,
                                width: 1.5,
                              ),
                            ),
                          ),
                  ),
                  if (!last)
                    Expanded(
                      child: VerticalDivider(
                        width: 2,
                        thickness: 2,
                        color: palette.border,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: text.titleMedium?.copyWith(
                        color: step.done ? palette.textTertiary : palette.ink,
                      ),
                    ),
                    if (expanded && step.subtitle != null)
                      Text(
                        step.subtitle!,
                        style: text.bodyMedium?.copyWith(
                          color: palette.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (expanded) Icon(Icons.chevron_right_rounded, color: palette.ink),
          ],
        ),
      ),
    );
  }
}

/// "Find an outfit": a one-tap request to the AI stylist, with the Free
/// messages left today.
class FindOutfitBar extends StatelessWidget {
  const FindOutfitBar({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    final persona = context.select<StylistStore, StylistPersona>(
      (s) => s.persona,
    );
    final limit = context.select<SettingsController, int?>(
      (s) => s.plan.stylistMessagesPerDay,
    );
    final (used, bonus) = context.select<StylistStore, (int, int)>(
      (s) => (s.usedToday, s.bonusToday),
    );
    final left = limit == null ? null : math.max(0, limit + bonus - used);
    return Material(
      color: palette.surface,
      elevation: 2,
      shadowColor: Colors.black26,
      shape: StadiumBorder(side: BorderSide(color: palette.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => AppNavigator.stylist(
          context,
          launch: const StylistLaunch(prompt: StylistScreen.findOutfitPrompt),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              StylistAvatar(persona: persona, size: 40),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text('Find an outfit', style: text.titleMedium)),
              if (left != null)
                Text(
                  '${left}x free today',
                  style: text.bodyMedium?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              Icon(Icons.chevron_right_rounded, color: palette.ink),
            ],
          ),
        ),
      ),
    );
  }
}
