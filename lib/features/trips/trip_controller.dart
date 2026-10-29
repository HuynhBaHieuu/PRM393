import 'package:flutter/foundation.dart';

import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/utils/date_helpers.dart';
import 'package:all_fits/core/utils/id_generator.dart';
import 'package:all_fits/core/utils/load_status.dart';
import 'package:all_fits/core/utils/validators.dart';
import 'package:all_fits/data/models/trip.dart';
import 'package:all_fits/data/models/weather.dart';
import 'package:all_fits/data/repositories/trip_repository.dart';

/// Owns the user's trips. Trips only point at outfits; putting those
/// outfits on the planner is done by `TripFlows` through `ClosetActions`.
class TripController extends ChangeNotifier {
  TripController({
    required this._repository,
    IdGenerator idGenerator = const UuidIdGenerator(),
    this._clock = systemClock,
  }) : _ids = idGenerator;

  final TripRepository _repository;
  final IdGenerator _ids;
  final Clock _clock;

  LoadStatus _status = LoadStatus.idle;
  Map<String, Trip> _byId = const {};
  List<Trip> _trips = const [];

  LoadStatus get status => _status;

  /// Upcoming and current trips soonest first, then past ones latest first.
  List<Trip> get trips => _trips;

  Trip? tripById(String id) => _byId[id];

