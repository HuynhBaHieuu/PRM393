import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/utils/json_reader.dart';
import 'package:all_fits/core/utils/validators.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/stylist_persona.dart';
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

/// A piece the stylist suggests buying, with what to search for.
class ShoppingPick {
  const ShoppingPick({
    required this.name,
    required this.query,
    required this.reason,
  });

  factory ShoppingPick.fromJson(JsonMap json) {
    final name = JsonReader.nonEmptyString(json, 'name') ?? '';
    return ShoppingPick(
      name: name,
      query: JsonReader.nonEmptyString(json, 'query') ?? name,
      reason: JsonReader.nonEmptyString(json, 'reason') ?? '',
    );
  }

  final String name;
  final String query;
  final String reason;

  JsonMap toJson() => {'name': name, 'query': query, 'reason': reason};
}

/// One chat bubble: the user's text with any photo or wardrobe pieces they
/// attached, or the stylist's answer with what it proposed.
class StylistMessage {
  const StylistMessage.user(this.text, {this.itemIds = const [], this.photo})
    : fromUser = true,
      outfits = const [],
      packingList = const [],
      shopping = const [];

  const StylistMessage.stylist(
    this.text, {
    this.outfits = const [],
    this.packingList = const [],
    this.shopping = const [],
    this.photo,
  }) : fromUser = false,
       itemIds = const [];

  factory StylistMessage.fromJson(JsonMap json) {
    final text = JsonReader.nonEmptyString(json, 'text') ?? '';
    final photo = JsonReader.nonEmptyString(json, 'photo');
    if (JsonReader.boolean(json, 'fromUser')) {
      return StylistMessage.user(
        text,
        itemIds: JsonReader.stringList(json, 'itemIds'),
        photo: photo,
      );
    }
    List<T> list<T>(String key, T Function(JsonMap json) fromJson) => [
      if (json[key] case final List values)
        for (final value in values)
          if (value is Map) fromJson(Map<String, dynamic>.from(value)),
    ];
    return StylistMessage.stylist(
      text,
      outfits: list('outfits', OutfitSuggestion.fromJson),
      packingList: JsonReader.stringList(json, 'packingList'),
      shopping: list('shopping', ShoppingPick.fromJson),
      photo: photo,
    );
  }

  final String text;
  final bool fromUser;

  /// Pieces the user attached to their message.
  final List<String> itemIds;

  /// Image storage reference of the user's photo, or of the stylist's
  /// try-on picture.
  final String? photo;
  final List<OutfitSuggestion> outfits;

  /// Wardrobe pieces to pack for a trip.
  final List<String> packingList;
  final List<ShoppingPick> shopping;

  JsonMap toJson() => {
    'text': text,
    'fromUser': fromUser,
    if (itemIds.isNotEmpty) 'itemIds': itemIds,
    'photo': ?photo,
    if (outfits.isNotEmpty) 'outfits': [for (final o in outfits) o.toJson()],
    if (packingList.isNotEmpty) 'packingList': packingList,
    if (shopping.isNotEmpty) 'shopping': [for (final s in shopping) s.toJson()],
  };
}

