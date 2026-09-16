import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ngo_app/core/theme/app_theme.dart';
import 'package:ngo_app/features/admin/presentation/admin_shell_screen.dart';
import 'package:ngo_app/features/auth/application/auth_controller.dart';
import 'package:ngo_app/features/auth/application/auth_state.dart';
import 'package:ngo_app/features/auth/presentation/login_screen.dart';
import 'package:ngo_app/features/auth/presentation/reset_password_confirm_screen.dart';
import 'package:ngo_app/features/auth/presentation/reset_password_request_screen.dart';
import 'package:ngo_app/features/auth/presentation/signup_screen.dart';
import 'package:ngo_app/features/auth/presentation/verify_email_screen.dart';
import 'package:ngo_app/features/health/health_screen.dart';
import 'package:ngo_app/features/onboarding/presentation/onboarding_shell_screen.dart';

final _routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authControllerProvider.notifier);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);

      if (auth.status == AuthStatus.unknown) {
        return state.matchedLocation == '/splash' ? null : '/splash';
      }
      if (state.matchedLocation == '/splash') {
        if (auth.status == AuthStatus.unauthenticated) return '/login';
        return auth.isAdmin ? '/admin' : '/onboarding';
      }

      final goingToAuthRoute = _publicRoutes.any((route) => state.matchedLocation.startsWith(route));

      if (auth.status == AuthStatus.unauthenticated) {
        return goingToAuthRoute ? null : '/login';
      }

      // Authenticated: keep users off the login/signup screens, route each
      // role to its own landing shell.
      if (goingToAuthRoute && state.matchedLocation != '/status') {
        return auth.isAdmin ? '/admin' : '/onboarding';
      }
      if (state.matchedLocation == '/admin' && !auth.isAdmin) return '/onboarding';
      if (state.matchedLocation == '/onboarding' && auth.isAdmin) return '/admin';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) => VerifyEmailScreen(token: state.uri.queryParameters['token']),
      ),
      GoRoute(
        path: '/reset-password/request',
        builder: (context, state) => const ResetPasswordRequestScreen(),
      ),
      GoRoute(
        path: '/reset-password/confirm',
        builder: (context, state) =>
            ResetPasswordConfirmScreen(token: state.uri.queryParameters['token']),
      ),
      GoRoute(path: '/status', builder: (context, state) => const HealthScreen()),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingShellScreen()),
      GoRoute(path: '/admin', builder: (context, state) => const AdminShellScreen()),
    ],
  );
});

const _publicRoutes = ['/login', '/signup', '/verify-email', '/reset-password', '/status'];

/// Bridges Riverpod's [authControllerProvider] state changes into a
/// [Listenable] so go_router re-evaluates `redirect` whenever auth status
/// changes (login, logout, session expiry).
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }
}

class NgoApp extends ConsumerWidget {
  const NgoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(_routerProvider);

    return MaterialApp.router(
      title: 'NGO Fellow & Volunteer App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }
}
