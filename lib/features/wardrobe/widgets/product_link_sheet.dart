import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/remote/product_link_service.dart';

/// Asks for a shop's product link, reads the page and, when it has several
/// photos, lets the user pick the main one. Resolves to null when the user
/// closes the sheet. When the page can't be read the user may still go on
/// by hand: the result then has an empty page that keeps the link.
Future<ProductLinkResult?> showProductLinkSheet(BuildContext context) {
  return showModalBottomSheet<ProductLinkResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _ProductLinkSheet(),
  );
}

enum _Phase { input, reading, choosing, downloading, failed }

class _ProductLinkSheet extends StatefulWidget {
  const _ProductLinkSheet();

  @override
  State<_ProductLinkSheet> createState() => _ProductLinkSheetState();
}

class _ProductLinkSheetState extends State<_ProductLinkSheet> {
  final _link = TextEditingController();
  _Phase _phase = _Phase.input;
  String? _inputError;
  Object? _failure;
  ProductPage? _page;
  int _chosen = 0;
  Completer<void>? _cancel;

  @override
  void dispose() {
    _stop();
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
      _inputError = null;
    });
  }

  /// Drops the request in flight; its answer is ignored.
  void _stop() {
    final cancel = _cancel;
    if (cancel != null && !cancel.isCompleted) cancel.complete();
    _cancel = null;
  }

  Future<void> _read() async {
    final text = _link.text.trim();
    if (ProductPageParser.findUrl(text) == null) {
      setState(() => _inputError = 'Paste a link that starts with https://');
      return;
    }
    FocusScope.of(context).unfocus();
    final service = context.read<ProductLinkService>();
    final cancel = _cancel = Completer<void>();
    setState(() => _phase = _Phase.reading);
    try {
      final page = await service.read(text, cancel: cancel.future);
      if (!mounted || cancel.isCompleted) return;
      _cancel = null;
      _page = page;
      if (page.imageUrls.length > 1) {
        setState(() {
          _chosen = 0;
          _phase = _Phase.choosing;
        });
      } else {
        await _download(page.imageUrl);
      }
    } catch (error) {
      if (!mounted || cancel.isCompleted) return;
      _cancel = null;
      setState(() {
        _failure = error;
        _phase = _Phase.failed;
      });
    }
  }

  /// Downloads [imageUrl] (none: the page has no photo) and hands the page
  /// to the form.
  Future<void> _download(Uri? imageUrl) async {
    final page = _page!;
    if (imageUrl == null) {
      Navigator.of(context).pop(ProductLinkResult(page: page));
      return;
    }
    final service = context.read<ProductLinkService>();
    final cancel = _cancel = Completer<void>();
    setState(() => _phase = _Phase.downloading);
    final path = await service.downloadImage(
      page,
      imageUrl,
      cancel: cancel.future,
    );
    if (!mounted || cancel.isCompleted) return;
    _cancel = null;
    Navigator.of(context).pop(ProductLinkResult(page: page, imagePath: path));
  }

  void _cancelLoading() {
    _stop();
    setState(() {
      // Stopping the photo goes back to the photos, the page to the link.
      _phase = _phase == _Phase.downloading && _page!.imageUrls.length > 1
          ? _Phase.choosing
          : _Phase.input;
    });
  }

  /// Goes on without the page's details, keeping the link.
  void _fillByHand() {
    final url = ProductPageParser.findUrl(_link.text);
    Navigator.of(context).pop(ProductLinkResult(page: ProductPage.empty(url!)));
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
              SheetHeader(
                title: _phase == _Phase.choosing
                    ? 'Choose the main photo'
                    : 'Add from a shop link',
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  child: switch (_phase) {
                    _Phase.input => _buildInput(context),
                    _Phase.reading => _Loading(
                      title: 'Reading the shop page…',
                      message:
                          'This takes up to '
                          '${WebProductLinkService.timeout.inSeconds} seconds.',
                      onCancel: _cancelLoading,
                    ),
                    _Phase.downloading => _Loading(
                      title: 'Downloading the photo…',
                      onCancel: _cancelLoading,
                    ),
                    _Phase.choosing => _buildChoice(context),
                    _Phase.failed => _buildFailure(context),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Copy a product’s link from a brand’s own store, such as Yame, '
          'IVY moda, Juno, 5S Fashion or Tiki. The photo, name, brand and '
          'price are filled in for you to check before saving. Some shops, '
          'like Shopee and Zara, only show products in a web browser and '
          'can’t be read this way.',
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
            if (_inputError != null) setState(() => _inputError = null);
          },
          onSubmitted: (_) => _read(),
          decoration: InputDecoration(
            labelText: 'Product link',
            hintText: 'https://…',
            errorText: _inputError,
            suffixIcon: IconButton(
              tooltip: 'Paste',
              icon: const Icon(Icons.content_paste_rounded),
              onPressed: _paste,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton.icon(
          onPressed: _read,
          icon: const Icon(Icons.download_rounded),
          label: const Text('Get details'),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Photos from shops are only for your own wardrobe: pieces added '
          'from a link are never shown on your public profile.',
          textAlign: TextAlign.center,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.palette.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildChoice(BuildContext context) {
    final page = _page!;
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'This page has ${page.imageUrls.length} photos. Pick the one that '
          'shows the piece best; you can add more photos later.',
          style: context.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.md),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.xs,
          crossAxisSpacing: AppSpacing.xs,
          childAspectRatio: 0.8,
          children: [
            for (final (index, url) in page.imageUrls.indexed)
              Semantics(
                button: true,
                selected: index == _chosen,
                label: 'Photo ${index + 1}',
                child: GestureDetector(
                  onTap: () => setState(() => _chosen = index),
                  child: DecoratedBox(
                    position: DecorationPosition.foreground,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: index == _chosen ? palette.ink : palette.border,
                        width: index == _chosen ? 3 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: ColoredBox(
                        color: palette.surfaceMuted,
                        child: Image.network(
                          url.toString(),
                          fit: BoxFit.cover,
                          cacheWidth: 300,
                          // Some shops only serve photos to their own pages.
                          headers: {'Referer': page.url.toString()},
                          errorBuilder: (_, _, _) => Icon(
                            Icons.broken_image_outlined,
                            color: palette.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: () => _download(page.imageUrls[_chosen]),
          child: const Text('Use this photo'),
        ),
      ],
    );
  }

  Widget _buildFailure(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.link_off_rounded, size: 40, color: palette.textSecondary),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Couldn’t read this page',
          textAlign: TextAlign.center,
          style: context.textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          describeError(_failure!),
          textAlign: TextAlign.center,
          style: context.textTheme.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          onPressed: _fillByHand,
          child: const Text('Add the photo myself'),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          onPressed: () => setState(() => _phase = _Phase.input),
          child: const Text('Try another link'),
        ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.title, required this.onCancel, this.message});

  final String title;
  final String? message;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.lg),
          Text(title, style: context.textTheme.titleMedium),
          if (message case final message?) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(message, style: context.textTheme.bodySmall),
          ],
          const SizedBox(height: AppSpacing.lg),
          OutlinedButton(onPressed: onCancel, child: const Text('Cancel')),
        ],
      ),
    );
  }
}
