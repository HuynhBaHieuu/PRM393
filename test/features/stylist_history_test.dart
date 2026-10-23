import 'package:flutter_test/flutter_test.dart';

import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/utils/id_generator.dart';
import 'package:all_fits/data/local/local_storage_service.dart';
import 'package:all_fits/data/remote/ai_stylist_service.dart';
import 'package:all_fits/features/stylist/stylist_history.dart';

class _Counter implements IdGenerator {
  int _n = 0;

  @override
  String next() => 'chat-${++_n}';
}

void main() {
  test('chats and the daily count survive a reload', () async {
    final storage = InMemoryStorageService();
    var now = DateTime(2026, 10, 23, 9);
    StylistHistory open() => StylistHistory(
      storage: storage,
      idGenerator: _Counter(),
      clock: () => now,
    );

    final history = open();
    await history.load();
    const messages = [
      StylistMessage.user('Date night?', itemIds: ['tee']),
      StylistMessage.stylist(
        'Try this 😎',
        outfits: [
          OutfitSuggestion(
            name: 'Night',
            itemIds: ['tee', 'jeans'],
            reason: 'Sharp.',
          ),
        ],
      ),
    ];
    await history.save('a', messages);
    await history.countMessage();
    await history.countMessage();

    final reopened = open();
    await reopened.load();
    final chat = reopened.chats.single;
    expect(chat.title, 'Date night?');
    expect(chat.messages.first.itemIds, ['tee']);
    expect(chat.messages.last.outfits.single.itemIds, ['tee', 'jeans']);
    expect(reopened.usedToday, 2);

    // The count starts over the next day.
    now = now.add(const Duration(days: 1));
    expect(reopened.usedToday, 0);
    await reopened.countMessage();
    final nextDay = open();
    await nextDay.load();
    expect(nextDay.usedToday, 1);

    await reopened.delete('a');
    expect(reopened.chats, isEmpty);
  });

  test('keeps only the newest chats', () async {
    var minute = 0;
    final history = StylistHistory(
      storage: InMemoryStorageService(),
      idGenerator: _Counter(),
      clock: () => DateTime(2026, 10, 23).add(Duration(minutes: minute++)),
    );
    await history.load();
    for (var i = 0; i <= AppConfig.stylistChatsKept; i++) {
      await history.save('$i', [StylistMessage.user('Q$i')]);
    }
    expect(history.chats, hasLength(AppConfig.stylistChatsKept));
    expect(history.chats.first.id, '${AppConfig.stylistChatsKept}');
    expect(history.chats.any((c) => c.id == '0'), isFalse);
  });
}
