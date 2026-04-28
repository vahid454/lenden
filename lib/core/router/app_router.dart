import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/customer_entity.dart';
import '../../presentation/auth/pages/otp_verification_page.dart';
import '../../presentation/auth/pages/phone_input_page.dart';
import '../../presentation/auth/pages/profile_setup_page.dart';
import '../../presentation/auth/pages/splash_page.dart';
import '../../presentation/customers/pages/add_edit_customer_page.dart';
import '../../presentation/customers/pages/customer_detail_page.dart';
import '../../presentation/customers/pages/customer_list_page.dart';
import '../../presentation/dashboard/pages/dashboard_page.dart';
import '../providers/auth_providers.dart';

class AppRoutes {
  AppRoutes._();
  static const splash       = '/';
  static const phoneInput   = '/auth/phone';
  static const otpVerify    = '/auth/otp';
  static const profileSetup = '/auth/profile-setup';
  static const dashboard    = '/home';
  static const customers    = '/customers';
  static const addCustomer  = '/customers/add';
  static const editCustomer = '/customers/edit';
  static String customerDetail(String id) => '/customers/$id';
}

final _routerKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthNotifier(ref);

  final router = GoRouter(
    navigatorKey:        _routerKey,
    initialLocation:     AppRoutes.splash,
    debugLogDiagnostics: false,
    refreshListenable:   notifier,

    redirect: (context, state) {
      final isLoggedIn   = notifier.isLoggedIn;
      final isLoading    = notifier.isLoading;
      final hasProfile   = notifier.hasProfile;
      final loc          = state.matchedLocation;

      // Always allow splash to handle itself
      if (loc == AppRoutes.splash) return null;

      // While Firebase auth is still resolving — stay put
      if (isLoading) return null;

      final onAuth         = loc.startsWith('/auth');
      final onProfileSetup = loc == AppRoutes.profileSetup;

      // Not logged in → force to phone input
      if (!isLoggedIn && !onAuth) return AppRoutes.phoneInput;

      // Logged in but no profile yet → profile setup
      // BUT: allow profile-setup page itself (don't redirect in a loop)
      if (isLoggedIn && !hasProfile && !onProfileSetup) {
        return AppRoutes.profileSetup;
      }

      // Logged in WITH profile → don't allow going back to auth screens
      if (isLoggedIn && hasProfile && onAuth) return AppRoutes.dashboard;

      return null;
    },

    routes: [
      GoRoute(
        path:        AppRoutes.splash,
        pageBuilder: (_, s) => const NoTransitionPage(child: SplashPage()),
      ),
      GoRoute(
        path:        AppRoutes.phoneInput,
        pageBuilder: (_, s) => _slide(s, const PhoneInputPage()),
      ),
      GoRoute(
        path: AppRoutes.otpVerify,
        pageBuilder: (_, s) {
          final extra = s.extra as Map<String, dynamic>;
          return _slide(s, OtpVerificationPage(
            phoneNumber:    extra['phoneNumber']    as String,
            verificationId: extra['verificationId'] as String,
          ));
        },
      ),
      GoRoute(
        path: AppRoutes.profileSetup,
        pageBuilder: (_, s) {
          // Extra can be null if router redirect brought us here
          final extra  = s.extra as Map<String, dynamic>?;
          final userId = extra?['userId'] as String? ?? notifier.currentUid ?? '';
          final phone  = extra?['phone']  as String? ?? notifier.currentPhone ?? '';
          return _slide(s, ProfileSetupPage(userId: userId, phone: phone));
        },
      ),
      GoRoute(
        path:        AppRoutes.dashboard,
        pageBuilder: (_, s) => _fade(s, const DashboardPage()),
      ),
      GoRoute(
        path:        AppRoutes.customers,
        pageBuilder: (_, s) => _slide(s, const CustomerListPage()),
      ),
      GoRoute(
        path:        AppRoutes.addCustomer,
        pageBuilder: (_, s) => _slideUp(s, const AddEditCustomerPage()),
      ),
      GoRoute(
        path: AppRoutes.editCustomer,
        pageBuilder: (_, s) {
          final c = s.extra as CustomerEntity;
          return _slideUp(s, AddEditCustomerPage(existingCustomer: c));
        },
      ),
      GoRoute(
        path: '/customers/:id',
        pageBuilder: (_, s) {
          final id       = s.pathParameters['id']!;
          final customer = s.extra as CustomerEntity?;
          return _slide(s, CustomerDetailPage(
            customerId: id, initialCustomer: customer));
        },
      ),
    ],

    errorPageBuilder: (ctx, state) => MaterialPage(
      child: Scaffold(
        body: Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text('Page not found'),
            TextButton(
              onPressed: () => ctx.go(AppRoutes.dashboard),
              child: const Text('Go Home'),
            ),
          ],
        )),
      ),
    ),
  );

  ref.onDispose(notifier.dispose);
  return router;
});

// ── Auth notifier ─────────────────────────────────────────────────────────────
class _AuthNotifier extends ChangeNotifier {
  final Ref _ref;
  bool   _isLoggedIn = false;
  bool   _isLoading  = true;
  bool   _hasProfile = false;
  String? _currentUid;
  String? _currentPhone;

  _AuthNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, next) {
      _isLoading  = next.isLoading;
      final user  = next.valueOrNull;
      _isLoggedIn = user != null;
      // A "complete" profile has a non-empty name
      _hasProfile = user != null && user.name.isNotEmpty;
      _currentUid   = user?.id;
      _currentPhone = user?.phone;
      notifyListeners();
    });
  }

  bool    get isLoggedIn  => _isLoggedIn;
  bool    get isLoading   => _isLoading;
  bool    get hasProfile  => _hasProfile;
  String? get currentUid  => _currentUid;
  String? get currentPhone => _currentPhone;
}

// ── Transitions ───────────────────────────────────────────────────────────────
CustomTransitionPage<void> _slide(GoRouterState s, Widget child) =>
    CustomTransitionPage<void>(
      key: s.pageKey, child: child,
      transitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween(begin: const Offset(1, 0), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOutCubic)).animate(anim),
        child: child,
      ),
    );

CustomTransitionPage<void> _fade(GoRouterState s, Widget child) =>
    CustomTransitionPage<void>(
      key: s.pageKey, child: child,
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    );

CustomTransitionPage<void> _slideUp(GoRouterState s, Widget child) =>
    CustomTransitionPage<void>(
      key: s.pageKey, child: child,
      transitionDuration: const Duration(milliseconds: 300),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero)
            .chain(CurveTween(curve: Curves.easeOutCubic)).animate(anim),
        child: child,
      ),
    );
