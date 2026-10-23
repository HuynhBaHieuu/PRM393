import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/local/image_storage_service.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/stylist_persona.dart';
import 'package:all_fits/data/remote/ai_stylist_service.dart';
import 'package:all_fits/features/outfits/widgets/outfit_canvas.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/stylist/stylist_store.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';

class StylistAvatar extends StatelessWidget {
  const StylistAvatar({super.key, required this.persona, this.size = 36});

  final StylistPersona persona;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: palette.ink, shape: BoxShape.circle),
      child: Text(
        persona.label.characters.first,
        style: TextStyle(
          color: palette.onInk,
          fontSize: size * 0.45,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

/// The stylist's avatar, name and taste; tap to change stylist.
class StylistHeader extends StatelessWidget {
  const StylistHeader({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final persona = context.select<StylistStore, StylistPersona>(
      (s) => s.persona,
    );
    return Semantics(
      button: true,
      label: 'Change stylist',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Row(
          children: [
            StylistAvatar(persona: persona),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          persona.label,
                          style: text.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.expand_more_rounded, size: 20),
                    ],
                  ),
                  Text(
                    'AI Stylist · ${persona.style}',
                    style: text.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown before the first message.
class StylistWelcome extends StatelessWidget {
  const StylistWelcome({super.key, required this.canChat});

  final bool canChat;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final name = context.select<SettingsController, String>(
      (s) => s.displayName,
    );
    final persona = context.select<StylistStore, StylistPersona>(
      (s) => s.persona,
    );
    final firstName = name.split(' ').first;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StylistAvatar(persona: persona, size: 56),
            const SizedBox(height: AppSpacing.md),
            Text(
              canChat
                  ? firstName.isEmpty
                        ? 'How can I help you?'
                        : 'How can I help you, $firstName?'
                  : 'Add a few clothes first',
              textAlign: TextAlign.center,
              style: text.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              canChat
                  ? 'Ask for an outfit or send a photo, and I’ll build the '
                        'look from your wardrobe. Item names and colors go to '
                        'the AI service, and a photo only when you attach one.'
                  : 'I need at least two pieces to style an outfit.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(
                color: context.palette.textSecondary,
              ),
            ),
            if (!canChat) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () => AppNavigator.addClothing(context),
                child: const Text('Add clothes'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Black bubble on the right for the user, grey on the left for the stylist.
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.text, required this.fromUser});

  final String text;
  final bool fromUser;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: context.screenSize.width * 0.78),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: fromUser ? palette.ink : palette.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: Text(
            text,
            style: context.textTheme.bodyLarge?.copyWith(
              color: fromUser ? palette.onInk : palette.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// A wardrobe piece's photo; opens the piece when [onTap] is null.
class PieceThumb extends StatelessWidget {
  const PieceThumb({super.key, required this.item, this.onTap});

  final ClothingItem item;
  final VoidCallback? onTap;

  static const double size = 48;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: item.name,
      child: InkWell(
        onTap: onTap ?? () => AppNavigator.clothingDetail(context, item.id),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: context.palette.surfaceMuted,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: ClothingImage(
            item: item,
            cutout: true,
            fit: BoxFit.contain,
            decodeWidth: size,
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
    );
  }
}

/// A photo from [path], a file path or `https` URL, or a placeholder when it
/// can't be loaded.
class ChatPhoto extends StatelessWidget {
  const ChatPhoto({super.key, required this.path, required this.size});

  final String? path;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = this.path;
    final placeholder = ColoredBox(
      color: context.palette.surfaceMuted,
      child: Icon(Icons.image_outlined, color: context.palette.textTertiary),
    );
    return Semantics(
      container: true,
      image: true,
      label: 'Photo',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: SizedBox.square(
          dimension: size,
          child: path == null
              ? placeholder
              : Image(
                  image: ResizeImage.resizeIfNeeded(
                    (size * 3).round(),
                    null,
                    path.startsWith('https://')
                        ? NetworkImage(path)
                        : FileImage(File(path)),
                  ),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => placeholder,
                ),
        ),
      ),
    );
  }
}

class UserMessageView extends StatelessWidget {
  const UserMessageView({super.key, required this.message});

  final StylistMessage message;

  static const double _photoSize = 180;

  @override
  Widget build(BuildContext context) {
    final items = context.watch<WardrobeController>().itemsByIds(
      message.itemIds,
    );
    final photo = message.photo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (photo != null) ...[
          ChatPhoto(
            path: context.read<ImageStorageService>().resolvePath(photo),
            size: _photoSize,
          ),
          const SizedBox(height: AppSpacing.xxs),
        ],
        if (items.isNotEmpty) ...[
          Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpacing.xxs,
            runSpacing: AppSpacing.xxs,
            children: [for (final item in items) PieceThumb(item: item)],
          ),
          const SizedBox(height: AppSpacing.xxs),
        ],
        ChatBubble(text: message.text, fromUser: true),
      ],
    );
  }
}

class StylistAnswerView extends StatelessWidget {
  const StylistAnswerView({
    super.key,
    required this.message,
    required this.saved,
    required this.onSave,
    required this.onTryOn,
    required this.onShop,
  });

  final StylistMessage message;
  final Set<OutfitSuggestion> saved;
  final ValueChanged<OutfitSuggestion> onSave;

  /// Null when try-ons aren't available.
  final ValueChanged<OutfitSuggestion>? onTryOn;
  final ValueChanged<ShoppingPick> onShop;

  static const double _photoSize = 260;

  @override
  Widget build(BuildContext context) {
    final photo = message.photo;
    final onTryOn = this.onTryOn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (photo != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: ChatPhoto(
              path: context.read<ImageStorageService>().resolvePath(photo),
              size: _photoSize,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
        ],
        if (message.text.isNotEmpty)
          ChatBubble(text: message.text, fromUser: false),
        if (message.packingList.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          _PackingListCard(itemIds: message.packingList),
        ],
        for (final outfit in message.outfits) ...[
          const SizedBox(height: AppSpacing.xs),
          SuggestionCard(
            suggestion: outfit,
            saved: saved.contains(outfit),
            onSave: () => onSave(outfit),
            onTryOn: onTryOn == null ? null : () => onTryOn(outfit),
          ),
        ],
        if (message.shopping.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          _ShoppingCard(picks: message.shopping, onShop: onShop),
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Material, not a decorated box, so list tiles inside show their ink.
    return Material(
      color: context.palette.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: context.palette.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: child,
      ),
    );
  }
}

class _PackingListCard extends StatelessWidget {
  const _PackingListCard({required this.itemIds});

  final List<String> itemIds;

  @override
  Widget build(BuildContext context) {
    final items = context.watch<WardrobeController>().itemsByIds(itemIds);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Packing list · ${AppFormatters.count(items.length, 'piece')}',
            style: context.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final item in items)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: PieceThumb(item: item),
              title: Text(item.name),
              onTap: () => AppNavigator.clothingDetail(context, item.id),
            ),
        ],
      ),
    );
  }
}

