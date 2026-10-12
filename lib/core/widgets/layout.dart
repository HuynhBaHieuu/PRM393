import 'package:flutter/material.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';

/// Centers content and caps its width on tablets.
class ResponsiveCenter extends StatelessWidget {
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = AppSizes.maxContentWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// Horizontal page padding that grows on wide screens so content stays
/// centered at [maxWidth].
EdgeInsets pageInsets(
  double width, {
  double maxWidth = AppSizes.maxContentWidth * 1.6,
}) {
  final extra = width > maxWidth ? (width - maxWidth) / 2 : 0.0;
  return EdgeInsets.symmetric(horizontal: AppSpacing.page + extra);
}
