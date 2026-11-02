import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/utils/widget_snapshot.dart';
import 'package:all_fits/data/local/home_screen_widget.dart';
import 'package:all_fits/data/local/image_storage_service.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/outfit_layout.dart';
import 'package:all_fits/features/outfits/widgets/outfit_canvas.dart';
import 'package:all_fits/features/outfits/widgets/outfit_cover.dart';
import 'package:all_fits/features/planner/controllers/planner_controller.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/shared/closet_actions.dart';
import 'package:all_fits/features/shared/closet_flows.dart';
import 'package:all_fits/features/today_widget/today_widget_data.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/features/weather/controllers/weather_controller.dart';

/// Keeps the "Today" home screen widget in step with the closet, and opens
/// what the user tapped on it. Wraps the signed-in app.
class TodayWidgetSync extends StatefulWidget {
  const TodayWidgetSync({super.key, required this.child});

  final Widget child;

  /// The outfit picture's size on the widget, in logical pixels.
  static const Size pictureSize = Size(160, 160 / AppSizes.outfitImageAspect);

  @override
  State<TodayWidgetSync> createState() => _TodayWidgetSyncState();
}

class _TodayWidgetSyncState extends State<TodayWidgetSync>
    with WidgetsBindingObserver {
  late final HomeScreenWidget _homeWidget;
  late final Listenable _closet;
  StreamSubscription<Uri>? _taps;
  Timer? _debounce;
  String? _shown;
  bool _busy = false;
  bool _again = false;

  @override
  void initState() {
    super.initState();
    _homeWidget = context.read<HomeScreenWidget>();
    _closet = Listenable.merge([
      context.read<PlannerController>(),
      context.read<OutfitController>(),
      context.read<WardrobeController>(),
      context.read<WeatherController>(),
    ])..addListener(_schedule);
    WidgetsBinding.instance.addObserver(this);
    _taps = _homeWidget.taps.listen(_open);
    _schedule();
  }

  @override
  void dispose() {
    _closet.removeListener(_schedule);
    WidgetsBinding.instance.removeObserver(this);
    _taps?.cancel();
    _debounce?.cancel();
    // Signed out: don't leave this user's outfit on the home screen.
    _homeWidget.update(TodayWidgetData.signedOutValues);
    super.dispose();
  }

  /// The day may have changed while the app was in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _schedule();
  }

  /// Waits for a burst of changes (loading, saving) to settle.
  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _push);
  }

  Future<void> _push() async {
    if (!mounted) return;
    if (_busy) {
      _again = true;
      return;
    }
    // The weather loads on Home; load it here too in case the app went to
    // the background first. Loading notifies, which runs this again.
    final weather = context.read<WeatherController>();
    final location = context.read<SettingsController>().weatherLocation;
    if (location != null && weather.needsRefresh(location)) {
      weather.refresh(location);
    }
    final closet = context.read<ClosetActions>();
    final today = closet.today;
    final data = TodayWidgetData.from(
      today: today,
      plan: closet.planner.dayPlan(today),
      outfitById: closet.outfits.outfitById,
      itemsByIds: closet.wardrobe.itemsByIds,
      wardrobe: closet.wardrobe.activeItems,
      weather: weather.report,
    );
    if (data.signature == _shown) return;
    _busy = true;
    try {
      Uint8List? picture;
      if (data.hasPicture && _homeWidget.showsPicture) {
        // Drawing needs the GPU, which Android pauses in the background;
        // give up and try again when the app is back.
        picture = await _draw(data)
            .timeout(const Duration(seconds: 10), onTimeout: () => null);
        if (picture == null) return;
      }
      await _homeWidget.update(data.toWidgetValues(), picture: picture);
      _shown = data.signature;
    } finally {
      _busy = false;
      if (_again) {
        _again = false;
        _schedule();
      }
    }
  }

  /// The outfit as it looks in the app, head to toe.
  Future<Uint8List?> _draw(TodayWidgetData data) {
    final outfit = data.outfit;
    final size = TodayWidgetSync.pictureSize;
    final Widget picture = outfit != null
        ? OutfitCover(outfit: outfit, items: data.items, worn: true)
        : OutfitCanvas(
            items: data.items,
            layout: OutfitLayout.worn(data.items),
          );
    return snapshotWidget(
      MediaQuery(
        data: MediaQuery.of(context).copyWith(size: size),
        child: Theme(
          data: Theme.of(context),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Provider<ImageStorageService>.value(
              value: context.read<ImageStorageService>(),
              child: SizedBox.fromSize(size: size, child: picture),
            ),
          ),
        ),
      ),
      size: size,
      pixelRatio: 2.5,
    );
  }

  /// Opens what a tap on the widget asked for; see [TodayWidgetLink].
  void _open(Uri link) {
    if (!mounted ||
        link.scheme != TodayWidgetLink.scheme ||
        link.host != TodayWidgetLink.host) {
      return;
    }
    final id = link.queryParameters['id'];
    final outfits = context.read<OutfitController>();
    switch (link.path) {
      case '/outfit' when id != null && outfits.outfitById(id) != null:
        AppNavigator.outfitDetail(context, id);
      case '/wear' when id != null:
        ClosetFlows.markWorn(context, id);
      case '/compose':
        // Saved looks are planned for today, so the widget can wear them.
        final ids = link.queryParameters['items']?.split(',') ?? const [];
        AppNavigator.composeOutfit(
          context,
          itemIds: ids,
          planDate: context.read<ClosetActions>().today,
        );
      case '/add-clothes':
        AppNavigator.addClothing(context);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
