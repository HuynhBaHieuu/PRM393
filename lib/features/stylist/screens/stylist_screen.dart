import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/extensions/model_presentation.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/layout.dart';
import 'package:all_fits/core/widgets/selectable_pill.dart';
import 'package:all_fits/core/widgets/small_widgets.dart';
import 'package:all_fits/data/models/occasion.dart';
import 'package:all_fits/data/models/subscription_plan.dart';
import 'package:all_fits/data/remote/ai_stylist_service.dart';
import 'package:all_fits/features/outfits/controllers/outfit_controller.dart';
import 'package:all_fits/features/outfits/controllers/outfit_draft.dart';
import 'package:all_fits/features/outfits/widgets/outfit_collage.dart';
import 'package:all_fits/features/premium/widgets/premium_widgets.dart';
import 'package:all_fits/features/settings/controllers/settings_controller.dart';
import 'package:all_fits/features/wardrobe/controllers/wardrobe_controller.dart';

/// Asks the AI stylist for outfits built from the user's wardrobe.
class StylistScreen extends StatefulWidget {
  const StylistScreen({super.key});

  @override
  State<StylistScreen> createState() => _StylistScreenState();
}

class _StylistScreenState extends State<StylistScreen> {
  static const int _maxNoteLength = 200;

  final TextEditingController _note = TextEditingController();
  Occasion? _occasion;

  bool _busy = false;
  Object? _error;
  List<OutfitSuggestion> _suggestions = const [];

  /// The occasion the current suggestions were made for.
  Occasion? _suggestedFor;
  final Set<OutfitSuggestion> _saved = {};

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _suggest() async {
    FocusScope.of(context).unfocus();
    final occasion = _occasion;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final suggestions = await context.read<AiStylistService>().suggest(
        wardrobe: context.read<WardrobeController>().activeItems,
        occasion: occasion,
        note: _note.text,
      );
      if (!mounted) return;
      setState(() {
        _suggestions = suggestions;
        _suggestedFor = occasion;
        _saved.clear();
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(OutfitSuggestion suggestion) async {
    try {
      await context.read<OutfitController>().createOutfit(
        OutfitDraft(
          name: suggestion.name,
          itemIds: suggestion.itemIds,
          occasion: _suggestedFor,
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
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Close',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('AI Stylist'),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final plan = context.select<SettingsController, SubscriptionPlan>(
      (s) => s.plan,
    );
    if (!plan.hasAiStylist) {
      return const PremiumLockedView(
        title: 'AI Stylist is a Premium feature',
        message:
            'Upgrade to get outfit ideas built from the clothes you '
            'already own.',
      );
    }
    if (!context.read<AiStylistService>().isConfigured) {
      return const AppEmptyState(
        icon: Icons.auto_awesome_outlined,
        title: 'AI stylist isn’t set up',
        message: 'Add your API key to assets/env.json, then restart the app.',
      );
    }
    final wardrobe = context.watch<WardrobeController>();
    if (wardrobe.activeItems.length < 2) {
      return AppEmptyState(
        icon: Icons.checkroom_outlined,
        title: 'Add a few clothes first',
        message: 'The stylist needs at least two pieces to work with.',
        actionLabel: 'Add Clothing',
        onAction: () => AppNavigator.addClothing(context),
      );
    }

    final palette = context.palette;
    final text = context.textTheme;
    final error = _error;
    return ListView(
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
              Text(
                'Get outfit ideas from the clothes you already own.',
                style: text.bodyLarge?.copyWith(color: palette.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              LabeledSection(
                label: 'Occasion',
                child: PillGroup<Occasion>(
                  options: Occasion.values,
                  selected: {?_occasion},
                  labelOf: (o) => o.label,
                  leadingOf: (o) => Icon(
                    o.icon,
                    size: 16,
                    color: o == _occasion ? palette.onInk : palette.ink,
                  ),
                  onToggle: (o) =>
                      setState(() => _occasion = o == _occasion ? null : o),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _note,
                maxLength: _maxNoteLength,
                minLines: 1,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Anything else?',
                  hintText: 'e.g. rainy day, dinner with friends',
                  counterText: '',
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: _busy ? null : _suggest,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
                ),
                icon: _busy
                    ? const SizedBox.square(
                        dimension: AppSizes.iconSm,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_outlined),
                label: Text(
                  _busy
                      ? 'Styling…'
                      : _suggestions.isEmpty
                      ? 'Suggest outfits'
                      : 'Suggest again',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Item names, categories and colors are sent to the AI '
                'service. Photos stay on your device.',
                textAlign: TextAlign.center,
                style: text.bodySmall,
              ),
              if (error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  describeError(error),
                  textAlign: TextAlign.center,
                  style: text.bodyMedium?.copyWith(color: palette.danger),
                ),
              ],
              for (final suggestion in _suggestions) ...[
                const SizedBox(height: AppSpacing.lg),
                _SuggestionCard(
                  suggestion: suggestion,
                  saved: _saved.contains(suggestion),
                  onSave: () => _save(suggestion),
                  onEdit: () => AppNavigator.createOutfit(
                    context,
                    initialItemIds: suggestion.itemIds,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
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
              child: OutfitCollage(items: items, borderRadius: AppRadius.md),
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