  Future<void> load() async {
    _status = LoadStatus.loading;
    notifyListeners();
    try {
      _setTrips(await _repository.fetchAll());
      _status = LoadStatus.ready;
    } catch (_) {
      _status = LoadStatus.failure;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  /// Trips that haven't ended yet, which the Free plan limits.
  int get activeCount => _trips.where(isActive).length;

  bool isActive(Trip trip) => !trip.isPast(_clock());

  /// The trip that [day] is part of, if any; the earliest when several are.
  Trip? tripOn(DateTime day) {
    Trip? found;
    for (final trip in _trips) {
      if (trip.contains(day) &&
          (found == null || trip.startDate.isBefore(found.startDate))) {
        found = trip;
      }
    }
    return found;
  }

  Future<Trip> createTrip(
    String name,
    DateTime start,
    DateTime end, {
    WeatherLocation? location,
  }) async {
    final now = _clock();
    final trip = Trip(
      id: _ids.next(),
      name: _validName(name),
      startDate: start,
      endDate: end,
      location: location,
      createdAt: now,
      updatedAt: now,
    );
    _checkDates(trip.startDate, trip.endDate);
    await _commit(trip);
    return trip;
  }

  /// Renames and moves the trip. Outfits on days outside the new dates are
  /// dropped; the caller takes them off the planner.
  Future<Trip> updateDetails(
    String id, {
    required String name,
    required DateTime start,
    required DateTime end,
    WeatherLocation? location,
  }) async {
    final trip = _require(id);
    final first = DateHelpers.dateOnly(start);
    final last = DateHelpers.dateOnly(end);
    _checkDates(first, last);
    final updated = trip.copyWith(
      name: _validName(name),
      startDate: first,
      endDate: last,
      location: location,
      outfitByDay: {
        for (final MapEntry(:key, :value) in trip.outfitByDay.entries)
          if (DateHelpers.fromKey(key) case final day?
              when !day.isBefore(first) && !day.isAfter(last))
            key: value,
      },
      updatedAt: _clock(),
    );
    await _commit(updated);
    return updated;
  }

  /// Puts [outfitId] on [day], or clears the day when it is null.
  Future<void> setDayOutfit(String id, DateTime day, String? outfitId) async {
    final trip = _require(id);
    if (!trip.contains(day)) {
      throw const ValidationException('That day is not part of this trip.');
    }
    final key = DateHelpers.toKey(day);
    final days = Map.of(trip.outfitByDay);
    if (outfitId == null) {
      if (days.remove(key) == null) return;
    } else {
      if (days[key] == outfitId) return;
      days[key] = outfitId;
    }
    await _commit(trip.copyWith(outfitByDay: days, updatedAt: _clock()));
  }

  Future<void> setItemPacked(String id, String itemId, bool packed) async {
    final trip = _require(id);
    final ids = trip.packedItemIds.toSet();
    if (!(packed ? ids.add(itemId) : ids.remove(itemId))) return;
    await _commit(
      trip.copyWith(packedItemIds: ids.toList(), updatedAt: _clock()),
    );
  }

  Future<void> addExtra(String id, String label) async {
    final trip = _require(id);
    final text = label.trim();
    final error = Validators.requiredName(text, subject: 'what to pack');
    if (error != null) throw ValidationException(error);
    await _commit(
      trip.copyWith(
        extras: [
          ...trip.extras,
          PackingExtra(id: _ids.next(), label: text),
        ],
        updatedAt: _clock(),
      ),
    );
  }

  Future<void> setExtraPacked(String id, String extraId, bool packed) =>
      _updateExtras(
        id,
        (extras) => [
          for (final e in extras)
            e.id == extraId ? e.copyWith(packed: packed) : e,
        ],
      );

  Future<void> removeExtra(String id, String extraId) => _updateExtras(
    id,
    (extras) => extras.where((e) => e.id != extraId).toList(),
  );

  /// Unticks everything, e.g. to pack again for the way home.
  Future<void> resetPacking(String id) async {
    final trip = _require(id);
    await _commit(
      trip.copyWith(
        packedItemIds: const [],
        extras: [for (final e in trip.extras) e.copyWith(packed: false)],
        updatedAt: _clock(),
      ),
    );
  }

  Future<void> deleteTrip(String id) async {
    if (!_byId.containsKey(id)) return;
    await _repository.deleteAll([id]);
    _setTrips(_trips.where((t) => t.id != id));
    notifyListeners();
  }

  /// Clears days that used a deleted outfit.
  Future<void> removeOutfitReferences(Iterable<String> outfitIds) async {
    final ids = outfitIds.toSet();
    final now = _clock();
    final changed = [
      for (final trip in _trips)
        if (trip.outfitByDay.values.any(ids.contains))
          trip.copyWith(
            outfitByDay: {
              for (final MapEntry(:key, :value) in trip.outfitByDay.entries)
                if (!ids.contains(value)) key: value,
            },
            updatedAt: now,
          ),
    ];
    if (changed.isEmpty) return;
    await _repository.saveAll(changed);
    _setTrips({..._byId, for (final t in changed) t.id: t}.values);
    notifyListeners();
  }

  Future<void> clearAll() async {
    await _repository.clear();
    _setTrips(const []);
    notifyListeners();
  }

  String _validName(String name) {
    final trimmed = name.trim();
    final error = Validators.requiredName(trimmed, subject: 'a trip name');
    if (error != null) throw ValidationException(error);
    return trimmed;
  }

  static void _checkDates(DateTime start, DateTime end) {
    if (end.isBefore(start)) {
      throw const ValidationException('The trip can’t end before it starts.');
    }
    if (DateHelpers.daysBetween(start, end) + 1 > Trip.maxDays) {
      throw const ValidationException(
        'A trip can be at most ${Trip.maxDays} days long.',
      );
    }
  }

  Future<void> _updateExtras(
    String id,
    List<PackingExtra> Function(List<PackingExtra>) change,
  ) async {
    final trip = _require(id);
    await _commit(
      trip.copyWith(extras: change(trip.extras), updatedAt: _clock()),
    );
  }

  Trip _require(String id) {
    final trip = _byId[id];
    if (trip == null) {
      throw const NotFoundException('This trip no longer exists.');
    }
    return trip;
  }

  Future<void> _commit(Trip trip) async {
    await _repository.saveAll([trip]);
    _setTrips({..._byId, trip.id: trip}.values);
    notifyListeners();
  }

  void _setTrips(Iterable<Trip> trips) {
    final today = DateHelpers.dateOnly(_clock());
    final upcoming = trips.where((t) => !t.isPast(today)).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    final past = trips.where((t) => t.isPast(today)).toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    _trips = List.unmodifiable([...upcoming, ...past]);
    _byId = {for (final trip in _trips) trip.id: trip};
  }
}
