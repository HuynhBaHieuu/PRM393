import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_color.dart';
import 'package:all_fits/data/models/shopping_item.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/shopping/controllers/shopping_controller.dart';
import 'package:all_fits/features/shopping/controllers/shopping_draft.dart';

/// Add an item to the shopping list, or edit one when [itemId] is given.
class ShoppingItemFormScreen extends StatefulWidget {
  const ShoppingItemFormScreen({super.key, this.itemId});

  final String? itemId;

  @override
  State<ShoppingItemFormScreen> createState() => _ShoppingItemFormScreenState();
}

class _ShoppingItemFormScreenState extends State<ShoppingItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _brand;
  late final TextEditingController _price;
  late final TextEditingController _link;
  late final TextEditingController _notes;

  ShoppingItem? _existing;
  ClothingCategory? _category;
  ClothingColor? _color;
  ShoppingPriority _priority = ShoppingPriority.medium;

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
        : context.read<ShoppingController>().itemById(itemId);
    _existing = item;
    _category = item?.category;
    _color = item?.color;
    _priority = item?.priority ?? ShoppingPriority.medium;
    _name = TextEditingController(text: item?.name);
    _brand = TextEditingController(text: item?.brand);
    _price = TextEditingController(
      text: item?.price == null ? '' : _formatPriceInput(item!.price!),
    );
    _link = TextEditingController(text: item?.link);
    _notes = TextEditingController(text: item?.notes);
    for (final controller in [_name, _brand, _price, _link, _notes]) {
      controller.addListener(_markDirty);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _price.dispose();
    _link.dispose();
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

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    setState(() => _showErrors = true);
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid || _category == null) {
      context.showSnack('Please complete the highlighted fields.');
      return;
    }

    final draft = ShoppingDraft(
      name: _name.text,
      category: _category,
      color: _color,
      brand: _brand.text,
      price: Validators.parsePrice(_price.text),
      link: _link.text,
      notes: _notes.text,
      priority: _priority,
    );

    setState(() => _saving = true);
    final shopping = context.read<ShoppingController>();
    final navigator = Navigator.of(context);
    try {
      if (_existing == null) {
        final item = await shopping.addItem(draft);
        _dirty = false;
        navigator.pop();
        if (mounted) context.showSnack('${item.name} added to your list');
      } else {
        await shopping.updateItem(_existing!.id, draft);
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
        message: 'This item is no longer on your shopping list.',
      );
    }
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
          title: Text(_isEditing ? 'Edit wish' : 'Add to shopping list'),
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
              AppSpacing.md,
              AppSpacing.page,
              AppSpacing.xxl,
            ),
            children: [
              ResponsiveCenter(
                maxWidth: AppSizes.maxFormWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.next,
                      maxLength: Validators.maxNameLength,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        hintText: 'e.g. Black leather boots',
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
                      label: 'Priority',
                      child: PillGroup<ShoppingPriority>(
                        options: ShoppingPriority.values,
                        selected: {_priority},
                        labelOf: (p) => p.label,
                        onToggle: (p) => _update(() => _priority = p),
                      ),
                    ),
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
                              labelText: 'Brand / store',
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
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _link,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Link',
                        hintText: 'shop.com/product',
                      ),
                      validator: Validators.optionalLink,
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
                        hintText: 'Size, fit, what it would go with…',
                        alignLabelWithHint: true,
                      ),
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
                          : Text(_isEditing ? 'Save changes' : 'Add to list'),
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
