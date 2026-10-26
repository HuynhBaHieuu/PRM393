import 'package:all_fits/core/utils/date_helpers.dart';
import 'package:all_fits/core/utils/json_reader.dart';

enum CalendarEntryStatus { planned, worn }

const Object _unset = Object();

class OutfitCalendarEntry {
  OutfitCalendarEntry({
    required this.id,
    required DateTime date,
    required this.outfitId,
    required this.status,
    this.note,
  }) : date = DateHelpers.dateOnly(date);

  factory OutfitCalendarEntry.fromJson(JsonMap json) {
    final id = JsonReader.nonEmptyString(json, 'id');
    final outfitId = JsonReader.nonEmptyString(json, 'outfitId');
    final date = DateHelpers.fromKey(JsonReader.string(json, 'date'));
    final status = JsonReader.enumValue(
      CalendarEntryStatus.values,
      json['status'],
    );
    if (id == null || outfitId == null || date == null || status == null) {
      throw const FormatException('Calendar entry is incomplete');
    }
    return OutfitCalendarEntry(
      id: id,
      date: date,
      outfitId: outfitId,
      status: status,
      note: JsonReader.nonEmptyString(json, 'note'),
    );
  }

  final String id;

  /// Calendar day without a time component.
  final DateTime date;
  final String outfitId;
  final CalendarEntryStatus status;

  /// What the user wrote on the planner card for this day.
  final String? note;

  String get dateKey => DateHelpers.toKey(date);

  bool get isWorn => status == CalendarEntryStatus.worn;

  bool get isPlanned => status == CalendarEntryStatus.planned;

  JsonMap toJson() => {
    'id': id,
    'date': dateKey,
    'outfitId': outfitId,
    'status': status.name,
    'note': note,
  };

  OutfitCalendarEntry copyWith({
    DateTime? date,
    String? outfitId,
    CalendarEntryStatus? status,
    Object? note = _unset,
  }) {
    return OutfitCalendarEntry(
      id: id,
      date: date ?? this.date,
      outfitId: outfitId ?? this.outfitId,
      status: status ?? this.status,
      note: identical(note, _unset) ? this.note : note as String?,
    );
  }
}
