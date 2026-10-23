import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/formatters.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/local/image_picker_service.dart';
import 'package:all_fits/data/local/image_storage_service.dart';
import 'package:all_fits/data/models/clothing_item.dart';
import 'package:all_fits/data/models/weather.dart';
import 'package:all_fits/data/remote/ai_stylist_service.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/controllers/outfit_draft.dart';
import 'package:all_fits/features/outfits/widgets/item_picker_sheet.dart';
import 'package:all_fits/features/outfits/widgets/outfit_canvas.dart';
import 'package:all_fits/features/outfits/widgets/outfit_cards.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/stylist/stylist_history.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/features/weather/controllers/weather_controller.dart';

/// Chat with the AI stylist, which answers with outfits built from the
/// user's wardrobe. Chats are saved on the device and can be reopened from
/// the history.
class StylistScreen extends StatefulWidget {
  const StylistScreen({super.key});

  /// Quick starts shown before the first message: chip label, then the
  /// message it sends.
  static const List<(String, String)> prompts = [
    ('Work', 'What should I wear to work today?'),
    ('Date', 'Help me pick an outfit for a date tonight.'),
    ('Rainy day', 'It’s a rainy day. What should I wear?'),
    ('Weekend', 'Give me a relaxed weekend outfit.'),
  ];

  /// Sent when the user attaches pieces without typing anything.
  static const String attachPrompt =
      'Please include my selected pieces in the outfit.';

  /// Sent when the user attaches a photo without typing anything.
  static const String photoPrompt =
      'Pick clothes from my wardrobe that go with this photo.';

  @override
  State<StylistScreen> createState() => _StylistScreenState();
}

enum _Attachment { camera, library, clothes, outfit }

class _StylistScreenState extends State<StylistScreen> {
  static const int _maxMessageLength = 500;

  /// Fewer pieces than this can't make an outfit.
  static const int _minWardrobe = 2;

  final TextEditingController _input = TextEditingController();
  List<StylistMessage> _messages = [];
  final Set<OutfitSuggestion> _saved = {};

  /// Pieces to send with the next message.
  List<String> _attached = [];

  /// Picked photo, still in the picker's temporary folder, to send with the
  /// next message.
  String? _photo;

  /// Id of the saved chat on screen; null until the first answer.
  String? _chatId;

  bool _busy = false;

  /// Why the answer to the last user message failed, if it did.
  Object? _error;

