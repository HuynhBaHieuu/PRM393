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
import 'package:all_fits/data/models/season.dart';
import 'package:all_fits/features/premium/premium_flows.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/wardrobe/controllers/clothing_draft.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/features/wardrobe/widgets/photo_picker_field.dart';
import 'package:all_fits/navigation/app_navigation.dart';

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
  ClothingColor? _color;
  final Set<Season> _seasons = {};
  bool _isFavorite = false;
  String? _newImagePath;

  bool _saving = false;
  bool _dirty = false;
  bool _showErrors = false;

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
  }

  @override
  void dispose() {
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
    try {
      final path = await context.read<ImagePickerService>().pickImage(source);
      if (path != null && mounted) _update(() => _newImagePath = path);
    } catch (error) {
      if (mounted) context.showErrorSnack(error);
    }
  }

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
                    const SizedBox(height: AppSpacing.xl),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      maxLength: Validators.maxNameLength,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'e.g. White linen shirt',
                        counterText: '',
                      ),
                      validator: (v) =>
                          Validators.requiredName(v, subject: 'a name'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    LabeledSection(
                      label: 'Category',
                      child: PillGroup<ClothingCategory>(
                        options: ClothingCategory.values,
                        selected: {?_category},
                        labelOf: (c) => c.singularLabel,
                        leadingOf: (c) => Icon(
                          c.icon,
                          size: 16,
                          color: c == _category ? palette.onInk : palette.ink,
                        ),
                        onToggle: (c) => _update(() => _category = c),
                      ),
                    ),
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
                      trailing: _color == null
                          ? null
                          : Text(
                              _color!.label,
                              style: context.textTheme.bodySmall,
                            ),
                      child: ColorSwatchPicker(
                        selected: _color,
                        onChanged: (c) =>
                            _update(() => _color = _color == c ? null : c),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    LabeledSection(
                      label: 'Season',
                      child: PillGroup<Season>(
                        options: Season.values,
                        selected: _seasons,
                        labelOf: (s) => s.label,
                        onToggle: (s) => _update(
                          () => _seasons.contains(s)
                              ? _seasons.remove(s)
                              : _seasons.add(s),
                        ),
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
                            decoration: const InputDecoration(
                              labelText: 'Brand',
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
