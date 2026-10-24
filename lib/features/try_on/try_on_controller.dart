import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/constants/storage_keys.dart';
import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/utils/id_generator.dart';
import 'package:all_fits/core/utils/json_reader.dart';
import 'package:all_fits/data/local/image_storage_service.dart';
import 'package:all_fits/data/local/json_collection_store.dart';
import 'package:all_fits/data/local/local_storage_service.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/subscription_plan.dart';
import 'package:all_fits/data/models/try_on.dart';
import 'package:all_fits/data/remote/ai_stylist_service.dart';
import 'package:all_fits/data/sample/sample_data.dart';

/// What to draw: these pieces, on whom, where.
class TryOnRequest {
  const TryOnRequest({
    required this.itemIds,
    this.outfitId,
    this.background = TryOnBackground.studio,
    this.wearer = TryOnWearer.me,
    this.highQuality = false,
    this.notes = '',
  });

  final List<String> itemIds;
  final String? outfitId;
  final TryOnBackground background;
  final TryOnWearer wearer;
  final bool highQuality;
  final String notes;
}

/// One user's try-on profile, their generated pictures and the credits they
/// have used. A picture is drawn by [generate], which keeps running when the
/// screen that started it closes; [onBackgroundResult] then tells the user.
///
/// ponytail: kept on the device and the AI is called from the app, so the
/// credit count resets with the app data; move both behind a server function
/// before charging real money for credits.
class TryOnController extends ChangeNotifier {
  TryOnController({
    required LocalStorageService storage,
    required this._images,
    required this._service,
    required this._idGenerator,
    this._clock = systemClock,
    this._tempDirectory = getTemporaryDirectory,
  }) : _storage = storage,
       _store = JsonCollectionStore<TryOnResult>(
         storage: storage,
         key: StorageKeys.tryOnResults,
         fromJson: TryOnResult.fromJson,
         toJson: (result) => result.toJson(),
         idOf: (result) => result.id,
       );

  final LocalStorageService _storage;
  final JsonCollectionStore<TryOnResult> _store;
  final ImageStorageService _images;
  final AiStylistService _service;
  final IdGenerator _idGenerator;
  final Clock _clock;
  final Future<Directory> Function() _tempDirectory;

  TryOnProfile _profile = const TryOnProfile();
  List<TryOnResult> _results = const [];
  String _usageMonth = '';
  int _usedThisMonth = 0;
  int _usedEver = 0;
  Future<void>? _loading;

  TryOnRequest? _job;
  Completer<void>? _cancel;
  int _viewers = 0;
  bool _disposed = false;

  /// Called with a finished picture, or the error, when no try-on screen
  /// is open to show it.
  void Function(TryOnResult result)? onBackgroundResult;
  void Function(Object error)? onBackgroundError;

  TryOnProfile get profile => _profile;

  /// Newest first.
  List<TryOnResult> get results => _results;

  /// The request being drawn right now, or null.
  TryOnRequest? get job => _job;

  bool get isGenerating => _job != null;

  /// Whether this build has an image AI to draw with.
  bool get isAvailable => _service.canTryOn;

  String get _month {
    final now = _clock();
    return '${now.year}-${now.month}';
  }

  int get usedThisMonth => _usageMonth == _month ? _usedThisMonth : 0;

  /// Pictures [plan] can still make: this month for Premium, ever for Free.
  int creditsLeft(SubscriptionPlan plan) => plan.isPremium
      ? math.max(0, AppConfig.premiumTryOnsPerMonth - usedThisMonth)
      : math.max(0, AppConfig.freeTryOns - _usedEver);

  List<TryOnResult> resultsForOutfit(String outfitId) => [
    for (final result in _results)
      if (result.outfitId == outfitId) result,
  ];

  TryOnResult? resultById(String id) =>
      _results.where((r) => r.id == id).firstOrNull;

  /// A try-on screen is showing; background notices wait until [unwatch].
  void watch() => _viewers++;

