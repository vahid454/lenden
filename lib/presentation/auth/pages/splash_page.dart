import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/auth_providers.dart';
import '../../../core/router/app_router.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Minimum 1.8s splash, then navigate when auth resolves
    Future.delayed(const Duration(milliseconds: 1800), _navigate);
  }

  void _navigate() {
    if (_navigated || !mounted) return;

    final authState = ref.read(authStateProvider);
    // If still loading, wait a bit more and retry
    if (authState.isLoading) {
      Future.delayed(const Duration(milliseconds: 500), _navigate);
      return;
    }

    _navigated = true;
    final user = authState.valueOrNull;

    if (user == null) {
      context.go(AppRoutes.phoneInput);
    } else if (user.name.isEmpty) {
      // Firebase signed in but no profile — go to profile setup
      context.go(AppRoutes.profileSetup, extra: {
        'userId': user.id,
        'phone':  user.phone,
      });
    } else {
      context.go(AppRoutes.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Also listen so if auth resolves AFTER the 1.8s delay we still navigate
    ref.listen(authStateProvider, (_, next) {
      if (!next.isLoading) _navigate();
    });

    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 40, 
                    offset: const Offset(0, 16),
                  ),
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(-2, -2),
                  ),
                ],
              ),
              child: Center(
                child: Text('₹', style: GoogleFonts.poppins(
                    fontSize: 54, fontWeight: FontWeight.w800,
                    color: cs.primary,
                    height: 1)),
              ),
            )
                .animate()
                .scale(begin: const Offset(0.4, 0.4),
                    curve: Curves.elasticOut, duration: 900.ms)
                .fadeIn(duration: 400.ms),
            const SizedBox(height: 32),
            Text('LenDen', style: GoogleFonts.poppins(
                fontSize: 42, fontWeight: FontWeight.w800,
                color: Colors.white, letterSpacing: -1.2))
                .animate()
                .fadeIn(delay: 300.ms, duration: 500.ms)
                .slideY(begin: 0.3, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 12),
            Text('Your accounts, in your hands',
                style: GoogleFonts.poppins(
                    fontSize: 16, 
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.8),
                    letterSpacing: 0.3))
                .animate().fadeIn(delay: 500.ms),
            const SizedBox(height: 60),
            SizedBox(
              width: 28, height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withValues(alpha: 0.55)),
              ),
            ).animate().fadeIn(delay: 700.ms),
          ],
        ),
      ),
    );
  }
}
