import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/utils/validators.dart';
import 'package:all_fits/features/auth/controllers/auth_controller.dart';
import 'package:all_fits/features/auth/widgets/auth_widgets.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    try {
      await context.read<AuthController>().register(
        displayName: _name.text,
        email: _email.text,
        password: _password.text,
      );
      // On success the app switches to the new user's wardrobe.
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = describeError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return AuthScaffold(
      showBack: true,
      eyebrow: 'Get started',
      title: 'Create account',
      subtitle: 'Build your digital closet and plan every look.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                textInputAction: TextInputAction.next,
                maxLength: Validators.maxNameLength,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  counterText: '',
                ),
                validator: (v) =>
                    Validators.requiredName(v, subject: 'your name'),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: Validators.email,
              ),
              const SizedBox(height: AppSpacing.md),
              PasswordField(
                controller: _password,
                label: 'Password',
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                validator: Validators.newPassword,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'At least ${Validators.minPasswordLength} characters, '
                'with a letter and a number.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              PasswordField(
                controller: _confirm,
                label: 'Confirm password',
                autofillHints: const [AutofillHints.newPassword],
                validator: (v) => Validators.confirmPassword(v, _password.text),
                onSubmitted: (_) => _submit(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (error != null) ...[
          AuthErrorBanner(message: error),
          const SizedBox(height: AppSpacing.md),
        ],
        AuthSubmitButton(
          label: 'Create account',
          busy: _busy,
          onPressed: _submit,
        ),
        const SizedBox(height: AppSpacing.md),
        AuthSwitchPrompt(
          question: 'Already have an account?',
          action: 'Log in',
          onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(height: AppSpacing.xl),
        const AuthFootnote(),
      ],
    );
  }
}
