import 'package:flutter/material.dart';

import 'package:all_fits/core/constants/app_durations.dart';

/// Fades and lifts [child] into place when it first appears. Items in a list
/// pass their [index] so they arrive one after another.
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  static const double _rise = 16;
  static const int _stepMs = 45;

  /// The stagger restarts after this many items, so later rows never wait
  /// longer than the first one.
  static const int _cycle = 6;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final delay = (index % _cycle) * _stepMs;
    final total = AppDurations.slow.inMilliseconds + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, _rise * (1 - t)),
          child: child,
        ),
      ),
    );
  }
}
