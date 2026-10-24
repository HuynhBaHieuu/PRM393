import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_color.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/stylist_persona.dart';
import 'package:all_fits/data/models/weather.dart';
import 'package:all_fits/data/remote/ai_stylist_service.dart';

ClothingItem _item(String id, String name, ClothingCategory category) {
  final now = DateTime(2026, 10, 1);
  return ClothingItem(
    id: id,
    name: name,
    category: category,
    color: ClothingColor.white,
    imagePath: 'images/$id.jpg',
    createdAt: now,
    updatedAt: now,
  );
}

/// The first bytes of a WebP file.
final List<int> _webp = [...'RIFF0000WEBP'.codeUnits, 7];

void main() {
  // A local stand-in for the chat completions endpoint, so the real HTTP
  // path is exercised without a network or an API key.
  late HttpServer server;
  late int status;

  /// Status for requests to the Muse stand-in under /muse.
  late int museStatus;

  /// Status for requests to the Cloudflare stand-in under /cf.
  late int cfStatus;
  late List<String> paths;
  late String reply;

  /// Sent as is instead of a chat completion, when set.
  String? rawResponse;

  /// When set, the server waits for it before answering.
  Completer<void>? hold;
  Map<String, dynamic>? sentBody;

  /// The request body as sent, one character per byte.
  String? sentRaw;
  String? sentAuth;
  String? sentPath;
  String? sentGoogleKey;

  final wardrobe = [
    _item('uuid-tee', 'White Tee', ClothingCategory.tops),
    _item('uuid-jeans', 'Blue Jeans', ClothingCategory.bottoms),
    _item('uuid-shoes', 'Sneakers', ClothingCategory.shoes),
  ];

  AiStylistService service({String apiKey = 'test-key'}) => AiStylistService(
    apiKey: apiKey,
    baseUrl: 'http://127.0.0.1:${server.port}',
    model: 'test-model',
  );

  String outfits(List<Map<String, Object?>> list, {String text = 'Here!'}) =>
      jsonEncode({'reply': text, 'outfits': list});

  const ask = [StylistMessage.user('Trời mưa, mặc gì đi làm?')];

  setUp(() async {
    status = HttpStatus.ok;
    museStatus = HttpStatus.ok;
    cfStatus = HttpStatus.ok;
    paths = [];
    reply = outfits([]);
    rawResponse = null;
    hold = null;
    sentBody = null;
    sentAuth = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      // Photos uploaded to cloud storage are fetched by URL.
      if (request.method == 'GET') {
        request.response.add(_webp);
        await request.response.close();
        return;
      }
      sentAuth = request.headers.value(HttpHeaders.authorizationHeader);
      sentGoogleKey = request.headers.value('x-goog-api-key');
      sentPath = request.uri.path;
      paths.add(request.uri.path);
      sentRaw = await latin1.decoder.bind(request).join();
      // Multipart bodies (Cloudflare) are only kept raw.
      sentBody = request.headers.contentType?.mimeType == 'application/json'
          ? jsonDecode(utf8.decode(latin1.encode(sentRaw!)))
                as Map<String, dynamic>
          : null;
      await hold?.future;
      try {
        request.response
          ..statusCode = sentPath!.startsWith('/muse')
              ? museStatus
              : sentPath!.startsWith('/cf')
              ? cfStatus
              : status
          ..headers.contentType = ContentType.json
          ..write(
            rawResponse ??
                jsonEncode({
                  'choices': [
                    {
                      'message': {'content': reply},
                    },
                  ],
                }),
          );
        await request.response.close();
      } on Object {
        // The client went away (a cancelled request).
      }
    });
  });

  tearDown(() => server.close(force: true));

  test(
    'sends wardrobe metadata and maps the reply back to real items',
    () async {
      reply = outfits(text: 'Two rainy-day looks ☔', [
        {
          'name': 'Weekend',
          'itemIds': ['1', '2', '3', '2'],
          'reason': 'Relaxed and clean.',
        },
        // Only one known item: not an outfit.
        {
          'name': 'Ghost',
          'itemIds': ['1', '99'],
          'reason': '',
        },
        {
          'name': '',
          'itemIds': ['2', '3'],
          'reason': 'Simple.',
        },
      ]);

      final result = await service().reply(
        wardrobe: wardrobe,
        history: ask,
        weather: WeatherReport(
          location: const WeatherLocation(
            name: 'Hanoi',
            latitude: 21,
            longitude: 105.8,
          ),
          temperature: 24,
          high: 26.4,
          low: 21.6,
          condition: WeatherCondition.rain,
          rainChance: 80,
          fetchedAt: DateTime(2026, 10, 1),
        ),
      );

      expect(result.fromUser, isFalse);
      expect(result.text, 'Two rainy-day looks ☔');
      final looks = result.outfits;
      expect(looks, hasLength(2));
      expect(looks[0].name, 'Weekend');
      expect(looks[0].itemIds, ['uuid-tee', 'uuid-jeans', 'uuid-shoes']);
      expect(looks[0].reason, 'Relaxed and clean.');
      expect(looks[1].name, 'AI outfit');

      expect(sentAuth, 'Bearer test-key');
      expect(sentBody!['model'], 'test-model');
      expect(sentBody!['response_format']['json_schema']['strict'], isTrue);
      final messages = sentBody!['messages'] as List;
      expect(messages.last, {'role': 'user', 'content': ask.single.text});
      final contextJson = messages[1]['content'] as String;
      final context = jsonDecode(contextJson) as Map<String, dynamic>;
      expect(context['weather'], {
        'city': 'Hanoi',
        'condition': 'Rain',
        'highC': 26,
        'lowC': 22,
        'rainChance': 80,
      });
      expect(context['wardrobe'], hasLength(3));
      expect(context['wardrobe'][0], {
        'id': '1',
        'name': 'White Tee',
        'category': 'tops',
        'color': 'white',
        'wears': 0,
      });
      // Photos and real ids stay on the device.
      expect(contextJson, isNot(contains('images/')));
      expect(contextJson, isNot(contains('uuid-')));
    },
  );

  test('sends earlier outfits back with short ids and keeps the last '
      '${AiStylistService.maxHistory} messages', () async {
    reply = outfits([], text: 'Sure!');
    final history = [
      for (var i = 0; i < AiStylistService.maxHistory; i++)
        const StylistMessage.user('filler'),
      const StylistMessage.stylist(
        'Try this',
        outfits: [
          OutfitSuggestion(
            name: 'Look',
            itemIds: ['uuid-tee', 'uuid-gone', 'uuid-shoes'],
            reason: 'Clean.',
          ),
        ],
      ),
      const StylistMessage.user(
        'Other shoes please',
        itemIds: ['uuid-shoes', 'uuid-gone'],
      ),
    ];

    final result = await service().reply(wardrobe: wardrobe, history: history);
    expect(result.text, 'Sure!');
    expect(result.outfits, isEmpty);

    final messages = sentBody!['messages'] as List;
    // Persona, context, then the newest messages only.
    expect(messages, hasLength(2 + AiStylistService.maxHistory));
    // Attached pieces are named by their short ids.
    expect(
      messages.last['content'],
      'Other shoes please\n(Attached pieces, by id: 3)',
    );
    final earlier = messages[messages.length - 2];
    expect(earlier['role'], 'assistant');
    expect(jsonDecode(earlier['content'] as String), {
      'reply': 'Try this',
      'outfits': [
        {
          'name': 'Look',
          // An item no longer in the wardrobe is left out.
          'itemIds': ['1', '3'],
          'reason': 'Clean.',
        },
      ],
      'packingItemIds': <String>[],
      'shopping': <Object>[],
    });
  });

  test('reads its settings from the config file contents', () {
    final gemini = AiStylistService.fromConfig(
      '{"OPENAI_API_KEY": " key-1 ", "AI_BASE_URL": "https://example.test/v1", '
      '"AI_MODEL": "some-model"}',
    );
    expect(gemini.apiKey, 'key-1');
    expect(gemini.baseUrl, 'https://example.test/v1');
    expect(gemini.model, 'some-model');

    final keyOnly = AiStylistService.fromConfig('{"OPENAI_API_KEY": "k"}');
    expect(keyOnly.isConfigured, isTrue);
    expect(keyOnly.baseUrl, AiStylistService.defaultBaseUrl);
    expect(keyOnly.model, AiStylistService.defaultModel);

    final muse = AiStylistService.fromConfig('{"MUSE_API_KEY": "m"}');
    expect(muse.isConfigured, isTrue);
    // Muse Image draws try-ons on the same key.
    expect(muse.canTryOn, isTrue);
    expect(muse.museImageModel, AiStylistService.defaultMuseImageModel);
    expect(muse.primary, (
      apiKey: 'm',
      baseUrl: AiStylistService.museBaseUrl,
      model: AiStylistService.museModel,
    ));
    expect(keyOnly.primary, isNull);

    for (final broken in ['', 'not json', '[]', '{"OPENAI_API_KEY": 5}']) {
      expect(AiStylistService.fromConfig(broken).isConfigured, isFalse);
    }
  });

  test('sends only the newest photo, as a data URL', () async {
    final dir = await Directory.systemTemp.createTemp('stylist');
    addTearDown(() => dir.delete(recursive: true));
    final newer = File('${dir.path}/new.png')
      ..writeAsBytesSync([0x89, 0x50, 0x4E, 0x47, 1, 2]);
    File('${dir.path}/old.jpg').writeAsBytesSync([9]);

    await service().reply(
      wardrobe: wardrobe,
      history: const [
        StylistMessage.user('Old look', photo: 'old.jpg'),
        StylistMessage.stylist('Nice'),
        StylistMessage.user('Match this', photo: 'new.png'),
      ],
      resolvePhoto: (photo) => '${dir.path}/$photo',
    );

    final messages = sentBody!['messages'] as List;
    expect(messages[2]['content'], 'Old look');
    expect(messages.last['content'], [
      {'type': 'text', 'text': 'Match this'},
      {
        'type': 'image_url',
        'image_url': {
          'url':
              'data:image/png;base64,${base64Encode(newer.readAsBytesSync())}',
        },
      },
    ]);

    // A photo that is gone leaves just the text.
    await service().reply(
      wardrobe: wardrobe,
      history: const [StylistMessage.user('Match this', photo: 'gone.jpg')],
      resolvePhoto: (photo) => '${dir.path}/$photo',
    );
    expect((sentBody!['messages'] as List).last['content'], 'Match this');

    // Photos kept in cloud storage are downloaded first.
    final url = 'http://127.0.0.1:${server.port}/u/photo.webp?v=1';
    await service().reply(
      wardrobe: wardrobe,
      history: [StylistMessage.user('Cloud', photo: url)],
      resolvePhoto: (photo) => photo,
    );
    final content = (sentBody!['messages'] as List).last['content'] as List;
    expect(
      content.last['image_url']['url'],
      'data:image/webp;base64,${base64Encode(_webp)}',
    );
  });

  test(
    'speaks as the chosen stylist and keeps packing and shopping lists',
    () async {
      reply = jsonEncode({
        'reply': 'Packed! 🧳',
        'outfits': [],
        'packingItemIds': ['1', '2', '1', '99'],
        'shopping': [
          {
            'name': 'Rain jacket',
            'query': 'black rain jacket',
            'reason': 'Wet.',
          },
          {'name': '', 'query': 'x', 'reason': ''},
        ],
      });
      final result = await service().reply(
        wardrobe: wardrobe,
        history: ask,
        persona: StylistPersona.theo,
        notes: ' 1m80, no shorts ',
      );
      expect(result.text, 'Packed! 🧳');
      expect(result.packingList, ['uuid-tee', 'uuid-jeans']);
      expect(result.shopping.single.query, 'black rain jacket');

      final messages = sentBody!['messages'] as List;
      expect(messages[0]['content'], contains('You are Theo'));
      expect(messages[0]['content'], contains(StylistPersona.theo.direction));
      final context = jsonDecode(messages[1]['content'] as String) as Map;
      expect(context['aboutUser'], '1m80, no shorts');

      // The JSON survives a save and reload.
      final copy = StylistMessage.fromJson(
        jsonDecode(jsonEncode(result.toJson())) as Map<String, dynamic>,
      );
      expect(copy.packingList, result.packingList);
      expect(copy.shopping.single.name, 'Rain jacket');
    },
  );

  test('a cancelled request stops at once', () async {
    hold = Completer<void>();
    final cancel = Completer<void>();
    final call = service().reply(
      wardrobe: wardrobe,
      history: ask,
      cancel: cancel.future,
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    cancel.complete();
    await expectLater(call, throwsA(isA<AiException>()));
    hold!.complete();
  });

  group('try-on', () {
    AiStylistService gemini() => AiStylistService(
      apiKey: 'test-key',
      baseUrl: 'http://127.0.0.1:${server.port}/v1beta/openai',
      imageModel: 'image-model',
      qualityImageModel: 'quality-model',
    );

    String pictureResponse(List<int> picture) => jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {
                'inlineData': {
                  'mimeType': 'image/png',
                  'data': base64Encode(picture),
                },
              },
            ],
          },
        },
      ],
    });

    test(
      'sends the person and pieces to Gemini and returns the picture',
      () async {
        final picture = [0x89, 0x50, 0x4E, 0x47, 9];
        rawResponse = jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'Here you go'},
                  {
                    'inlineData': {
                      'mimeType': 'image/png',
                      'data': base64Encode(picture),
                    },
                  },
                ],
              },
            },
          ],
        });

        expect(service().canTryOn, isFalse);
        final result = await gemini().tryOn(
          person: [0xFF, 0xD8, 1],
          pieces: [
            for (var i = 0; i < 6; i++) [0xFF, 0xD8, i],
          ],
        );

        expect(result, picture);
        expect(sentPath, '/v1beta/models/image-model:generateContent');
        expect(sentGoogleKey, 'test-key');
        final parts = sentBody!['contents'][0]['parts'] as List;
        // The prompt, the person, then at most five pieces.
        expect(parts, hasLength(2 + AiStylistService.maxTryOnPieces));
        expect(parts[1]['inline_data'], {
          'mime_type': 'image/jpeg',
          'data': base64Encode([0xFF, 0xD8, 1]),
        });
        expect(sentBody!['generationConfig'], {
          'responseModalities': ['IMAGE'],
          'imageConfig': {'aspectRatio': '3:4'},
        });
      },
    );

    test('draws an AI model with the body type, scene and notes', () async {
      rawResponse = pictureResponse([0x89, 0x50, 0x4E, 0x47]);
      await gemini().tryOn(
        pieces: [
          [0xFF, 0xD8, 1],
          [0xFF, 0xD8, 2],
        ],
        bodyType: 'a man with a slim build',
        appearance: 'short beard',
        scene: 'a skatepark',
        notes: ' oversized fit ',
        highQuality: true,
      );

      expect(sentPath, '/v1beta/models/quality-model:generateContent');
      final parts = sentBody!['contents'][0]['parts'] as List;
      // No photo of the user: only the prompt and the two pieces.
      expect(parts, hasLength(3));
      final prompt = parts[0]['text'] as String;
      expect(prompt, contains('fashion model, a man with a slim build'));
      expect(prompt, contains('last 2 images'));
      expect(prompt, contains('Setting: a skatepark.'));
      expect(prompt, contains('How the person looks: short beard.'));
      expect(prompt, contains('Styling notes from the user: oversized fit.'));
    });

    test('tries Muse Image first and falls back to Gemini', () async {
      final picture = [0x89, 0x50, 0x4E, 0x47, 5];
      // Both shapes in one answer: Muse reads data, Gemini candidates.
      rawResponse = jsonEncode({
        'data': [
          {'b64_json': base64Encode(picture)},
        ],
        ...jsonDecode(pictureResponse(picture)) as Map<String, dynamic>,
      });
      final both = AiStylistService(
        apiKey: 'gemini-key',
        baseUrl: 'http://127.0.0.1:${server.port}/v1beta/openai',
        imageModel: 'image-model',
        primary: (
          apiKey: 'muse-key',
          baseUrl: 'http://127.0.0.1:${server.port}/muse',
          model: 'muse-model',
        ),
      );
      Future<List<int>> draw() => both.tryOn(
        person: [0xFF, 0xD8, 7],
        pieces: [
          [0xFF, 0xD8, 1],
        ],
      );

      expect(await draw(), picture);
      expect(paths, ['/muse/images/edits']);
      expect(sentAuth, 'Bearer muse-key');
      expect(sentBody!['model'], AiStylistService.defaultMuseImageModel);
      expect(sentBody!['images'], [
        {
          'image_url':
              'data:image/jpeg;base64,${base64Encode([0xFF, 0xD8, 7])}',
        },
        {
          'image_url':
              'data:image/jpeg;base64,${base64Encode([0xFF, 0xD8, 1])}',
        },
      ]);
      expect(sentBody!['prompt'], contains("person's face"));

      // No billing on Muse: Gemini draws it instead.
      paths.clear();
      museStatus = HttpStatus.paymentRequired;
      expect(await draw(), picture);
      expect(paths, [
        '/muse/images/edits',
        '/v1beta/models/image-model:generateContent',
      ]);

      // Muse alone can try on too.
      expect(
        const AiStylistService(
          apiKey: '',
          primary: (apiKey: 'k', baseUrl: 'https://x', model: 'm'),
        ).canTryOn,
        isTrue,
      );
    });

    test('falls back to Cloudflare FLUX.2 with at most four images', () async {
      final picture = [0xFF, 0xD8, 0xFF, 9];
      rawResponse = jsonEncode({
        'result': {'image': base64Encode(picture)},
        'success': true,
      });
      final shrunk = <int>[];
      final all = AiStylistService(
        apiKey: 'gemini-key',
        baseUrl: 'http://127.0.0.1:${server.port}/v1beta/openai',
        imageModel: 'image-model',
        primary: (
          apiKey: 'muse-key',
          baseUrl: 'http://127.0.0.1:${server.port}/muse',
          model: 'muse-model',
        ),
        cloudflare: (
          baseUrl: 'http://127.0.0.1:${server.port}/cf',
          accountId: 'acc',
          apiToken: 'cf-token',
          model: '@cf/flux',
        ),
        shrinkImage: (image, maxSide) async {
          shrunk.add(maxSide);
          return image;
        },
      );
      // Muse has no billing and Gemini no image quota.
      museStatus = HttpStatus.paymentRequired;
      status = HttpStatus.tooManyRequests;

      final drawn = await all.tryOn(
        person: [0xFF, 0xD8, 7],
        body: [0xFF, 0xD8, 8],
        pieces: [
          for (var i = 0; i < 5; i++) [0xFF, 0xD8, i],
        ],
      );

      expect(drawn, picture);
      expect(paths, [
        '/muse/images/edits',
        '/v1beta/models/image-model:generateContent',
        '/cf/accounts/acc/ai/run/@cf/flux',
      ]);
      expect(sentAuth, 'Bearer cf-token');
      // The selfie and three pieces; the body photo and two pieces are left
      // out, and each image is shrunk.
      expect(shrunk, [511, 511, 511, 511]);
      expect(sentRaw, contains('name="input_image_3"'));
      expect(sentRaw, isNot(contains('name="input_image_4"')));
      expect(sentRaw, contains('the person in image 1'));
      expect(sentRaw, contains('images 2 to 4'));
      expect(sentRaw, contains('fully clothed'));
      expect(sentRaw, contains('name="height"'));
    });

    test('tries Cloudflare again when its filter flags a picture', () async {
      final flux = AiStylistService(
        apiKey: '',
        cloudflare: (
          baseUrl: 'http://127.0.0.1:${server.port}/cf',
          accountId: 'acc',
          apiToken: 'cf-token',
          model: '@cf/flux',
        ),
        shrinkImage: (image, _) async => image,
      );
      cfStatus = HttpStatus.badRequest;
      rawResponse = jsonEncode({
        'errors': [
          {'message': 'AiError: Your output has been flagged.', 'code': 3030},
        ],
        'success': false,
      });
      await expectLater(
        flux.tryOn(
          person: [0xFF, 0xD8, 7],
          pieces: [
            [0xFF, 0xD8, 1],
          ],
        ),
        throwsA(
          isA<AiException>().having(
            (e) => e.message,
            'message',
            contains('safety filter'),
          ),
        ),
      );
      expect(paths, hasLength(4));

      // Other errors are shown with the provider's reason, without retrying.
      paths.clear();
      rawResponse = jsonEncode({
        'errors': [
          {'message': 'Bad input image', 'code': 5006},
        ],
      });
      await expectLater(
        flux.tryOn(
          pieces: [
            [0xFF, 0xD8, 1],
          ],
        ),
        throwsA(
          isA<AiException>().having(
            (e) => e.message,
            'message',
            'The AI service returned an error (400): Bad input image',
          ),
        ),
      );
      expect(paths, hasLength(1));
    });

    test('sends the selfie before the full-body photo', () async {
      rawResponse = pictureResponse([0x89, 0x50, 0x4E, 0x47]);
      await gemini().tryOn(
        person: [0xFF, 0xD8, 7],
        body: [0xFF, 0xD8, 8],
        pieces: [
          [0xFF, 0xD8, 1],
        ],
      );

      expect(sentPath, '/v1beta/models/image-model:generateContent');
      final parts = sentBody!['contents'][0]['parts'] as List;
      expect(parts, hasLength(4));
      expect(parts[0]['text'], contains('selfie'));
      expect(parts[1]['inline_data']['data'], base64Encode([0xFF, 0xD8, 7]));
      expect(parts[2]['inline_data']['data'], base64Encode([0xFF, 0xD8, 8]));
    });

    test('explains a plan without image generation', () async {
      status = HttpStatus.tooManyRequests;
      rawResponse = '{"error": {"message": "Quota exceeded, limit: 0"}}';
      await expectLater(
        gemini().tryOn(
          person: [1],
          pieces: [
            [2],
          ],
        ),
        throwsA(
          isA<AiException>().having(
            (e) => e.message,
            'message',
            contains('billing'),
          ),
        ),
      );

      status = HttpStatus.ok;
      rawResponse = '{"candidates": []}';
      await expectLater(
        gemini().tryOn(
          person: [1],
          pieces: [
            [2],
          ],
        ),
        throwsA(isA<AiException>()),
      );
    });
  });

  test('reads JSON wrapped in a code fence', () async {
    final json = outfits([
      {
        'name': 'Fenced',
        'itemIds': ['1', '2'],
        'reason': 'ok',
      },
    ]);
    reply = 'Here you go:\n```json\n$json\n```';
    final result = await service().reply(wardrobe: wardrobe, history: ask);
    expect(result.outfits.single.name, 'Fenced');
  });

  test('asks Muse first and falls back when it runs out of quota', () async {
    AiStylistService both({String apiKey = 'gemini-key'}) => AiStylistService(
      apiKey: apiKey,
      baseUrl: 'http://127.0.0.1:${server.port}',
      model: 'gemini-model',
      primary: (
        apiKey: 'muse-key',
        baseUrl: 'http://127.0.0.1:${server.port}/muse',
        model: 'muse-model',
      ),
    );
    Future<Object> send(AiStylistService stylist) async {
      try {
        return await stylist.reply(wardrobe: wardrobe, history: ask);
      } on AiException catch (error) {
        return error.message;
      }
    }

    expect(await send(both()), isA<StylistMessage>());
    expect(paths, ['/muse/chat/completions']);
    expect(sentAuth, 'Bearer muse-key');
    expect(sentBody!['model'], 'muse-model');

    for (final outOfQuota in [
      HttpStatus.paymentRequired,
      HttpStatus.tooManyRequests,
    ]) {
      paths.clear();
      museStatus = outOfQuota;
      expect(await send(both()), isA<StylistMessage>());
      expect(paths, ['/muse/chat/completions', '/chat/completions']);
      expect(sentAuth, 'Bearer gemini-key');
      expect(sentBody!['model'], 'gemini-model');
    }

    // Other failures are not a reason to switch.
    paths.clear();
    museStatus = HttpStatus.unauthorized;
    expect(await send(both()), contains('API key'));
    expect(paths, ['/muse/chat/completions']);

    // Without a Gemini key, Muse's error is shown.
    museStatus = HttpStatus.paymentRequired;
    final museOnly = both(apiKey: '');
    expect(museOnly.isConfigured, isTrue);
    expect(museOnly.canTryOn, isTrue);
    expect(await send(museOnly), contains('out of credits'));
  });

  test('turns failures into user-facing errors', () async {
    Future<String> messageOf(AiStylistService stylist) async {
      try {
        await stylist.reply(wardrobe: wardrobe, history: ask);
      } on AiException catch (error) {
        return error.message;
      }
      fail('Expected an AiException');
    }

    // Neither text nor a usable outfit.
    reply = outfits([
      {
        'name': 'Ghost',
        'itemIds': ['98', '99'],
        'reason': '',
      },
    ], text: ' ');
    expect(await messageOf(service()), contains('could not be read'));

    reply = 'not json at all';
    expect(await messageOf(service()), contains('could not be read'));

    status = HttpStatus.unauthorized;
    expect(await messageOf(service()), contains('API key'));

    status = HttpStatus.serviceUnavailable;
    expect(await messageOf(service()), contains('busy right now'));

    // Without a key no request is made at all.
    sentBody = null;
    final unconfigured = service(apiKey: '');
    expect(unconfigured.isConfigured, isFalse);
    expect(await messageOf(unconfigured), contains('not set up'));
    expect(sentBody, isNull);

    final offline = service();
    await server.close(force: true);
    expect(await messageOf(offline), contains('Could not reach'));
  });
}
