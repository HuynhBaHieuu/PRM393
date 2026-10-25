import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/constants/storage_keys.dart';
import 'package:all_fits/core/utils/id_generator.dart';
import 'package:all_fits/core/utils/json_reader.dart';
import 'package:all_fits/data/local/local_storage_service.dart';
import 'package:all_fits/data/models/subscription_plan.dart';
import 'package:all_fits/data/remote/ai_stylist_service.dart';

/// AI detection of new pieces from their photo: whether the user agreed to
/// send photos and still wants it, and how many detections Free has used
/// this month.
///
/// ponytail: the count lives on the device, like the try-on credits, so it
/// resets with the app data; move it behind a server function if it ever
/// costs real money.
class AutoDetectController extends ChangeNotifier {
  AutoDetectController({
    required this._storage,
    required this._service,
    this._clock = systemClock,
    this._readFile = _readBytes,
  });

  final LocalStorageService _storage;
  final AiStylistService _service;
  final Clock _clock;
  final Future<List<int>> Function(String path) _readFile;

  static Future<List<int>> _readBytes(String path) => File(path).readAsBytes();

  bool _consented = false;
  bool _enabled = true;
  bool _tipsSeen = false;
  String _usageMonth = '';
  int _usedThisMonth = 0;
  Future<void>? _loading;

  /// Whether this build has an AI that can read photos.
  bool get isAvailable => _service.isConfigured;

  /// The user agreed to send photos to the AI provider.
  bool get consented => _consented;

  /// Switched on in Settings; on until the user turns it off or declines.
  bool get enabled => _enabled;

  /// Whether the user has seen "How to get best results", shown once before
  /// their first photo, as in Fits.
  bool get tipsSeen => _tipsSeen;

  /// Whether picking a photo should start a detection.
  bool get isOn => isAvailable && _enabled;

  String get _month {
    final now = _clock();
    return '${now.year}-${now.month}';
  }

  int get usedThisMonth => _usageMonth == _month ? _usedThisMonth : 0;

  /// Detections [plan] has left this month, or null for no limit.
  int? left(SubscriptionPlan plan) => plan.isPremium
      ? null
      : math.max(0, AppConfig.freeDetectionsPerMonth - usedThisMonth);

  Future<void> load() => _loading ??= _load();

  Future<void> _load() async {
    try {
      final stored = await _storage.read(StorageKeys.autoDetect);
      if (jsonDecode(stored ?? '{}') case final Map json) {
        final map = Map<String, dynamic>.from(json);
        _consented = JsonReader.boolean(map, 'consented');
        _enabled = JsonReader.boolean(map, 'enabled', fallback: true);
        _tipsSeen = JsonReader.boolean(map, 'tipsSeen');
        _usageMonth = JsonReader.string(map, 'month') ?? '';
        _usedThisMonth = JsonReader.integer(map, 'count');
      }
    } catch (error) {
      developer.log('Detection data unreadable', name: 'storage', error: error);
    }
    notifyListeners();
  }

  /// The user agreed to send photos, which also switches detection on.
  Future<void> consent() {
    _consented = true;
    _enabled = true;
    return _save();
  }

  Future<void> setEnabled(bool enabled) {
    _enabled = enabled;
    return _save();
  }

  Future<void> markTipsSeen() {
    _tipsSeen = true;
    return _save();
  }

  /// Tags the piece in the photo at [path] and counts the detection once it
  /// worked. Throws [AiException] when it didn't.
  Future<ClothingDetection> detect(String path, {Future<void>? cancel}) async {
    final detection = await _service.detectClothing(
      await _readFile(path),
      cancel: cancel,
    );
    _usedThisMonth = usedThisMonth + 1;
    _usageMonth = _month;
    await _save();
    return detection;
  }

  Future<void> _save() async {
    notifyListeners();
    try {
      await _storage.write(
        StorageKeys.autoDetect,
        jsonEncode({
          'consented': _consented,
          'enabled': _enabled,
          'tipsSeen': _tipsSeen,
          'month': _usageMonth,
          'count': _usedThisMonth,
        }),
      );
    } catch (error) {
      // Never lose a detection over the counter.
      developer.log('Detection data not saved', name: 'storage', error: error);
    }
  }
}
