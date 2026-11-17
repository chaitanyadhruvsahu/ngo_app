import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ngo_app/core/theme/app_theme.dart';
import 'package:ngo_app/core/theme/workspace.dart';
import 'package:ngo_app/features/admin/presentation/fellow_directory_screen.dart';
import 'package:ngo_app/core/i18n/translator.dart';
import 'package:ngo_app/features/admin/presentation/admin_fellow_detail_screen.dart';
import 'package:ngo_app/features/admin/presentation/admin_fellow_list_screen.dart';
import 'package:ngo_app/features/auth/application/auth_controller.dart';
import 'package:ngo_app/features/auth/application/auth_state.dart';
import 'package:ngo_app/features/auth/presentation/login_screen.dart';
import 'package:ngo_app/features/auth/presentation/reset_password_confirm_screen.dart';
import 'package:ngo_app/features/auth/presentation/reset_password_request_screen.dart';
import 'package:ngo_app/features/auth/presentation/signup_screen.dart';
import 'package:ngo_app/features/auth/presentation/verify_email_screen.dart';
import 'package:ngo_app/features/documents/presentation/documents_screen.dart';
import 'package:ngo_app/features/health/health_screen.dart';
import 'package:ngo_app/features/jobs/admin/admin_jobs_screen.dart';
import 'package:ngo_app/features/jobs/presentation/fellow_jobs_screen.dart';
import 'package:ngo_app/features/jobs/presentation/fellow_job_detail_screen.dart';
import 'package:ngo_app/features/onboarding/presentation/onboarding_shell_screen.dart';
import 'package:ngo_app/features/notifications/presentation/updates_screen.dart';
import 'package:ngo_app/features/reporting/reports_screen.dart';
import 'package:ngo_app/features/profile/presentation/profile_screen.dart';
import 'package:ngo_app/features/volunteers/presentation/volunteer_form_screen.dart';
import 'package:ngo_app/features/volunteers/presentation/volunteers_screen.dart';

final _routerProvider = Provider<GoRouter>((ref) {
  ref.watch(authControllerProvider.notifier);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);

      if (auth.status == AuthStatus.unknown) {
        return state.matchedLocation == '/splash'
            ? null
            : Uri(
                path: '/splash',
                queryParameters: {'from': state.uri.toString()}).toString();
      }
      if (state.matchedLocation == '/splash') {
        final destination = state.uri.queryParameters['from'];
        if (destination != null &&
            destination.startsWith('/') &&
            !destination.startsWith('//') &&
            !destination.startsWith('/splash')) {
          return destination;
        }
        if (auth.status == AuthStatus.unauthenticated) return '/login';
        return auth.isAdmin ? '/admin' : '/onboarding';
      }

      final goingToAuthRoute =
          _publicRoutes.any((route) => state.matchedLocation.startsWith(route));

      if (auth.status == AuthStatus.unauthenticated) {
        return goingToAuthRoute ? null : '/login';
      }

      // Authenticated: keep users off the login/signup screens, route each
      // role to its own landing shell.
      if (goingToAuthRoute &&
          state.matchedLocation != '/status' &&
          state.matchedLocation != '/verify-email' &&
          state.matchedLocation != '/reset-password/confirm') {
        return auth.isAdmin ? '/admin' : '/onboarding';
      }
      final goingToAdminRoute = state.matchedLocation.startsWith('/admin');
      final goingToFellowOnlyRoute = _fellowOnlyRoutes.any(
        (route) => state.matchedLocation.startsWith(route),
      );
      if (goingToAdminRoute && !auth.isAdmin) return '/onboarding';
      if (goingToFellowOnlyRoute && auth.isAdmin) return '/admin';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
          path: '/signup', builder: (context, state) => const SignupScreen()),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) =>
            VerifyEmailScreen(token: state.uri.queryParameters['token']),
      ),
      GoRoute(
        path: '/reset-password/request',
        builder: (context, state) => const ResetPasswordRequestScreen(),
      ),
      GoRoute(
        path: '/reset-password/confirm',
        builder: (context, state) => ResetPasswordConfirmScreen(
            token: state.uri.queryParameters['token']),
      ),
      GoRoute(
          path: '/status', builder: (context, state) => const HealthScreen()),
      ShellRoute(
          builder: (context, state, child) =>
              WorkspaceShell(path: state.uri.path, child: child),
          routes: [
            GoRoute(
                path: '/onboarding',
                builder: (context, state) => const OnboardingShellScreen()),
            GoRoute(
                path: '/profile',
                builder: (context, state) => const ProfileScreen()),
            GoRoute(
                path: '/documents',
                builder: (context, state) => const DocumentsScreen()),
            GoRoute(
                path: '/notifications',
                builder: (context, state) => const UpdatesScreen()),
            GoRoute(
              path: '/jobs',
              builder: (context, state) => const FellowJobsScreen(),
              routes: [
                GoRoute(
                  path: ':jobId',
                  builder: (context, state) => FellowJobDetailScreen(
                      jobId: state.pathParameters['jobId']!),
                ),
              ],
            ),
            GoRoute(
              path: '/volunteers',
              builder: (context, state) => const VolunteersScreen(),
              routes: [
                GoRoute(
                  path: 'new',
                  builder: (context, state) => const VolunteerFormScreen(),
                ),
                GoRoute(
                  path: ':volunteerId',
                  builder: (context, state) => VolunteerFormScreen(
                      volunteerId: state.pathParameters['volunteerId']),
                ),
              ],
            ),
            GoRoute(
              path: '/admin',
              builder: (context, state) => const AdminFellowListScreen(),
              routes: [
                GoRoute(
                    path: 'fellows',
                    builder: (context, state) => const FellowDirectoryScreen()),
                GoRoute(
                  path: 'notifications',
                  builder: (context, state) => const UpdatesScreen(admin: true),
                ),
                GoRoute(
                  path: 'reports',
                  builder: (context, state) => const ReportsScreen(),
                ),
                GoRoute(
                  path: 'jobs',
                  builder: (context, state) => AdminJobsScreen(
                      key: ValueKey(state.uri.query),
                      initialStatus: state.uri.queryParameters['status']),
                  routes: [
                    GoRoute(
                        path: 'new',
                        builder: (context, state) =>
                            const AdminJobFormScreen()),
                    GoRoute(
                      path: ':jobId',
                      builder: (context, state) => AdminJobDetailScreen(
                          jobId: state.pathParameters['jobId']!),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'fellows/:fellowId',
                  builder: (context, state) => AdminFellowDetailScreen(
                      fellowId: state.pathParameters['fellowId']!),
                ),
              ],
            ),
          ]),
    ],
  );
});

const _publicRoutes = [
  '/login',
  '/signup',
  '/verify-email',
  '/reset-password',
  '/status'
];
const _fellowOnlyRoutes = [
  '/onboarding',
  '/profile',
  '/documents',
  '/volunteers',
  '/jobs'
];

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
      onGenerateTitle: (_) => t('common.app_name'),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
    );
  }
}
