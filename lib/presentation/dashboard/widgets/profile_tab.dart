import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/providers/customer_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/services/cache_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_formatters.dart';
import '../../common/widgets/common_widgets.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user          = ref.watch(currentUserProvider);
    final cs            = Theme.of(context).colorScheme;
    final customerCount = ref.watch(customersStreamProvider).valueOrNull?.length ?? 0;
    final toReceive     = ref.watch(totalToReceiveProvider);
    final toPay         = ref.watch(totalToPayProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [

        // ── Profile Card ──────────────────────────────────────────────────
        _ProfileCard(
          name:         user?.name ?? '—',
          phone:        user?.phone ?? '—',
          businessName: user?.businessName,
          initials:     user?.initials ?? '?',
        ).animate().fadeIn(),

        const SizedBox(height: 16),

        // ── Stats Row ─────────────────────────────────────────────────────
        _StatsRow(
          customerCount: customerCount,
          toReceive:     toReceive,
          toPay:         toPay,
        ).animate().fadeIn(delay: 80.ms),

        const SizedBox(height: 20),

        // ── Preferences ───────────────────────────────────────────────────
        _SectionHeader(label: 'Preferences'),
        const SizedBox(height: 8),

        _SettingsTile(
          icon:   Icons.dark_mode_outlined,
          iconBg: const Color(0xFF6366F1),
          label:  'Dark Mode',
          trailing: Consumer(builder: (ctx, ref, _) {
            final isDark = ref.watch(themeModeProvider.notifier).isDark;
            return Switch(
              value: isDark,
              onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
            );
          }),
        ).animate().fadeIn(delay: 100.ms),

        // ── Support ───────────────────────────────────────────────────────
        _SectionHeader(label: 'Support'),
        const SizedBox(height: 8),

        _SettingsTile(
          icon:     Icons.help_outline_rounded,
          iconBg:   const Color(0xFF7C3AED),
          label:    'Help & Support',
          subtitle: 'Contact us, report issues',
          onTap:    () => _showHelpSheet(context),
        ).animate().fadeIn(delay: 140.ms),

        const SizedBox(height: 8),

        _SettingsTile(
          icon:     Icons.quiz_outlined,
          iconBg:   const Color(0xFF0EA5E9),
          label:    'FAQ',
          subtitle: 'Frequently asked questions',
          onTap:    () => _showFaq(context),
        ).animate().fadeIn(delay: 150.ms),

        const SizedBox(height: 8),

        _SettingsTile(
          icon:     Icons.shield_outlined,
          iconBg:   const Color(0xFF059669),
          label:    'Privacy Policy',
          subtitle: 'How we protect your data',
          onTap:    () => _showPrivacyPolicy(context),
        ).animate().fadeIn(delay: 160.ms),

        const SizedBox(height: 24),

        // ── Sign Out ──────────────────────────────────────────────────────
        AppButton(
          label:       'Sign Out',
          variant:     AppButtonVariant.danger,
          leadingIcon: Icons.logout_rounded,
          onPressed:   () => _signOut(context, ref),
        ).animate().fadeIn(delay: 180.ms),

        const SizedBox(height: 28),

        Text(
          'Made with ❤️ in India\nLenDen — Apna hisaab, apni marzi',
          style: GoogleFonts.poppins(
              fontSize: 11,
              color: cs.onSurface.withOpacity(0.3),
              height: 1.6),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 220.ms),

        const SizedBox(height: 24),
      ]),
    );
  }

  // ── Help & Support bottom sheet ───────────────────────────────────────────
  Future<void> _showHelpSheet(BuildContext context) async {
    final subj = Uri.encodeComponent('LenDen App — Help Request');
    final body = Uri.encodeComponent(
      'Hi LenDen Team,\n\nI need help with:\n\n[Describe your issue here]\n\nThank you.',
    );
    final mailUri = Uri.parse(
        'mailto:${AppConstants.supportEmail}?subject=$subj&body=$body');

    await showModalBottomSheet<void>(
      context:          context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Handle
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border,
                  borderRadius: BorderRadius.circular(4)))),
          const SizedBox(height: 20),

          Text('Help & Support', style: GoogleFonts.poppins(
              fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text('We are here to help you.',
              style: GoogleFonts.poppins(fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55))),

          const SizedBox(height: 20),

          _HelpRow(icon: Icons.mail_outline_rounded,
              iconBg: const Color(0xFF7C3AED),
              title: 'Email Us',
              subtitle: AppConstants.supportEmail,
              onTap: () async {
                if (await canLaunchUrl(mailUri)) launchUrl(mailUri);
              }),

          const SizedBox(height: 12),

          _HelpRow(icon: Icons.info_outline_rounded,
              iconBg: const Color(0xFF0EA5E9),
              title: 'Data Deletion Request',
              subtitle: 'Email us to delete your account or customer data',
              onTap: () async {
                final subj2 = Uri.encodeComponent('LenDen — Data Deletion Request');
                final body2 = Uri.encodeComponent(
                  'Hi LenDen Team,\n\nI request deletion of:\n[ ] My entire account\n[ ] Specific customer: ___\n\nReason: ___\n\nThank you.',
                );
                final uri2 = Uri.parse(
                    'mailto:${AppConstants.supportEmail}?subject=$subj2&body=$body2');
                if (await canLaunchUrl(uri2)) launchUrl(uri2);
              }),

          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warningAmber.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warningAmber.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.lock_outline_rounded,
                  size: 18, color: AppColors.warning),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'Customer deletion is disabled in-app for data safety. '
                'Contact support to request any data changes.',
                style: GoogleFonts.poppins(fontSize: 12, height: 1.4),
              )),
            ]),
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Close', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }

  // ── FAQ ───────────────────────────────────────────────────────────────────
  void _showFaq(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => Column(children: [
          const SizedBox(height: 12),
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border,
                  borderRadius: BorderRadius.circular(4)))),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Text('FAQ', style: GoogleFonts.poppins(
                fontSize: 20, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
              children: const [
                _FaqItem(
                  q: 'What is LenDen?',
                  a: 'LenDen is a personal ledger app that helps you track money you lend and borrow — '
                     'designed for individuals and small businesses in India.',
                ),
                _FaqItem(
                  q: 'Is my data safe?',
                  a: 'Yes. Your data is stored securely in Google Firebase (Firestore) and is visible only '
                     'to you. We do not share your data with anyone.',
                ),
                _FaqItem(
                  q: 'Can I delete a customer?',
                  a: 'Customer deletion is disabled in-app to protect financial records. '
                     'Please contact support at ${AppConstants.supportEmail} if you need a customer removed.',
                ),
                _FaqItem(
                  q: 'Can I edit or delete a transaction?',
                  a: 'Transactions are permanent financial records and cannot be edited or deleted '
                     'to ensure data integrity. Please contact support if there is a genuine error.',
                ),
                _FaqItem(
                  q: 'How is my balance calculated?',
                  a: 'Balance = Total "You Gave" − Total "You Got" for each customer. '
                     'Positive balance means the customer owes you. Negative means you owe them.',
                ),
                _FaqItem(
                  q: 'How do I export my data?',
                  a: 'Open any customer and tap the PDF icon in the top right to generate and share a PDF ledger.',
                ),
                _FaqItem(
                  q: 'I lost my phone. Is my data gone?',
                  a: 'No. All data is stored in the cloud. Simply log in with your phone number on any device and your data will be restored.',
                ),
                _FaqItem(
                  q: 'How do I request account deletion?',
                  a: 'Email us at ${AppConstants.supportEmail} with subject "Account Deletion Request". '
                     'We will process it within 7 business days.',
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // ── Privacy Policy ────────────────────────────────────────────────────────
  void _showPrivacyPolicy(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => Column(children: [
          const SizedBox(height: 12),
          Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border,
                  borderRadius: BorderRadius.circular(4)))),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Text('Privacy Policy', style: GoogleFonts.poppins(
                fontSize: 20, fontWeight: FontWeight.w700)),
          ),
          Expanded(child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            children: [
              _PolicySection(
                title: 'Data We Collect',
                body: 'We collect your mobile number for authentication, and the names, phone numbers, '
                      'and transaction amounts that you enter into the app.',
              ),
              _PolicySection(
                title: 'How We Use Your Data',
                body: 'Your data is used solely to provide the LenDen ledger service. '
                      'We do not sell, share, or use your data for advertising.',
              ),
              _PolicySection(
                title: 'Data Storage',
                body: 'All data is stored securely on Google Firebase (Firestore) with industry-standard '
                      'encryption. Your data is linked to your phone number and is not accessible to other users.',
              ),
              _PolicySection(
                title: 'Data Retention',
                body: 'We retain your data as long as your account is active. You may request account '
                      'and data deletion at any time by contacting support.',
              ),
              _PolicySection(
                title: 'Third-Party Services',
                body: 'We use Firebase (by Google) for authentication and data storage. '
                      'Firebase\'s privacy policy is available at firebase.google.com.',
              ),
              _PolicySection(
                title: 'Contact',
                body: 'For privacy concerns, data deletion requests, or questions: ${AppConstants.supportEmail}',
              ),
              const SizedBox(height: 8),
              Text('Last updated: January 2025',
                  style: GoogleFonts.poppins(fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4))),
            ],
          )),
        ]),
      ),
    );
  }

  // ── Sign Out ──────────────────────────────────────────────────────────────
  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Sign Out?', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('You will be signed out of this device.',
            style: GoogleFonts.poppins(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger, minimumSize: const Size(90, 40)),
            child: Text('Sign Out', style: GoogleFonts.poppins(color: Colors.white))),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await ref.read(cacheServiceProvider).clearUserCache();
      await ref.read(signOutUseCaseProvider)();
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
    required this.name, required this.phone,
    this.businessName, required this.initials,
  });

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color:        cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(children: [
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
                blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Center(child: Text(initials, style: GoogleFonts.poppins(
              fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white))),
        ),
        const SizedBox(height: 14),
        Text(name, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w700)),
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
  final int customerCount; final double toReceive; final double toPay;
  const _StatsRow({required this.customerCount, required this.toReceive, required this.toPay});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _StatCard(label: 'Customers', value: '$customerCount',
          icon: Icons.group_outlined,
          color: Theme.of(context).colorScheme.primary)),
      const SizedBox(width: 10),
      Expanded(child: _StatCard(label: 'Receive',
          value: '₹${AppFormatters.currency(toReceive)}',
          icon: Icons.arrow_downward_rounded, color: AppColors.success)),
      const SizedBox(width: 10),
      Expanded(child: _StatCard(label: 'Pay',
          value: '₹${AppFormatters.currency(toPay)}',
          icon: Icons.arrow_upward_rounded, color: AppColors.danger)),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w700, color: color)),
        ),
        Text(label, style: GoogleFonts.poppins(fontSize: 10,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5))),
      ]),
    );
  }
}

