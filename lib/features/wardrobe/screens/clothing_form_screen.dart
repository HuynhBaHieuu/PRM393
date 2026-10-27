import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/extensions/model_presentation.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/utils/validators.dart';
import 'package:all_fits/core/widgets/app_dialogs.dart';
import 'package:all_fits/core/widgets/color_swatch.dart';
import 'package:all_fits/core/widgets/feedback_views.dart';
import 'package:all_fits/core/widgets/layout.dart';
import 'package:all_fits/core/widgets/selectable_pill.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/local/image_picker_service.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_color.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/clothing_subcategory.dart';
import 'package:all_fits/data/models/season.dart';
import 'package:all_fits/data/remote/ai_stylist_service.dart';
import 'package:all_fits/data/remote/product_link_service.dart';
import 'package:all_fits/features/premium/premium_flows.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/wardrobe/controllers/auto_detect_controller.dart';
import 'package:all_fits/features/wardrobe/controllers/clothing_draft.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/features/wardrobe/widgets/detect_status.dart';
import 'package:all_fits/features/wardrobe/widgets/photo_picker_field.dart';
import 'package:all_fits/features/wardrobe/widgets/photo_tips_sheet.dart';
import 'package:all_fits/features/wardrobe/widgets/product_link_sheet.dart';
import 'package:all_fits/navigation/app_navigation.dart';

/// Form fields the AI can fill in from the photo.
enum _AiField { name, category, subcategory, color, seasons, brand }

/// The fields as they were before the AI filled them, for Undo.
typedef _BeforeAi = ({
  String name,
  ClothingCategory? category,
  ClothingSubcategory? subcategory,
  ClothingColor? color,
  Set<Season> seasons,
  String brand,
});

/// Add a new clothing item, or edit one when [itemId] is given.
class ClothingFormScreen extends StatefulWidget {
  const ClothingFormScreen({super.key, this.itemId, this.initial});

  final String? itemId;

  /// Values to start a new item with, e.g. prefilled by another screen.
  final ClothingDraft? initial;

  @override
  State<ClothingFormScreen> createState() => _ClothingFormScreenState();
}

