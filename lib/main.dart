import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:all_fits/app/app.dart';
import 'package:all_fits/app/app_dependencies.dart';
import 'package:all_fits/data/sample/sample_data.dart';
import 'package:all_fits/features/settings/controllers/language_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Photo credits appear on the licenses page (Settings).
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'Sample wardrobe photos',
    ], await rootBundle.loadString(SampleData.photoCreditsAsset));
  });
  final dependencies = await AppDependencies.production();
  // Loaded first so the first screen is already in the right language.
  final language = LanguageController(dependencies.storage);
  await language.load();
  runApp(AllFitsApp(dependencies: dependencies, language: language));
}
