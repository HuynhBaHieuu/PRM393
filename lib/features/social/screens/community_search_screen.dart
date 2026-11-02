import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/extensions/string_extensions.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';
import 'package:all_fits/core/widgets/clothing_image.dart';
import 'package:all_fits/core/widgets/feedback_views.dart';
import 'package:all_fits/data/models/social.dart';
import 'package:all_fits/features/social/screens/community_screen.dart';
import 'package:all_fits/features/social/social_controller.dart';
import 'package:all_fits/features/social/social_flows.dart';
import 'package:all_fits/features/social/widgets/social_widgets.dart';
import 'package:all_fits/core/l10n/l10n.dart';

/// Fits' Community search. While typing: the search itself, then people
/// whose username or name matches. After searching: Clothes and Users tabs.
class CommunitySearchScreen extends StatefulWidget {
  const CommunitySearchScreen({super.key});

  @override
  State<CommunitySearchScreen> createState() => _CommunitySearchScreenState();
}

class _CommunitySearchScreenState extends State<CommunitySearchScreen> {
  final TextEditingController _query = TextEditingController();
  final FocusNode _focus = FocusNode();

  /// Everyone with a profile; null while loading.
  List<SocialProfile>? _people;
  Object? _error;

  /// The search shown in the Clothes and Users tabs; null while typing.
  String? _submitted;

  static const int _maxSuggestions = 20;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final people = await context.read<SocialController>().repository.people();
      if (mounted) {
        setState(() {
          _people = people;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  String get _term => _query.text.replaceAll('@', '').trim();

  List<SocialProfile> _matches(String term) {
    final folded = term.folded;
    return [
      for (final p in _people ?? const <SocialProfile>[])
        if (p.username.contains(folded) ||
            p.displayName.folded.contains(folded))
          p,
    ];
  }

  void _submit() {
    if (_term.isEmpty) return;
    _focus.unfocus();
    setState(() => _submitted = _term);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _query,
          focusNode: _focus,
          autofocus: true,
          autocorrect: false,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() => _submitted = null),
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: tr('Search'),
            prefixIcon: const Icon(Icons.search_rounded),
            isDense: true,
            filled: false,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide(color: palette.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide(color: palette.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              borderSide: BorderSide(color: palette.ink, width: 2),
            ),
          ),
        ),
        actions: const [SizedBox(width: AppSpacing.md)],
      ),
      body: _submitted == null
          ? _suggestions(context)
          : _Results(
              key: ValueKey(_submitted),
              query: _submitted!,
              people: _matches(_submitted!),
              peopleError: _people == null ? _error : null,
              onRetryPeople: _load,
            ),
    );
  }

  Widget _suggestions(BuildContext context) {
    final palette = context.palette;
    final term = _term;
    if (term.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Align(
          alignment: Alignment.topCenter,
          child: Text(
            tr('Search for clothes and users'),
            style: context.textTheme.bodyLarge?.copyWith(
              color: palette.textSecondary,
            ),
          ),
        ),
      );
    }
    final people = _matches(term).take(_maxSuggestions).toList();
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.page,
          ),
          onTap: _submit,
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: palette.border),
            ),
            child: Icon(Icons.search_rounded, color: palette.ink),
          ),
          title: Text(term, style: context.textTheme.titleSmall),
        ),
        if (_people == null && _error == null)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          ),
        for (final profile in people)
          ProfileRow(
            profile: profile,
            onTap: () => SocialFlows.openProfile(context, profile.userId),
          ),
      ],
    );
  }
}

/// Clothes | Users results for one search.
class _Results extends StatelessWidget {
  const _Results({
    super.key,
    required this.query,
    required this.people,
    required this.peopleError,
    required this.onRetryPeople,
  });

  final String query;
  final List<SocialProfile> people;
  final Object? peopleError;
  final Future<void> Function() onRetryPeople;

  @override
  Widget build(BuildContext context) {
    final Widget users;
    if (peopleError != null) {
      users = AppErrorView(error: peopleError!, onRetry: onRetryPeople);
    } else if (people.isEmpty) {
      users = AppEmptyState(
        icon: Icons.search_off_rounded,
        title: tr('No users found'),
        message: tr('Check the spelling, or ask them for their username.'),
      );
    } else {
      users = ListView.builder(
        itemCount: people.length,
        itemBuilder: (context, index) => ProfileRow(
          profile: people[index],
          onTap: () => SocialFlows.openProfile(context, people[index].userId),
        ),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: tr('Clothes')),
              Tab(text: tr('Users')),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _ClothesResults(query: query),
                users,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pieces whose name or brand matches, three across without frames.
class _ClothesResults extends StatefulWidget {
  const _ClothesResults({required this.query});

  final String query;

  @override
  State<_ClothesResults> createState() => _ClothesResultsState();
}

class _ClothesResultsState extends State<_ClothesResults>
    with
        AutomaticKeepAliveClientMixin,
        CommunityPaging<CommunityItem, _ClothesResults> {
  static const int _columns = 3;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    loadMore();
  }

  @override
  Future<List<CommunityItem>> fetchPage(int offset) => context
      .read<SocialController>()
      .repository
      .communityItems(query: widget.query, offset: offset);

  Future<void> _open(CommunityItem entry) async {
    final result = await AppNavigator.publicPiece(context, entry);
    if (result != null && mounted) {
      replaceEntry((e) => e.isSameItem(result), result);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final placeholder = placeholderSliver(
      loadingSliver: const SliverFillRemaining(child: AppLoadingView()),
      empty: AppEmptyState(
        icon: Icons.search_off_rounded,
        title: tr('No clothes found'),
        message: tr('Try another name or brand.'),
      ),
    );
    return pagedScroll(
      slivers: [
        placeholder ??
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.page),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _columns,
                  mainAxisSpacing: AppSpacing.md,
                  crossAxisSpacing: AppSpacing.sm,
                ),
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return Semantics(
                    button: true,
                    label: entry.item.name,
                    child: InkWell(
                      onTap: () => _open(entry),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: ClothingImage(
                        item: entry.item,
                        cutout: true,
                        fit: BoxFit.contain,
                        decodeWidth: 160,
                      ),
                    ),
                  );
                },
              ),
            ),
      ],
    );
  }
}
