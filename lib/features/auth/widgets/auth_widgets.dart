import 'package:flutter/material.dart';

import 'package:all_fits/core/constants/app_config.dart';
import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/widgets/section_header.dart';

/// Shared layout for the sign-in screens: brand, title and a scrollable,
/// keyboard-safe form column capped to form width on tablets.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.children,
    this.showBack = false,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final text = context.textTheme;
    final palette = context.palette;
    return Scaffold(
      appBar: showBack ? AppBar() : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.xl,
              AppSpacing.page,
              AppSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.maxFormWidth,
              ),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      AppConfig.appName,
                      style: text.titleLarge?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Eyebrow(eyebrow),
                    const SizedBox(height: AppSpacing.xs),
                    Text(title, style: text.displaySmall),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      style: text.bodyLarge?.copyWith(
                        color: palette.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Password input with a show/hide toggle.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.validator,
    this.autofillHints = const [AutofillHints.password],
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String> validator;
  final Iterable<String> autofillHints;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscured = true;

  // "Next" on the keyboard should jump to the following field, not the
  // show/hide toggle.
  final FocusNode _toggleFocus = FocusNode(skipTraversal: true);

  @override
  void dispose() {
    _toggleFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscured,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: widget.autofillHints,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          focusNode: _toggleFocus,
          tooltip: _obscured ? 'Show password' : 'Hide password',
          icon: Icon(
            _obscured
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
          onPressed: () => setState(() => _obscured = !_obscured),
        ),
      ),
      validator: widget.validator,
    );
  }
}

/// Inline error shown above the submit button.
class AuthErrorBanner extends StatelessWidget {
  const AuthErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: palette.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: AppSizes.iconSm,
            color: palette.danger,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: context.textTheme.bodyMedium?.copyWith(
                color: palette.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width primary button that shows a spinner while [busy].
class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
      ),
      child: busy
          ? SizedBox.square(
              dimension: AppSizes.iconSm,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: context.palette.onInk,
              ),
            )
          : Text(label),
    );
  }
}

/// "Question? Action" row linking the two auth screens.
class AuthSwitchPrompt extends StatelessWidget {
  const AuthSwitchPrompt({
    super.key,
    required this.question,
    required this.action,
    required this.onPressed,
  });

  final String question;
  final String action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(question, style: context.textTheme.bodyMedium),
        TextButton(onPressed: onPressed, child: Text(action)),
      ],
    );
  }
}

/// Small print explaining where accounts live.
class AuthFootnote extends StatelessWidget {
  const AuthFootnote({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'Your account and wardrobe are stored on this device only.',
      textAlign: TextAlign.center,
      style: context.textTheme.bodySmall,
    );
  }
}
