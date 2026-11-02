import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';

import 'package:all_fits/core/constants/storage_keys.dart';
import 'package:all_fits/core/l10n/l10n.dart';
import 'package:all_fits/data/local/local_storage_service.dart';

/// The app's language. Kept on the device, not per account, so the sign-in
/// screens use it too. Without a saved choice it follows the phone.
class LanguageController extends ChangeNotifier {
  LanguageController(this._storage);

  final LocalStorageService _storage;

  AppLanguage get language => L10n.current;

  Locale get locale => Locale(language.name);

  /// Reads the saved language; call before the first frame.
  Future<void> load() async {
    String? saved;
    try {
      saved = await _storage.read(StorageKeys.language);
    } catch (error) {
      developer.log('Language not read', name: 'l10n', error: error);
    }
    L10n.current = AppLanguage.values.asNameMap()[saved] ?? _deviceLanguage();
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (language == L10n.current) return;
    L10n.current = language;
    notifyListeners();
    _rebuildAll();
    try {
      await _storage.write(StorageKeys.language, language.name);
    } catch (error) {
      developer.log('Language not saved', name: 'l10n', error: error);
    }
  }

  static AppLanguage _deviceLanguage() {
    final code = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return code == AppLanguage.vi.name ? AppLanguage.vi : AppLanguage.en;
  }

  /// Text from [tr] isn't tied to any widget, so every widget rebuilds.
  static void _rebuildAll() {
    void rebuild(Element element) {
      element.markNeedsBuild();
      element.visitChildren(rebuild);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(rebuild);
  }
}
