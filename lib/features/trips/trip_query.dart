import 'package:all_fits/core/utils/date_helpers.dart';
import 'package:all_fits/data/models/trip.dart';

enum TripStatus { upcoming, ongoing, past }

extension TripTiming on Trip {
  TripStatus statusOn(DateTime today) {
    final day = DateHelpers.dateOnly(today);
    if (endDate.isBefore(day)) return TripStatus.past;
    if (startDate.isAfter(day)) return TripStatus.upcoming;
    return TripStatus.ongoing;
  }

  /// "Ongoing", "Tomorrow", "In 5 days" or "Past".
  String statusLabel(DateTime today) => switch (statusOn(today)) {
    TripStatus.ongoing => 'Ongoing',
    TripStatus.past => 'Past',
    TripStatus.upcoming => switch (DateHelpers.daysBetween(
      DateHelpers.dateOnly(today),
      startDate,
    )) {
      1 => 'Tomorrow',
      final days => 'In $days days',
    },
  };
}

enum TripFilter {
  all('All'),
  upcoming('Upcoming'),
  ongoing('Ongoing'),
  past('Past');

  const TripFilter(this.label);

  final String label;

  bool matches(Trip trip, DateTime today) => switch (this) {
    TripFilter.all => true,
    TripFilter.upcoming => trip.statusOn(today) == TripStatus.upcoming,
    TripFilter.ongoing => trip.statusOn(today) == TripStatus.ongoing,
    TripFilter.past => trip.statusOn(today) == TripStatus.past,
  };
}

enum TripSort {
  soonest('Soonest first'),
  newest('Recently created'),
  name('Name A–Z');

  const TripSort(this.label);

  final String label;
}

/// What the Trips screen shows: a search over names, a status filter and
/// an order.
class TripQuery {
  const TripQuery({
    this.search = '',
    this.filter = TripFilter.all,
    this.sort = TripSort.soonest,
  });

  final String search;
  final TripFilter filter;
  final TripSort sort;

  bool get isFiltered => search.trim().isNotEmpty || filter != TripFilter.all;

  TripQuery copyWith({String? search, TripFilter? filter, TripSort? sort}) =>
      TripQuery(
        search: search ?? this.search,
        filter: filter ?? this.filter,
        sort: sort ?? this.sort,
      );

  /// [trips] arrive soonest first with past trips last (the controller's
  /// order), which [TripSort.soonest] keeps.
  List<Trip> apply(List<Trip> trips, DateTime today) {
    final words = search.trim().toLowerCase();
    final found = [
      for (final trip in trips)
        if (filter.matches(trip, today) &&
            (words.isEmpty || trip.name.toLowerCase().contains(words)))
          trip,
    ];
    switch (sort) {
      case TripSort.soonest:
        break;
      case TripSort.newest:
        found.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case TripSort.name:
        found.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
    }
    return found;
  }
}
