import 'package:uuid/uuid.dart';

/// Produces unique identifiers for locally created records.
abstract interface class IdGenerator {
  String next();
}

class UuidIdGenerator implements IdGenerator {
  const UuidIdGenerator();

  static final Uuid _uuid = Uuid();

  @override
  String next() => _uuid.v4();
}

/// Injectable time source, so business logic can be tested deterministically.
typedef Clock = DateTime Function();

DateTime systemClock() => DateTime.now();
