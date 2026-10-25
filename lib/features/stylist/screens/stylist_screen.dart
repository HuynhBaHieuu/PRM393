import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/data/local/image_picker_service.dart';
import 'package:all_fits/data/local/image_storage_service.dart';
import 'package:all_fits/data/models/weather.dart';
import 'package:all_fits/data/remote/ai_stylist_service.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/controllers/outfit_draft.dart';
import 'package:all_fits/features/outfits/widgets/item_picker_sheet.dart';
import 'package:all_fits/features/outfits/widgets/outfit_cards.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/stylist/stylist_store.dart';
import 'package:all_fits/features/stylist/widgets/stylist_widgets.dart';
import 'package:all_fits/features/try_on/try_on_controller.dart';
import 'package:all_fits/features/try_on/try_on_flows.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';
import 'package:all_fits/features/weather/controllers/weather_controller.dart';

/// Chat with the AI stylist, which answers with outfits built from the
/// user's wardrobe, packing lists, shopping ideas and try-on pictures. Chats
/// are saved on the device and can be reopened from the history.
/// How the stylist chat opens from elsewhere, e.g. Home's "Find an outfit"
/// or a piece's 💬: a first message, pieces to attach, or a photo to pick.
class StylistLaunch {
  const StylistLaunch({
    this.prompt,
    this.itemIds = const [],
    this.withPhoto = false,
  });

  final String? prompt;
  final List<String> itemIds;

  /// Asks for a photo first and sends it with [prompt].
  final bool withPhoto;
}

class StylistScreen extends StatefulWidget {
  const StylistScreen({super.key, this.launch});

  final StylistLaunch? launch;

