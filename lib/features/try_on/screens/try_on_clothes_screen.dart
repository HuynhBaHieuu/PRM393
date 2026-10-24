import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/features/try_on/try_on_controller.dart';
import 'package:all_fits/features/try_on/try_on_flows.dart';
import 'package:all_fits/features/try_on/widgets/try_on_clothes_picker.dart';
import 'package:all_fits/features/try_on/widgets/try_on_widgets.dart';

/// First step of a try-on started without an outfit: pick the pieces, then
/// "Next" opens the try-on screen. The avatar opens the try-on profile.
class TryOnClothesScreen extends StatelessWidget {
  const TryOnClothesScreen({super.key, required this.args});

  final TryOnArgs args;

  static const double _avatar = 36;

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<TryOnController>().profile;
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select clothes to try on'),
        actions: [
          IconButton(
            tooltip: 'Try on profile',
            onPressed: () => AppNavigator.tryOnProfile(context),
            icon: ClipOval(
              child: SizedBox.square(
                dimension: _avatar,
                child: StoredPhoto(
                  reference: profile.selfiePhoto ?? profile.bodyPhoto,
                  decodeWidth: _avatar,
                  placeholder: ColoredBox(
                    color: palette.surfaceMuted,
                    child: Icon(
                      Icons.person_outline_rounded,
                      color: palette.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: TryOnClothesPicker(
        initial: args.itemIds,
        onNext: (itemIds) => AppNavigator.tryOn(
          context,
          TryOnArgs(itemIds: itemIds, wearer: args.wearer),
        ),
      ),
    );
  }
}
