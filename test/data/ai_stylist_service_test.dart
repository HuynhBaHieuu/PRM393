import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_color.dart';
import 'package:all_fits/data/models/clothing_item.dart';
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

void main() {
  // A local stand-in for the chat completions endpoint, so the real HTTP
  // path is exercised without a network or an API key.
  late HttpServer server;
  late int status;
  late String reply;
  Map<String, dynamic>? sentBody;
  String? sentAuth;

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
    reply = outfits([]);
    sentBody = null;
    sentAuth = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      // Photos uploaded to cloud storage are fetched by URL.
      if (request.method == 'GET') {
        request.response.add([7, 7]);
        await request.response.close();
        return;
      }
      sentAuth = request.headers.value(HttpHeaders.authorizationHeader);
      sentBody = jsonDecode(
        await utf8.decoder.bind(request).join(),
      ) as Map<String, dynamic>;
      request.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'choices': [
              {
                'message': {'content': reply},
              },
            ],
          }),
        );
      await request.response.close();
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

    for (final broken in ['', 'not json', '[]', '{"OPENAI_API_KEY": 5}']) {
      expect(AiStylistService.fromConfig(broken).isConfigured, isFalse);
    }
  });

  test('sends only the newest photo, as a data URL', () async {
    final dir = await Directory.systemTemp.createTemp('stylist');
    addTearDown(() => dir.delete(recursive: true));
    final newer = File('${dir.path}/new.png')..writeAsBytesSync([1, 2, 3]);
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
          'url': 'data:image/png;base64,${base64Encode(newer.readAsBytesSync())}',
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
      'data:image/webp;base64,${base64Encode([7, 7])}',
    );
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
