import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/core/widgets/feedback_views.dart';
import 'package:all_fits/data/models/trip.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/widgets/outfit_cover.dart';
import 'package:all_fits/features/trips/packing_list.dart';
import 'package:all_fits/features/trips/trip_controller.dart';
import 'package:all_fits/features/trips/trip_flows.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';

enum _TripMenu { edit, copy, untick, delete }

/// One trip: an outfit for each day, and the packing list made from them.
class TripDetailScreen extends StatelessWidget {
  const TripDetailScreen({super.key, required this.tripId});

  final String tripId;

  Future<void> _onMenu(
    BuildContext context,
    Trip trip,
    _TripMenu choice,
  ) async {
    switch (choice) {
      case _TripMenu.edit:
        await TripFlows.edit(context, trip);
      case _TripMenu.copy:
        await TripFlows.copyPackingList(context, trip);
      case _TripMenu.untick:
        await context.read<TripController>().resetPacking(trip.id);
      case _TripMenu.delete:
        final deleted = await TripFlows.delete(context, trip);
        if (deleted && context.mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = context.select<TripController, Trip?>(
      (c) => c.tripById(tripId),
    );
    if (trip == null) {
      return const NotFoundView(
        title: 'Trip not found',
        message: 'This trip has been deleted.',
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(trip.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                '${AppFormatters.shortDate(trip.startDate)} – '
                '${AppFormatters.shortDate(trip.endDate)}',
                style: context.textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            PopupMenuButton<_TripMenu>(
              tooltip: 'More',
              onSelected: (choice) => _onMenu(context, trip, choice),
              itemBuilder: (_) => const [
                PopupMenuItem(value: _TripMenu.edit, child: Text('Edit trip')),
                PopupMenuItem(
                  value: _TripMenu.copy,
                  child: Text('Copy packing list'),
                ),
                PopupMenuItem(
                  value: _TripMenu.untick,
                  child: Text('Untick everything'),
                ),
                PopupMenuItem(
                  value: _TripMenu.delete,
                  child: Text('Delete trip'),
                ),
              ],
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Days'),
              Tab(text: 'Packing list'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _DaysTab(trip: trip),
            _PackingTab(trip: trip),
          ],
        ),
      ),
    );
  }
}

class _DaysTab extends StatelessWidget {
  const _DaysTab({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final outfits = context.watch<OutfitController>();
    final wardrobe = context.watch<WardrobeController>();
    final days = trip.days;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      itemCount: days.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final day = days[index];
        final outfitId = trip.outfitOn(day);
        final outfit = outfitId == null ? null : outfits.outfitById(outfitId);
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.page,
            vertical: AppSpacing.xxs,
          ),
          leading: SizedBox(
            width: 52,
            height: 64,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: outfit == null
                  ? ColoredBox(
                      color: context.palette.surfaceMuted,
                      child: Icon(
                        Icons.add_rounded,
                        color: context.palette.textSecondary,
                      ),
                    )
                  : OutfitCover(
                      outfit: outfit,
                      items: wardrobe.itemsByIds(outfit.itemIds),
                    ),
            ),
          ),
          title: Text(
            'Day ${index + 1} · ${AppFormatters.weekdayName(day)}, '
            '${AppFormatters.shortDate(day)}',
          ),
          subtitle: Text(
            outfit?.name ?? 'Tap to choose an outfit',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: outfit == null
              ? null
              : IconButton(
                  tooltip: 'Clear this day',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => TripFlows.clearDay(context, trip, day),
                ),
          onTap: () => TripFlows.chooseOutfit(context, trip, day),
        );
      },
    );
  }
}

class _PackingTab extends StatelessWidget {
  const _PackingTab({required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final list = PackingList.of(
      trip,
      outfitById: context.watch<OutfitController>().outfitById,
      itemById: context.watch<WardrobeController>().itemById,
    );
    final controller = context.read<TripController>();
    final text = context.textTheme;

    if (list.lines.isEmpty && list.extras.isEmpty) {
      return AppEmptyState(
        icon: Icons.checklist_rounded,
        title: 'Nothing to pack yet',
        message:
            'Choose outfits on the Days tab: their pieces show up here, '
            'each listed once.',
        actionLabel: 'Add something else',
        onAction: () => TripFlows.addExtra(context, trip),
      );
    }

    final progress = list.total == 0 ? 0.0 : list.packedCount / list.total;
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.xxl * 2),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.md,
            AppSpacing.page,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${list.packedCount} of ${list.total} packed',
                style: text.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: LinearProgressIndicator(value: progress, minHeight: 8),
              ),
            ],
          ),
        ),
        for (final MapEntry(key: category, value: lines)
            in list.byCategory.entries) ...[
          _SectionTitle(category.label),
          for (final line in lines)
            CheckboxListTile(
              value: line.packed,
              onChanged: (packed) =>
                  controller.setItemPacked(trip.id, line.item.id, packed!),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.page,
              ),
              title: Text(line.item.name),
              subtitle: line.days > 1
                  ? Text('Worn ${AppFormatters.count(line.days, 'day')}')
                  : null,
              secondary: SizedBox.square(
                dimension: 44,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: ClothingImage(item: line.item, decodeWidth: 120),
                ),
              ),
            ),
        ],
        _SectionTitle(
          PackingList.extrasTitle,
          trailing: TextButton.icon(
            onPressed: () => TripFlows.addExtra(context, trip),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add'),
          ),
        ),
        if (list.extras.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
            child: Text(
              'Things that aren’t clothes, like a phone charger or '
              'sunscreen.',
              style: text.bodySmall,
            ),
          ),
        for (final extra in list.extras)
          CheckboxListTile(
            value: extra.packed,
            onChanged: (packed) =>
                controller.setExtraPacked(trip.id, extra.id, packed!),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.page,
            ),
            title: Text(extra.label),
            secondary: IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.close_rounded),
              onPressed: () => controller.removeExtra(trip.id, extra.id),
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.xxs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: context.textTheme.labelMedium,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
