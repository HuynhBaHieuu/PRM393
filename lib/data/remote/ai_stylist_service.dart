import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/utils/validators.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/occasion.dart';

/// One AI-proposed outfit. [itemIds] only ever holds ids of wardrobe items
/// that were sent with the request.
class OutfitSuggestion {
  const OutfitSuggestion({
    required this.name,
    required this.itemIds,
    required this.reason,
  });

  final String name;
  final List<String> itemIds;
  final String reason;
}

/// Asks an OpenAI-compatible chat completions API to build outfits from the
/// user's wardrobe. Only item metadata is sent; photos never leave the device.
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

  static const int suggestionCount = 3;
  static const int _minPieces = 2;

  // ponytail: only the first 120 items are sent to keep requests small;
  // prefilter by occasion/season if wardrobes outgrow this.
  static const int _maxItems = 120;
  static const Duration _timeout = Duration(seconds: 60);

  static const String _unreadable =
      'The AI reply could not be read. Please try again.';
  static const String _systemPrompt =
      'You are a personal stylist with a streetwear eye. Build outfits '
      'using only items from the '
      'wardrobe list the user sends. Each outfit needs one top and one '
      'bottom, or one dress, plus one pair of shoes when available. '
      'Outerwear, bags and accessories are optional. Refer to items by '
      'their id exactly as given and never invent items. Style them the '
      'streetwear way: let the sneakers or one statement piece anchor the '
      'look, layer outerwear over tees and hoodies, balance loose and '
      'fitted shapes, and keep loud logos or prints to one or two pieces. '
      'Prefer colors that '
      'work together, the requested occasion, and items with a low "wears" '
      'count. Make the outfits clearly different from each other. "reason" '
      'is one short sentence. Write "name" and "reason" in the language of '
      'the user\'s note, or in English when there is no note.';

  final String apiKey;
  final String baseUrl;
  final String model;

  bool get isConfigured => apiKey.isNotEmpty;

  /// Throws [AiException] with a user-facing message on any failure.
  Future<List<OutfitSuggestion>> suggest({
    required List<ClothingItem> wardrobe,
    Occasion? occasion,
    String note = '',
  }) async {
    if (!isConfigured) {
      throw const AiException('The AI stylist is not set up.');
    }
    // Short ids cost fewer tokens than UUIDs and are harder to get wrong.
    final byShortId = {
      for (final (index, item) in wardrobe.take(_maxItems).indexed)
        '${index + 1}': item,
    };
    final content = await _complete({
      'model': model,
      'messages': [
        {'role': 'system', 'content': _systemPrompt},
        {
          'role': 'user',
          'content': jsonEncode({
            'outfitsWanted': suggestionCount,
            'occasion': ?occasion?.label,
            if (note.trim().isNotEmpty) 'note': note.trim(),
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
      ],
      'response_format': _responseFormat,
    });
    final suggestions = _parse(content, byShortId);
    if (suggestions.isEmpty) {
      throw const AiException(
        'No outfits could be made from your wardrobe. Try a different '
        'request.',
      );
    }
    return suggestions;
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

  /// Keeps only outfits made of known items; model output is never trusted.
  static List<OutfitSuggestion> _parse(
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
    return suggestions.take(suggestionCount).toList();
  }

  static String _clip(Object? value, int max, {String fallback = ''}) {
    final text = value is String ? value.trim() : '';
    if (text.isEmpty) return fallback;
    return text.length <= max ? text : text.substring(0, max);
  }

  static const Map<String, Object?> _responseFormat = {
    'type': 'json_schema',
    'json_schema': {
      'name': 'outfit_suggestions',
      'strict': true,
      'schema': {
        'type': 'object',
        'properties': {
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
        'required': ['outfits'],
        'additionalProperties': false,
      },
    },
  };
}