// ── Settings Tile ─────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon; final Color iconBg; final String label;
  final String? subtitle; final Widget? trailing; final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon, required this.iconBg, required this.label,
    this.subtitle, this.trailing, this.onTap,
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
          Container(width: 36, height: 36,
              decoration: BoxDecoration(color: iconBg,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: Colors.white, size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w600)),
            if (subtitle != null)
              Text(subtitle!, style: GoogleFonts.poppins(
                  fontSize: 11, color: cs.onSurface.withOpacity(0.5))),
          ])),
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
      child: Text(label.toUpperCase(), style: GoogleFonts.poppins(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          letterSpacing: 1.2)),
    );
  }
}

// ── Help Row ──────────────────────────────────────────────────────────────────

class _HelpRow extends StatelessWidget {
  final IconData icon; final Color iconBg;
  final String title, subtitle; final VoidCallback onTap;
  const _HelpRow({required this.icon, required this.iconBg,
    required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
        ),
        child: Row(children: [
          Container(width: 40, height: 40,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.white, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
            Text(subtitle, style: GoogleFonts.poppins(
                fontSize: 11, color: cs.onSurface.withOpacity(0.5))),
          ])),
          Icon(Icons.chevron_right_rounded,
              size: 18, color: cs.onSurface.withOpacity(0.3)),
        ]),
      ),
    );
  }
}

// ── FAQ Item ──────────────────────────────────────────────────────────────────

class _FaqItem extends StatelessWidget {
  final String q, a;
  const _FaqItem({required this.q, required this.a});

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(q, style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w600)),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(a, style: GoogleFonts.poppins(
                  fontSize: 13, height: 1.6,
                  color: cs.onSurface.withOpacity(0.7))),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Privacy Policy Section ────────────────────────────────────────────────────

class _PolicySection extends StatelessWidget {
  final String title, body;
  const _PolicySection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.poppins(
            fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(body, style: GoogleFonts.poppins(
            fontSize: 13, height: 1.6,
            color: cs.onSurface.withOpacity(0.65))),
      ]),
    );
  }
}
