import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/app_dialogs.dart';
import 'package:all_fits/data/models/social.dart';
import 'package:all_fits/features/social/social_controller.dart';
import 'package:all_fits/features/social/social_flows.dart';
import 'package:all_fits/features/social/widgets/social_widgets.dart';
import 'package:all_fits/core/l10n/l10n.dart';

/// Fits' Comments sheet for an outfit or a piece: the comments, oldest
/// first, and "Add a comment..." with a round send button at the bottom.
class CommentsSheet extends StatefulWidget {
  const CommentsSheet({
    super.key,
    required this.ownerId,
    required this.load,
    required this.add,
    required this.delete,
    this.outfitId,
  });

  /// Whose outfit or piece it is; they may delete any comment on it.
  final String ownerId;
  final Future<List<PostComment>> Function() load;
  final Future<PostComment> Function(String body) add;
  final Future<void> Function(String commentId) delete;

  /// Sent with a report, when the comments are on an outfit.
  final String? outfitId;

  /// Resolves to how many comments there are when the sheet closes, or null
  /// when they never loaded.
  static Future<int?> show(
    BuildContext context, {
    required String ownerId,
    required Future<List<PostComment>> Function() load,
    required Future<PostComment> Function(String body) add,
    required Future<void> Function(String commentId) delete,
    String? outfitId,
  }) => showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => CommentsSheet(
      ownerId: ownerId,
      load: load,
      add: add,
      delete: delete,
      outfitId: outfitId,
    ),
  );

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _field = TextEditingController();

  /// Null while loading.
  List<PostComment>? _comments;
  Object? _error;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _comments = null;
      _error = null;
    });
    try {
      final comments = await widget.load();
      if (mounted) setState(() => _comments = comments);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _send() async {
    final body = _field.text.trim();
    if (body.isEmpty || _sending) return;
    if (!await SocialFlows.requireProfile(context) || !mounted) return;
    setState(() => _sending = true);
    try {
      final comment = await widget.add(body);
      if (!mounted) return;
      _field.clear();
      setState(() => _comments = [...?_comments, comment]);
    } catch (error) {
      if (mounted) context.showErrorSnack(error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Delete for the author and the owner; Report for everyone else.
  Future<void> _showMenu(PostComment comment) async {
    final me = context.read<SocialController>().me?.userId;
    final mine = comment.author.userId == me;
    final canDelete = mine || widget.ownerId == me;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canDelete)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: Text(tr('Delete comment')),
                onTap: () => Navigator.of(sheetContext).pop('delete'),
              ),
            if (!mine)
              ListTile(
                leading: const Icon(Icons.error_outline_rounded),
                title: Text(tr('Report')),
                onTap: () => Navigator.of(sheetContext).pop('report'),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'delete':
        await _deleteComment(comment);
      case 'report':
        await SocialFlows.report(
          context,
          comment.author,
          outfitId: widget.outfitId,
        );
    }
  }

  Future<void> _deleteComment(PostComment comment) async {
    final confirmed = await showConfirmDialog(
      context,
      title: tr('Delete this comment?'),
      message: tr('It will be removed for everyone.'),
      confirmLabel: tr('Delete'),
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await widget.delete(comment.id);
      if (!mounted) return;
      setState(() {
        _comments = [
          for (final c in _comments ?? const <PostComment>[])
            if (c.id != comment.id) c,
        ];
      });
    } catch (error) {
      if (mounted) context.showErrorSnack(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_comments?.length);
      },
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.6,
        child: Column(
          children: [
            Text(tr('Comments'), style: context.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Divider(height: 1, color: palette.border),
            Expanded(child: _list(context)),
            _composer(context),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context) {
    final comments = _comments;
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tr('Couldn’t load comments.')),
            TextButton(onPressed: _load, child: Text(tr('Retry'))),
          ],
        ),
      );
    }
    if (comments == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (comments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            tr('No comments yet. Be the first to say something!'),
            textAlign: TextAlign.center,
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      itemCount: comments.length,
      itemBuilder: (context, index) {
        final comment = comments[index];
        return CommentTile(
          comment: comment,
          onAuthorTap: () =>
              SocialFlows.openProfile(context, comment.author.userId),
          onMore: () => _showMenu(comment),
        );
      },
    );
  }

  Widget _composer(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.sm + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        padding: const EdgeInsets.only(left: AppSpacing.md),
        decoration: BoxDecoration(
          border: Border.all(color: palette.border),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _field,
                enabled: !_sending,
                minLines: 1,
                maxLines: 4,
                maxLength: PostComment.maxLength,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: tr('Add a comment…'),
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xxs),
              child: IconButton.filled(
                tooltip: tr('Send'),
                onPressed: _sending ? null : _send,
                style: IconButton.styleFrom(
                  backgroundColor: palette.ink,
                  foregroundColor: palette.onInk,
                ),
                icon: _sending
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: palette.onInk,
                        ),
                      )
                    : const Icon(Icons.arrow_upward_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
