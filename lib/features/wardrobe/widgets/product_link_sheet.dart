import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/remote/product_link_service.dart';

/// Asks for a shop's product link. Returns the text the user entered, or
/// null when they close the sheet.
Future<String?> showProductLinkSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _ProductLinkSheet(),
  );
}

class _ProductLinkSheet extends StatefulWidget {
  const _ProductLinkSheet();

  @override
  State<_ProductLinkSheet> createState() => _ProductLinkSheetState();
}

class _ProductLinkSheetState extends State<_ProductLinkSheet> {
  final _link = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  // The clipboard is read only when the user taps Paste, never on open.
  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty || !mounted) return;
    setState(() {
      _link.text = text;
      _error = null;
    });
  }

  void _submit() {
    final text = _link.text.trim();
    if (ProductPageParser.findUrl(text) == null) {
      setState(() => _error = 'Paste a link that starts with https://');
      return;
    }
    Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetHeader(title: 'Add from a shop link'),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.page,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Copy a product’s link from a brand’s own store, such '
                      'as Yame, IVY moda, Juno, 5S Fashion or Tiki. The '
                      'photo, name, brand and price are filled in for you to '
                      'check before saving. Some shops, like Shopee and Zara, '
                      'only show products in a web browser and can’t be '
                      'added this way.',
                      style: context.textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: _link,
                      autofocus: true,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.go,
                      autocorrect: false,
                      onChanged: (_) {
                        if (_error != null) setState(() => _error = null);
                      },
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Product link',
                        hintText: 'https://…',
                        errorText: _error,
                        suffixIcon: IconButton(
                          tooltip: 'Paste',
                          icon: const Icon(Icons.content_paste_rounded),
                          onPressed: _paste,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Get details'),
                    ),
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
