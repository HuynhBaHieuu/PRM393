import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/selectable_pill.dart';
import 'package:all_fits/data/models/trip.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/shared/closet_actions.dart';
import 'package:all_fits/features/trips/packing_list.dart';
import 'package:all_fits/features/trips/trip_controller.dart';
import 'package:all_fits/features/trips/trip_flows.dart';
import 'package:all_fits/features/trips/trip_query.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';

/// Every trip, with a search, a status filter and a sort order.
class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  final _search = TextEditingController();
  TripQuery _query = const TripQuery();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _clear() {
    _search.clear();
    setState(() => _query = TripQuery(sort: _query.sort));
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<TripController>().trips;
    final today = context.read<ClosetActions>().today;
    final shown = _query.apply(all, today);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trips'),
        actions: [
          if (all.isNotEmpty)
            PopupMenuButton<TripSort>(
              tooltip: 'Sort',
              icon: const Icon(Icons.swap_vert_rounded),
              initialValue: _query.sort,
              onSelected: (sort) =>
                  setState(() => _query = _query.copyWith(sort: sort)),
              itemBuilder: (_) => [
                for (final sort in TripSort.values)
                  CheckedPopupMenuItem(
                    value: sort,
                    checked: sort == _query.sort,
                    child: Text(sort.label),
                  ),
              ],
            ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      floatingActionButton: all.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => TripFlows.create(context),
              // The theme's FAB is a circle; a labelled one needs a pill.
              shape: const StadiumBorder(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Plan a trip'),
            ),
      body: all.isEmpty
          ? AppEmptyState(
              icon: Icons.luggage_outlined,
              title: 'No trips yet',
              message:
                  'Choose an outfit for each day of a trip and get a packing '
                  'list for your suitcase.',
              actionLabel: 'Plan a trip',
              onAction: () => TripFlows.create(context),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.xs,
                    AppSpacing.page,
                    AppSpacing.sm,
                  ),
                  child: TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    onChanged: (text) =>
                        setState(() => _query = _query.copyWith(search: text)),
                    decoration: InputDecoration(
                      hintText: 'Search trips',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.search.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _search.clear();
                                setState(
                                  () => _query = _query.copyWith(search: ''),
                                );
                              },
                            ),
                    ),
                  ),
                ),
                PillBar(
                  pills: [
                    for (final filter in TripFilter.values)
                      SelectablePill(
                        label: filter == TripFilter.all
                            ? filter.label
                            : '${filter.label} '
                                  '${all.where((t) => filter.matches(t, today)).length}',
                        selected: filter == _query.filter,
                        onTap: () => setState(
                          () => _query = _query.copyWith(filter: filter),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: shown.isEmpty
                      ? AppEmptyState(
                          compact: true,
                          icon: Icons.search_off_rounded,
                          title: 'No trips match',
                          message: 'Try another name or filter.',
                          actionLabel: 'Clear filters',
                          onAction: _clear,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.page,
                            0,
                            AppSpacing.page,
                            AppSpacing.xxl * 3,
                          ),
                          itemCount: shown.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) =>
                              _TripCard(trip: shown[index], today: today),
                        ),
                ),
              ],
            ),
    );
  }
}

enum _CardMenu { edit, copy, delete }

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.today});

  final Trip trip;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final outfits = context.watch<OutfitController>();
    final list = PackingList.of(
      trip,
      outfitById: outfits.outfitById,
      itemById: context.watch<WardrobeController>().itemById,
    );
    final planned = list.plannedDays(outfits.outfitById);
    final status = trip.statusOn(today);
    final past = status == TripStatus.past;
    final text = context.textTheme;
    final palette = context.palette;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => AppNavigator.tripDetail(context, trip.id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxs),
                child: Icon(
                  past ? Icons.luggage_outlined : Icons.luggage_rounded,
                  color: past ? palette.textTertiary : palette.ink,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            trip.name,
                            style: text.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _StatusChip(
                          label: trip.statusLabel(today),
                          highlight: status == TripStatus.ongoing,
                          muted: past,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${AppFormatters.shortDate(trip.startDate)} – '
                      '${AppFormatters.shortDate(trip.endDate)} · '
                      '${AppFormatters.count(trip.length, 'day')} · '
                      '$planned/${trip.length} planned',
                      style: text.bodySmall,
                    ),
                    if (!list.isEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              child: LinearProgressIndicator(
                                value: list.packedCount / list.total,
                                minHeight: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          // A fixed width keeps every card's bar the same
                          // length.
                          SizedBox(
                            width: 96,
                            child: Text(
                              '${list.packedCount}/${list.total} packed',
                              textAlign: TextAlign.end,
                              style: text.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<_CardMenu>(
                tooltip: 'More',
                onSelected: (choice) => switch (choice) {
                  _CardMenu.edit => TripFlows.edit(context, trip),
                  _CardMenu.copy => TripFlows.copyPackingList(context, trip),
                  _CardMenu.delete => TripFlows.delete(context, trip),
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: _CardMenu.edit, child: Text('Edit')),
                  PopupMenuItem(
                    value: _CardMenu.copy,
                    child: Text('Copy packing list'),
                  ),
                  PopupMenuItem(value: _CardMenu.delete, child: Text('Delete')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    this.highlight = false,
    this.muted = false,
  });

  final String label;
  final bool highlight;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlight ? palette.ink : palette.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 2,
        ),
        child: Text(
          label,
          style: context.textTheme.labelSmall?.copyWith(
            color: highlight
                ? palette.onInk
                : muted
                ? palette.textTertiary
                : palette.ink,
          ),
        ),
      ),
    );
  }
}
