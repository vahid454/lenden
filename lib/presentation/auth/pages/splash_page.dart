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
              width: 90, height: 90,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 32, offset: const Offset(0, 12),
                )],
              ),
              child: Center(
                child: Text('₹', style: GoogleFonts.poppins(
                    fontSize: 46, fontWeight: FontWeight.w700,
                    color: cs.primary)),
              ),
            )
                .animate()
                .scale(begin: const Offset(0.5, 0.5),
                    curve: Curves.elasticOut, duration: 800.ms)
                .fadeIn(duration: 400.ms),
            const SizedBox(height: 24),
            Text('LenDen', style: GoogleFonts.poppins(
                fontSize: 40, fontWeight: FontWeight.w700,
                color: Colors.white, letterSpacing: -1))
                .animate()
                .fadeIn(delay: 300.ms, duration: 500.ms)
                .slideY(begin: 0.3, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 8),
            Text('Apna hisaab, apni marzi',
                style: GoogleFonts.poppins(
                    fontSize: 14, color: Colors.white.withOpacity(0.7)))
                .animate().fadeIn(delay: 500.ms),
            const SizedBox(height: 60),
            SizedBox(
              width: 28, height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withOpacity(0.55)),
              ),
            ).animate().fadeIn(delay: 700.ms),
          ],
        ),
      ),
    );
  }
}
