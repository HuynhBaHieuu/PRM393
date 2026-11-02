import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/theme/app_theme.dart';
import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/widgets/app_logo.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/widgets/feedback_views.dart';
import 'package:all_fits/features/settings/controllers/language_controller.dart';

/// The app's [MaterialApp] configuration, shared by the signed-out and
/// signed-in trees.
class AppMaterialApp extends StatelessWidget {
  const AppMaterialApp({
    super.key,
    required this.home,
    this.themeMode = ThemeMode.system,
    this.onGenerateRoute,
    this.navigatorKey,
    this.scaffoldMessengerKey,
  });

  final Widget home;
  final ThemeMode themeMode;
  final RouteFactory? onGenerateRoute;

  /// For notices from work that outlives its screen, like a try-on.
  final GlobalKey<NavigatorState>? navigatorKey;
  final GlobalKey<ScaffoldMessengerState>? scaffoldMessengerKey;

  @override
  Widget build(BuildContext context) {
    // Null where a test builds this without the root widget.
    final language = context.watch<LanguageController?>();
    return MaterialApp(
      locale: language?.locale,
      supportedLocales: const [Locale('en'), Locale('vi')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      onGenerateRoute: onGenerateRoute,
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: home,
    );
  }
}

class AppSplashView extends StatelessWidget {
  const AppSplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppWordmark(height: 36),
            const SizedBox(height: AppSpacing.lg),
            const AppLoadingView(),
          ],
        ),
      ),
    );
  }
}
