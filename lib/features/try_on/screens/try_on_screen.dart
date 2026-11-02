import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/try_on.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/widgets/outfit_canvas.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/try_on/try_on_controller.dart';
import 'package:all_fits/features/try_on/try_on_flows.dart';
import 'package:all_fits/features/try_on/widgets/try_on_clothes_picker.dart';
import 'package:all_fits/features/try_on/widgets/try_on_widgets.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/core/l10n/l10n.dart';

/// Draws the chosen clothes on the user, or on an AI model, with a
/// background, speed and styling prompt to choose. Shows a blurred preview
/// until the picture comes back.
class TryOnScreen extends StatefulWidget {
  const TryOnScreen({super.key, required this.args});

  final TryOnArgs args;

  @override
  State<TryOnScreen> createState() => _TryOnScreenState();
}

class _TryOnScreenState extends State<TryOnScreen> {
  static const int _maxPromptLength = 200;

  late final TryOnController _tryOn = context.read<TryOnController>();
  late List<String> _itemIds = widget.args.itemIds;
  late TryOnWearer _wearer = widget.args.wearer;
  TryOnBackground _background = TryOnBackground.studio;
  bool _highQuality = false;
  String _notes = '';

  /// The picture on screen; null shows the preview.
  TryOnResult? _shown;
  Object? _error;

  /// Held down to compare with the clothes.
  bool _showOriginal = false;

  @override
  void initState() {
    super.initState();
    _tryOn.watch();
    final id = widget.args.resultId;
    final result = id == null ? null : _tryOn.resultById(id);
    if (result != null) {
      _shown = result;
      _background = result.background;
    }
  }

  @override
  void dispose() {
    _tryOn.unwatch();
    super.dispose();
  }

  /// Any change goes back to the preview; the last picture stays saved.
  void _change(VoidCallback change) => setState(() {
    change();
    _shown = null;
    _error = null;
  });

