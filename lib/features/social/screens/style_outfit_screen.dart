import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/feedback_views.dart';
import 'package:all_fits/data/models/clothing_category.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/outfit_placement.dart';
import 'package:all_fits/data/models/social.dart';
import 'package:all_fits/features/outfits/widgets/outfit_canvas.dart';
import 'package:all_fits/features/social/social_controller.dart';
import 'package:all_fits/features/social/widgets/social_widgets.dart';
import 'package:all_fits/features/wardrobe/widgets/clothing_grid.dart';

/// "Add outfit for …": pick pieces from [recipient]'s closet, arrange them,
/// add a note and send. The recipient finds it under Styled together.
class StyleOutfitScreen extends StatefulWidget {
  const StyleOutfitScreen({super.key, required this.recipient});

  final SocialProfile recipient;

  @override
  State<StyleOutfitScreen> createState() => _StyleOutfitScreenState();
}

class _StyleOutfitScreenState extends State<StyleOutfitScreen> {
  late Future<PublicCloset?> _closet = _fetch();
  final List<String> _selected = [];
  ClothingCategory? _category;

  Future<PublicCloset?> _fetch() => context
      .read<SocialController>()
      .repository
      .closet(widget.recipient.userId);

  void _toggle(ClothingItem item) => setState(() {
    if (!_selected.remove(item.id)) _selected.add(item.id);
  });

  Future<void> _next(List<ClothingItem> items) async {
    final byId = {for (final item in items) item.id: item};
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _ComposeScreen(
          recipient: widget.recipient,
          items: [for (final id in _selected) ?byId[id]],
        ),
      ),
    );
    if (sent == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text('Add outfit for ${widget.recipient.username}'),
      ),
      body: FutureBuilder<PublicCloset?>(
        future: _closet,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return AppErrorView(
              error: snapshot.error!,
              onRetry: () => setState(() => _closet = _fetch()),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const AppLoadingView();
          }
          // Pieces the owner keeps out of other people's outfits.
          final items = [
            for (final item in snapshot.data?.items ?? const <ClothingItem>[])
              if (!item.noStyling) item,
          ];
          if (items.isEmpty) {
            return AppEmptyState(
              icon: Icons.checkroom_outlined,
              title: 'Nothing to style yet',
              message: snapshot.data == null
                  ? 'You can’t see this closet anymore.'
                  : '${widget.recipient.username} hasn’t added any clothes.',
            );
          }
          final shown = _category == null
              ? items
              : items.where((i) => i.category == _category).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: CategoryPillBar(
                  items: items,
                  selected: _category,
                  onSelected: (c) => setState(() => _category = c),
                ),
              ),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.page,
                        0,
                        AppSpacing.page,
                        AppSpacing.lg,
                      ),
                      sliver: ClothingSliverGrid(
                        items: shown,
                        isSelected: (item) => _selected.contains(item.id),
                        onTap: _toggle,
                      ),
                    ),
                  ],
                ),
              ),
              _SelectionBar(
                count: _selected.length,
                onNext: _selected.isEmpty ? null : () => _next(items),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// "2 selected" and Next, pinned to the bottom like Fits.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.count, required this.onNext});

  final int count;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.page,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  count == 0 ? 'Pick pieces' : '$count selected',
                  style: context.textTheme.titleMedium,
                ),
              ),
              FilledButton.icon(
                onPressed: onNext,
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComposeScreen extends StatefulWidget {
  const _ComposeScreen({required this.recipient, required this.items});

  final SocialProfile recipient;
  final List<ClothingItem> items;

  @override
  State<_ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<_ComposeScreen> {
  static const int _maxMessageLength = 300;

  final TextEditingController _message = TextEditingController();
  List<OutfitPlacement> _layout = const [];
  bool _sending = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    FocusScope.of(context).unfocus();
    final navigator = Navigator.of(context);
    setState(() => _sending = true);
    try {
      await context.read<SocialController>().sendStyledOutfit(
        recipientId: widget.recipient.userId,
        itemIds: [for (final item in widget.items) item.id],
        layout: _layout,
        message: _message.text.trim(),
      );
      if (!mounted) return;
      context.showSnack(
        'Sent to ${widget.recipient.username}. We’ll let them know.',
      );
      navigator.pop(true);
    } catch (error) {
      if (mounted) {
        setState(() => _sending = false);
        context.showErrorSnack(error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(title: const Text('Arrange outfit')),
      body: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          0,
          AppSpacing.page,
          AppSpacing.xxl,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.maxPreviewWidth,
              ),
              child: AspectRatio(
                aspectRatio: AppSizes.outfitImageAspect,
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    border: Border.all(color: palette.border),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    child: OutfitCanvas(
                      items: widget.items,
                      layout: _layout,
                      onChanged: (layout) => setState(() => _layout = layout),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Drag to move, pinch to resize and turn.',
            style: context.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _message,
            minLines: 2,
            maxLines: 4,
            maxLength: _maxMessageLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Message for ${widget.recipient.username}',
              hintText: 'e.g. Try this for Friday dinner',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: const Icon(Icons.send_rounded),
            label: Text('Send to ${widget.recipient.username}'),
          ),
        ],
      ),
    );
  }
}