  @override
  void initState() {
    super.initState();
    context.read<StylistHistory>().load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  /// Messages the user may still send today, or null for no limit.
  int? _messagesLeft(BuildContext context) {
    final limit = context.select<SettingsController, int?>(
      (s) => s.plan.stylistMessagesPerDay,
    );
    if (limit == null) return null;
    final used = context.select<StylistHistory, int>((h) => h.usedToday);
    return math.max(0, limit - used);
  }

  Future<void> _send(String text) async {
    final attached = _attached;
    final pickedPhoto = _photo;
    var message = text.trim();
    if (message.isEmpty) {
      if (pickedPhoto != null) {
        message = StylistScreen.photoPrompt;
      } else if (attached.isNotEmpty) {
        message = StylistScreen.attachPrompt;
      }
    }
    if (message.isEmpty || _busy) return;
    String? photo;
    if (pickedPhoto != null) {
      setState(() => _busy = true);
      try {
        // Kept in app storage so the chat history can show it later.
        photo = await context.read<ImageStorageService>().saveImage(
          pickedPhoto,
        );
      } catch (error) {
        if (mounted) {
          setState(() => _busy = false);
          context.showErrorSnack(error);
        }
        return;
      }
      if (!mounted) return;
    }
    _input.clear();
    setState(() {
      _messages.add(
        StylistMessage.user(message, itemIds: attached, photo: photo),
      );
      _attached = [];
      _photo = null;
    });
    await _answer();
  }

  /// Asks for a reply to the conversation so far; also retries a failure.
  Future<void> _answer() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final StylistMessage reply;
    try {
      reply = await context.read<AiStylistService>().reply(
        wardrobe: context.read<WardrobeController>().activeItems,
        history: List.of(_messages),
        weather: _todayWeather(),
        resolvePhoto: context.read<ImageStorageService>().resolvePath,
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _busy = false;
        });
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _messages.add(reply);
      _busy = false;
    });
    final history = context.read<StylistHistory>();
    final id = _chatId ??= history.newChatId();
    try {
      await history.countMessage();
      await history.save(id, _messages);
    } catch (error) {
      if (mounted) context.showErrorSnack(error);
    }
  }

  /// Today's weather, when the user has picked a city and it has loaded.
  WeatherReport? _todayWeather() {
    final city = context.read<SettingsController>().weatherLocation;
    final report = context.read<WeatherController>().report;
    return city != null && report?.location == city ? report : null;
  }

  void _show(StylistChat? chat) {
    _input.clear();
    setState(() {
      _messages = [...?chat?.messages];
      _chatId = chat?.id;
      _attached = [];
      _photo = null;
      _saved.clear();
      _error = null;
    });
  }

  Future<void> _openHistory() async {
    final chat = await showModalBottomSheet<StylistChat>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _HistorySheet(),
    );
    if (chat != null && mounted) _show(chat);
  }

  /// Picks a photo to send with the next message; returns whether one was
  /// picked.
  Future<bool> _pickPhoto(ImagePickSource source) async {
    try {
      final path = await context.read<ImagePickerService>().pickImage(source);
      if (path == null || !mounted) return false;
      setState(() => _photo = path);
      return true;
    } catch (error) {
      if (mounted) context.showErrorSnack(error);
      return false;
    }
  }

  /// Sends a photo from the library straight away for matching clothes.
  Future<void> _matchPhoto() async {
    if (await _pickPhoto(ImagePickSource.gallery)) await _send('');
  }

  Future<void> _attach() async {
    final camera = context.read<ImagePickerService>().supportsCamera;
    Widget option(
      BuildContext sheetContext,
      IconData icon,
      String label,
      _Attachment value,
    ) => ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () => Navigator.of(sheetContext).pop(value),
    );
    final kind = await showModalBottomSheet<_Attachment>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (camera)
              option(
                sheetContext,
                Icons.photo_camera_outlined,
                'Camera',
                _Attachment.camera,
              ),
            option(
              sheetContext,
              Icons.photo_library_outlined,
              'Library',
              _Attachment.library,
            ),
            option(
              sheetContext,
              Icons.checkroom_outlined,
              'Clothes',
              _Attachment.clothes,
            ),
            option(
              sheetContext,
              Icons.style_outlined,
              'Outfits',
              _Attachment.outfit,
            ),
          ],
        ),
      ),
    );
    if (kind == null || !mounted) return;
    final List<String>? picked;
    switch (kind) {
      case _Attachment.camera:
        await _pickPhoto(ImagePickSource.camera);
        return;
      case _Attachment.library:
        await _pickPhoto(ImagePickSource.gallery);
        return;
      case _Attachment.clothes:
        picked = await showItemPickerSheet(
          context,
          slot: null,
          selected: _attached.toSet(),
        );
      case _Attachment.outfit:
        final outfits = context.read<OutfitController>();
        final id = await showOutfitPickerSheet(
          context,
          title: 'Attach an outfit',
          outfits: outfits.outfits,
        );
        picked = id == null ? null : outfits.outfitById(id)?.itemIds;
    }
    if (picked != null && mounted) setState(() => _attached = picked!);
  }

  Future<void> _save(OutfitSuggestion suggestion) async {
    try {
      await context.read<OutfitController>().createOutfit(
        OutfitDraft(
          name: suggestion.name,
          itemIds: suggestion.itemIds,
          notes: suggestion.reason,
        ),
      );
      if (!mounted) return;
      setState(() => _saved.add(suggestion));
      context.showSnack('${suggestion.name} saved to your outfits');
    } catch (error) {
      if (mounted) context.showErrorSnack(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured = context.read<AiStylistService>().isConfigured;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: const _StylistHeader(),
        actions: [
          if (configured && _messages.isNotEmpty)
            IconButton(
              tooltip: 'New chat',
              onPressed: _busy ? null : () => _show(null),
              icon: const Icon(Icons.add_comment_outlined),
            ),
          if (configured)
            IconButton(
              tooltip: 'Chat history',
              onPressed: _busy ? null : _openHistory,
              icon: const Icon(Icons.history_rounded),
            ),
        ],
      ),
      body: configured
          ? _buildChat(context)
          : const AppEmptyState(
              icon: Icons.auto_awesome_outlined,
              title: 'AI stylist isn’t set up',
              message:
                  'Add your API key to assets/env.json, then restart the app.',
            ),
    );
  }

  Widget _buildChat(BuildContext context) {
    final canChat =
        context.watch<WardrobeController>().activeItems.length >= _minWardrobe;
    final left = _messagesLeft(context);
    final outOfMessages = left == 0;
    final error = _error;
    final entries = [
      for (final message in _messages)
        message.fromUser
            ? _UserMessage(message: message)
            : _StylistAnswer(message: message, saved: _saved, onSave: _save),
      if (_busy) const _Bubble(text: 'Styling…', fromUser: false),
      if (error != null && !_busy) _ErrorNote(error: error, onRetry: _answer),
    ];

    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: entries.isEmpty
                ? _Welcome(canChat: canChat)
                : ListView.separated(
                    // Reversed so the newest message sits above the input.
                    reverse: true,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(AppSpacing.page),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, index) =>
                        entries[entries.length - 1 - index],
                  ),
          ),
          if (canChat && !outOfMessages && _messages.isEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: ActionChip(
                      avatar: const Icon(Icons.photo_library_outlined),
                      label: const Text('Match a photo'),
                      onPressed: _busy ? null : _matchPhoto,
                    ),
                  ),
                  for (final (label, prompt) in StylistScreen.prompts)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: ActionChip(
                        label: Text(label),
                        onPressed: () => _send(prompt),
                      ),
                    ),
                ],
              ),
            ),
          if (left != null && canChat) _QuotaNote(left: left),
          if (_attached.isNotEmpty || _photo != null)
            _Attachments(
              photo: _photo,
              itemIds: _attached,
              onRemovePhoto: () => setState(() => _photo = null),
              onRemove: (id) => setState(
                () => _attached = [..._attached.where((i) => i != id)],
              ),
            ),
          _Composer(
            controller: _input,
            enabled: canChat && !outOfMessages,
            busy: _busy,
            hasAttachments: _attached.isNotEmpty || _photo != null,
            maxLength: _maxMessageLength,
            onAttach: _attach,
            onSend: () => _send(_input.text),
          ),
        ],
      ),
    );
  }
}