/// Chats with an OpenAI-compatible chat completions API that styles outfits
/// from the user's wardrobe, and draws try-on pictures with Meta's Muse
/// Image, or Gemini when Muse is missing or out of credits. Item metadata is
/// sent with every message; photos only when the user attaches one or asks
/// for a try-on.
class AiStylistService {
  const AiStylistService({
    required this.apiKey,
    this.baseUrl = defaultBaseUrl,
    this.model = defaultModel,
    this.imageModel = defaultImageModel,
    this.qualityImageModel = defaultQualityImageModel,
    this.museImageModel = defaultMuseImageModel,
    this.primary,
    this.cloudflare,
    this.shrinkImage = fitImage,
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

        final museKey = read('MUSE_API_KEY');
        final cloudflareAccount = read('CLOUDFLARE_ACCOUNT_ID');
        final cloudflareToken = read('CLOUDFLARE_API_TOKEN');
        return AiStylistService(
          apiKey: read('OPENAI_API_KEY') ?? '',
          baseUrl: read('AI_BASE_URL') ?? defaultBaseUrl,
          model: read('AI_MODEL') ?? defaultModel,
          imageModel: read('AI_IMAGE_MODEL') ?? defaultImageModel,
          qualityImageModel:
              read('AI_IMAGE_MODEL_QUALITY') ?? defaultQualityImageModel,
          museImageModel: read('MUSE_IMAGE_MODEL') ?? defaultMuseImageModel,
          primary: museKey == null
              ? null
              : (
                  apiKey: museKey,
                  baseUrl: read('MUSE_BASE_URL') ?? museBaseUrl,
                  model: read('MUSE_MODEL') ?? museModel,
                ),
          cloudflare: cloudflareAccount == null || cloudflareToken == null
              ? null
              : (
                  baseUrl: cloudflareBaseUrl,
                  accountId: cloudflareAccount,
                  apiToken: cloudflareToken,
                  model: read('CLOUDFLARE_IMAGE_MODEL') ?? cloudflareImageModel,
                ),
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
  static const String defaultImageModel = 'gemini-2.5-flash-image';
  static const String defaultQualityImageModel = 'gemini-3-pro-image-preview';
  static const String museBaseUrl = 'https://api.meta.ai/v1';
  static const String museModel = 'muse-spark-1.3';
  static const String defaultMuseImageModel = 'muse-image-1.0';
  static const String cloudflareBaseUrl =
      'https://api.cloudflare.com/client/v4';
  static const String cloudflareImageModel =
      '@cf/black-forest-labs/flux-2-klein-4b';

  /// Cloudflare's FLUX.2 takes at most this many reference images, each
  /// smaller than 512 x 512.
  static const int _cloudflareMaxImages = 4;
  static const int _cloudflareMaxSide = 511;
  static const int _cloudflareTries = 4;

  static const int maxOutfits = 3;
  static const int maxShopping = 3;

  /// Most pieces drawn onto one try-on picture.
  static const int maxTryOnPieces = 5;
  static const int _minPieces = 2;

  /// Only the latest messages are sent: 10 questions and their answers.
  static const int maxHistory = 20;

  // ponytail: only the first 120 items are sent to keep requests small;
  // prefilter by occasion/season if wardrobes outgrow this.
  static const int _maxItems = 120;
  static const int _maxReplyLength = 600;
  static const Duration _timeout = Duration(seconds: 60);
  static const Duration _imageTimeout = Duration(seconds: 120);

  static const String _noPicture =
      'No try-on picture came back. Try a clearer, full-body photo of you.';

  static const String _unreadable =
      'The AI reply could not be read. Please try again.';

  // Short numbered rules: small models follow them more reliably than prose.
  static String _systemPrompt(StylistPersona persona) =>
      'You are ${persona.label}, a ${persona.style.toLowerCase()} personal '
      'stylist chatting inside a wardrobe app. Rules:\n'
      '1. "reply" is ONE short sentence, 20 words at most, like a text '
      'message; an emoji now and then. Use the language of the newest user '
      'message. Never mention item ids.\n'
      '2. Only talk about clothes and style; politely decline anything '
      'else.\n'
      '3. Outfits use only wardrobe items from the context message, by their '
      'id, never invented. Each needs a top and a bottom, or a dress, plus '
      'shoes when available; outerwear, bags and accessories are optional. '
      'Give 1 to 3 outfits when the user wants something to wear.\n'
      '4. Style: ${persona.direction} Prefer colors that work together, the '
      'weather when given, what the context says about the user, and items '
      'with a low "wears" count.\n'
      '5. Build outfits around attached pieces. A photo may show the user, a '
      'look they like or one piece: pick wardrobe items that recreate or go '
      'with it.\n'
      '6. Asked to rate an outfit: give a kind, honest score out of 10 in '
      '"reply" and suggest better swaps from the wardrobe.\n'
      '7. Packing list: if you don\'t know where and for how many days yet, '
      'only ask that and leave every list empty. Once you know, "packingItemIds" '
      'MUST hold the id of every piece to pack, and "outfits" a few looks '
      'made from those pieces.\n'
      '8. "shopping" holds up to 3 pieces to buy, only when a look needs '
      'something the wardrobe lacks or the user asks what to buy: the piece '
      'as "name", a web search "query" and a short "reason".\n'
      '9. Asked to change an outfit you suggested, send the changed outfit.\n'
      '10. Leave any list empty when it isn\'t needed. Write "name", '
      '"reason" and shopping text in the language of "reply".';

  static String _tryOnPrompt({
    required bool hasSelfie,
    required bool hasBody,
    required int pieceCount,
    required String bodyType,
    required String appearance,
    required String scene,
    required String notes,
  }) {
    final person = switch ((hasSelfie, hasBody)) {
      (true, true) =>
        'The first image is a selfie of a person and the second shows their '
            'full body. Create a realistic full-body photo of this same '
            'person, keeping their face, hair, skin tone and body shape,',
      (true, false) =>
        'The first image shows a person\'s face. Create a realistic '
            'full-body photo of this same person, keeping their face, hair '
            'and skin tone, as $bodyType,',
      (false, true) =>
        'The first image shows a person. Create a realistic full-body photo '
            'of this same person, keeping their face, body and skin tone,',
      (false, false) =>
        'Create a realistic full-body photo of a fashion model, $bodyType,',
    };
    return 'Virtual try-on. $person standing naturally and wearing all of '
        'the clothing pieces shown in the last $pieceCount images together '
        'as one outfit. Keep each piece\'s color, pattern, fit and logos. '
        'Setting: $scene.'
        '${appearance.isEmpty ? '' : ' How the person looks: $appearance.'}'
        '${notes.isEmpty ? '' : ' Styling notes from the user: $notes.'}';
  }

  /// FLUX on Cloudflare flags pictures less often when images are named by
  /// number and nothing asks to copy a face.
  static String _fluxPrompt({
    required bool hasSelfie,
    required bool hasBody,
    required int pieceCount,
    required String bodyType,
    required String appearance,
    required String scene,
    required String notes,
  }) {
    final people = (hasSelfie ? 1 : 0) + (hasBody ? 1 : 0);
    final who = switch (people) {
      0 => 'a fashion model, $bodyType,',
      1 when hasSelfie => 'the person in image 1, $bodyType,',
      1 => 'the person in image 1',
      _ => 'the person in images 1 and 2',
    };
    final first = people + 1;
    final last = people + pieceCount;
    final pieces = first == last ? 'image $first' : 'images $first to $last';
    return 'Full-body fashion photo of $who fully clothed, wearing the '
        'clothing from $pieces together as one outfit, with the same colors, '
        'patterns and logos. Natural standing pose. Setting: $scene.'
        '${appearance.isEmpty ? '' : ' The person: $appearance.'}'
        '${notes.isEmpty ? '' : ' Styling: $notes.'}';
  }

  final String apiKey;
  final String baseUrl;
  final String model;

  /// Gemini model that draws try-on pictures.
  final String imageModel;

  /// Slower Gemini model for "Quality" try-ons.
  final String qualityImageModel;

  /// Muse model that draws try-on pictures on [primary]'s endpoint, tried
  /// before Gemini.
  final String museImageModel;

  /// Workers AI image model tried last; its daily allowance is free.
  final ({String baseUrl, String accountId, String apiToken, String model})?
  cloudflare;

  /// Shrinks an image to fit a size; [fitImage] outside tests.
  final Future<List<int>> Function(List<int> image, int maxSide) shrinkImage;

  /// Chat endpoint tried first, such as Meta's Muse Spark; the one above
  /// takes over when it runs out of credits or quota.
  final ({String apiKey, String baseUrl, String model})? primary;

  bool get isConfigured => apiKey.isNotEmpty || primary != null;

  /// The native Gemini API behind Gemini's OpenAI-compatible [baseUrl];
  /// null for other providers.
  String? get _geminiRoot => baseUrl.endsWith('/openai')
      ? baseUrl.substring(0, baseUrl.length - '/openai'.length)
      : null;

  /// Whether [tryOn] can work with this provider.
  bool get canTryOn => primary != null || _canGeminiTryOn || cloudflare != null;

  bool get _canGeminiTryOn => apiKey.isNotEmpty && _geminiRoot != null;

  /// Answers the last message in [history], which the user just sent, as
  /// [persona]. [notes] is what the user told the stylist about themselves.
  /// [resolvePhoto] turns a message's photo reference into a file path or
  /// web URL. Completing [cancel] stops the request. Throws [AiException]
  /// with a user-facing message on any failure.
  Future<StylistMessage> reply({
    required List<ClothingItem> wardrobe,
    required List<StylistMessage> history,
    WeatherReport? weather,
    StylistPersona persona = StylistPersona.kai,
    String notes = '',
    String? Function(String photo)? resolvePhoto,
    Future<void>? cancel,
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
    List<String> shortIds(List<String> ids) => [
      for (final id in ids) ?shortIdOf[id],
    ];
    final recent = history.length > maxHistory
        ? history.sublist(history.length - maxHistory)
        : history;
    // ponytail: only the newest user photo is sent, since each image costs
    // far more tokens than text; send more if follow-ups need older ones.
    final photoMessage = recent.reversed
        .where((m) => m.fromUser && m.photo != null)
        .firstOrNull;
    final photoUrl = photoMessage == null
        ? null
        : await _dataUrl(resolvePhoto?.call(photoMessage.photo!));
    final text = await _chat({
      'messages': [
        {'role': 'system', 'content': _systemPrompt(persona)},
        {
          'role': 'system',
          'content': jsonEncode({
            if (notes.trim().isNotEmpty) 'aboutUser': notes.trim(),
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
                      'itemIds': shortIds(outfit.itemIds),
                      'reason': outfit.reason,
                    },
                ],
                'packingItemIds': shortIds(message.packingList),
                'shopping': [for (final s in message.shopping) s.toJson()],
              }),
            },
      ],
      'response_format': _responseFormat,
    }, cancel);
    final content = switch (_decode(text)) {
      {'choices': [{'message': {'content': final String content}}, ...]} =>
        content,
      _ => throw const AiException(_unreadable),
    };
    return _parse(content, byShortId);
  }

  /// Draws [pieces] (photos of the clothes, at most [maxTryOnPieces]) on the
  /// person in [person] (a selfie) and [body] (a full-body photo), or on an
  /// AI model when both are null, and returns the picture's bytes.
  /// [bodyType] describes the figure, e.g. "a woman with a slim build";
  /// [appearance] is how the user describes themselves; [scene] the
  /// setting; [notes] is the user's own styling prompt.
  Future<Uint8List> tryOn({
    List<int>? person,
    List<int>? body,
    required List<List<int>> pieces,
    String bodyType = 'a person with an average build',
    String appearance = '',
    String scene = 'a plain light grey photo studio',
    String notes = '',
    bool highQuality = false,
    Future<void>? cancel,
  }) async {
    if (!canTryOn) {
      throw const AiException(
        'Virtual try-on needs a Muse, Gemini or Cloudflare API key.',
      );
    }
    final worn = pieces.take(maxTryOnPieces).toList();
    // The images, in the order the prompt names them, and that prompt.
    (List<List<int>>, String) request(List<int>? body, List<List<int>> worn) =>
        (
          [?person, ?body, ...worn],
          _tryOnPrompt(
            hasSelfie: person != null,
            hasBody: body != null,
            pieceCount: worn.length,
            bodyType: bodyType,
            appearance: appearance.trim(),
            scene: scene,
            notes: notes.trim(),
          ),
        );
    final (images, prompt) = request(body, worn);
    // Tried in order; the next one takes over when one is out of credits.
    final attempts = <Future<Uint8List> Function()>[
      if (primary case final muse?)
        () => _museTryOn(muse, prompt, images, cancel),
      if (_canGeminiTryOn)
        () => _geminiTryOn(prompt, images, highQuality, cancel),
      if (cloudflare case final flux?)
        () {
          // Room for four images: the body photo goes first, then pieces.
          final room = _cloudflareMaxImages - (person == null ? 0 : 1);
          final keepBody = body != null && worn.length < room;
          final fewer = [
            ?person,
            if (keepBody) body,
            ...worn.take(room - (keepBody ? 1 : 0)),
          ];
          final prompt = _fluxPrompt(
            hasSelfie: person != null,
            hasBody: keepBody,
            pieceCount:
                fewer.length - (person == null ? 0 : 1) - (keepBody ? 1 : 0),
            bodyType: bodyType,
            appearance: appearance.trim(),
            scene: scene,
            notes: notes.trim(),
          );
          return _cloudflareTryOn(flux, prompt, fewer, cancel);
        },
    ];
    for (final (index, attempt) in attempts.indexed) {
      try {
        return await attempt();
      } on _OutOfQuota {
        if (index == attempts.length - 1) rethrow;
      }
    }
    throw StateError('No try-on provider');
  }

  /// FLUX.2 on Cloudflare Workers AI, free up to a daily allowance. Images
  /// are sent shrunk as multipart fields `input_image_0`, `input_image_1`...
  Future<Uint8List> _cloudflareTryOn(
    ({String baseUrl, String accountId, String apiToken, String model}) flux,
    String prompt,
    List<List<int>> images,
    Future<void>? cancel,
  ) async {
    final small = [
      for (final image in images) await shrinkImage(image, _cloudflareMaxSide),
    ];
    // Its safety filter sometimes flags a fine picture with a person in it;
    // another try usually passes.
    for (var attempt = 1; ; attempt++) {
      try {
        return await _cloudflareDraw(flux, prompt, small, cancel);
      } on _Flagged {
        if (attempt == _cloudflareTries) {
          throw const AiException(
            'The free AI’s safety filter blocked this picture. Try again, '
            'use the AI model, or a different photo of you.',
          );
        }
      }
    }
  }

  Future<Uint8List> _cloudflareDraw(
    ({String baseUrl, String accountId, String apiToken, String model}) flux,
    String prompt,
    List<List<int>> small,
    Future<void>? cancel,
  ) async {
    final text = await _request(
      Uri.parse(
        '${flux.baseUrl}/accounts/${flux.accountId}/ai/run/${flux.model}',
      ),
      _Multipart(
        fields: {'prompt': prompt, 'width': '768', 'height': '1024'},
        files: {
          for (final (index, image) in small.indexed)
            'input_image_$index': image,
        },
      ),
      headers: {HttpHeaders.authorizationHeader: 'Bearer ${flux.apiToken}'},
      modelName: flux.model,
      timeout: _imageTimeout,
      cancel: cancel,
    );
    if (_decode(text) case {'result': {'image': final String data}}) {
      return base64Decode(data);
    }
    throw const AiException(_noPicture);
  }

  /// Scales [bytes] down so neither side is over [maxSide], as PNG; small
  /// images are returned as they are.
  static Future<List<int>> fitImage(List<int> bytes, int maxSide) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(
      Uint8List.fromList(bytes),
    );
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      final scale = maxSide / math.max(descriptor.width, descriptor.height);
      if (scale >= 1) return bytes;
      final codec = await descriptor.instantiateCodec(
        targetWidth: (descriptor.width * scale).floor(),
        targetHeight: (descriptor.height * scale).floor(),
      );
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();
      codec.dispose();
      return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } finally {
      descriptor.dispose();
      buffer.dispose();
    }
  }

