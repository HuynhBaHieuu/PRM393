import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_color.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/occasion.dart';
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

  String outfits(List<Map<String, Object?>> list) =>
      jsonEncode({'outfits': list});

  setUp(() async {
    status = HttpStatus.ok;
    reply = outfits([]);
    sentBody = null;
    sentAuth = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
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
      reply = outfits([
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

      final result = await service().suggest(
        wardrobe: wardrobe,
        occasion: Occasion.work,
        note: 'Trời mưa',
      );

      expect(result, hasLength(2));
      expect(result[0].name, 'Weekend');
      expect(result[0].itemIds, ['uuid-tee', 'uuid-jeans', 'uuid-shoes']);
      expect(result[0].reason, 'Relaxed and clean.');
      expect(result[1].name, 'AI outfit');

      expect(sentAuth, 'Bearer test-key');
      expect(sentBody!['model'], 'test-model');
      expect(sentBody!['response_format']['json_schema']['strict'], isTrue);
      final messages = sentBody!['messages'] as List;
      final userContent = messages.last['content'] as String;
      final request = jsonDecode(userContent) as Map<String, dynamic>;
      expect(request['occasion'], 'Work');
      expect(request['note'], 'Trời mưa');
      expect(request['wardrobe'], hasLength(3));
      expect(request['wardrobe'][0], {
        'id': '1',
        'name': 'White Tee',
        'category': 'tops',
        'color': 'white',
        'wears': 0,
      });
      // Photos and real ids stay on the device.
      expect(userContent, isNot(contains('images/')));
      expect(userContent, isNot(contains('uuid-')));
    },
  );

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

  test('reads JSON wrapped in a code fence', () async {
    final json = outfits([
      {
        'name': 'Fenced',
        'itemIds': ['1', '2'],
        'reason': 'ok',
      },
    ]);
    reply = 'Here you go:\n```json\n$json\n```';
    final result = await service().suggest(wardrobe: wardrobe);
    expect(result.single.name, 'Fenced');
  });

  test('turns failures into user-facing errors', () async {
    Future<String> messageOf(Future<Object?> call) async {
      try {
        await call;
      } on AiException catch (error) {
        return error.message;
      }
      fail('Expected an AiException');
    }

    // No usable outfits in the reply.
    expect(
      await messageOf(service().suggest(wardrobe: wardrobe)),
      contains('No outfits'),
    );

    reply = 'not json at all';
    expect(
      await messageOf(service().suggest(wardrobe: wardrobe)),
      contains('could not be read'),
    );

    status = HttpStatus.unauthorized;
    expect(
      await messageOf(service().suggest(wardrobe: wardrobe)),
      contains('API key'),
    );

    status = HttpStatus.serviceUnavailable;
    expect(
      await messageOf(service().suggest(wardrobe: wardrobe)),
      contains('busy right now'),
    );

    // Without a key no request is made at all.
    sentBody = null;
    final unconfigured = service(apiKey: '');
    expect(unconfigured.isConfigured, isFalse);
    expect(
      await messageOf(unconfigured.suggest(wardrobe: wardrobe)),
      contains('not set up'),
    );
    expect(sentBody, isNull);

    final offline = service();
    await server.close(force: true);
    expect(
      await messageOf(offline.suggest(wardrobe: wardrobe)),
      contains('Could not reach'),
    );
  });
}