class _StylistAvatar extends StatelessWidget {
  const _StylistAvatar({this.size = 36});

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
        AiStylistService.stylistName.characters.first,
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

class _StylistHeader extends StatelessWidget {
  const _StylistHeader();

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    return Row(
      children: [
        const _StylistAvatar(),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AiStylistService.stylistName,
                style: text.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'AI Stylist',
                style: text.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shown before the first message.
class _Welcome extends StatelessWidget {
  const _Welcome({required this.canChat});

  final bool canChat;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final name = context.select<SettingsController, String>(
      (s) => s.displayName,
    );
    final firstName = name.split(' ').first;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _StylistAvatar(size: 56),
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
class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.fromUser});

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

class _PieceThumb extends StatelessWidget {
  const _PieceThumb({required this.item});

  final ClothingItem item;

  static const double size = 48;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: item.name,
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
    );
  }
}

class _UserMessage extends StatelessWidget {
  const _UserMessage({required this.message});

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
          _PhotoThumb(
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
            children: [for (final item in items) _PieceThumb(item: item)],
          ),
          const SizedBox(height: AppSpacing.xxs),
        ],
        _Bubble(text: message.text, fromUser: true),
      ],
    );
  }
}

class _StylistAnswer extends StatelessWidget {
  const _StylistAnswer({
    required this.message,
    required this.saved,
    required this.onSave,
  });