class _ClothingFormScreenState extends State<ClothingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _brand;
  late final TextEditingController _price;
  late final TextEditingController _notes;

  ClothingItem? _existing;
  ClothingCategory? _category;
  ClothingSubcategory? _subcategory;
  ClothingColor? _color;
  final Set<Season> _seasons = {};
  bool _isFavorite = false;
  String? _newImagePath;

  bool _saving = false;
  bool _readingLink = false;
  bool _dirty = false;
  bool _showErrors = false;

  DetectPhase _detectPhase = DetectPhase.idle;

  /// Fields the AI filled in that the user hasn't changed since.
  final Set<_AiField> _aiFilled = {};
  _BeforeAi? _beforeAi;
  ClothingDetection? _detection;

  /// Bumped for every detection, so a stale answer is ignored.
  int _detectRun = 0;
  Completer<void>? _cancelDetect;

  bool get _isEditing => widget.itemId != null;

  @override
  void initState() {
    super.initState();
    final itemId = widget.itemId;
    final item = itemId == null
        ? null
        : context.read<WardrobeController>().itemById(itemId);
    final initial = item == null ? widget.initial : null;
    _existing = item;
    _category = item?.category ?? initial?.category;
    _subcategory = item?.subcategory ?? initial?.subcategory;
    _color = item?.color ?? initial?.color;
    _seasons.addAll(item?.seasons ?? initial?.seasons ?? const []);
    _isFavorite = item?.isFavorite ?? initial?.isFavorite ?? false;
    _name = TextEditingController(text: item?.name ?? initial?.name);
    _brand = TextEditingController(text: item?.brand ?? initial?.brand);
    final price = item?.price ?? initial?.price;
    _price = TextEditingController(
      text: price == null ? '' : _formatPriceInput(price),
    );
    _notes = TextEditingController(text: item?.notes ?? initial?.notes);
    for (final controller in [_name, _brand, _price, _notes]) {
      controller.addListener(_markDirty);
    }
    // Typing over an AI value makes it the user's own.
    _name.addListener(() {
      if (_name.text != _detection?.name) _unmark(_AiField.name);
    });
    _brand.addListener(() {
      if (_brand.text != _detection?.brand) _unmark(_AiField.brand);
    });
  }

  @override
  void dispose() {
    _stopDetection();
    _name.dispose();
    _brand.dispose();
    _price.dispose();
    _notes.dispose();
    super.dispose();
  }

  static String _formatPriceInput(double price) =>
      price == price.roundToDouble()
      ? price.toStringAsFixed(0)
      : price.toStringAsFixed(2);

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  void _update(VoidCallback change) {
    setState(() {
      change();
      _dirty = true;
    });
  }

  bool get _missingImage =>
      _newImagePath == null && _existing?.imagePath == null && !_isEditing;

  Future<void> _pickImage(ImagePickSource source) async {
    final detector = context.read<AutoDetectController>();
    if (!_isEditing && !detector.tipsSeen) {
      await showPhotoTipsSheet(context);
      await detector.markTipsSeen();
      if (!mounted) return;
    }
    try {
      final path = await context.read<ImagePickerService>().pickImage(source);
      if (path != null && mounted) {
        _update(() => _newImagePath = path);
        unawaited(_detect(path));
      }
    } catch (error) {
      if (mounted) context.showErrorSnack(error);
    }
  }

  /// Reads a shop's product page into the form for the user to check.
  Future<void> _addFromLink() async {
    final link = await showProductLinkSheet(context);
    if (link == null || !mounted) return;
    final service = context.read<ProductLinkService>();
    setState(() => _readingLink = true);
    try {
      final result = await service.fetch(link);
      if (mounted) _fillFromLink(result);
    } catch (error) {
      if (mounted) context.showErrorSnack(error);
    } finally {
      if (mounted) setState(() => _readingLink = false);
    }
  }

  /// The user asked for this page's details, so they replace what was
  /// typed; fields the page doesn't give keep their value. The downloaded
  /// photo is treated like a picked one, so the AI fills in the rest.
  void _fillFromLink(ProductLinkResult result) {
    final page = result.page;
    _stopDetection();
    _undoAi();
    if (page.name case final name?) _name.text = name;
    if (page.brand case final brand?) _brand.text = brand;
    if (page.price case final price?) _price.text = _formatPriceInput(price);
    final link = page.url.toString();
    if (_notes.text.trim().isEmpty && link.length <= Validators.maxNotesLength) {
      _notes.text = link;
    }
    final path = result.imagePath;
    _update(() {
      if (path != null) _newImagePath = path;
    });
    if (path != null) unawaited(_detect(path));
    context.showSnack(
      path == null
          ? 'Details added from ${page.url.host}. The photo couldn’t be '
                'downloaded, so add one yourself.'
          : 'Added from ${page.url.host}. Check the details before saving.',
    );
  }

  /// Has the AI fill in the empty fields from the new photo at [path]. A
  /// new photo starts over: what the AI filled from the last one goes.
  Future<void> _detect(String path) async {
    final detector = context.read<AutoDetectController>();
    if (_isEditing || !detector.isOn) return;
    _stopDetection();
    _undoAi();
    setState(() => _detectPhase = DetectPhase.idle);
    if (!detector.consented) {
      final agreed = await showConfirmDialog(
        context,
        title: 'Let AI fill in this piece?',
        message:
            'AI can read the category, type, color, season, name and brand '
            'from your photo. To do that, the photo is sent to an AI '
            'service. You can turn this off in Settings at any time.',
        confirmLabel: 'Allow',
        cancelLabel: 'Not now',
      );
      if (!mounted) return;
      if (!agreed) {
        await detector.setEnabled(false);
        if (mounted) {
          context.showSnack('AI detection is off. Turn it on in Settings.');
        }
        return;
      }
      await detector.consent();
      if (!mounted || path != _newImagePath) return;
    }
    if (detector.left(context.read<SettingsController>().plan) == 0) {
      setState(() => _detectPhase = DetectPhase.noCredits);
      return;
    }
    final run = ++_detectRun;
    final cancel = _cancelDetect = Completer<void>();
    setState(() => _detectPhase = DetectPhase.running);
    try {
      final detection = await detector.detect(path, cancel: cancel.future);
      if (!mounted || run != _detectRun) return;
      _fillIn(detection);
    } catch (_) {
      if (!mounted || run != _detectRun) return;
      setState(() => _detectPhase = DetectPhase.failed);
    }
  }

  /// Drops a detection in flight; its answer is ignored.
  void _stopDetection() {
    _detectRun++;
    final cancel = _cancelDetect;
    if (cancel != null && !cancel.isCompleted) cancel.complete();
    _cancelDetect = null;
  }

  /// Fills only the fields that are still empty, never what the user set.
  void _fillIn(ClothingDetection found) {
    _detection = found;
    _beforeAi = (
      name: _name.text,
      category: _category,
      subcategory: _subcategory,
      color: _color,
      seasons: {..._seasons},
      brand: _brand.text,
    );
    final filled = <_AiField>{};
    if (_category == null && found.category != null) {
      _category = found.category;
      filled.add(_AiField.category);
    }
    if (_subcategory == null && found.subcategory?.category == _category) {
      _subcategory = found.subcategory;
      if (_subcategory != null) filled.add(_AiField.subcategory);
    }
    // The field holds one color: the main one. The rest show below it.
    if (_color == null && found.colors.isNotEmpty) {
      _color = found.colors.first;
      filled.add(_AiField.color);
    }
    if (_seasons.isEmpty && found.seasons.isNotEmpty) {
      _seasons.addAll(found.seasons);
      filled.add(_AiField.seasons);
    }
    if (_name.text.trim().isEmpty && found.name.isNotEmpty) {
      _name.text = found.name;
      filled.add(_AiField.name);
    }
    if (_brand.text.trim().isEmpty && found.brand.isNotEmpty) {
      _brand.text = found.brand;
      filled.add(_AiField.brand);
    }
    setState(() {
      _aiFilled
        ..clear()
        ..addAll(filled);
      _detectPhase = DetectPhase.done;
      if (filled.isNotEmpty) _dirty = true;
    });
  }

  /// Puts back what the AI filled in and the user hasn't changed since.
  void _undoAi() {
    final before = _beforeAi;
    if (before == null) return;
    final filled = {..._aiFilled};
    _beforeAi = null;
    _detection = null;
    _aiFilled.clear();
    if (filled.contains(_AiField.name)) _name.text = before.name;
    if (filled.contains(_AiField.brand)) _brand.text = before.brand;
    setState(() {
      if (filled.contains(_AiField.category)) {
        _category = before.category;
        if (_subcategory?.category != _category) _subcategory = null;
      }
      if (filled.contains(_AiField.subcategory)) {
        _subcategory = before.subcategory;
      }
      if (filled.contains(_AiField.color)) _color = before.color;
      if (filled.contains(_AiField.seasons)) {
        _seasons
          ..clear()
          ..addAll(before.seasons);
      }
      _detectPhase = DetectPhase.idle;
    });
  }

  void _unmark(_AiField field) {
    if (_aiFilled.contains(field)) setState(() => _aiFilled.remove(field));
  }

  Widget? _markIf(_AiField field) =>
      _aiFilled.contains(field) ? const AiMark() : null;

  /// Colors the AI saw besides the one in the Color field.
  List<ClothingColor> get _otherColors => [
    for (final color in _detection?.colors ?? const <ClothingColor>[])
      if (color != _color) color,
  ];

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() => _showErrors = true);
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid || _missingImage || _category == null) {
      context.showSnack('Please complete the highlighted fields.');
      return;
    }

    // The limit is checked before the form opens; this covers pieces added
    // elsewhere while it was open.
    if (_existing == null && !PremiumFlows.canAddClothing(context)) {
      await PremiumFlows.showWardrobeLimit(context);
      return;
    }

    final draft = ClothingDraft(
      name: _name.text,
      category: _category,
      subcategory: _subcategory,
      color: _color,
      seasons: Season.values.where(_seasons.contains).toList(),
      brand: _brand.text,
      price: Validators.parsePrice(_price.text),
      notes: _notes.text,
      isFavorite: _isFavorite,
      newImagePath: _newImagePath,
    );

    setState(() => _saving = true);
    final wardrobe = context.read<WardrobeController>();
    final shell = context.read<ShellController>();
    final navigator = Navigator.of(context);
    try {
      if (_existing == null) {
        final item = await wardrobe.addItem(draft);
        shell.openCloset(ClosetTab.clothes);
        _dirty = false;
        navigator.pop(item.id);
        if (mounted) context.showSnack('${item.name} added to your wardrobe');
      } else {
        await wardrobe.updateItem(_existing!.id, draft);
        _dirty = false;
        navigator.pop();
        if (mounted) context.showSnack('Changes saved');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        context.showErrorSnack(error);
      }
    }
  }

  Future<void> _confirmDiscard() async {
    final discard = await showConfirmDialog(
      context,
      title: 'Discard changes?',
      message: 'Your edits to this item will be lost.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
      destructive: true,
    );
    if (discard && mounted) {
      setState(() => _dirty = false);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEditing && _existing == null) {
      return const NotFoundView(
        title: 'Item not found',
        message: 'This item is no longer in your wardrobe.',
      );
    }
    final picker = context.read<ImagePickerService>();
    final currency = context.select<SettingsController, String>(
      (s) => s.currencySymbol,
    );
    final palette = context.palette;

    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(_isEditing ? 'Edit item' : 'Add clothing'),
          actions: [
            TextButton(
              onPressed: _saving ? null : _save,
              child: const Text('Save'),
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
        ),
        body: Form(
          key: _formKey,
          autovalidateMode: _showErrors
              ? AutovalidateMode.onUserInteraction
              : AutovalidateMode.disabled,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.xs,
              AppSpacing.page,
              AppSpacing.xxl,
            ),
            children: [
              ResponsiveCenter(
                maxWidth: AppSizes.maxFormWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PhotoPickerField(
                      newImagePath: _newImagePath,
                      existingItem: _existing,
                      supportsCamera: picker.supportsCamera,
                      onPick: _pickImage,
                      errorText: _showErrors && _missingImage
                          ? 'A photo is required'
                          : null,
                    ),
                    DetectStatus(
                      phase: _detectPhase,
                      filledAny: _beforeAi != null && _aiFilled.isNotEmpty,
                      creditsLeft: context.watch<AutoDetectController>().left(
                        context.watch<SettingsController>().plan,
                      ),
                      onUndo: _undoAi,
                    ),
                    if (!_isEditing) ...[
                      const SizedBox(height: AppSpacing.md),
                      Center(
                        child: OutlinedButton.icon(
                          onPressed: _readingLink || _saving
                              ? null
                              : _addFromLink,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(
                              0,
                              AppSizes.compactButtonHeight,
                            ),
                          ),
                          icon: _readingLink
                              ? const SizedBox.square(
                                  dimension: AppSizes.iconSm,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.link_rounded,
                                  size: AppSizes.iconSm,
                                ),
                          label: Text(
                            _readingLink
                                ? 'Reading the shop page…'
                                : 'Add from a shop link',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      maxLength: Validators.maxItemNameLength,
                      // Shop names can be long; let them wrap.
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Name',
                        hintText: 'e.g. White linen shirt',
                        counterText: '',
                        suffixIcon: _markIf(_AiField.name),
                      ),
                      validator: (v) => Validators.requiredName(
                        v,
                        subject: 'a name',
                        max: Validators.maxItemNameLength,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    LabeledSection(
                      label: 'Category',
                      badge: _markIf(_AiField.category),
                      child: PillGroup<ClothingCategory>(
                        options: ClothingCategory.values,
                        selected: {?_category},
                        labelOf: (c) => c.singularLabel,
                        leadingOf: (c) => Icon(
                          c.icon,
                          size: 16,
                          color: c == _category ? palette.onInk : palette.ink,
                        ),
                        onToggle: (c) => _update(() {
                          _category = c;
                          _aiFilled.remove(_AiField.category);
                          if (_subcategory?.category != c) {
                            _subcategory = null;
                            _aiFilled.remove(_AiField.subcategory);
                          }
                        }),
                      ),
                    ),
                    if (_category case final category?
                        when ClothingSubcategory.of(category).isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      LabeledSection(
                        label: 'Type',
                        badge: _markIf(_AiField.subcategory),
                        child: PillGroup<ClothingSubcategory>(
                          options: ClothingSubcategory.of(category),
                          selected: {?_subcategory},
                          labelOf: (s) => s.label,
                          // Tapping the chosen type again clears it.
                          onToggle: (s) => _update(() {
                            _subcategory = s == _subcategory ? null : s;
                            _aiFilled.remove(_AiField.subcategory);
                          }),
                        ),
                      ),
                    ],
                    if (_showErrors && _category == null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Choose a category',
                        style: context.textTheme.bodySmall?.copyWith(
                          color: palette.danger,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    LabeledSection(
                      label: 'Color',
                      badge: _markIf(_AiField.color),
                      trailing: _color == null
                          ? null
                          : Text(
                              _color!.label,
                              style: context.textTheme.bodySmall,
                            ),
                      child: ColorSwatchPicker(
                        selected: _color,
                        onChanged: (c) => _update(() {
                          _color = _color == c ? null : c;
                          _aiFilled.remove(_AiField.color);
                        }),
                      ),
                    ),
                    if (_otherColors case final others
                        when others.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      AiOtherColors(
                        colors: others,
                        onPick: (c) => _update(() {
                          _color = c;
                          _aiFilled.remove(_AiField.color);
                        }),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    LabeledSection(
                      label: 'Season',
                      badge: _markIf(_AiField.seasons),
                      child: PillGroup<Season>(
                        options: Season.values,
                        selected: _seasons,
                        labelOf: (s) => s.label,
                        onToggle: (s) => _update(() {
                          if (!_seasons.remove(s)) _seasons.add(s);
                          _aiFilled.remove(_AiField.seasons);
                        }),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _brand,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Brand',
                              suffixIcon: _markIf(_AiField.brand),
                            ),
                            validator: Validators.optionalName,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _price,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,]'),
                              ),
                            ],
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Price',
                              prefixText: currency,
                            ),
                            validator: Validators.optionalPrice,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _brand,
                      // Typing in the brand field narrows the suggestions.
                      builder: (context, value, _) {
                        final typed = value.text.trim().toLowerCase();
                        final matches = AppConfig.suggestedBrands.where(
                          (b) => b.toLowerCase().contains(typed),
                        );
                        if (matches.isEmpty) return const SizedBox.shrink();
                        return PillBar(
                          padding: EdgeInsets.zero,
                          pills: [
                            for (final brand in matches)
                              SelectablePill(
                                label: brand,
                                selected: brand.toLowerCase() == typed,
                                onTap: () => _brand.text =
                                    brand.toLowerCase() == typed ? '' : brand,
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _notes,
                      minLines: 3,
                      maxLines: 6,
                      maxLength: Validators.maxNotesLength,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Notes',
                        hintText:
                            'Fit, care instructions, where you bought it…',
                        alignLabelWithHint: true,
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Favorite'),
                      subtitle: const Text('Show this piece in your favorites'),
                      value: _isFavorite,
                      onChanged: (v) => _update(() => _isFavorite = v),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? SizedBox.square(
                              dimension: AppSizes.iconSm,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: palette.onInk,
                              ),
                            )
                          : Text(
                              _isEditing ? 'Save changes' : 'Add to wardrobe',
                            ),
                    ),
                    if (_existing != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Added ${AppFormatters.shortDate(_existing!.createdAt)}',
                        textAlign: TextAlign.center,
                        style: context.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