  Future<void> _pickClothes() async {
    final picked = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Column(
          children: [
            SheetHeader(title: tr('Clothes')),
            Expanded(
              child: TryOnClothesPicker(
                initial: _itemIds,
                scrollController: scrollController,
                onNext: (itemIds) => Navigator.of(sheetContext).pop(itemIds),
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null && picked.isNotEmpty && mounted) {
      _change(() => _itemIds = picked);
    }
  }

  Future<void> _pickBackground() async {
    final picked = await showModalBottomSheet<TryOnBackground>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _BackgroundSheet(selected: _background),
    );
    if (picked != null && mounted) _change(() => _background = picked);
  }

  Future<void> _editPrompt() async {
    final notes = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _PromptSheet(initial: _notes, maxLength: _maxPromptLength),
    );
    if (notes != null && notes != _notes && mounted) {
      _change(() => _notes = notes);
    }
  }

  Future<void> _pickWearer() async {
    final profile = _tryOn.profile;
    final choice = await showModalBottomSheet<Object>(
      context: context,
      builder: (sheetContext) {
        ListTile option(TryOnWearer wearer, String title, String subtitle) =>
            ListTile(
              title: Text(title),
              subtitle: Text(subtitle),
              trailing: _wearer == wearer
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () => Navigator.of(sheetContext).pop(wearer),
            );
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetHeader(title: tr('Who wears it')),
              option(
                TryOnWearer.me,
                tr('Me'),
                profile.hasPhoto
                    ? tr('Your selfie and body photo')
                    : tr('Add a selfie in your try-on profile'),
              ),
              option(
                TryOnWearer.model,
                tr('AI model'),
                (profile.bodyType ?? BodyType.fallback).label,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: Text(tr('Edit try-on profile')),
                onTap: () => Navigator.of(sheetContext).pop('profile'),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted) return;
    if (choice is TryOnWearer && choice != _wearer) {
      _change(() => _wearer = choice);
    } else if (choice == 'profile') {
      await AppNavigator.tryOnProfile(context);
    }
  }

  Future<void> _generate() async {
    final plan = context.read<SettingsController>().plan;
    if (_tryOn.creditsLeft(plan) <= 0) {
      await TryOnFlows.showNoCredits(context);
      return;
    }
    if (_wearer == TryOnWearer.me && !_tryOn.profile.hasPhoto) {
      await AppNavigator.tryOnProfile(context);
      if (!mounted || !_tryOn.profile.hasPhoto) return;
    }
    final items = _items(context.read<WardrobeController>());
    if (items.isEmpty) return _pickClothes();
    setState(() => _error = null);
    try {
      final result = await _tryOn.generate(
        TryOnRequest(
          itemIds: _itemIds,
          outfitId: widget.args.outfitId,
          background: _background,
          wearer: _wearer,
          highQuality: _highQuality,
          notes: _notes,
        ),
        items,
        plan: plan,
      );
      if (result != null && mounted) setState(() => _shown = result);
    } on PlanLimitException {
      if (mounted) await TryOnFlows.showNoCredits(context);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _delete(TryOnResult result) async {
    if (await TryOnFlows.delete(context, result) && mounted) {
      setState(() => _shown = null);
    }
  }

  List<ClothingItem> _items(WardrobeController wardrobe) =>
      wardrobe.itemsByIds(_itemIds);

  @override
  Widget build(BuildContext context) {
    final tryOn = context.watch<TryOnController>();
    final items = _items(context.watch<WardrobeController>());
    final palette = context.palette;
    final text = context.textTheme;
    final shown = _shown == null ? null : tryOn.resultById(_shown!.id);
    final plan = context.watch<SettingsController>().plan;
    final freeTry = !plan.isPremium && tryOn.creditsLeft(plan) > 0;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: GestureDetector(
                      onLongPressStart: shown == null
                          ? null
                          : (_) => setState(() => _showOriginal = true),
                      onLongPressEnd: shown == null
                          ? null
                          : (_) => setState(() => _showOriginal = false),
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                        ),
                        foregroundDecoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          border: Border.all(color: palette.border),
                        ),
                        child: ColoredBox(
                          color: palette.surfaceMuted,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (shown != null && !_showOriginal)
                                StoredPhoto(reference: shown.photo)
                              else
                                _Preview(
                                  items: items,
                                  outfitId: widget.args.outfitId,
                                  blurred: shown == null,
                                ),
                              if (tryOn.isGenerating)
                                _Generating(
                                  highQuality:
                                      tryOn.job?.highQuality ?? _highQuality,
                                  onCancel: tryOn.cancel,
                                )
                              else if (shown != null) ...[
                                Positioned(
                                  top: AppSpacing.sm,
                                  left: AppSpacing.sm,
                                  child: OverlayPill(
                                    text: tr('AI-generated image'),
                                    icon: Icons.auto_awesome_rounded,
                                  ),
                                ),
                                Positioned(
                                  bottom: AppSpacing.sm,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: OverlayPill(
                                      text: tr(
                                        'Tap and hold to see the clothes',
                                      ),
                                    ),
                                  ),
                                ),
                              ] else
                                _GenerateButton(
                                  costLabel: freeTry
                                      ? tr('Your free try-on')
                                      : tr('Costs 1 AI credit'),
                                  error: _error,
                                  onPressed: items.isEmpty ? null : _generate,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (shown != null && !tryOn.isGenerating)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ResultAction(
                      icon: Icons.refresh_rounded,
                      label: tr('Try again'),
                      onTap: _generate,
                    ),
                    _ResultAction(
                      icon: Icons.download_rounded,
                      label: tr('Save'),
                      onTap: () => TryOnFlows.save(context, shown),
                    ),
                    _ResultAction(
                      icon: Icons.ios_share_rounded,
                      label: tr('Share'),
                      onTap: () => TryOnFlows.share(context, shown),
                    ),
                    _ResultAction(
                      icon: Icons.delete_outline_rounded,
                      label: tr('Delete'),
                      onTap: () => _delete(shown),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(TryOnFlows.creditsLabel(context), style: text.titleSmall),
                const SizedBox(width: AppSpacing.xs),
                IconButton.filled(
                  tooltip: tr('Get more credits'),
                  style: IconButton.styleFrom(
                    backgroundColor: palette.ink,
                    foregroundColor: palette.onInk,
                    minimumSize: const Size.square(28),
                    fixedSize: const Size.square(28),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.padded,
                  ),
                  iconSize: AppSizes.iconSm,
                  onPressed: () => plan.isPremium
                      ? TryOnFlows.showNoCredits(context)
                      : AppNavigator.premium(context),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              height: _OptionTile.height,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                children: [
                  _OptionTile(
                    label: tr('Background'),
                    sublabel: _background.label,
                    onTap: _pickBackground,
                    child: _BackgroundImage(background: _background),
                  ),
                  _OptionTile(
                    label: tr('Clothes'),
                    sublabel: AppFormatters.count(items.length, 'piece'),
                    onTap: _pickClothes,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final item in items.take(2))
                          Flexible(
                            child: ClothingImage(
                              item: item,
                              cutout: true,
                              fit: BoxFit.contain,
                              decodeWidth: 44,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _OptionTile(
                    label: _highQuality ? tr('Quality') : tr('Fast'),
                    sublabel: _highQuality ? tr('2x slower') : null,
                    active: _highQuality,
                    onTap: () => _change(() => _highQuality = !_highQuality),
                    child: Icon(
                      _highQuality
                          ? Icons.diamond_outlined
                          : Icons.bolt_rounded,
                      size: AppSizes.iconXl,
                    ),
                  ),
                  _OptionTile(
                    label: tr('Prompt'),
                    sublabel: _notes.isEmpty ? null : tr('Added'),
                    active: _notes.isNotEmpty,
                    onTap: _editPrompt,
                    child: Icon(
                      Icons.edit_outlined,
                      size: AppSizes.iconXl,
                      color: _notes.isEmpty ? palette.textTertiary : null,
                    ),
                  ),
                  _OptionTile(
                    label: _wearer == TryOnWearer.me
                        ? tr('Try on profile')
                        : tr('AI model'),
                    onTap: _pickWearer,
                    child: _wearer == TryOnWearer.me
                        ? StoredPhoto(
                            reference:
                                tryOn.profile.selfiePhoto ??
                                tryOn.profile.bodyPhoto,
                            decodeWidth: _OptionTile.size,
                            placeholder: Icon(
                              Icons.person_outline_rounded,
                              size: AppSizes.iconXl,
                              color: palette.textTertiary,
                            ),
                          )
                        : BodySilhouette(
                            type: tryOn.profile.bodyType ?? BodyType.fallback,
                            size: 60,
                          ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                AppSpacing.xs,
                AppSpacing.page,
                AppSpacing.sm,
              ),
              child: Text(
                tr(
                  'To make a picture, we send the inputs above to our AI '
                  'provider. AI pictures can get colours or fit wrong.',
                ),
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: palette.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The clothes as an outfit, blurred until a picture is made.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.items,
    required this.outfitId,
    required this.blurred,
  });

  final List<ClothingItem> items;
  final String? outfitId;
  final bool blurred;

  @override
  Widget build(BuildContext context) {
    final outfit = outfitId == null
        ? null
        : context.watch<OutfitController>().outfitById(outfitId!);
    // The saved arrangement only fits while the pieces are unchanged.
    final sameItems =
        outfit != null &&
        outfit.itemIds.toSet().containsAll(items.map((i) => i.id)) &&
        outfit.itemIds.length == items.length;
    return ImageFiltered(
      enabled: blurred,
      imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
      child: OutfitCanvas(
        items: items,
        layout: sameItems ? outfit.layout : const [],
      ),
    );
  }
}

class _GenerateButton extends StatelessWidget {
  const _GenerateButton({
    required this.costLabel,
    required this.error,
    required this.onPressed,
  });

  final String costLabel;
  final Object? error;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final error = this.error;
    final palette = context.palette;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (error != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Text(
                  tr('{0}\nNo credit was used.', [describeError(error)]),
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, AppSizes.buttonHeight + 8),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                textStyle: context.textTheme.titleMedium,
              ),
              onPressed: onPressed,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: Text(
                error == null ? tr('Generate image') : tr('Try again'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            OverlayPill(text: costLabel),
          ],
        ),
      ),
    );
  }
}

class _Generating extends StatelessWidget {
  const _Generating({required this.highQuality, required this.onCancel});

  final bool highQuality;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    return ColoredBox(
      color: palette.background.withValues(alpha: 0.55),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: palette.ink),
              const SizedBox(height: AppSpacing.md),
              Text(tr('Generating image…'), style: text.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                tr(
                  '{0}. You can leave this screen; we’ll let you know when it’s ready.',
                  [
                    highQuality
                        ? tr('About a minute or two')
                        : tr(
                            'Usually 20 to 60 '
                            'seconds',
                          ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton(onPressed: onCancel, child: Text(tr('Cancel'))),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultAction extends StatelessWidget {
  const _ResultAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          children: [
            Icon(icon),
            const SizedBox(height: 2),
            Text(label, style: context.textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

/// A square button on the options strip under the picture.
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.onTap,
    required this.child,
    this.sublabel,
    this.active = false,
  });

  static const double size = 84;
  static const double height = size + 52;

  final String label;
  final String? sublabel;
  final bool active;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Semantics(
        button: true,
        label: [label, ?sublabel].join(', '),
        excludeSemantics: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: SizedBox(
            width: size,
            child: Column(
              children: [
                Container(
                  width: size,
                  height: size,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  // In front, so a photo can't cover it.
                  foregroundDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: active ? palette.ink : palette.border,
                      width: active ? 2 : 1,
                    ),
                  ),
                  child: Center(child: child),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelMedium,
                ),
                if (sublabel != null)
                  Text(
                    sublabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall?.copyWith(
                      color: palette.textTertiary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackgroundImage extends StatelessWidget {
  const _BackgroundImage({required this.background});

  final TryOnBackground background;

  @override
  Widget build(BuildContext context) {
    final asset = background.asset;
    if (asset != null) {
      return SizedBox.expand(
        child: Image.asset(asset, fit: BoxFit.cover, cacheWidth: 360),
      );
    }
    return SizedBox.expand(
      child: ColoredBox(
        color: context.palette.surfaceMuted,
        child: Icon(
          Icons.light_outlined,
          size: AppSizes.iconXl,
          color: context.palette.textTertiary,
        ),
      ),
    );
  }
}

class _BackgroundSheet extends StatelessWidget {
  const _BackgroundSheet({required this.selected});

  final TryOnBackground selected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Column(
        children: [
          SheetHeader(title: tr('Background')),
          Expanded(
            child: GridView.count(
              controller: scrollController,
              crossAxisCount: 2,
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                0,
                AppSpacing.page,
                AppSpacing.xl,
              ),
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.66,
              children: [
                for (final background in TryOnBackground.values)
                  Semantics(
                    button: true,
                    selected: background == selected,
                    label: background.label,
                    excludeSemantics: true,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(background),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Container(
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.lg,
                                ),
                                border: Border.all(
                                  color: background == selected
                                      ? palette.ink
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.lg - 2,
                                ),
                                child: _BackgroundImage(background: background),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            background.label,
                            textAlign: TextAlign.center,
                            style: context.textTheme.titleSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Extra styling for the AI, e.g. "oversized fit, tee tucked in".
class _PromptSheet extends StatefulWidget {
  const _PromptSheet({required this.initial, required this.maxLength});

  final String initial;
  final int maxLength;

  @override
  State<_PromptSheet> createState() => _PromptSheetState();
}

class _PromptSheetState extends State<_PromptSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            0,
            AppSpacing.page,
            AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SheetHeader(title: tr('Prompt')),
              TextField(
                controller: _controller,
                autofocus: true,
                minLines: 3,
                maxLines: 5,
                maxLength: widget.maxLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: tr('Example: Oversized fit, tee tucked in'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(''),
                      child: Text(tr('Clear')),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          Navigator.of(context).pop(_controller.text.trim()),
                      child: Text(tr('Done')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
