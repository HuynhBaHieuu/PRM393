import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/extensions/model_presentation.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/utils/load_status.dart';
import 'package:all_fits/core/widgets/app_dialogs.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/outfit_create_mode.dart';
import 'package:all_fits/data/models/try_on.dart';
import 'package:all_fits/data/models/weather.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/outfit_flows.dart';
import 'package:all_fits/features/outfits/outfit_ideas.dart';
import 'package:all_fits/features/outfits/widgets/outfit_cards.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/shared/closet_actions.dart';
import 'package:all_fits/features/stylist/screens/stylist_screen.dart';
import 'package:all_fits/features/try_on/try_on_controller.dart';
import 'package:all_fits/features/try_on/try_on_flows.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/features/weather/controllers/weather_controller.dart';
import 'package:all_fits/navigation/app_navigation.dart';

const EdgeInsets _pagePadding = EdgeInsets.symmetric(
  horizontal: AppSpacing.page,
);

/// Fits' section title: large and bold, with a "›" when it leads somewhere.
class HomeSectionTitle extends StatelessWidget {
  const HomeSectionTitle({
    super.key,
    required this.title,
    this.onTap,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xl,
        AppSpacing.page,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: onTap,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: text.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (onTap != null)
                          Icon(
                            Icons.chevron_right_rounded,
                            size: AppSizes.iconLg,
                            color: context.palette.textTertiary,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: text.bodyMedium?.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

/// Planner, Dressing Room, AI Try On and Selfie.
class QuickTiles extends StatelessWidget {
  const QuickTiles({super.key});

  @override
  Widget build(BuildContext context) {
    final tryOn = context.select<TryOnController, bool>((t) => t.isAvailable);
    final tiles = [
      _Tile(
        icon: Icons.calendar_today_outlined,
        label: 'Planner',
        onTap: () => AppNavigator.planner(context),
      ),
      _Tile(
        icon: Icons.swipe_outlined,
        label: OutfitCreateMode.dressingRoom.label,
        onTap: () => AppNavigator.swipeOutfit(context),
      ),
      if (tryOn)
        _Tile(
          icon: Icons.auto_awesome_outlined,
          label: OutfitCreateMode.tryOn.label,
          onTap: () => TryOnFlows.start(context),
        ),
      _Tile(
        icon: Icons.accessibility_new_rounded,
        label: 'Selfie',
        onTap: () => OutfitFlows.selfie(context),
      ),
    ];
    return Padding(
      padding: _pagePadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Icon(icon, size: AppSizes.iconLg),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            ExcludeSemantics(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: context.textTheme.labelLarge,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks for a city, looks it up and saves it.
Future<void> chooseWeatherCity(BuildContext context) async {
  final settings = context.read<SettingsController>();
  final weather = context.read<WeatherController>();
  final name = await showTextInputDialog(
    context,
    title: 'Your city',
    initialValue: settings.weatherLocation?.name ?? '',
    hint: 'e.g. Ho Chi Minh City',
    maxLength: 60,
    confirmLabel: 'Find',
  );
  if (name == null || name.isEmpty || !context.mounted) return;
  try {
    final location = await weather.findCity(name);
    if (!context.mounted) return;
    if (location == null) {
      context.showSnack('We couldn’t find “$name”. Try another spelling.');
      return;
    }
    await settings.setWeatherLocation(location);
    await weather.refresh(location);
  } catch (error) {
    if (context.mounted) context.showErrorSnack(error);
  }
}

/// Fits' "For today": looks made from the wardrobe for today's weather,
/// found from the device's city without asking.
class ForTodaySection extends StatefulWidget {
  const ForTodaySection({super.key});

  @override
  State<ForTodaySection> createState() => _ForTodaySectionState();
}

class _ForTodaySectionState extends State<ForTodaySection> {
  @override
  void initState() {
    super.initState();
    _locate();
  }

  /// Without a saved city, uses the one the internet address points to.
  Future<void> _locate() async {
    final settings = context.read<SettingsController>();
    if (settings.weatherLocation != null) return;
    final location = await context.read<WeatherController>().locateOnce();
    if (location != null && mounted && settings.weatherLocation == null) {
      await settings.setWeatherLocation(location);
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = context.select<SettingsController, WeatherLocation?>(
      (s) => s.weatherLocation,
    );
    final weather = context.watch<WeatherController>();
    if (location != null && weather.needsRefresh(location)) {
      // Load after this frame; refresh() notifies listeners.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => weather.refresh(location),
      );
    }
    final report = weather.report;
    final ready =
        location != null &&
        report?.location == location &&
        weather.status == LoadStatus.ready;
    final wardrobe = context.watch<WardrobeController>();
    final ideas = OutfitIdeas.generate(
      wardrobe.activeItems,
      day: context.read<ClosetActions>().today,
      weather: ready ? report : null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionTitle(
          title: 'For today',
          onTap: ideas.isEmpty ? null : () => _openSuggestions(context),
          trailing: _WeatherChip(
            report: ready ? report : null,
            label: location?.name,
            onTap: () => chooseWeatherCity(context),
          ),
        ),
        if (ideas.isEmpty)
          _InlineEmpty(
            message: 'Add tops, bottoms and shoes to get new ideas every day.',
            actionLabel: 'Add clothes',
            onAction: () => AppNavigator.addClothing(context),
          )
        else
          IdeaStrip(ideas: ideas),
      ],
    );
  }

  Future<void> _openSuggestions(BuildContext context) async {
    final ids = await OutfitFlows.pickSuggestion(context);
    if (ids != null && context.mounted) {
      await AppNavigator.composeOutfit(context, itemIds: ids);
    }
  }
}

class _WeatherChip extends StatelessWidget {
  const _WeatherChip({required this.onTap, this.report, this.label});

  final WeatherReport? report;
  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final report = this.report;
    return Semantics(
      button: true,
      label: label == null ? 'Set your city' : 'Weather in $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxs),
          child: report == null
              ? Text(
                  label == null ? 'Set city' : '…',
                  style: context.textTheme.titleMedium?.copyWith(
                    color: palette.textSecondary,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(report.condition.icon, color: palette.ink),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${report.high.round()}° / ${report.low.round()}°',
                      style: context.textTheme.titleMedium?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// A row of idea cards; tapping one opens it in the collage builder.
class IdeaStrip extends StatelessWidget {
  const IdeaStrip({super.key, required this.ideas});

  final List<OutfitIdea> ideas;

  static const double _width = 190;
  static const double _height = 300;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: _pagePadding,
        itemCount: ideas.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) => SizedBox(
          width: _width,
          child: IdeaCard(
            idea: ideas[index],
            onTap: () => AppNavigator.composeOutfit(
              context,
              itemIds: ideas[index].itemIds,
            ),
          ),
        ),
      ),
    );
  }
}

/// "Rate my outfit" and "Find my colors", each sending a photo to the
/// AI stylist.
class AiStylistSection extends StatelessWidget {
  const AiStylistSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionTitle(
          title: 'AI Stylist',
          onTap: () => AppNavigator.stylist(context),
        ),
        Padding(
          padding: _pagePadding,
          child: Row(
            children: [
              Expanded(
                child: _StylistCard(
                  icon: Icons.thumbs_up_down_outlined,
                  label: 'Rate my outfit',
                  onTap: () => AppNavigator.stylist(
                    context,
                    launch: const StylistLaunch(
                      prompt: StylistScreen.ratePrompt,
                      withPhoto: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StylistCard(
                  icon: Icons.palette_outlined,
                  label: 'Find my colors',
                  onTap: () => AppNavigator.stylist(
                    context,
                    launch: const StylistLaunch(
                      prompt: StylistScreen.colorsPrompt,
                      withPhoto: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StylistCard extends StatelessWidget {
  const _StylistCard({
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
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1.4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: palette.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Icon(icon, size: AppSizes.iconXl + 12),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(label, style: context.textTheme.titleSmall),
        ],
      ),
    );
  }
}

/// The newest outfits, or an invitation to make the first.
class RecentOutfitsSection extends StatelessWidget {
  const RecentOutfitsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final outfits = context
        .watch<OutfitController>()
        .outfits
        .take(AppConfig.recentOutfitsLimit)
        .toList();
    final palette = context.palette;
    final shell = context.read<ShellController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionTitle(
          title: 'Recent outfits',
          onTap: () => shell.openCloset(ClosetTab.outfits),
        ),
        if (outfits.isEmpty)
          Padding(
            padding: _pagePadding,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: palette.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.xl),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.style_outlined,
                    size: AppSizes.iconXl + 12,
                    color: palette.textSecondary,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Your outfits will appear here.',
                    style: context.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: () => AppNavigator.createOutfit(context),
                    child: const Text('Create outfit'),
                  ),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height:
                AppSizes.recentOutfitWidth / AppSizes.outfitImageAspect +
                MediaQuery.textScalerOf(context)
                    .scale(AppSizes.outfitTileFooterHeight),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: _pagePadding,
              itemCount: outfits.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) => SizedBox(
                width: AppSizes.recentOutfitWidth,
                child: OutfitCard(
                  outfit: outfits[index],
                  onTap: () =>
                      AppNavigator.outfitDetail(context, outfits[index].id),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// A row of cut-outs, each with an optional caption ("2 days ago").
class ItemStrip extends StatelessWidget {
  const ItemStrip({super.key, required this.items, this.captionOf});

  final List<ClothingItem> items;
  final String Function(ClothingItem item)? captionOf;

  static const double _size = 124;

  @override
  Widget build(BuildContext context) {
    final ids = [for (final item in items) item.id];
    final caption = captionOf;
    return SizedBox(
      height: _size + (caption == null ? 0 : 28),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: _pagePadding,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) {
          final item = items[index];
          return Semantics(
            button: true,
            label: item.name,
            child: GestureDetector(
              onTap: () =>
                  AppNavigator.clothingDetail(context, item.id, siblings: ids),
              child: SizedBox(
                width: _size,
                child: Column(
                  children: [
                    SizedBox.square(
                      dimension: _size,
                      child: ClothingImage(
                        item: item,
                        cutout: true,
                        fit: BoxFit.contain,
                        decodeWidth: _size,
                      ),
                    ),
                    if (caption != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        caption(item),
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: context.palette.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// "Recently added items" with how long ago each was added.
class RecentlyAddedSection extends StatelessWidget {
  const RecentlyAddedSection({super.key});

  @override
  Widget build(BuildContext context) {
    final items = context.watch<WardrobeController>().recentlyAdded(
      AppConfig.recentItemsLimit,
    );
    final shell = context.read<ShellController>();
    final today = context.read<ClosetActions>().today;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionTitle(
          title: 'Recently added items',
          onTap: () => shell.openCloset(ClosetTab.clothes),
        ),
        if (items.isEmpty)
          _InlineEmpty(
            message: 'Your wardrobe is empty. Add your first piece.',
            actionLabel: 'Add clothes',
            onAction: () => AppNavigator.addClothing(context),
          )
        else
          ItemStrip(
            items: items,
            captionOf: (item) =>
                AppFormatters.relativeDay(item.createdAt, now: today),
          ),
      ],
    );
  }
}

/// Pieces never marked as worn; hidden when there are none.
class NotYetWornSection extends StatelessWidget {
  const NotYetWornSection({super.key});

  @override
  Widget build(BuildContext context) {
    final items = context
        .watch<WardrobeController>()
        .activeItems
        .where((item) => item.wearCount == 0)
        .take(AppConfig.recentItemsLimit)
        .toList();
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionTitle(
          title: 'Not yet worn',
          onTap: () => AppNavigator.createOutfit(
            context,
            initialItemIds: [items.first.id],
          ),
        ),
        ItemStrip(items: items),
      ],
    );
  }
}

/// One look built around each of the newest pieces.
class NewestIdeasSection extends StatelessWidget {
  const NewestIdeasSection({super.key});

  static const int _pieces = 3;

  @override
  Widget build(BuildContext context) {
    final wardrobe = context.watch<WardrobeController>();
    final weather = context.select<WeatherController, WeatherReport?>(
      (w) => w.status == LoadStatus.ready ? w.report : null,
    );
    final today = context.read<ClosetActions>().today;
    final ideas = [
      for (final piece in wardrobe.activeItems.take(_pieces))
        ...OutfitIdeas.generate(
          wardrobe.activeItems,
          day: today,
          weather: weather,
          anchor: piece,
          count: 1,
        ),
    ];
    if (ideas.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionTitle(
          title: 'Ideas for your newest pieces',
          onTap: () => AppNavigator.createOutfit(
            context,
            initialItemIds: [wardrobe.activeItems.first.id],
          ),
        ),
        IdeaStrip(ideas: ideas),
      ],
    );
  }
}

/// The try-on scenes as photo cards; each opens AI try-on.
class TryOnBackgroundsSection extends StatelessWidget {
  const TryOnBackgroundsSection({super.key});

  static const double _width = 170;
  static const double _height = 240;

  @override
  Widget build(BuildContext context) {
    final available = context.select<TryOnController, bool>(
      (t) => t.isAvailable,
    );
    if (!available) return const SizedBox.shrink();
    final scenes = [
      for (final background in TryOnBackground.values)
        if (background.asset != null) background,
    ];
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeSectionTitle(
          title: 'AI Try On backgrounds',
          subtitle: 'Create outfit photos at various locations',
          onTap: () => TryOnFlows.start(context),
        ),
        SizedBox(
          height: _height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: _pagePadding,
            itemCount: scenes.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) => Semantics(
              button: true,
              label: scenes[index].label,
              child: GestureDetector(
                onTap: () => TryOnFlows.start(context),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  child: SizedBox(
                    width: _width,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          scenes[index].asset!,
                          fit: BoxFit.cover,
                          cacheWidth: (_width * 2).round(),
                        ),
                        Positioned(
                          top: AppSpacing.sm,
                          right: AppSpacing.sm,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              'AI',
                              style: context.textTheme.labelLarge?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: AppSpacing.sm,
                          bottom: AppSpacing.sm,
                          child: Text(
                            scenes[index].label,
                            style: context.textTheme.titleSmall?.copyWith(
                              color: palette.onInk,
                              shadows: const [
                                Shadow(blurRadius: 6, color: Colors.black54),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: _pagePadding,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: palette.surfaceMuted,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                message,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      ),
    );
  }
}
