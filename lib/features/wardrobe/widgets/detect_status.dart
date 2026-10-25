import 'dart:async';

import 'package:flutter/material.dart';

import 'package:all_fits/app/routes.dart';
import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/constants/app_durations.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/color_swatch.dart';
import 'package:all_fits/core/widgets/selectable_pill.dart';
import 'package:all_fits/data/models/clothing_color.dart';

/// Where AI detection of the form's photo stands.
enum DetectPhase { idle, running, done, failed, noCredits }

/// The line under the clothing photo while the AI reads it, and what came
/// of it.
class DetectStatus extends StatelessWidget {
  const DetectStatus({
    super.key,
    required this.phase,
    this.filledAny = false,
    this.creditsLeft,
    this.onUndo,
  });

  final DetectPhase phase;

  /// Whether the AI filled in any field, so there is something to undo.
  final bool filledAny;

  /// Free detections left this month; null for Premium.
  final int? creditsLeft;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppDurations.fast,
      alignment: Alignment.topCenter,
      child: switch (phase) {
        DetectPhase.idle => const SizedBox(width: double.infinity),
        DetectPhase.running => const _Row(child: _Detecting()),
        DetectPhase.done => _Row(
          icon: Icons.auto_awesome_rounded,
          text: filledAny
              ? [
                  'Filled in by AI. Check the details',
                  if (creditsLeft case final left?)
                    '$left free ${left == 1 ? 'detection' : 'detections'} '
                        'left this month',
                ].join(' · ')
              : 'AI found nothing new to fill in',
          action: filledAny
              ? TextButton(onPressed: onUndo, child: const Text('Undo'))
              : null,
        ),
        DetectPhase.failed => const _Row(
          icon: Icons.info_outline_rounded,
          text: 'Couldn’t detect this piece. Fill it in yourself.',
        ),
        DetectPhase.noCredits => _Row(
          icon: Icons.auto_awesome_outlined,
          text:
              'You’ve used your ${AppConfig.freeDetectionsPerMonth} free AI '
              'detections this month.',
          action: TextButton(
            onPressed: () => AppNavigator.premium(context),
            child: const Text('Go Premium'),
          ),
        ),
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({this.icon, this.text, this.child, this.action});

  final IconData? icon;
  final String? text;
  final Widget? child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppSizes.iconSm, color: palette.ink),
            const SizedBox(width: AppSpacing.xs),
          ],
          Expanded(
            child:
                child ??
                Text(
                  text!,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Names one thing the AI is reading after another, like Fits, then
/// "Still detecting…" once it has gone through them all.
class _Detecting extends StatefulWidget {
  const _Detecting();

  @override
  State<_Detecting> createState() => _DetectingState();
}

class _DetectingState extends State<_Detecting> {
  static const List<String> _steps = [
    'AI detecting category…',
    'AI detecting color…',
    'AI detecting season…',
    'AI detecting brand…',
    'Still detecting…',
  ];
  static const Duration _stepTime = Duration(milliseconds: 1600);

  late final Timer _timer;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_stepTime, (timer) {
      setState(() => _step++);
      if (_step == _steps.length - 1) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        SizedBox.square(
          dimension: AppSizes.iconSm - 4,
          child: CircularProgressIndicator(strokeWidth: 2, color: palette.ink),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: AnimatedSwitcher(
            duration: AppDurations.fast,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.centerLeft,
              children: [...previous, ?current],
            ),
            child: Text(
              _steps[_step],
              key: ValueKey(_step),
              style: context.textTheme.bodySmall?.copyWith(
                color: palette.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The other colors the AI saw in the piece; tapping one makes it the main
/// color.
class AiOtherColors extends StatelessWidget {
  const AiOtherColors({super.key, required this.colors, required this.onPick});

  final List<ClothingColor> colors;
  final ValueChanged<ClothingColor> onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Also in this piece',
          style: context.textTheme.bodySmall?.copyWith(
            color: context.palette.textSecondary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final color in colors)
                SelectablePill(
                  label: color.label,
                  selected: false,
                  leading: ColorSwatchDot(color: color, size: 14),
                  onTap: () => onPick(color),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Small sparkle beside a field the AI filled in.
class AiMark extends StatelessWidget {
  const AiMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Filled in by AI',
      child: Icon(
        Icons.auto_awesome_rounded,
        size: 14,
        color: context.palette.ink,
      ),
    );
  }
}
