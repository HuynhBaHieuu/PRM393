import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/constants/storage_keys.dart';
import 'package:all_fits/core/utils/id_generator.dart';
import 'package:all_fits/core/utils/json_reader.dart';
import 'package:all_fits/data/local/image_storage_service.dart';
import 'package:all_fits/data/local/json_collection_store.dart';
import 'package:all_fits/data/local/local_storage_service.dart';
import 'package:all_fits/data/models/stylist_persona.dart';
import 'package:all_fits/data/remote/ai_stylist_service.dart';

/// One saved conversation with the AI stylist.
class StylistChat {
  const StylistChat({
    required this.id,
    required this.updatedAt,
    required this.messages,
  });

  factory StylistChat.fromJson(JsonMap json) {
    final messages = json['messages'];
    return StylistChat(
      id:
          JsonReader.nonEmptyString(json, 'id') ??
          (throw const FormatException('Chat without an id')),
      updatedAt:
          JsonReader.date(json, 'updatedAt') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      messages: [
        if (messages is List)
          for (final message in messages)
            if (message is Map)
              StylistMessage.fromJson(Map<String, dynamic>.from(message)),
      ],
    );
  }

  final String id;
  final DateTime updatedAt;
  final List<StylistMessage> messages;

  /// The first thing the user asked.
  String get title => messages
      .firstWhere(
        (m) => m.fromUser && m.text.isNotEmpty,
        orElse: () => const StylistMessage.user('Chat'),
      )
      .text;

  JsonMap toJson() => {
    'id': id,
    'updatedAt': updatedAt.toIso8601String(),
    'messages': [for (final m in messages) m.toJson()],
  };
}

/// One user's AI Stylist data: past chats, their chosen stylist and notes,
/// and today's message count.
///
/// ponytail: kept on the device, so the Free daily limit resets with the app
/// data; enforce it server-side once the AI calls go through a backend.
class StylistStore extends ChangeNotifier {
  StylistStore({
    required LocalStorageService storage,
    required this._idGenerator,
    this._images,
    this._clock = systemClock,
  }) : _storage = storage,
       _store = JsonCollectionStore<StylistChat>(
         storage: storage,
         key: StorageKeys.stylistChats,
         fromJson: StylistChat.fromJson,
         toJson: (chat) => chat.toJson(),
         idOf: (chat) => chat.id,
       );

  final LocalStorageService _storage;
  final JsonCollectionStore<StylistChat> _store;
  final IdGenerator _idGenerator;

  /// Holds the photos attached to messages; they go when their chat does.
  final ImageStorageService? _images;
  final Clock _clock;

  List<StylistChat> _chats = const [];
  String _usageDay = '';
  int _usageCount = 0;
  int _usageBonus = 0;
  StylistPersona _persona = StylistPersona.kai;
  String _notes = '';
  Future<void>? _loading;

  /// Newest first.
  List<StylistChat> get chats => _chats;

  /// Messages sent today.
  int get usedToday => _usageDay == _today ? _usageCount : 0;

  /// Extra Free messages earned today by sharing the app.
  int get bonusToday => _usageDay == _today ? _usageBonus : 0;

  StylistPersona get persona => _persona;

  /// What the user wants the stylist to know about them.
  String get notes => _notes;

  String get _today {
    final now = _clock();
    return '${now.year}-${now.month}-${now.day}';
  }

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    _chats = await _store.readAll()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    try {
      final usage = await _storage.read(StorageKeys.stylistUsage);
      if (jsonDecode(usage ?? '{}')
          case {'day': final String day, 'count': final int count} &&
              final Map json) {
        _usageDay = day;
        _usageCount = count;
        _usageBonus = json['bonus'] is int ? json['bonus'] as int : 0;
      }
      final prefs = await _storage.read(StorageKeys.stylistPrefs);
      if (jsonDecode(prefs ?? '{}') case final Map json) {
        final map = Map<String, dynamic>.from(json);
        _persona =
            JsonReader.enumValue(StylistPersona.values, map['persona']) ??
            StylistPersona.kai;
        _notes = JsonReader.nonEmptyString(map, 'notes') ?? '';
      }
    } catch (error) {
      developer.log('Stylist data unreadable', name: 'storage', error: error);
    }
    notifyListeners();
  }

  Future<void> setPersona(StylistPersona persona) =>
      _savePrefs(persona, _notes);

  Future<void> setNotes(String notes) => _savePrefs(_persona, notes.trim());

  Future<void> _savePrefs(StylistPersona persona, String notes) async {
    await _storage.write(
      StorageKeys.stylistPrefs,
      jsonEncode({'persona': persona.name, 'notes': notes}),
    );
    _persona = persona;
    _notes = notes;
    notifyListeners();
  }

  String newChatId() => _idGenerator.next();

  /// Saves [messages] as chat [id], dropping the oldest chats past the limit.
  Future<void> save(String id, List<StylistMessage> messages) async {
    final chat = StylistChat(
      id: id,
      updatedAt: _clock(),
      messages: List.unmodifiable(messages),
    );
    final next = [chat, ..._chats.where((c) => c.id != id)];
    await _store.upsertAll([chat]);
    if (next.length > AppConfig.stylistChatsKept) {
      final dropped = next.sublist(AppConfig.stylistChatsKept);
      await _store.removeIds([for (final c in dropped) c.id]);
      next.removeRange(AppConfig.stylistChatsKept, next.length);
      await _deletePhotos(dropped);
    }
    _chats = next;
    notifyListeners();
  }

  Future<void> delete(String id) async {
    await _store.removeIds([id]);
    final gone = _chats.where((c) => c.id == id).toList();
    _chats = [..._chats.where((c) => c.id != id)];
    notifyListeners();
    await _deletePhotos(gone);
  }

  Future<void> _deletePhotos(Iterable<StylistChat> chats) async {
    for (final chat in chats) {
      for (final message in chat.messages) {
        final photo = message.photo;
        if (photo != null) await _images?.deleteImage(photo);
      }
    }
  }

  /// Records one message sent today.
  Future<void> countMessage() => _saveUsage(usedToday + 1, bonusToday);

  /// Adds today's share bonus; only once a day.
  Future<void> grantShareBonus() async {
    if (bonusToday > 0) return;
    await _saveUsage(usedToday, AppConfig.shareBonusMessages);
  }

  Future<void> _saveUsage(int count, int bonus) async {
    final day = _today;
    await _storage.write(
      StorageKeys.stylistUsage,
      jsonEncode({'day': day, 'count': count, 'bonus': bonus}),
    );
    _usageDay = day;
    _usageCount = count;
    _usageBonus = bonus;
    notifyListeners();
  }
}