  final StylistMessage message;
  final Set<OutfitSuggestion> saved;
  final ValueChanged<OutfitSuggestion> onSave;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (message.text.isNotEmpty)
          _Bubble(text: message.text, fromUser: false),
        for (final outfit in message.outfits) ...[
          const SizedBox(height: AppSpacing.xs),
          _SuggestionCard(
            suggestion: outfit,
            saved: saved.contains(outfit),
            onSave: () => onSave(outfit),
            onEdit: () => AppNavigator.createOutfit(
              context,
              initialItemIds: outfit.itemIds,
            ),
          ),
        ],
      ],
    );
  }
}

class _ErrorNote extends StatelessWidget {
  const _ErrorNote({required this.error, required this.onRetry});

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

/// Free plan: messages left today, or an upgrade offer once they run out.
class _QuotaNote extends StatelessWidget {
  const _QuotaNote({required this.left});

  final int left;

  @override
  Widget build(BuildContext context) {
    final style = context.textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        AppSpacing.xs,
        AppSpacing.page,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              left == 0
                  ? 'You’ve used today’s free messages. Come back tomorrow '
                        'or go Premium for unlimited chat.'
                  : '${AppFormatters.count(left, 'free message')} left today',
              style: style,
            ),
          ),
          TextButton(
            onPressed: () => AppNavigator.premium(context),
            child: const Text('See Premium'),
          ),
        ],
      ),
    );
  }
}

/// A photo and pieces waiting to be sent with the next message; tap one to
/// remove it.
class _Attachments extends StatelessWidget {
  const _Attachments({
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
    Widget removable(String label, VoidCallback onTap, Widget thumb) =>
        Tooltip(
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
      height: _PieceThumb.size + AppSpacing.sm,
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
              _PhotoThumb(path: photo, size: _PieceThumb.size),
            ),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xs),
              child: removable(
                item.name,
                () => onRemove(item.id),
                _PieceThumb(item: item),
              ),
            ),
        ],
      ),
    );
  }
}

/// A photo from [path], a file path or `https` URL, or a placeholder when it
/// can't be loaded.
class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.path, required this.size});

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

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.busy,
    required this.hasAttachments,
    required this.maxLength,
    required this.onAttach,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool busy;
  final bool hasAttachments;
  final int maxLength;
  final VoidCallback onAttach;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
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
          ValueListenableBuilder(
            valueListenable: controller,
            builder: (context, value, _) => IconButton.filled(
              tooltip: 'Send',
              onPressed:
                  enabled &&
                      !busy &&
                      (hasAttachments || value.text.trim().isNotEmpty)
                  ? onSend
                  : null,
              icon: const Icon(Icons.arrow_upward_rounded),
              style: IconButton.styleFrom(
                backgroundColor: palette.ink,
                foregroundColor: palette.onInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Past chats, newest first. Resolves to the chat to reopen.
class _HistorySheet extends StatelessWidget {
  const _HistorySheet();

  @override
  Widget build(BuildContext context) {
    final history = context.watch<StylistHistory>();
    final chats = history.chats;
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
                      message: 'Your conversations with the stylist show up '
                          'here.',
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
                        subtitle: Text(AppFormatters.relativeDay(chat.updatedAt)),
                        onTap: () => Navigator.of(context).pop(chat),
                        trailing: IconButton(
                          tooltip: 'Delete chat',
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () async {
                            try {
                              await history.delete(chat.id);
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

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.saved,
    required this.onSave,
    required this.onEdit,
  });

  final OutfitSuggestion suggestion;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onEdit;

  static const double _previewWidth = 112;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.textTheme;
    final items = context.watch<WardrobeController>().itemsByIds(
      suggestion.itemIds,
    );
    final compactButton = ButtonStyle(
      minimumSize: WidgetStateProperty.all(
        const Size(0, AppSizes.compactButtonHeight),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: palette.border),
      ),
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
                Text(
                  items.map((item) => item.name).join(' · '),
                  style: text.bodySmall,
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
                      onPressed: onEdit,
                      style: compactButton,
                      child: const Text('Edit'),
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
