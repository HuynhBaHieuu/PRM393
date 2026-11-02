import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/validators.dart';
import 'package:all_fits/features/auth/controllers/auth_controller.dart';
import 'package:all_fits/features/auth/widgets/auth_widgets.dart';
import 'package:all_fits/core/l10n/l10n.dart';

/// Resets a forgotten password in two steps: the email, then (with the
/// emailed code on Supabase) a new password. Pops with the email so the
/// login screen can prefill it.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailForm = GlobalKey<FormState>();
  final _resetForm = GlobalKey<FormState>();
  late final TextEditingController _email;
  final TextEditingController _code = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  /// Set once the email step succeeds.
  bool _emailConfirmed = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _run(
    GlobalKey<FormState> form,
    Future<void> Function(AuthController auth) action,
  ) async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(form.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    try {
      await action(context.read<AuthController>());
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendEmail() => _run(_emailForm, (auth) async {
    await auth.requestPasswordReset(_email.text);
    if (!mounted) return;
    setState(() => _emailConfirmed = true);
    if (auth.passwordResetNeedsCode) {
      context.showSnack(tr('Code sent. Check your inbox.'));
    }
  });

  Future<void> _resendCode() async {
    if (_busy) return;
    setState(() => _error = null);
    try {
      await context.read<AuthController>().requestPasswordReset(_email.text);
      if (mounted) context.showSnack(tr('New code sent.'));
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error));
    }
  }

  Future<void> _reset() => _run(_resetForm, (auth) async {
    await auth.resetPassword(
      email: _email.text,
      newPassword: _password.text,
      code: auth.passwordResetNeedsCode ? _code.text : null,
    );
    if (mounted) {
      Navigator.of(context).pop(Validators.normalizeEmail(_email.text));
    }
  });

  void _changeEmail() => setState(() {
    _emailConfirmed = false;
    _error = null;
    _code.clear();
  });

  @override
  Widget build(BuildContext context) {
    final needsCode = context.read<AuthController>().passwordResetNeedsCode;
    final email = Validators.normalizeEmail(_email.text);
    final error = _error;
    return AuthScaffold(
      showBack: true,
      eyebrow: tr('Forgot password'),
      title: _emailConfirmed ? tr('New password') : tr('Reset password'),
      subtitle: switch ((_emailConfirmed, needsCode)) {
        (false, true) => tr('Enter your email and we’ll send you a code.'),
        (false, false) => tr('Enter the email you signed up with.'),
        (true, true) => tr('Enter the code sent to {0} and a new password.', [
          email,
        ]),
        (true, false) => tr('Choose a new password for {0}.', [email]),
      },
      children: [
        if (!_emailConfirmed)
          Form(
            key: _emailForm,
            child: TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(labelText: tr('Email')),
              validator: Validators.email,
              onFieldSubmitted: (_) => _sendEmail(),
            ),
          )
        else
          Form(
            key: _resetForm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (needsCode) ...[
                  TextFormField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: InputDecoration(labelText: tr('Code')),
                    validator: (v) => (v ?? '').trim().length < 6
                        ? tr('Enter the code we emailed you')
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                PasswordField(
                  controller: _password,
                  label: tr('New password'),
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  validator: Validators.newPassword,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  tr('At least {0} characters, with a letter and a number.', [
                    Validators.minPasswordLength,
                  ]),
                  style: context.textTheme.bodySmall,
                ),
                const SizedBox(height: AppSpacing.md),
                PasswordField(
                  controller: _confirm,
                  label: tr('Confirm new password'),
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (v) =>
                      Validators.confirmPassword(v, _password.text),
                  onSubmitted: (_) => _reset(),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        if (error != null) ...[
          AuthErrorBanner(message: error),
          const SizedBox(height: AppSpacing.md),
        ],
        if (!_emailConfirmed)
          AuthSubmitButton(
            label: needsCode ? tr('Send code') : tr('Continue'),
            busy: _busy,
            onPressed: _sendEmail,
          )
        else ...[
          AuthSubmitButton(
            label: tr('Save new password'),
            busy: _busy,
            onPressed: _reset,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton(
                onPressed: _busy ? null : _changeEmail,
                child: Text(tr('Use another email')),
              ),
              if (needsCode)
                TextButton(
                  onPressed: _busy ? null : _resendCode,
                  child: Text(tr('Resend code')),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
