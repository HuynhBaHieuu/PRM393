import 'package:flutter/material.dart';

import 'package:all_fits/app/theme/app_theme.dart';
import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/feedback_views.dart';

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
    return MaterialApp(
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
            Text(AppConfig.appName, style: context.textTheme.displaySmall),
            const SizedBox(height: AppSpacing.lg),
            const AppLoadingView(),
          ],
        ),
      ),
    );
  }
}
