import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/app_dialogs.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/core/widgets/layout.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/try_on.dart';
import 'package:all_fits/features/try_on/try_on_controller.dart';
import 'package:all_fits/features/try_on/try_on_flows.dart';
import 'package:all_fits/features/try_on/widgets/try_on_widgets.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';

/// The selfie, body photo, body type and appearance notes used for
/// try-ons. Only the user sees it. During [onboarding] it explains try-ons
/// and "Continue" is the consent to send photos; the screen then resolves
/// to who wears the outfit. Otherwise it is a plain editor, as in Fits.
class TryOnProfileScreen extends StatefulWidget {
  const TryOnProfileScreen({super.key, this.onboarding = false});

  final bool onboarding;

  @override
  State<TryOnProfileScreen> createState() => _TryOnProfileScreenState();
}

enum _PhotoAction { view, replace, delete }

class _TryOnProfileScreenState extends State<TryOnProfileScreen> {
  static const double _thumb = 76;
  static const Duration _saveDelay = Duration(milliseconds: 600);

  late final TryOnController _tryOn = context.read<TryOnController>();
  late final TextEditingController _appearance = TextEditingController(
    text: _tryOn.profile.appearance,
  );
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _tryOn.load();
  }

  @override
  void dispose() {
    if (_saveTimer?.isActive ?? false) {
      _saveTimer!.cancel();
      unawaited(_tryOn.setAppearance(_appearance.text));
    }
    _appearance.dispose();
    super.dispose();
  }

  /// Saves the appearance notes once typing pauses.
  void _onAppearanceChanged(String _) {
    _saveTimer?.cancel();
    _saveTimer = Timer(
      _saveDelay,
      () => _guard(() => _tryOn.setAppearance(_appearance.text)),
    );
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) context.showErrorSnack(error);
    }
  }

  Future<void> _editPhoto({
    required String? current,
    required String title,
    required String message,
    required Future<void> Function(String? reference) save,
  }) async {
    if (current != null) {
      final action = await showModalBottomSheet<_PhotoAction>(
        context: context,
        builder: (sheetContext) => SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('View photo'),
                onTap: () => Navigator.of(sheetContext).pop(_PhotoAction.view),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Replace photo'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_PhotoAction.replace),
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: context.palette.danger,
                ),
                title: Text(
                  'Delete photo',
                  style: TextStyle(color: context.palette.danger),
                ),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_PhotoAction.delete),
              ),
            ],
          ),
        ),
      );
      if (!mounted || action == null) return;
      switch (action) {
        case _PhotoAction.view:
          await _view(current);
          return;
        case _PhotoAction.delete:
          final confirmed = await showConfirmDialog(
            context,
            title: 'Delete this photo?',
            message: 'It’s removed from All Fits right away.',
            confirmLabel: 'Delete',
            destructive: true,
          );
          if (confirmed && mounted) await _guard(() => save(null));
          return;
        case _PhotoAction.replace:
          break;
      }
    }
    if (!mounted) return;
    final reference = await TryOnFlows.pickPhoto(
      context,
      title: title,
      message: message,
    );
    if (reference != null && mounted) await _guard(() => save(reference));
  }

  Future<void> _view(String reference) => showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        onTap: () => Navigator.of(dialogContext).pop(),
        child: StoredPhoto(reference: reference, fit: BoxFit.contain),
      ),
    ),
  );

  Future<void> _editBodyType() async {
    final tryOn = context.read<TryOnController>();
    final type = await showBodyTypeSheet(context, tryOn.profile.bodyType);
    if (type != null && mounted) await _guard(() => tryOn.setBodyType(type));
  }

  Future<void> _continue(TryOnWearer wearer) async {
    final tryOn = context.read<TryOnController>();
    await _guard(tryOn.consent);
    if (mounted) Navigator.of(context).pop(wearer);
  }

  @override
  Widget build(BuildContext context) {
    final tryOn = context.watch<TryOnController>();
    final profile = tryOn.profile;
    final palette = context.palette;
    final text = context.textTheme;
    final note = text.bodyMedium?.copyWith(color: palette.textSecondary);
    final bodyType = profile.bodyType;

    return Scaffold(
      appBar: AppBar(title: const Text('Try on profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.xl,
        ),
        children: [
          ResponsiveCenter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.onboarding) ...[
                  _Hero(
                    selfie: profile.selfiePhoto ?? profile.bodyPhoto,
                    bodyType: bodyType ?? BodyType.fallback,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Set up your profile to try on clothes virtually',
                    textAlign: TextAlign.center,
                    style: text.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                _ProfileRow(
                  leading: StoredPhoto(
                    reference: profile.selfiePhoto,
                    decodeWidth: _thumb,
                    placeholder: _Placeholder(icon: Icons.face_outlined),
                  ),
                  title: 'Selfie photo',
                  subtitle:
                      'Should show your face clearly, facing the camera in '
                      'good light.',
                  onTap: () => _editPhoto(
                    current: profile.selfiePhoto,
                    title: 'Add a selfie',
                    message: 'Face the camera in good light.',
                    save: tryOn.setSelfie,
                  ),
                ),
                _ProfileRow(
                  leading: StoredPhoto(
                    reference: profile.bodyPhoto,
                    decodeWidth: _thumb,
                    placeholder: _Placeholder(icon: Icons.image_outlined),
                  ),
                  title: 'Body photo (optional)',
                  subtitle:
                      'A full-body photo of you standing straight (no baggy '
                      'clothes), for more accurate results.',
                  onTap: () => _editPhoto(
                    current: profile.bodyPhoto,
                    title: 'Add a full-body photo',
                    message:
                        'Stand straight, head to feet in the frame, in good '
                        'light.',
                    save: tryOn.setBodyPhoto,
                  ),
                ),
                _ProfileRow(
                  leading: _Placeholder(
                    child: BodySilhouette(
                      type: bodyType ?? BodyType.fallback,
                      size: 52,
                    ),
                  ),
                  title: 'Body type',
                  subtitle:
                      bodyType?.label ??
                      'Helps the AI get your proportions right.',
                  onTap: _editBodyType,
                ),
                if (!widget.onboarding) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text('Additional prompt', style: text.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  TextField(
                    controller: _appearance,
                    onChanged: _onAppearanceChanged,
                    maxLength: TryOnProfile.maxAppearanceLength,
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Describe your appearance (optional)',
                      helperText:
                          'Max ${TryOnProfile.maxAppearanceLength} characters',
                      counterText: '',
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                _Note(
                  icon: Icons.lock_outline_rounded,
                  text:
                      'This info is only visible to you and not part of your '
                      'public profile. Delete it here any time.',
                  style: note,
                ),
                const SizedBox(height: AppSpacing.sm),
                _Note(
                  icon: Icons.verified_user_outlined,
                  text:
                      'Your selfie and body photo are sent to our AI '
                      'providers (Meta, or Google as a backup) only when you '
                      'make a try-on. You agree to sharing this personal data '
                      'only for image generation.',
                  style: note,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: !widget.onboarding
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  AppSpacing.xs,
                  AppSpacing.page,
                  AppSpacing.sm,
                ),
                // Not in a ResponsiveCenter: its Align would fill the screen here.
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton(
                      onPressed: profile.hasPhoto
                          ? () => _continue(TryOnWearer.me)
                          : null,
                      child: const Text('Continue'),
                    ),
                    TextButton(
                      onPressed: () => _continue(TryOnWearer.model),
                      child: const Text('Use an AI model instead'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Clothes from the wardrobe, an arrow, and the person who'll wear them.
class _Hero extends StatelessWidget {
  const _Hero({required this.selfie, required this.bodyType});

  final String? selfie;
  final BodyType bodyType;

  static const double _height = 220;

  /// One piece of each, in this order, like an outfit laid out.
  static const List<ClothingCategory> _shown = [
    ClothingCategory.outerwear,
    ClothingCategory.tops,
    ClothingCategory.bottoms,
    ClothingCategory.shoes,
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final wardrobe = context.watch<WardrobeController>().activeItems;
    final items = [
      for (final category in _shown)
        ?wardrobe.where((i) => i.category == category).firstOrNull,
    ];
    return SizedBox(
      height: _height,
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: GridView.count(
              crossAxisCount: 2,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.xs,
              crossAxisSpacing: AppSpacing.xs,
              childAspectRatio: 0.9,
              children: [
                for (final item in items)
                  ClothingImage(
                    item: item,
                    cutout: true,
                    fit: BoxFit.contain,
                    decodeWidth: 90,
                  ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 56,
            color: palette.textTertiary,
          ),
          Expanded(
            flex: 3,
            child: Center(
              child: AspectRatio(
                aspectRatio: 0.6,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  child: StoredPhoto(
                    reference: selfie,
                    decodeWidth: 140,
                    placeholder: ColoredBox(
                      color: palette.surfaceMuted,
                      child: Center(
                        child: BodySilhouette(type: bodyType, size: 150),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final palette = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Container(
              width: _TryOnProfileScreenState._thumb,
              height: _TryOnProfileScreenState._thumb,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              // In front, so a photo can't cover it.
              foregroundDecoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: palette.border),
              ),
              child: leading,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: text.bodySmall?.copyWith(
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({this.icon, this.child});

  final IconData? icon;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ColoredBox(
      color: palette.surface,
      child: Center(child: child ?? Icon(icon, color: palette.textTertiary)),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text, this.style});

  final IconData icon;
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppSizes.iconSm, color: style?.color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: Text(text, style: style)),
      ],
    );
  }
}
