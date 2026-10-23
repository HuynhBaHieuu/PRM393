import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/core/constants/app_dimensions.dart';
import 'package:all_fits/core/errors/app_exceptions.dart';
import 'package:all_fits/core/extensions/context_extensions.dart';
import 'package:all_fits/core/utils/validators.dart';
import 'package:all_fits/data/repositories/auth_repository.dart';
import 'package:all_fits/features/auth/controllers/auth_controller.dart';
import 'package:all_fits/features/auth/screens/register_screen.dart';
import 'package:all_fits/features/auth/widgets/auth_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;
  final TextEditingController _password = TextEditingController();

  bool _busy = false;

  /// The provider whose browser login is being opened.
  SocialProvider? _socialBusy;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(
      text: context.read<AuthController>().lastEmail,
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _busy = true);
    try {
      await context.read<AuthController>().signIn(
        email: _email.text,
        password: _password.text,
      );
      // On success the app switches to the wardrobe; nothing else to do.
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = describeError(error);
        });
      }
    }
  }

  Future<void> _signInWith(SocialProvider provider) async {
    if (_busy || _socialBusy != null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _socialBusy = provider;
    });
    try {
      // Only opens the browser; the app signs in when it comes back.
      await context.read<AuthController>().signInWith(provider);
    } catch (error) {
      if (mounted) setState(() => _error = describeError(error));
    } finally {
      if (mounted) setState(() => _socialBusy = null);
    }
  }

  Future<void> _openRegister() async {
    final email = await Navigator.of(
      context,
    ).push(MaterialPageRoute<String>(builder: (_) => const RegisterScreen()));
    if (email == null || !mounted) return;
    setState(() => _error = null);
    _email.text = email;
    _password.clear();
    context.showSnack('Account created. Log in to continue.');
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final error = _error ?? auth.externalError;
    return AuthScaffold(
      eyebrow: 'Welcome back',
      title: 'Log in',
      subtitle: 'Your wardrobe is waiting.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                validator: Validators.requiredPassword,
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
        AuthSubmitButton(label: 'Log in', busy: _busy, onPressed: _submit),
        if (auth.supportsSocialLogin) ...[
          const SizedBox(height: AppSpacing.md),
          const AuthOrDivider(),
          for (final provider in SocialProvider.values) ...[
            const SizedBox(height: AppSpacing.md),
            SocialLoginButton(
              provider: provider,
              busy: _socialBusy == provider,
              onPressed: _busy || _socialBusy != null
                  ? null
                  : () => _signInWith(provider),
            ),
          ],
        ],
        const SizedBox(height: AppSpacing.md),
        AuthSwitchPrompt(
          question: 'New to All Fits?',
          action: 'Create an account',
          onPressed: _busy ? null : _openRegister,
        ),
        const SizedBox(height: AppSpacing.xl),
        const AuthFootnote(),
      ],
    );
  }
}
