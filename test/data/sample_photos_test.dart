import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:all_fits/data/sample/sample_data.dart';

void main() {
  test('every sample item has its own photo, and no two are the same', () {
    final items = SampleData.items(DateTime(2026, 10, 12));
    final hashes = <String, String>{};
    for (final item in items) {
      final path = SampleData.photoFor(item.id);
      expect(path, isNotNull, reason: item.name);
      final file = File(path!);
      expect(file.existsSync(), isTrue, reason: '${item.name}: $path');
      final hash = sha256.convert(file.readAsBytesSync()).toString();
      expect(
        hashes[hash],
        isNull,
        reason: '${item.name} uses the same photo as ${hashes[hash]}',
      );
      hashes[hash] = item.name;
    }
    expect(hashes, hasLength(items.length));
    expect(File(SampleData.photoCreditsAsset).existsSync(), isTrue);
  });

  test('items the user added have no bundled photo', () {
    expect(SampleData.photoFor('0d7c2c1e-user-item'), isNull);
  });
}
