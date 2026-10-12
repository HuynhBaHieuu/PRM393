import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/app_bootstrap.dart';
import 'package:all_fits/app/app_dependencies.dart';
import 'package:all_fits/app/app_material_app.dart';
import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/widgets/feedback_views.dart';
import 'package:all_fits/data/local/image_picker_service.dart';
import 'package:all_fits/data/local/image_storage_service.dart';
import 'package:all_fits/data/models/user_account.dart';
import 'package:all_fits/data/remote/ai_stylist_service.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/planner/controllers/planner_controller.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/shared/closet_actions.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/navigation/app_navigation.dart';

/// Everything that belongs to one signed-in user: their controllers,
/// providers and navigation stack. Keyed by user id, so signing out or
/// switching accounts disposes it and starts fresh.
class UserSession extends StatefulWidget {
  const UserSession({
    super.key,
    required this.dependencies,
    required this.user,
  });

  final AppDependencies dependencies;
  final AppUser user;

  @override
  State<UserSession> createState() => _UserSessionState();
}

class _UserSessionState extends State<UserSession> {
  late final SettingsController _settings;
  late final WardrobeController _wardrobe;
  late final OutfitController _outfits;
  late final PlannerController _planner;
  late final ClosetActions _closet;
  late final ShellController _shell;
  late final AppBootstrap _bootstrap;
  late Future<void> _startup;

  @override
  void initState() {
    super.initState();
    final deps = widget.dependencies;
    final repositories = deps.repositoriesFor(widget.user.id);
    _settings = SettingsController(repository: repositories.settings);
    _wardrobe = WardrobeController(
      repository: repositories.wardrobe,
      imageStorage: deps.imageStorage,
      idGenerator: deps.idGenerator,
      clock: deps.clock,
    );
    _outfits = OutfitController(
      repository: repositories.outfits,
      idGenerator: deps.idGenerator,
      clock: deps.clock,
    );
    _planner = PlannerController(
      repository: repositories.calendar,
      idGenerator: deps.idGenerator,
    );
    _closet = ClosetActions(
      wardrobe: _wardrobe,
      outfits: _outfits,
      planner: _planner,
      idGenerator: deps.idGenerator,
      clock: deps.clock,
    );
    _shell = ShellController();
    _bootstrap = AppBootstrap(
      user: widget.user,
      settings: _settings,
      wardrobe: _wardrobe,
      outfits: _outfits,
      planner: _planner,
      closet: _closet,
      seedSampleData: deps.seedSampleData,
    );
    _startup = _bootstrap.run();
  }

  @override
  void dispose() {
    _settings.dispose();
    _wardrobe.dispose();
    _outfits.dispose();
    _planner.dispose();
    _shell.dispose();
    super.dispose();
  }

  void _retry() => setState(() => _startup = _bootstrap.run());

  @override
  Widget build(BuildContext context) {
    final deps = widget.dependencies;
    return MultiProvider(
      providers: [
        Provider<AppUser>.value(value: widget.user),
        Provider<ImageStorageService>.value(value: deps.imageStorage),
        Provider<ImagePickerService>.value(value: deps.imagePicker),
        Provider<AiStylistService>.value(value: deps.aiStylist),
        ChangeNotifierProvider.value(value: _settings),
        ChangeNotifierProvider.value(value: _wardrobe),
        ChangeNotifierProvider.value(value: _outfits),
        ChangeNotifierProvider.value(value: _planner),
        ChangeNotifierProvider.value(value: _shell),
        Provider.value(value: _closet),
      ],
      child: Selector<SettingsController, ThemeMode>(
        selector: (_, settings) => settings.themeMode,
        builder: (context, themeMode, _) => AppMaterialApp(
          themeMode: themeMode,
          onGenerateRoute: AppRoutes.onGenerateRoute,
          home: FutureBuilder<void>(
            future: _startup,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const AppSplashView();
              }
              if (snapshot.hasError) {
                return Scaffold(
                  body: AppErrorView(error: snapshot.error!, onRetry: _retry),
                );
              }
              return const AppShell();
            },
          ),
        ),
      ),
    );
  }
}