class _ShoppingCard extends StatelessWidget {
  const _ShoppingCard({required this.picks, required this.onShop});

  final List<ShoppingPick> picks;
  final ValueChanged<ShoppingPick> onShop;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Worth buying', style: text.titleMedium),
          for (final pick in picks)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(pick.name),
              subtitle: pick.reason.isEmpty ? null : Text(pick.reason),
              trailing: IconButton(
                tooltip: 'Shop ${pick.name}',
                icon: const Icon(Icons.shopping_bag_outlined),
                onPressed: () => onShop(pick),
              ),
              onTap: () => onShop(pick),
            ),
        ],
      ),
    );
  }
}

class SuggestionCard extends StatelessWidget {
  const SuggestionCard({
    super.key,
    required this.suggestion,
    required this.saved,
    required this.onSave,
    required this.onTryOn,
  });

  final OutfitSuggestion suggestion;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback? onTryOn;

  static const double _previewWidth = 112;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final items = context.watch<WardrobeController>().itemsByIds(
      suggestion.itemIds,
    );
    final compactButton = ButtonStyle(
      minimumSize: WidgetStateProperty.all(
        const Size(0, AppSizes.compactButtonHeight),
      ),
    );
    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _previewWidth,
            child: AspectRatio(
              aspectRatio: AppSizes.outfitImageAspect,
              child: OutfitCanvas(items: items),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(suggestion.name, style: text.titleMedium),
                const SizedBox(height: AppSpacing.xxs),
                // Each piece opens its details.
                Wrap(
                  children: [
                    for (final (index, item) in items.indexed)
                      InkWell(
                        onTap: () =>
                            AppNavigator.clothingDetail(context, item.id),
                        child: Text(
                          index == items.length - 1
                              ? item.name
                              : '${item.name} · ',
                          style: text.bodySmall?.copyWith(
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                  ],
                ),
                if (suggestion.reason.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(suggestion.reason, style: text.bodyMedium),
                ],
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    FilledButton(
                      onPressed: saved ? null : onSave,
                      style: compactButton,
                      child: Text(saved ? 'Saved' : 'Save outfit'),
                    ),
                    OutlinedButton(
                      onPressed: () => AppNavigator.createOutfit(
                        context,
                        initialItemIds: suggestion.itemIds,
                      ),
                      style: compactButton,
                      child: const Text('Edit'),
                    ),
                    if (onTryOn != null)
                      OutlinedButton.icon(
                        onPressed: onTryOn,
                        style: compactButton,
                        icon: const Icon(Icons.accessibility_new_rounded),
                        label: const Text('Try on'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ChatErrorNote extends StatelessWidget {
  const ChatErrorNote({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          describeError(error),
          textAlign: TextAlign.end,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.palette.danger,
          ),
        ),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      ],
    );
  }
}

/// Free plan: messages left today, or ways to get more once they run out.
class QuotaNote extends StatelessWidget {
  const QuotaNote({
    super.key,
    required this.left,
    required this.canEarnMore,
    required this.onShare,
  });

  final int left;

  /// Whether sharing can still add messages today.
  final bool canEarnMore;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xs,
        AppSpacing.page,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            left == 0
                ? 'You’ve used today’s free messages. Come back tomorrow or '
                      'go Premium for unlimited chat.'
                : '${AppFormatters.count(left, 'free message')} left today',
            style: context.textTheme.bodySmall,
          ),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              if (left == 0 && canEarnMore)
                TextButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.ios_share_rounded),
                  label: Text(
                    'Share with a friend: +${AppConfig.shareBonusMessages}',
                  ),
                ),
              TextButton(
                onPressed: () => AppNavigator.premium(context),
                child: const Text('See Premium'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A photo and pieces waiting to be sent with the next message; tap one to
/// remove it.
class PendingAttachments extends StatelessWidget {
  const PendingAttachments({
    super.key,
    required this.photo,
    required this.itemIds,
    required this.onRemovePhoto,
    required this.onRemove,
  });

  /// Local file path of the picked photo.
  final String? photo;
  final List<String> itemIds;
  final VoidCallback onRemovePhoto;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final photo = this.photo;
    final items = context.watch<WardrobeController>().itemsByIds(itemIds);
    Widget removable(String label, VoidCallback onTap, Widget thumb) => Tooltip(
      message: 'Remove $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Stack(
          children: [
            thumb,
            Positioned(
              top: 2,
              right: 2,
              child: Icon(
                Icons.cancel_rounded,
                size: AppSizes.iconSm,
                color: context.palette.ink,
              ),
            ),
          ],
        ),
      ),
    );
    return SizedBox(
      height: PieceThumb.size + AppSpacing.sm,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          0,
        ),
        children: [
          if (photo != null)
            removable(
              'photo',
              onRemovePhoto,
              ChatPhoto(path: photo, size: PieceThumb.size),
            ),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xs),
              child: removable(
                item.name,
                () => onRemove(item.id),
                IgnorePointer(child: PieceThumb(item: item)),
              ),
            ),
        ],
      ),
    );
  }
}

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.busy,
    required this.hasAttachments,
    required this.maxLength,
    required this.onAttach,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool busy;
  final bool hasAttachments;
  final int maxLength;
  final VoidCallback onAttach;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final style = IconButton.styleFrom(
      backgroundColor: palette.ink,
      foregroundColor: palette.onInk,
    );
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.sm,
        AppSpacing.page,
        AppSpacing.sm,
      ),
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Attach',
            onPressed: enabled && !busy ? onAttach : null,
            icon: const Icon(Icons.add_rounded),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              maxLength: maxLength,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Ask anything',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: false,
                counterText: '',
              ),
            ),
          ),
          if (busy)
            IconButton.filled(
              tooltip: 'Stop',
              onPressed: onStop,
              icon: const Icon(Icons.stop_rounded),
              style: style,
            )
          else
            ValueListenableBuilder(
              valueListenable: controller,
              builder: (context, value, _) => IconButton.filled(
                tooltip: 'Send',
                onPressed:
                    enabled && (hasAttachments || value.text.trim().isNotEmpty)
                    ? onSend
                    : null,
                icon: const Icon(Icons.arrow_upward_rounded),
                style: style,
              ),
            ),
        ],
      ),
    );
  }
}