  /// Quick starts that send a message: chip label, then the message.
  static const List<(String, String)> prompts = [
    ('Packing list', 'Create a packing list for my next trip.'),
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

  static const String ratePrompt = 'Rate my outfit.';

  static const String colorsPrompt =
      'Find my colors: which color palette suits me best, and which pieces '
      'in my wardrobe match it?';

  static const String findOutfitPrompt = 'Find me an outfit for today.';

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

  /// Completing it stops the request in flight; null when idle.
  Completer<void>? _cancel;
  String _busyLabel = '';

  /// Why the last request failed, and how to try it again.
  Object? _error;
  VoidCallback? _retry;

  bool get _busy => _cancel != null;

  @override
  void initState() {
    super.initState();
    context.read<StylistStore>().load();
    final launch = widget.launch;
    if (launch != null) {
      _attached = [...launch.itemIds];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final prompt = launch.prompt ?? '';
        if (launch.withPhoto) {
          _sendPhoto(prompt);
        } else if (prompt.isNotEmpty) {
          _send(prompt);
        }
      });
    }
  }

  @override
  void dispose() {
    _cancel?.complete();
    _input.dispose();
    super.dispose();
  }

  /// Messages the user may still send today, or null for no limit.
  int? _messagesLeft(BuildContext context) {
    final limit = context.select<SettingsController, int?>(
      (s) => s.plan.stylistMessagesPerDay,
    );
    if (limit == null) return null;
    final (used, bonus) = context.select<StylistStore, (int, int)>(
      (s) => (s.usedToday, s.bonusToday),
    );
    return math.max(0, limit + bonus - used);
  }

  /// Runs one stylist request, showing [label] meanwhile, and adds its answer
  /// to the chat. A stopped request is dropped quietly.
  Future<void> _run(
    String label,
    Future<StylistMessage> Function(Future<void> cancel) request, {
    required VoidCallback retry,
  }) async {
    final cancel = Completer<void>();
    setState(() {
      _cancel = cancel;
      _busyLabel = label;
      _error = null;
      _retry = retry;
    });
    final StylistMessage answer;
    try {
      answer = await request(cancel.future);
    } catch (error) {
      if (mounted && !cancel.isCompleted) {
        setState(() {
          _error = error;
          _cancel = null;
        });
      }
      return;
    }
    if (!mounted || cancel.isCompleted) return;
    setState(() {
      _messages.add(answer);
      _cancel = null;
    });
    final store = context.read<StylistStore>();
    final id = _chatId ??= store.newChatId();
    try {
      await store.countMessage();
      await store.save(id, _messages);
    } catch (error) {
      if (mounted) context.showErrorSnack(error);
    }
  }

  void _stop() {
    _cancel?.complete();
    setState(() {
      _cancel = null;
      _error = null;
    });
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
      try {
        // Kept in app storage so the chat history can show it later.
        photo = await context.read<ImageStorageService>().saveImage(
          pickedPhoto,
        );
      } catch (error) {
        if (mounted) context.showErrorSnack(error);
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

  /// Asks for a reply to the conversation so far.
  Future<void> _answer() {
    final service = context.read<AiStylistService>();
    final store = context.read<StylistStore>();
    final wardrobe = context.read<WardrobeController>().activeItems;
    final weather = _todayWeather();
    final resolve = context.read<ImageStorageService>().resolvePath;
    return _run(
      'Styling…',
      (cancel) => service.reply(
        wardrobe: wardrobe,
        history: List.of(_messages),
        weather: weather,
        persona: store.persona,
        notes: store.notes,
        resolvePhoto: resolve,
        cancel: cancel,
      ),
      retry: _answer,
    );
  }

  /// Today's weather, when the user has picked a city and it has loaded.
  WeatherReport? _todayWeather() {
    final city = context.read<SettingsController>().weatherLocation;
    final report = context.read<WeatherController>().report;
    return city != null && report?.location == city ? report : null;
  }

  /// Opens AI try-on with [outfit]'s pieces.
  Future<void> _tryOn(OutfitSuggestion outfit) =>
      TryOnFlows.start(context, itemIds: outfit.itemIds);

  /// Camera or library; the library straight away without a camera.
  Future<ImagePickSource?> _choosePhotoSource({
    String? title,
    String? message,
  }) async {
    if (!context.read<ImagePickerService>().supportsCamera && title == null) {
      return ImagePickSource.gallery;
    }
    return showModalBottomSheet<ImagePickSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              ListTile(
                title: Text(title),
                subtitle: message == null ? null : Text(message),
              ),
            if (context.read<ImagePickerService>().supportsCamera)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Camera'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImagePickSource.camera),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Library'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(ImagePickSource.gallery),
            ),
          ],
        ),
      ),
    );
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

  /// Sends a photo straight away with [prompt].
  Future<void> _sendPhoto(String prompt) async {
    final source = await _choosePhotoSource();
    if (source != null && await _pickPhoto(source)) await _send(prompt);
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
      builder: (_) => const ChatHistorySheet(),
    );
    if (chat != null && mounted) _show(chat);
  }

  Future<void> _openPersona() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => PersonaSheet(
      onOpenTryOnProfile: () => AppNavigator.tryOnProfile(context),
    ),
  );

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

  Future<void> _shop(ShoppingPick pick) async {
    final url = Uri.https('www.google.com', '/search', {
      'tbm': 'shop',
      'q': pick.query,
    });
    if (!await launchUrl(url, mode: LaunchMode.externalApplication) &&
        mounted) {
      context.showSnack('Could not open the browser.');
    }
  }

  /// Shares the app; the first share each day adds Free messages.
  Future<void> _share() async {
    final store = context.read<StylistStore>();
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          text:
              'I plan my outfits with ${AppConfig.appName} and its AI '
              'stylist. Give it a try!',
        ),
      );
      if (result.status == ShareResultStatus.dismissed) return;
      await store.grantShareBonus();
      if (mounted) {
        context.showSnack(
          'Thanks! You got ${AppConfig.shareBonusMessages} more messages '
          'today.',
        );
      }
    } catch (error) {
      if (mounted) context.showErrorSnack(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.read<AiStylistService>();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: StylistHeader(onTap: _openPersona),
        actions: [
          if (service.isConfigured && _messages.isNotEmpty)
            IconButton(
              tooltip: 'New chat',
              onPressed: _busy ? null : () => _show(null),
              icon: const Icon(Icons.add_comment_outlined),
            ),
          if (service.isConfigured)
            IconButton(
              tooltip: 'Chat history',
              onPressed: _busy ? null : _openHistory,
              icon: const Icon(Icons.history_rounded),
            ),
        ],
      ),
      body: service.isConfigured
          ? _buildChat(
              context,
              canTryOn: context.read<TryOnController>().isAvailable,
            )
          : const AppEmptyState(
              icon: Icons.auto_awesome_outlined,
              title: 'AI stylist isn’t set up',
              message:
                  'Add your API key to assets/env.json, then restart the app.',
            ),
    );
  }

  Widget _buildChat(BuildContext context, {required bool canTryOn}) {
    final canChat =
        context.watch<WardrobeController>().activeItems.length >= _minWardrobe;
    final left = _messagesLeft(context);
    final outOfMessages = left == 0;
    final bonusToday = context.select<StylistStore, int>((s) => s.bonusToday);
    final error = _error;
    final retry = _retry;
    final entries = [
      for (final message in _messages)
        message.fromUser
            ? UserMessageView(message: message)
            : StylistAnswerView(
                message: message,
                saved: _saved,
                onSave: _save,
                onTryOn: canTryOn ? _tryOn : null,
                onShop: _shop,
              ),
      if (_busy) ChatBubble(text: _busyLabel, fromUser: false),
      if (error != null && !_busy && retry != null)
        ChatErrorNote(error: error, onRetry: retry),
    ];
    final chipsEnabled = canChat && !outOfMessages && !_busy;

    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: entries.isEmpty
                ? StylistWelcome(canChat: canChat)
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
          if (chipsEnabled && _messages.isEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              child: Row(
                children: [
                  for (final chip in [
                    ActionChip(
                      avatar: const Icon(Icons.photo_library_outlined),
                      label: const Text('Match a photo'),
                      onPressed: () => _sendPhoto(StylistScreen.photoPrompt),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.star_outline_rounded),
                      label: const Text('Rate my outfit'),
                      onPressed: () => _sendPhoto(StylistScreen.ratePrompt),
                    ),
                    for (final (label, prompt) in StylistScreen.prompts)
                      ActionChip(
                        label: Text(label),
                        onPressed: () => _send(prompt),
                      ),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: chip,
                    ),
                ],
              ),
            ),
          if (left != null && canChat)
            QuotaNote(
              left: left,
              canEarnMore: bonusToday == 0,
              onShare: _share,
            ),
          if (_attached.isNotEmpty || _photo != null)
            PendingAttachments(
              photo: _photo,
              itemIds: _attached,
              onRemovePhoto: () => setState(() => _photo = null),
              onRemove: (id) => setState(
                () => _attached = [..._attached.where((i) => i != id)],
              ),
            ),
          ChatComposer(
            controller: _input,
            enabled: canChat && !outOfMessages,
            busy: _busy,
            hasAttachments: _attached.isNotEmpty || _photo != null,
            maxLength: _maxMessageLength,
            onAttach: _attach,
            onSend: () => _send(_input.text),
            onStop: _stop,
          ),
        ],
      ),
    );
  }
}
