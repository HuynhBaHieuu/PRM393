import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// The "Today" widget on the phone's home screen. Abstract so tests and
/// unsupported platforms can skip it.
abstract interface class HomeScreenWidget {
  /// Saves [values] and [picture] (a PNG, or null for none) for the widget
  /// and redraws it.
  Future<void> update(Map<String, String?> values, {Uint8List? picture});

  /// Links from widget taps: the one that started the app, then later ones.
  Stream<Uri> get taps;

  /// Whether the widget shows the outfit's picture, so it is worth drawing.
  bool get showsPicture;
}

/// Does nothing; used in tests and where home screen widgets aren't
/// supported.
class NoHomeScreenWidget implements HomeScreenWidget {
  const NoHomeScreenWidget();

  @override
  Future<void> update(
    Map<String, String?> values, {
    Uint8List? picture,
  }) async {}

  @override
  Stream<Uri> get taps => const Stream.empty();

  @override
  bool get showsPicture => false;
}

/// Android's home screen widget through the home_widget plugin. The native
/// side is `TodayWidgetProvider.kt`.
class AndroidHomeScreenWidget implements HomeScreenWidget {
  AndroidHomeScreenWidget();

  /// Must match the provider class in AndroidManifest.xml.
  static const String _provider = 'com.example.all_fits.TodayWidgetProvider';
  static const String _pictureKey = 'today_picture';

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<void> update(Map<String, String?> values, {Uint8List? picture}) async {
    try {
      for (final MapEntry(:key, :value) in values.entries) {
        await HomeWidget.saveWidgetData<String>(key, value);
      }
      if (picture != null) {
        await HomeWidget.saveFile(_pictureKey, picture, extension: 'png');
      } else {
        await HomeWidget.saveWidgetData<String>(_pictureKey, null);
      }
      await HomeWidget.updateWidget(qualifiedAndroidName: _provider);
    } catch (error) {
      developer.log('Widget not updated', name: 'home_widget', error: error);
    }
  }

  @override
  bool get showsPicture => true;

  @override
  Stream<Uri> get taps async* {
    final first = await HomeWidget.initiallyLaunchedFromHomeWidget();
    if (first != null) yield first;
    yield* HomeWidget.widgetClicked.where((uri) => uri != null).cast<Uri>();
  }
}
