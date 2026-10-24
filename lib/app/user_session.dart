import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/app_bootstrap.dart';
import 'package:all_fits/app/app_dependencies.dart';
import 'package:all_fits/app/app_material_app.dart';
import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/storage_keys.dart';
import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/widgets/feedback_views.dart';
import 'package:all_fits/data/local/image_picker_service.dart';
import 'package:all_fits/data/local/image_storage_service.dart';
import 'package:all_fits/data/local/local_storage_service.dart';
import 'package:all_fits/data/models/user_account.dart';
import 'package:all_fits/data/remote/ai_stylist_service.dart';
import 'package:all_fits/data/remote/payos_checkout.dart';
import 'package:all_fits/features/collections/controllers/collection_controller.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/planner/controllers/planner_controller.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/shared/closet_actions.dart';
import 'package:all_fits/features/social/social_controller.dart';
import 'package:all_fits/features/stylist/stylist_store.dart';
import 'package:all_fits/features/try_on/try_on_controller.dart';
import 'package:all_fits/features/try_on/try_on_flows.dart';
import 'package:all_fits/data/models/try_on.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/features/weather/controllers/weather_controller.dart';
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
  late final CollectionController _collections;
  late final WeatherController _weather;
  late final StylistStore _stylist;
  late final TryOnController _tryOn;
  final GlobalKey<NavigatorState> _navigator = GlobalKey();
  final GlobalKey<ScaffoldMessengerState> _messenger = GlobalKey();
  late final ClosetActions _closet;
  late final ShellController _shell;

  /// Null without an online account: every community feature is hidden.
  SocialController? _social;
  late final AppBootstrap _bootstrap;
  late Future<void> _startup;

  @override
  void initState() {
    super.initState();
    final deps = widget.dependencies;
    final repositories = deps.repositoriesFor(widget.user.id);
    _settings = SettingsController(
      repository: repositories.settings,
      clock: deps.clock,
    );
    _wardrobe = WardrobeController(
      repository: repositories.wardrobe,
      imageStorage: deps.imageStorage,
      backgroundRemover: deps.backgroundRemover,
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
    _collections = CollectionController(
      repository: repositories.collections,
      imageStorage: deps.imageStorage,
      idGenerator: deps.idGenerator,
      clock: deps.clock,
    );
    _weather = WeatherController(service: deps.weather, clock: deps.clock);
    _stylist = StylistStore(
      storage: ScopedStorageService(
        deps.storage,
        StorageKeys.userScope(widget.user.id),
      ),
      idGenerator: deps.idGenerator,
      images: deps.imageStorage,
      clock: deps.clock,
    );
    _tryOn =
        TryOnController(
            storage: ScopedStorageService(
              deps.storage,
              StorageKeys.userScope(widget.user.id),
            ),
            images: deps.imageStorage,
            service: deps.aiStylist,
            idGenerator: deps.idGenerator,
            clock: deps.clock,
          )
          ..onBackgroundResult = _tryOnReady
          ..onBackgroundError = _tryOnFailed
          ..load();
    _closet = ClosetActions(
      wardrobe: _wardrobe,
      outfits: _outfits,
      planner: _planner,
      collections: _collections,
      idGenerator: deps.idGenerator,
      clock: deps.clock,
    );
    _shell = ShellController();
    final social = repositories.social;
    if (social != null) {
      _social = SocialController(
        repository: social,
        imageStorage: deps.imageStorage,
      )..load();
    }
    _bootstrap = AppBootstrap(
      user: widget.user,
      settings: _settings,
      wardrobe: _wardrobe,
      outfits: _outfits,
      planner: _planner,
      collections: _collections,
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
    _collections.dispose();
    _weather.dispose();
    _stylist.dispose();
    _tryOn.dispose();
    _shell.dispose();
    _social?.dispose();
    super.dispose();
  }

  void _retry() => setState(() => _startup = _bootstrap.run());

  /// A try-on finished after the user left its screen.
  void _tryOnReady(TryOnResult result) {
    _messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Your AI try-on is ready'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () {
              final navigator = _navigator.currentContext;
              if (navigator != null) TryOnFlows.open(navigator, result);
            },
          ),
        ),
      );
  }

  void _tryOnFailed(Object error) {
    _messenger.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Your try-on didn’t work: ${describeError(error)} No credit was '
            'used.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final deps = widget.dependencies;
    return MultiProvider(
      providers: [
        Provider<AppUser>.value(value: widget.user),
        Provider<ImageStorageService>.value(value: deps.imageStorage),
        Provider<ImagePickerService>.value(value: deps.imagePicker),
        Provider<AiStylistService>.value(value: deps.aiStylist),
        Provider<PayOSCheckout?>.value(value: deps.payments),
        ChangeNotifierProvider.value(value: _settings),
        ChangeNotifierProvider.value(value: _wardrobe),
        ChangeNotifierProvider.value(value: _outfits),
        ChangeNotifierProvider.value(value: _planner),
        ChangeNotifierProvider.value(value: _collections),
        ChangeNotifierProvider.value(value: _weather),
        ChangeNotifierProvider.value(value: _stylist),
        ChangeNotifierProvider.value(value: _tryOn),
        ChangeNotifierProvider.value(value: _shell),
        ChangeNotifierProvider<SocialController?>.value(value: _social),
        Provider.value(value: _closet),
      ],
      child: Selector<SettingsController, ThemeMode>(
        selector: (_, settings) => settings.themeMode,
        builder: (context, themeMode, _) => AppMaterialApp(
          themeMode: themeMode,
          onGenerateRoute: AppRoutes.onGenerateRoute,
          navigatorKey: _navigator,
          scaffoldMessengerKey: _messenger,
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