/// Past chats, newest first. Resolves to the chat to reopen.
class ChatHistorySheet extends StatelessWidget {
  const ChatHistorySheet({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StylistStore>();
    final chats = store.chats;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Column(
        children: [
          const SheetHeader(title: 'Chat history'),
          Expanded(
            child: chats.isEmpty
                ? SingleChildScrollView(
                    controller: scrollController,
                    child: const AppEmptyState(
                      compact: true,
                      icon: Icons.history_rounded,
                      title: 'No chats yet',
                      message:
                          'Your conversations with the stylist show up here.',
                    ),
                  )
                : ListView.builder(
                    controller: scrollController,
                    itemCount: chats.length,
                    itemBuilder: (context, index) {
                      final chat = chats[index];
                      return ListTile(
                        title: Text(
                          chat.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          AppFormatters.relativeDay(chat.updatedAt),
                        ),
                        onTap: () => Navigator.of(context).pop(chat),
                        trailing: IconButton(
                          tooltip: 'Delete chat',
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () async {
                            try {
                              await store.delete(chat.id);
                            } catch (error) {
                              if (context.mounted) {
                                context.showErrorSnack(error);
                              }
                            }
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Picks the stylist, says what they should know about the user, and sets
/// the try-on photo.
class PersonaSheet extends StatefulWidget {
  const PersonaSheet({super.key, required this.onChangeBodyPhoto});

  final VoidCallback onChangeBodyPhoto;

  @override
  State<PersonaSheet> createState() => _PersonaSheetState();
}

class _PersonaSheetState extends State<PersonaSheet> {
  late final TextEditingController _notes = TextEditingController(
    text: context.read<StylistStore>().notes,
  );

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) context.showErrorSnack(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<StylistStore>();
    final text = context.textTheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (_, scrollController) => ListView(
        controller: scrollController,
        children: [
          const SheetHeader(title: 'Your stylist'),
          for (final persona in StylistPersona.values)
            ListTile(
              leading: StylistAvatar(persona: persona),
              title: Text(persona.label),
              subtitle: Text(persona.style),
              selected: persona == store.persona,
              trailing: persona == store.persona
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () => _guard(() => store.setPersona(persona)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.lg,
              AppSpacing.page,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('About you', style: text.titleMedium),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: _notes,
                  maxLength: 300,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText:
                        'Anything ${store.persona.label} should know? '
                        'e.g. 1m75, I like loose fits, no shorts',
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => _guard(() async {
                      await store.setNotes(_notes.text);
                      if (mounted) this.context.showSnack('Saved');
                    }),
                    child: const Text('Save'),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.accessibility_new_rounded),
                  title: const Text('Try-on photo'),
                  subtitle: Text(
                    store.bodyPhoto == null
                        ? 'A full-body photo of you, used to try outfits on'
                        : 'Used to try outfits on',
                  ),
                  trailing: Text(store.bodyPhoto == null ? 'Add' : 'Change'),
                  onTap: widget.onChangeBodyPhoto,
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
