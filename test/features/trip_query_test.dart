import 'package:flutter_test/flutter_test.dart';

import 'package:all_fits/data/models/trip.dart';
import 'package:all_fits/features/trips/trip_query.dart';

void main() {
  final today = DateTime(2026, 11, 10);

  Trip trip(String name, int startIn, int length, {int createdDaysAgo = 0}) {
    final start = today.add(Duration(days: startIn));
    final created = today.subtract(Duration(days: createdDaysAgo));
    return Trip(
      id: name,
      name: name,
      startDate: start,
      endDate: start.add(Duration(days: length - 1)),
      createdAt: created,
      updatedAt: created,
    );
  }

  // In the controller's order: upcoming/ongoing soonest first, then past.
  final ongoing = trip('Hà Nội work', -1, 3, createdDaysAgo: 9);
  final tomorrow = trip('Beach', 1, 2, createdDaysAgo: 1);
  final later = trip('Đà Lạt', 5, 3, createdDaysAgo: 5);
  final past = trip('Hawaii', -20, 8, createdDaysAgo: 30);
  final trips = [ongoing, tomorrow, later, past];

  List<String> names(TripQuery query) =>
      query.apply(trips, today).map((t) => t.name).toList();

  test('status and its label', () {
    expect(ongoing.statusOn(today), TripStatus.ongoing);
    expect(ongoing.statusLabel(today), 'Ongoing');
    expect(tomorrow.statusLabel(today), 'Tomorrow');
    expect(later.statusLabel(today), 'In 5 days');
    expect(past.statusLabel(today), 'Past');
  });

  test('filters by status', () {
    expect(names(const TripQuery(filter: TripFilter.upcoming)), [
      'Beach',
      'Đà Lạt',
    ]);
    expect(names(const TripQuery(filter: TripFilter.ongoing)), ['Hà Nội work']);
    expect(names(const TripQuery(filter: TripFilter.past)), ['Hawaii']);
  });

  test('searches names, ignoring case', () {
    expect(names(const TripQuery(search: ' đà ')), ['Đà Lạt']);
    expect(names(const TripQuery(search: 'xyz')), isEmpty);
    expect(const TripQuery(search: 'a').isFiltered, isTrue);
    expect(const TripQuery().isFiltered, isFalse);
  });

  test('sorts', () {
    expect(names(const TripQuery()), [
      'Hà Nội work',
      'Beach',
      'Đà Lạt',
      'Hawaii',
    ]);
    expect(names(const TripQuery(sort: TripSort.newest)), [
      'Beach',
      'Đà Lạt',
      'Hà Nội work',
      'Hawaii',
    ]);
    expect(names(const TripQuery(sort: TripSort.name)).first, 'Beach');
  });
}
