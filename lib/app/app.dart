import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:all_fits/app/app_dependencies.dart';
import 'package:all_fits/app/app_material_app.dart';
import 'package:all_fits/app/user_session.dart';
import 'package:all_fits/features/auth/controllers/auth_controller.dart';
import 'package:all_fits/features/auth/screens/login_screen.dart';

/// Root widget: shows the sign-in flow or the signed-in user's session.
class AllFitsApp extends StatefulWidget {
  const AllFitsApp({super.key, required this.dependencies});

  final AppDependencies dependencies;

  @override
  State<AllFitsApp> createState() => _AllFitsAppState();
}

class _AllFitsAppState extends State<AllFitsApp> {
  late final AuthController _auth;

  @override
  void initState() {
    super.initState();
    final deps = widget.dependencies;
    _auth = AuthController(
      repository: deps.authRepository,
      onRegistered: (user) => deps.adoptLegacyData(user.id),
    )..init();
  }

  @override
  void dispose() {
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _auth,
      child: Consumer<AuthController>(
        builder: (context, auth, _) {
          final user = auth.user;
          return switch (auth.status) {
            AuthStatus.unknown => const AppMaterialApp(home: AppSplashView()),
            AuthStatus.signedOut => const AppMaterialApp(home: LoginScreen()),
            AuthStatus.signedIn => UserSession(
              key: ValueKey(user!.id),
              dependencies: widget.dependencies,
              user: user,
            ),
          };
        },
      ),
    );
  }
}
