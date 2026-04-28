import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/customer_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/cache_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_formatters.dart';
import '../../common/widgets/common_widgets.dart';

/// Full profile + settings tab.
class ProfileTab extends ConsumerWidget {
  ProfileTab({super.key});

  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user          = ref.watch(currentUserProvider);
    final cs            = Theme.of(context).colorScheme;
    final isDark        = Theme.of(context).brightness == Brightness.dark;
    final customerCount = ref.watch(customersStreamProvider).valueOrNull?.length ?? 0;
    final toReceive     = ref.watch(totalToReceiveProvider);
    final toPay         = ref.watch(totalToPayProvider);
    final net           = ref.watch(netBalanceProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [

          // ── Profile Card ────────────────────────────────────────────────
          _ProfileCard(
            name:         user?.name ?? '—',
            phone:        user?.phone ?? '—',
            businessName: user?.businessName,
            initials:     user?.initials ?? '?',
          ).animate().fadeIn(),

          const SizedBox(height: 16),

          // ── Stats Row ───────────────────────────────────────────────────
          _StatsRow(
            customerCount: customerCount,
            toReceive:     toReceive,
            toPay:         toPay,
          ).animate().fadeIn(delay: 80.ms),

          const SizedBox(height: 20),

          // ── Settings Section ────────────────────────────────────────────
          _SectionHeader(label: 'Preferences'),
          const SizedBox(height: 8),

          _SettingsTile(
            icon:     Icons.dark_mode_outlined,
            iconBg:   const Color(0xFF6366F1),
            label:    'Dark Mode',
            trailing: Consumer(builder: (ctx, ref, _) {
              final isDarkMode = ref.watch(themeModeProvider.notifier).isDark;
              return Switch(
                value:    isDarkMode,
                onChanged: (_) =>
                    ref.read(themeModeProvider.notifier).toggle(),
              );
            }),
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 8),

          // ── Security Section ────────────────────────────────────────────
          _SectionHeader(label: 'Security'),
          const SizedBox(height: 8),

          _SettingsTile(
            icon:     Icons.fingerprint_rounded,
            iconBg:   const Color(0xFF0891B2),
            label:    'Biometric Lock',
            subtitle: 'Use fingerprint to open app',
            trailing: Consumer(builder: (ctx, ref, _) {
              final cache = ref.read(cacheServiceProvider);
              return Switch(
                value:    cache.isBiometricEnabled,
                onChanged: (v) => _toggleBiometric(ctx, ref, v),
              );
            }),
          ).animate().fadeIn(delay: 120.ms),

          const SizedBox(height: 8),

          // ── Data Section ────────────────────────────────────────────────
          _SectionHeader(label: 'Data'),
          const SizedBox(height: 8),

          _SettingsTile(
            icon:    Icons.delete_sweep_outlined,
            iconBg:  AppColors.danger,
            label:   'Clear Cache',
            subtitle: 'Free up local storage',
            onTap:   () => _clearCache(context, ref),
          ).animate().fadeIn(delay: 140.ms),

          const SizedBox(height: 8),

          // ── About Section ───────────────────────────────────────────────
          _SectionHeader(label: 'About'),
          const SizedBox(height: 8),

          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (ctx, snap) {
              final version = snap.data?.version ?? '1.0.0';
              final build   = snap.data?.buildNumber ?? '4';
              return _SettingsTile(
                icon:     Icons.info_outline_rounded,
                iconBg:   const Color(0xFF6B7280),
                label:    'App Version',
                trailing: Text(
                  'v$version ($build)',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color:    cs.onSurface.withOpacity(0.45),
                  ),
                ),
              );
            },
          ).animate().fadeIn(delay: 160.ms),

          const SizedBox(height: 8),

          _SettingsTile(
            icon:    Icons.shield_outlined,
            iconBg:  const Color(0xFF059669),
            label:   'Privacy Policy',
            onTap:   () {},
          ).animate().fadeIn(delay: 180.ms),

          const SizedBox(height: 24),

          // ── Sign Out ────────────────────────────────────────────────────
          AppButton(
            label:        'Sign Out',
            variant:      AppButtonVariant.danger,
            leadingIcon:  Icons.logout_rounded,
            onPressed:    () => _signOut(context, ref),
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 32),