  /// Meta's Muse Image edit endpoint, which takes up to 10 images as data
  /// URLs. Muse has no slower model, so [tryOn]'s `highQuality` only picks
  /// the Gemini model.
  Future<Uint8List> _museTryOn(
    ({String apiKey, String baseUrl, String model}) muse,
    String prompt,
    List<List<int>> images,
    Future<void>? cancel,
  ) async {
    final text = await _request(
      Uri.parse('${muse.baseUrl}/images/edits'),
      {
        'model': museImageModel,
        'prompt': '$prompt Vertical 3:4 portrait photo.',
        'images': [
          for (final image in images)
            {
              'image_url':
                  'data:${mimeOf(image)};base64,${base64Encode(image)}',
            },
        ],
        'n': 1,
      },
      headers: {HttpHeaders.authorizationHeader: 'Bearer ${muse.apiKey}'},
      modelName: museImageModel,
      timeout: _imageTimeout,
      cancel: cancel,
    );
    if (_decode(text) case {'data': [{'b64_json': final String data}, ...]}) {
      return base64Decode(data);
    }
    throw const AiException(_noPicture);
  }

  Future<Uint8List> _geminiTryOn(
    String prompt,
    List<List<int>> images,
    bool highQuality,
    Future<void>? cancel,
  ) async {
    final model = highQuality ? qualityImageModel : imageModel;
    final text = await _request(
      Uri.parse('$_geminiRoot/models/$model:generateContent'),
      {
        'contents': [
          {
            'parts': [
              {'text': prompt},
              for (final image in images)
                {
                  'inline_data': {
                    'mime_type': mimeOf(image),
                    'data': base64Encode(image),
                  },
                },
            ],
          },
        ],
        'generationConfig': {
          'responseModalities': ['IMAGE'],
          'imageConfig': {'aspectRatio': '3:4'},
        },
      },
      headers: {'x-goog-api-key': apiKey},
      modelName: model,
      timeout: _imageTimeout,
      cancel: cancel,
    );
    if (_decode(text) case {
      'candidates': [{'content': {'parts': final List parts}}, ...],
    }) {
      for (final part in parts) {
        if (part case {'inlineData': {'data': final String data}}) {
          return base64Decode(data);
        }
      }
    }
    throw const AiException(_noPicture);
  }