  void unwatch() => _viewers = math.max(0, _viewers - 1);

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    _results = await _store.readAll()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    try {
      final profile = await _storage.read(StorageKeys.tryOnProfile);
      if (jsonDecode(profile ?? '{}') case final Map json) {
        _profile = TryOnProfile.fromJson(Map<String, dynamic>.from(json));
      }
      final usage = await _storage.read(StorageKeys.tryOnUsage);
      if (jsonDecode(usage ?? '{}') case final Map json) {
        final map = Map<String, dynamic>.from(json);
        _usageMonth = JsonReader.string(map, 'month') ?? '';
        _usedThisMonth = JsonReader.integer(map, 'count');
        _usedEver = JsonReader.integer(map, 'ever');
      }
    } catch (error) {
      developer.log('Try-on data unreadable', name: 'storage', error: error);
    }
    notifyListeners();
  }

  /// The user agreed to send their photos to the AI provider.
  Future<void> consent() => _saveProfile(_profile.copyWith(consented: true));

  Future<void> setBodyType(BodyType type) =>
      _saveProfile(_profile.copyWith(bodyType: type));

  Future<void> setAppearance(String appearance) =>
      _saveProfile(_profile.copyWith(appearance: appearance.trim()));

  /// Replaces the selfie with [reference] (or removes it when null) and
  /// deletes the old photo.
  Future<void> setSelfie(String? reference) async {
    final old = _profile.selfiePhoto;
    await _saveProfile(_profile.copyWith(selfiePhoto: () => reference));
    if (old != null && old != reference) await _images.deleteImage(old);
  }

  /// Like [setSelfie], for the full-body photo.
  Future<void> setBodyPhoto(String? reference) async {
    final old = _profile.bodyPhoto;
    await _saveProfile(_profile.copyWith(bodyPhoto: () => reference));
    if (old != null && old != reference) await _images.deleteImage(old);
  }

  Future<void> _saveProfile(TryOnProfile profile) async {
    await _storage.write(
      StorageKeys.tryOnProfile,
      jsonEncode(profile.toJson()),
    );
    _profile = profile;
    notifyListeners();
  }

  /// Draws [request] with [items] (its pieces, in wardrobe form) and saves
  /// the picture. Only a picture that comes back uses a credit. Resolves to
  /// null when [cancel] stops it.
  Future<TryOnResult?> generate(
    TryOnRequest request,
    List<ClothingItem> items, {
    required SubscriptionPlan plan,
  }) async {
    if (_job != null) {
      throw const AiException('A try-on is already being drawn.');
    }
    if (creditsLeft(plan) <= 0) {
      throw const PlanLimitException('You have no AI try-on credits left.');
    }
    final cancel = Completer<void>();
    _job = request;
    _cancel = cancel;
    notifyListeners();
    try {
      final result = await _draw(request, items, cancel.future);
      if (cancel.isCompleted) {
        await _images.deleteImage(result.photo);
        return null;
      }
      await _store.upsertAll([result]);
      _results = [result, ..._results];
      await _countUse();
      if (_viewers == 0) onBackgroundResult?.call(result);
      return result;
    } catch (error) {
      if (cancel.isCompleted) return null;
      if (_viewers == 0) onBackgroundError?.call(error);
      rethrow;
    } finally {
      _job = null;
      _cancel = null;
      if (!_disposed) notifyListeners();
    }
  }

  /// Stops the picture being drawn; nothing is saved or counted.
  void cancel() {
    final cancel = _cancel;
    if (cancel != null && !cancel.isCompleted) cancel.complete();
  }

  Future<TryOnResult> _draw(
    TryOnRequest request,
    List<ClothingItem> items,
    Future<void> cancel,
  ) async {
    List<int>? selfie;
    List<int>? body;
    if (request.wearer == TryOnWearer.me) {
      selfie = await _readStored(_profile.selfiePhoto);
      body = await _readStored(_profile.bodyPhoto);
      if (selfie == null && body == null) {
        throw const AiException(
          'Your try-on photo could not be loaded. Add it again in your '
          'try-on profile.',
        );
      }
    }
    final pieces = [
      for (final item in items.take(AiStylistService.maxTryOnPieces))
        ?await photoOf(item, _images),
    ];
    if (pieces.isEmpty) {
      throw const AiException('These clothes have no photos to try on.');
    }
    final picture = await _service.tryOn(
      person: selfie,
      body: body,
      pieces: pieces,
      bodyType: (_profile.bodyType ?? BodyType.fallback).prompt,
      appearance: _profile.appearance,
      scene: request.background.prompt,
      notes: request.notes,
      highQuality: request.highQuality,
      cancel: cancel,
    );
    final extension = switch (AiStylistService.mimeOf(picture)) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => 'jpg',
    };
    final dir = await _tempDirectory();
    final file = File(
      '${dir.path}/tryon_${_clock().microsecondsSinceEpoch}.$extension',
    );
    await file.writeAsBytes(picture);
    try {
      return TryOnResult(
        id: _idGenerator.next(),
        photo: await _images.saveImage(file.path),
        itemIds: [for (final item in items) item.id],
        createdAt: _clock(),
        outfitId: request.outfitId,
        background: request.background,
        wearer: request.wearer,
      );
    } finally {
      await file.delete();
    }
  }

  Future<List<int>?> _readStored(String? reference) async {
    if (reference == null) return null;
    return AiStylistService.readImage(
      _images.resolvePath(reference) ?? reference,
    );
  }

  /// The photo of [item]: the user's own, or a sample's bundled one.
  static Future<List<int>?> photoOf(
    ClothingItem item,
    ImageStorageService images,
  ) async {
    final reference = item.imagePath;
    if (reference != null) {
      final location = images.resolvePath(reference);
      return location == null ? null : AiStylistService.readImage(location);
    }
    final asset = SampleData.photoFor(item.id);
    if (asset == null) return null;
    final data = await rootBundle.load(asset);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  Future<void> _countUse() async {
    final month = _month;
    final count = usedThisMonth + 1;
    final ever = _usedEver + 1;
    try {
      await _storage.write(
        StorageKeys.tryOnUsage,
        jsonEncode({'month': month, 'count': count, 'ever': ever}),
      );
    } catch (error) {
      // The picture is saved; never lose it over the counter.
      developer.log('Try-on use not counted', name: 'storage', error: error);
    }
    _usageMonth = month;
    _usedThisMonth = count;
    _usedEver = ever;
  }

  Future<void> delete(String id) async {
    final gone = resultById(id);
    if (gone == null) return;
    await _store.removeIds([id]);
    _results = [..._results.where((r) => r.id != id)];
    notifyListeners();
    await _images.deleteImage(gone.photo);
  }

  @override
  void dispose() {
    _disposed = true;
    cancel();
    super.dispose();
  }
}
