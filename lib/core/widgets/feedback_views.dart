import 'package:flutter/material.dart';

import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/widgets/app_empty_state.dart';

class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key});

  static const double _size = 28;

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox.square(
        dimension: _size,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class AppErrorView extends StatelessWidget {
  const AppErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.cloud_off_outlined,
      title: 'Something went wrong',
      message: describeError(error),
      actionLabel: onRetry == null ? null : 'Try again',
      onAction: onRetry,
    );
  }
}

/// Shown when a route points at a record that no longer exists.
class NotFoundView extends StatelessWidget {
  const NotFoundView({
    super.key,
    this.title = 'Not found',
    this.message = 'This page is no longer available.',
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: AppEmptyState(
        icon: Icons.search_off_rounded,
        title: title,
        message: message,
        actionLabel: 'Go back',
        onAction: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}
