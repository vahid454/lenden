import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/router/app_router.dart';
import 'core/services/cache_service.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/shared_preferences_provider.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase — guard against duplicate-app crash on hot restart ──────────
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase already initialised (hot restart on emulator) — safe to ignore
    debugPrint('Firebase already initialized: $e');
  }

  // ── Hive offline cache ────────────────────────────────────────────────────
  await initHive();

  // ── SharedPreferences ─────────────────────────────────────────────────────
  final prefs = await SharedPreferences.getInstance();

  // ── Portrait only ─────────────────────────────────────────────────────────
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // ── Status bar transparent ────────────────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor:          Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const LenDenApp(),
    ),
  );
}

class LenDenApp extends ConsumerWidget {
  const LenDenApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router    = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title:                      'LenDen',
      debugShowCheckedModeBanner: false,
      theme:                      AppTheme.lightTheme,
      darkTheme:                  AppTheme.darkTheme,
      themeMode:                  themeMode,
      routerConfig:               router,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(
              MediaQuery.of(context).textScaleFactor.clamp(0.85, 1.2),
            ),
          ),
          child: child!,
        );
      },
    );
  }
}
