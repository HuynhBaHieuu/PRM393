import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/utils/json_reader.dart';
import 'package:all_fits/core/utils/validators.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/weather.dart';

/// One AI-proposed outfit. [itemIds] only ever holds ids of wardrobe items
/// that were sent with the request.
class OutfitSuggestion {
  const OutfitSuggestion({
    required this.name,
    required this.itemIds,
    required this.reason,
  });

  factory OutfitSuggestion.fromJson(JsonMap json) => OutfitSuggestion(
    name: JsonReader.nonEmptyString(json, 'name') ?? '',
    itemIds: JsonReader.stringList(json, 'itemIds'),
    reason: JsonReader.nonEmptyString(json, 'reason') ?? '',
  );

  final String name;
  final List<String> itemIds;
  final String reason;

  JsonMap toJson() => {'name': name, 'itemIds': itemIds, 'reason': reason};
}

/// One chat bubble: the user's text with any photo or wardrobe pieces they
/// attached, or the stylist's answer with any outfits it proposed.
class StylistMessage {
  const StylistMessage.user(this.text, {this.itemIds = const [], this.photo})
    : fromUser = true,
      outfits = const [];

  const StylistMessage.stylist(this.text, {this.outfits = const []})
    : fromUser = false,
      itemIds = const [],
      photo = null;

  factory StylistMessage.fromJson(JsonMap json) {
    final text = JsonReader.nonEmptyString(json, 'text') ?? '';
    if (JsonReader.boolean(json, 'fromUser')) {
      return StylistMessage.user(
        text,
        itemIds: JsonReader.stringList(json, 'itemIds'),
        photo: JsonReader.nonEmptyString(json, 'photo'),
      );
    }
    final outfits = json['outfits'];
    return StylistMessage.stylist(
      text,
      outfits: [
        if (outfits is List)
          for (final outfit in outfits)
            if (outfit is Map)
              OutfitSuggestion.fromJson(Map<String, dynamic>.from(outfit)),
      ],
    );
  }

  final String text;
  final bool fromUser;

  /// Pieces the user attached to their message.
  final List<String> itemIds;

  /// Image storage reference of a photo the user attached.
  final String? photo;
  final List<OutfitSuggestion> outfits;

  JsonMap toJson() => {
    'text': text,
    'fromUser': fromUser,
    if (itemIds.isNotEmpty) 'itemIds': itemIds,
    'photo': ?photo,
    if (outfits.isNotEmpty) 'outfits': [for (final o in outfits) o.toJson()],
  };
}

/// Chats with an OpenAI-compatible chat completions API that styles outfits
/// from the user's wardrobe. Only item metadata is sent; photos never leave
/// the device.
class AiStylistService {
  const AiStylistService({
    required this.apiKey,
    this.baseUrl = defaultBaseUrl,
    this.model = defaultModel,
  });

  /// Builds the service from the contents of [configAsset]. Anything missing
  /// or malformed gives an unconfigured service instead of an error.
  factory AiStylistService.fromConfig(String json) {
    try {
      if (jsonDecode(json) case final Map<String, dynamic> config) {
        String? read(String key) {
          final value = config[key];
          return value is String && value.trim().isNotEmpty
              ? value.trim()
              : null;
        }

        return AiStylistService(
          apiKey: read('OPENAI_API_KEY') ?? '',
          baseUrl: read('AI_BASE_URL') ?? defaultBaseUrl,
          model: read('AI_MODEL') ?? defaultModel,
        );
      }
    } on FormatException {
      // Fall through to the unconfigured service.
    }
    return const AiStylistService(apiKey: '');
  }

  // ponytail: this file is bundled into the app, so anyone with the APK can
  // read the key. Fine for development and demos; put a backend proxy in
  // front before publishing.
  static const String configAsset = 'assets/env.json';
  static const String defaultBaseUrl = 'https://api.openai.com/v1';
  static const String defaultModel = 'gpt-4o';

  static const int maxOutfits = 3;
  static const int _minPieces = 2;

  /// Only the latest messages are sent: 10 questions and their answers.
  static const int maxHistory = 20;

  // ponytail: only the first 120 items are sent to keep requests small;
  // prefilter by occasion/season if wardrobes outgrow this.
  static const int _maxItems = 120;
  static const int _maxReplyLength = 600;
  static const Duration _timeout = Duration(seconds: 60);

  static const String _unreadable =
      'The AI reply could not be read. Please try again.';
  /// The stylist's name, shown in the chat header.
  static const String stylistName = 'Kai';

