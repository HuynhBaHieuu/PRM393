import 'package:flutter/foundation.dart';

import 'package:all_fits/core/utils/date_helpers.dart';
import 'package:all_fits/core/utils/id_generator.dart';
import 'package:all_fits/core/utils/load_status.dart';
import 'package:all_fits/data/models/outfit_calendar_entry.dart';
import 'package:all_fits/data/repositories/calendar_repository.dart';

/// What happens on one calendar day: at most one planned and one worn outfit.
class DayPlan {
  const DayPlan({this.planned, this.worn});

  static const DayPlan empty = DayPlan();

  final OutfitCalendarEntry? planned;
  final OutfitCalendarEntry? worn;

  bool get isEmpty => planned == null && worn == null;

  /// The entry to feature for this day: what was worn, else what is planned.
  OutfitCalendarEntry? get primary => worn ?? planned;
}

/// Owns calendar entries (plans and wear history).
class PlannerController extends ChangeNotifier {
  PlannerController({
    required this._repository,
    IdGenerator idGenerator = const UuidIdGenerator(),
  }) : _ids = idGenerator;

  final CalendarRepository _repository;
  final IdGenerator _ids;

  LoadStatus _status = LoadStatus.idle;
  Object? _error;
  List<OutfitCalendarEntry> _entries = const [];
  Map<String, DayPlan> _byDay = const {};

  LoadStatus get status => _status;
  Object? get error => _error;
  List<OutfitCalendarEntry> get entries => _entries;

  /// Worn entries, most recent first.
  List<OutfitCalendarEntry> get wornEntries =>
      _entries.where((e) => e.isWorn).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  DayPlan dayPlan(DateTime date) =>
      _byDay[DateHelpers.toKey(date)] ?? DayPlan.empty;

  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    notifyListeners();
    try {
      _setEntries(_dedupe(await _repository.fetchAll()));
      _status = LoadStatus.ready;
    } catch (error) {
      _status = LoadStatus.failure;
      _error = error;
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  /// Plans [outfitId] for [date], replacing any existing plan for that day.
  Future<OutfitCalendarEntry> planOutfit(DateTime date, String outfitId) async {
    final existing = dayPlan(date).planned;
    final entry =
        existing?.copyWith(outfitId: outfitId) ??
        OutfitCalendarEntry(
          id: _ids.next(),
          date: date,
          outfitId: outfitId,
          status: CalendarEntryStatus.planned,
        );
    await saveEntry(entry);
    return entry;
  }

  Future<void> saveEntry(OutfitCalendarEntry entry) async {
    await _repository.saveAll([entry]);
    _setEntries([..._entries.where((e) => e.id != entry.id), entry]);
    notifyListeners();
  }

  Future<void> removeEntry(String id) => removeEntries([id]);

  Future<void> removeEntries(Iterable<String> ids) async {
    final targets = ids.toSet();
    if (!_entries.any((e) => targets.contains(e.id))) return;
    await _repository.deleteAll(targets);
    _setEntries(_entries.where((e) => !targets.contains(e.id)));
    notifyListeners();
  }

  Future<void> removeEntriesForOutfit(String outfitId) => removeEntries(
    _entries.where((e) => e.outfitId == outfitId).map((e) => e.id),
  );

  Future<void> clearAll() async {
    await _repository.clear();
    _setEntries(const []);
    notifyListeners();
  }

  void _setEntries(Iterable<OutfitCalendarEntry> entries) {
    _entries = List.unmodifiable(entries);
    final byDay = <String, DayPlan>{};
    for (final entry in _entries) {
      final current = byDay[entry.dateKey] ?? DayPlan.empty;
      byDay[entry.dateKey] = entry.isWorn
          ? DayPlan(planned: current.planned, worn: entry)
          : DayPlan(planned: entry, worn: current.worn);
    }
    _byDay = byDay;
  }

  /// Guards against malformed data with several entries of the same status
  /// on one day: the last one wins.
  static List<OutfitCalendarEntry> _dedupe(List<OutfitCalendarEntry> entries) {
    final unique = <String, OutfitCalendarEntry>{};
    for (final entry in entries) {
      unique['${entry.dateKey}/${entry.status.name}'] = entry;
    }
    return unique.values.toList();
  }
}