          // ── Footer ──────────────────────────────────────────────────────
          Text(
            'Made with ❤️ in India\nLenDen — Apna hisaab, apni marzi',
            style: GoogleFonts.poppins(
              fontSize:  11,
              color:     cs.onSurface.withOpacity(0.3),
              height:    1.6,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 250.ms),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _toggleBiometric(
      BuildContext context, WidgetRef ref, bool enable) async {
    if (enable) {
      final canCheck  = await _localAuth.canCheckBiometrics;
      final available = await _localAuth.getAvailableBiometrics();

      if (!canCheck || available.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Biometrics not available on this device.'),
            behavior: SnackBarBehavior.floating,
          ));
        }
        return;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to enable biometric lock',
        options: const AuthenticationOptions(biometricOnly: true),
      );

      if (!authenticated) return;
    }

    await ref.read(cacheServiceProvider).setBiometric(enable);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(enable ? 'Biometric lock enabled.' : 'Biometric lock disabled.'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _clearCache(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Clear Cache?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'This removes locally cached data. Your Firestore data remains safe.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                minimumSize: const Size(90, 40)),
            child: Text('Clear',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok == true) {
      await ref.read(cacheServiceProvider).clearUserCache();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:  Text('Cache cleared.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sign Out?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text(
          'You will be signed out of this device.',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                minimumSize: const Size(90, 40)),
            child: Text('Sign Out',
                style: GoogleFonts.poppins(color: Colors.white)),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      await ref.read(cacheServiceProvider).clearUserCache();
      final signOut = ref.read(signOutUseCaseProvider);
      await signOut();
      if (context.mounted) context.go(AppRoutes.phoneInput);
    }
  }
}

// ── Profile Card ──────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final String  name;
  final String  phone;
  final String? businessName;
  final String  initials;

  const _ProfileCard({
    required this.name,
    required this.phone,
    this.businessName,
    required this.initials,
  });

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width:   double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(children: [
        // Avatar
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.primary, cs.primary.withOpacity(0.65)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(
              color: cs.primary.withOpacity(0.3),
              blurRadius: 16, offset: const Offset(0, 6),
            )],
          ),
          child: Center(child: Text(initials, style: GoogleFonts.poppins(
              fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white))),
        ),

        const SizedBox(height: 14),

        Text(name, style: GoogleFonts.poppins(
            fontSize: 20, fontWeight: FontWeight.w700)),
        if (businessName != null && businessName!.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(businessName!, style: GoogleFonts.poppins(
              fontSize: 13, color: cs.onSurface.withOpacity(0.55))),
        ],
        const SizedBox(height: 4),
        Text(AppFormatters.phone(phone), style: GoogleFonts.poppins(
            fontSize: 13, color: cs.onSurface.withOpacity(0.4))),
      ]),
    );
  }
}

// ── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final int    customerCount;
  final double toReceive;
  final double toPay;

  const _StatsRow({
    required this.customerCount,
    required this.toReceive,
    required this.toPay,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _StatCard(
        label: 'Customers',
        value: '$customerCount',
        icon:  Icons.group_outlined,
        color: Theme.of(context).colorScheme.primary,
      )),
      const SizedBox(width: 10),
      Expanded(child: _StatCard(
        label: 'Receive',
        value: AppFormatters.compactCurrency(toReceive),
        icon:  Icons.arrow_downward_rounded,
        color: AppColors.success,
        prefix: '₹',
      )),
      const SizedBox(width: 10),
      Expanded(child: _StatCard(
        label: 'Pay',
        value: AppFormatters.compactCurrency(toPay),
        icon:  Icons.arrow_upward_rounded,
        color: AppColors.danger,
        prefix: '₹',
      )),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final String label; final String value;
  final IconData icon; final Color color;
  final String prefix;
  const _StatCard({
    required this.label, required this.value,
    required this.icon, required this.color, this.prefix = '',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color:        Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(
          '$prefix$value',
          style: GoogleFonts.poppins(
              fontSize: 15, fontWeight: FontWeight.w700, color: color),
        ),
        Text(label, style: GoogleFonts.poppins(
            fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
      ]),
    );
  }
}

// ── Settings Tile ─────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData  icon;
  final Color     iconBg;
  final String    label;
  final String?   subtitle;
  final Widget?   trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconBg,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color:        cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.poppins(
                  fontSize: 14, fontWeight: FontWeight.w600)),
              if (subtitle != null)
                Text(subtitle!, style: GoogleFonts.poppins(
                    fontSize: 11, color: cs.onSurface.withOpacity(0.5))),
            ],
          )),
          if (trailing != null) trailing!
          else if (onTap != null)
            Icon(Icons.chevron_right_rounded,
                color: cs.onSurface.withOpacity(0.3), size: 20),
        ]),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.poppins(
          fontSize: 11, fontWeight: FontWeight.w700,
          color:    Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