  static const String _systemPrompt =
      'You are $stylistName, a personal stylist with a streetwear eye, '
      'chatting inside a wardrobe app. Answer like a text message: friendly, '
      'one or two short '
      'sentences, an emoji now and then. Always reply in the language of '
      'the newest user message. Only talk about clothes and style; politely '
      'decline anything else. '
      'When the user wants something to wear, put 1 to 3 outfits in '
      '"outfits", built only from the wardrobe in the context message. Each '
      'outfit needs one top and one bottom, or one dress, plus one pair of '
      'shoes when available. Outerwear, bags and accessories are optional. '
      'Refer to items by their id exactly as given and never invent items. '
      'Style them the streetwear way: let the sneakers or one statement '
      'piece anchor the look, layer outerwear over tees and hoodies, balance '
      'loose and fitted shapes, and keep loud logos or prints to one or two '
      'pieces. Prefer colors that work together, the weather when given, '
      'and items with a low "wears" count. Build the outfits around any '
      'pieces the user attaches. The user may attach a photo of themselves, '
      'of a look they like or of a single piece: pick wardrobe items that '
      'recreate or go with it, and if they ask you to rate the outfit in '
      'the photo, rate it kindly and suggest swaps from the wardrobe. When '
      'the user asks to change an '
      'outfit you suggested, send the changed outfit. Leave "outfits" empty '
      'when no outfit is needed. Never show item ids in "reply". "name" and '
      '"reason" (one short sentence) use the same language as "reply".';

  final String apiKey;
  final String baseUrl;
  final String model;

  bool get isConfigured => apiKey.isNotEmpty;

  /// Answers the last message in [history], which the user just sent.
  /// [resolvePhoto] turns a message's photo reference into a file path or
  /// `https` URL. Throws [AiException] with a user-facing message on any
  /// failure.
  Future<StylistMessage> reply({
    required List<ClothingItem> wardrobe,
    required List<StylistMessage> history,
    WeatherReport? weather,
    String? Function(String photo)? resolvePhoto,
  }) async {
    if (!isConfigured) {
      throw const AiException('The AI stylist is not set up.');
    }
    // Short ids cost fewer tokens than UUIDs and are harder to get wrong.
    final byShortId = {
      for (final (index, item) in wardrobe.take(_maxItems).indexed)
        '${index + 1}': item,
    };
    final shortIdOf = {
      for (final MapEntry(key: shortId, value: item) in byShortId.entries)
        item.id: shortId,
    };
    final recent = history.length > maxHistory
        ? history.sublist(history.length - maxHistory)
        : history;
    // ponytail: only the newest photo is sent, since each image costs far
    // more tokens than text; send more if follow-ups need older ones.
    final photoMessage = recent.reversed
        .where((m) => m.photo != null)
        .firstOrNull;
    final photoUrl = photoMessage == null
        ? null
        : await _dataUrl(resolvePhoto?.call(photoMessage.photo!));
    final content = await _complete({
      'model': model,
      'messages': [
        {'role': 'system', 'content': _systemPrompt},
        {
          'role': 'system',
          'content': jsonEncode({
            if (weather != null)
              'weather': {
                'city': weather.location.name,
                'condition': weather.condition.label,
                'highC': weather.high.round(),
                'lowC': weather.low.round(),
                'rainChance': weather.rainChance,
              },
            'wardrobe': [
              for (final MapEntry(key: id, value: item) in byShortId.entries)
                {
                  'id': id,
                  'name': item.name,
                  'category': item.category.name,
                  'brand': ?item.brand,
                  'color': ?item.color?.name,
                  if (item.seasons.isNotEmpty)
                    'seasons': [for (final s in item.seasons) s.name],
                  'wears': item.wearCount,
                },
            ],
          }),
        },
        for (final message in recent)
          if (message.fromUser)
            {
              'role': 'user',
              'content': identical(message, photoMessage) && photoUrl != null
                  ? [
                      {
                        'type': 'text',
                        'text': _userContent(message, shortIdOf),
                      },
                      {
                        'type': 'image_url',
                        'image_url': {'url': photoUrl},
                      },
                    ]
                  : _userContent(message, shortIdOf),
            }
          else
            // Earlier answers go back as JSON so follow-ups like "other
            // shoes" can refer to the outfits by their ids.
            {
              'role': 'assistant',
              'content': jsonEncode({
                'reply': message.text,
                'outfits': [
                  for (final outfit in message.outfits)
                    {
                      'name': outfit.name,
                      'itemIds': [
                        for (final id in outfit.itemIds) ?shortIdOf[id],
                      ],
                      'reason': outfit.reason,
                    },
                ],
              }),
            },
      ],
      'response_format': _responseFormat,
    });
    return _parse(content, byShortId);
  }