  static Object? _decode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      throw const AiException(_unreadable);
    }
  }

  /// Sends the chat completions [body] to [primary] first, then to the main
  /// endpoint when [primary] is out of credits or quota.
  Future<String> _chat(Map<String, Object?> body, Future<void>? cancel) async {
    Future<String> send(String key, String base, String model) => _request(
      Uri.parse('$base/chat/completions'),
      {'model': model, ...body},
      headers: {HttpHeaders.authorizationHeader: 'Bearer $key'},
      modelName: model,
      cancel: cancel,
    );
    if (primary case final first?) {
      try {
        return await send(first.apiKey, first.baseUrl, first.model);
      } on _OutOfQuota {
        if (apiKey.isEmpty) rethrow;
      }
    }
    return send(apiKey, baseUrl, model);
  }

  /// Posts [body] as JSON to [url] and returns the response text.
  /// Posts [body], a JSON map or a [_Multipart], and returns the response
  /// text.
  Future<String> _request(
    Uri url,
    Object body, {
    required Map<String, String> headers,
    required String modelName,
    Duration timeout = _timeout,
    Future<void>? cancel,
  }) async {
    final client = HttpClient();
    // Closing the client aborts the request in flight.
    unawaited(cancel?.whenComplete(() => client.close(force: true)));
    try {
      final (status, text) = await _post(
        client,
        url,
        body,
        headers,
      ).timeout(timeout);
      if (status != HttpStatus.ok) {
        final message = switch (status) {
          HttpStatus.unauthorized ||
          HttpStatus.forbidden => 'The AI service rejected the API key.',
          HttpStatus.paymentRequired =>
            'The AI service is out of credits. Top up the API account.',
          // Gemini's free tier gives some models a quota of zero.
          HttpStatus.tooManyRequests when text.contains('limit: 0') =>
            'Your AI plan doesn’t include this feature. Turn on billing for '
                'the API key to use it.',
          HttpStatus.tooManyRequests =>
            'The AI service is busy or out of quota. Try again later.',
          HttpStatus.notFound => 'The AI model "$modelName" is not available.',
          >= HttpStatus.internalServerError =>
            'The AI service is busy right now. Try again in a moment.',
          _ => [
            'The AI service returned an error ($status)',
            ?_errorDetail(text),
          ].join(': '),
        };
        developer.log(
          'AI request to ${url.host} returned $status',
          name: 'ai',
          error: text.length > 500 ? text.substring(0, 500) : text,
        );
        if (status == HttpStatus.badRequest && text.contains('flagged')) {
          throw _Flagged(message);
        }
        throw status == HttpStatus.paymentRequired ||
                status == HttpStatus.tooManyRequests
            ? _OutOfQuota(message)
            : AiException(message);
      }
      return text;
    } on AiException {
      rethrow;
    } on TimeoutException {
      throw const AiException(
        'The AI service took too long to answer. Please try again.',
      );
    } on Exception catch (error) {
      // Socket and TLS failures, and cancelled requests.
      developer.log(
        'AI request to ${url.host} failed',
        name: 'ai',
        error: error,
      );
      throw const AiException(
        'Could not reach the AI service. Check your connection.',
      );
    } finally {
      client.close(force: true);
    }
  }

  /// The provider's own error message, when it sent one: Gemini and Muse
  /// use `error.message`, Cloudflare `errors[].message`.
  static String? _errorDetail(String text) {
    try {
      final message = switch (jsonDecode(text)) {
        {'error': {'message': final String message}} => message,
        {'errors': [{'message': final String message}, ...]} => message,
        _ => null,
      };
      if (message == null || message.trim().isEmpty) return null;
      final line = message.trim().split('\n').first;
      return line.length > 160 ? '${line.substring(0, 160)}…' : line;
    } on FormatException {
      return null;
    }
  }

  static Future<(int, String)> _post(
    HttpClient client,
    Uri url,
    Object body,
    Map<String, String> headers,
  ) async {
    final request = await client.postUrl(url);
    request.headers.contentType = body is _Multipart
        ? ContentType(
            'multipart',
            'form-data',
            parameters: {'boundary': body.boundary},
          )
        : ContentType.json;
    headers.forEach(request.headers.set);
    request.add(
      body is _Multipart ? body.bytes : utf8.encode(jsonEncode(body)),
    );
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

  /// The image at [location], a file path or web URL, or null when it can't
  /// be read.
  static Future<List<int>?> readImage(String location) async {
    final url = Uri.tryParse(location);
    try {
      if (url != null && (url.isScheme('https') || url.isScheme('http'))) {
        return await _download(url).timeout(_timeout);
      }
      return await File(location).readAsBytes();
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

  /// The image at [location] as a data URL, or null when it can't be read;
  /// the stylist then answers from the text alone.
  static Future<String?> _dataUrl(String? location) async {
    final bytes = location == null ? null : await readImage(location);
    if (bytes == null) return null;
    return 'data:${mimeOf(bytes)};base64,${base64Encode(bytes)}';
  }

  /// The image type of [bytes], read from its first bytes; JPEG when unsure.
  static String mimeOf(List<int> bytes) {
    bool has(List<int> magic, [int offset = 0]) {
      if (bytes.length < offset + magic.length) return false;
      for (var i = 0; i < magic.length; i++) {
        if (bytes[offset + i] != magic[i]) return false;
      }
      return true;
    }

    if (has([0x89, 0x50, 0x4E, 0x47])) return 'image/png';
    if (has([0x47, 0x49, 0x46])) return 'image/gif';
    if (has([0x57, 0x45, 0x42, 0x50], 8)) return 'image/webp';
    return 'image/jpeg';
  }

  /// Keeps only outfits and pieces from the wardrobe; model output is never
  /// trusted.
  static StylistMessage _parse(
    String content,
    Map<String, ClothingItem> byShortId,
  ) {
    // Providers that ignore response_format may wrap the JSON in prose.
    final start = content.indexOf('{');
    final end = content.lastIndexOf('}');
    if (start < 0 || end < start) throw const AiException(_unreadable);
    final decoded = _decode(content.substring(start, end + 1));
    if (decoded is! Map || decoded['outfits'] is! List) {
      throw const AiException(_unreadable);
    }
    // The set drops repeated ids; unknown ids are skipped.
    List<String> known(Object? ids) => ids is List
        ? {for (final id in ids) ?byShortId['$id']?.id}.toList()
        : const [];

    final suggestions = <OutfitSuggestion>[];
    for (final outfit in decoded['outfits'] as List) {
      if (outfit is! Map) continue;
      final itemIds = known(outfit['itemIds']);
      if (itemIds.length < _minPieces) continue;
      suggestions.add(
        OutfitSuggestion(
          name: _clip(
            outfit['name'],
            Validators.maxNameLength,
            fallback: 'AI outfit',
          ),
          itemIds: itemIds,
          reason: _clip(outfit['reason'], Validators.maxNotesLength),
        ),
      );
    }
    final shopping = [
      if (decoded['shopping'] case final List picks)
        for (final pick in picks)
          if (pick is Map && _clip(pick['name'], 80).isNotEmpty)
            ShoppingPick(
              name: _clip(pick['name'], 80),
              query: _clip(
                pick['query'],
                120,
                fallback: _clip(pick['name'], 80),
              ),
              reason: _clip(pick['reason'], Validators.maxNotesLength),
            ),
    ].take(maxShopping).toList();
    final packingList = known(decoded['packingItemIds']);
    final reply = _clip(decoded['reply'], _maxReplyLength);
    if (reply.isEmpty &&
        suggestions.isEmpty &&
        packingList.isEmpty &&
        shopping.isEmpty) {
      throw const AiException(_unreadable);
    }
    return StylistMessage.stylist(
      reply,
      outfits: suggestions.take(maxOutfits).toList(),
      packingList: packingList,
      shopping: shopping,
    );
  }

  static String _clip(Object? value, int max, {String fallback = ''}) {
    final text = value is String ? value.trim() : '';
    if (text.isEmpty) return fallback;
    return text.length <= max ? text : text.substring(0, max);
  }

  static const Map<String, Object?> _stringArray = {
    'type': 'array',
    'items': {'type': 'string'},
  };

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
                'itemIds': _stringArray,
                'reason': {'type': 'string'},
              },
              'required': ['name', 'itemIds', 'reason'],
              'additionalProperties': false,
            },
          },
          'packingItemIds': _stringArray,
          'shopping': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'name': {'type': 'string'},
                'query': {'type': 'string'},
                'reason': {'type': 'string'},
              },
              'required': ['name', 'query', 'reason'],
              'additionalProperties': false,
            },
          },
        },
        'required': ['reply', 'outfits', 'packingItemIds', 'shopping'],
        'additionalProperties': false,
      },
    },
  };
}

/// The provider has no credits or quota left; another one may take over.
class _OutOfQuota extends AiException {
  const _OutOfQuota(super.message);
}

/// The provider's safety filter rejected the picture it drew.
class _Flagged extends AiException {
  const _Flagged(super.message);
}

/// A multipart/form-data body of text [fields] and image [files].
class _Multipart {
  _Multipart({
    required Map<String, String> fields,
    required Map<String, List<int>> files,
  }) {
    final out = BytesBuilder(copy: false);
    void line(String text) => out.add(utf8.encode('$text\r\n'));
    for (final MapEntry(:key, :value) in fields.entries) {
      line('--$boundary');
      line('Content-Disposition: form-data; name="$key"');
      line('');
      line(value);
    }
    for (final MapEntry(:key, :value) in files.entries) {
      final mime = AiStylistService.mimeOf(value);
      line('--$boundary');
      line(
        'Content-Disposition: form-data; name="$key"; '
        'filename="$key.${mime.split('/').last}"',
      );
      line('Content-Type: $mime');
      line('');
      out.add(value);
      line('');
    }
    line('--$boundary--');
    bytes = out.takeBytes();
  }

  final String boundary = 'allfits-${DateTime.now().microsecondsSinceEpoch}';
  late final List<int> bytes;
}
