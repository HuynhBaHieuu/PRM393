import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:all_fits/app/app.dart';
import 'package:all_fits/app/app_dependencies.dart';
import 'package:all_fits/data/sample/sample_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Photo credits appear on the licenses page (Settings).
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'Sample wardrobe photos',
    ], await rootBundle.loadString(SampleData.photoCreditsAsset));
  });
  final dependencies = await AppDependencies.production();
  runApp(AllFitsApp(dependencies: dependencies));
}