  Future<String> _complete(Map<String, Object?> body) async {
    final client = HttpClient();
    try {
      final (status, text) = await _post(client, body).timeout(_timeout);

      if (status != HttpStatus.ok) {
        throw AiException(switch (status) {
          HttpStatus.unauthorized ||
          HttpStatus.forbidden => 'The AI service rejected the API key.',
          HttpStatus.tooManyRequests =>
            'The AI service is busy or out of quota. Try again later.',
          HttpStatus.notFound =>
            'The AI model "$model" is not available. Check AI_MODEL.',
          >= HttpStatus.internalServerError =>
            'The AI service is busy right now. Try again in a moment.',
          _ => 'The AI service returned an error ($status).',
        });
      }
      return switch (jsonDecode(text)) {
        {'choices': [{'message': {'content': final String content}}, ...]} =>
          content,
        _ => throw const AiException(_unreadable),
      };
    } on AiException {
      rethrow;
    } on FormatException {
      throw const AiException(_unreadable);
    } on TimeoutException {
      throw const AiException(
        'The AI service took too long to answer. Please try again.',
      );
    } on Exception {
      // Socket and TLS failures.
      throw const AiException(
        'Could not reach the AI service. Check your connection.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<(int, String)> _post(
    HttpClient client,
    Map<String, Object?> body,
  ) async {
    final request = await client.postUrl(
      Uri.parse('$baseUrl/chat/completions'),
    );
    request.headers
      ..contentType = ContentType.json
      ..set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
    request.add(utf8.encode(jsonEncode(body)));
    final response = await request.close();
    return (response.statusCode, await response.transform(utf8.decoder).join());
  }

  static String _userContent(
    StylistMessage message,
    Map<String, String> shortIdOf,
  ) {
    final attached = [for (final id in message.itemIds) ?shortIdOf[id]];
    return [
      message.text,
      if (attached.isNotEmpty)
        '(Attached pieces, by id: ${attached.join(', ')})',
    ].join('\n');
  }

  /// The photo at [location], a file path or web URL, as a data URL, or
  /// null when it can't be read; the stylist then answers from the text.
  static Future<String?> _dataUrl(String? location) async {
    if (location == null) return null;
    final url = Uri.tryParse(location);
    final isUrl = url != null && (url.isScheme('https') || url.isScheme('http'));
    final name = isUrl ? url.path : location;
    final type = switch (name.substring(name.lastIndexOf('.') + 1)
        .toLowerCase()) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' || 'heif' => 'image/heic',
      _ => 'image/jpeg',
    };
    try {
      final bytes = isUrl
          ? await _download(url).timeout(_timeout)
          : await File(location).readAsBytes();
      if (bytes == null) return null;
      return 'data:$type;base64,${base64Encode(bytes)}';
    } on Exception {
      return null;
    }
  }

  static Future<List<int>?> _download(Uri url) async {
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(url)).close();
      if (response.statusCode != HttpStatus.ok) return null;
      return [for (final chunk in await response.toList()) ...chunk];
    } finally {
      client.close(force: true);
    }
  }

  /// Keeps only outfits made of known items; model output is never trusted.
  static StylistMessage _parse(
    String content,
    Map<String, ClothingItem> byShortId,
  ) {
    // Providers that ignore response_format may wrap the JSON in prose.
    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    if (start < 0 || end < start) throw const AiException(_unreadable);
    final Object? decoded;
    try {
      decoded = jsonDecode(content.substring(start, end + 1));
    } on FormatException {
      throw const AiException(_unreadable);
    }
    if (decoded is! Map || decoded['outfits'] is! List) {
      throw const AiException(_unreadable);
    }

    final suggestions = <OutfitSuggestion>[];
    for (final outfit in decoded['outfits'] as List) {
      if (outfit is! Map) continue;
      final name = outfit['name'];
      final ids = outfit['itemIds'];
      final reason = outfit['reason'];
      if (ids is! List) continue;
      // The set drops repeated ids; unknown ids are skipped.
      final itemIds = {for (final id in ids) ?byShortId['$id']?.id}.toList();
      if (itemIds.length < _minPieces) continue;
      suggestions.add(
        OutfitSuggestion(
          name: _clip(name, Validators.maxNameLength, fallback: 'AI outfit'),
          itemIds: itemIds,
          reason: _clip(reason, Validators.maxNotesLength),
        ),
      );
    }
    final reply = _clip(decoded['reply'], _maxReplyLength);
    if (reply.isEmpty && suggestions.isEmpty) {
      throw const AiException(_unreadable);
    }
    return StylistMessage.stylist(
      reply,
      outfits: suggestions.take(maxOutfits).toList(),
    );
  }

  static String _clip(Object? value, int max, {String fallback = ''}) {
    final text = value is String ? value.trim() : '';
    if (text.isEmpty) return fallback;
    return text.length <= max ? text : text.substring(0, max);
  }

  static const Map<String, Object?> _responseFormat = {
    'type': 'json_schema',
    'json_schema': {
      'name': 'stylist_reply',
      'strict': true,
      'schema': {
        'type': 'object',
        'properties': {
          'reply': {'type': 'string'},
          'outfits': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'name': {'type': 'string'},
                'itemIds': {
                  'type': 'array',
                  'items': {'type': 'string'},
                },
                'reason': {'type': 'string'},
              },
              'required': ['name', 'itemIds', 'reason'],
              'additionalProperties': false,
            },
          },
        },
        'required': ['reply', 'outfits'],
        'additionalProperties': false,
      },
    },
  };
}
