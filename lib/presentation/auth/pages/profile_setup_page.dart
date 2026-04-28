import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/auth_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/validators.dart';
import '../../common/widgets/common_widgets.dart';
import '../providers/profile_setup_provider.dart';
import 'package:go_router/go_router.dart';

class ProfileSetupPage extends ConsumerStatefulWidget {
  final String userId;
  final String phone;

  const ProfileSetupPage({
    super.key,
    required this.userId,
    required this.phone,
  });

  @override
  ConsumerState<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends ConsumerState<ProfileSetupPage> {
  final _formKey      = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _businessCtrl = TextEditingController();
  final _nameFocus    = FocusNode();
  final _bizFocus     = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _businessCtrl.dispose();
    _nameFocus.dispose();
    _bizFocus.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final notifier = ref.read(profileSetupProvider.notifier);
    final success  = await notifier.saveProfile(
      userId:       widget.userId,
      name:         _nameCtrl.text.trim(),
      phone:        widget.phone,
      businessName: _businessCtrl.text.trim().isEmpty
                    ? null
                    : _businessCtrl.text.trim(),
    );

    if (!success || !mounted) return;

    // Wait for authStateChanges to emit the new profile (up to 3s)
    // This ensures the router sees hasProfile=true before we navigate
    for (int i = 0; i < 6; i++) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      final user = ref.read(currentUserProvider);
      if (user != null && user.name.isNotEmpty) break;
    }

    if (mounted) context.go(AppRoutes.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    final state       = ref.watch(profileSetupProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return KeyboardDismissWrapper(
      child: Scaffold(
        body: GradientBackground(
          child: SafeArea(
            child: LoadingOverlay(
              isLoading: state.isLoading,
              message:   'Setting up your profile…',
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 48),

                      Center(
                        child: Container(
                          width: 96, height: 96,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colorScheme.primary,
                                colorScheme.primary.withOpacity(0.6),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_rounded,
                              size: 48, color: Colors.white),
                        ),
                      ).animate().scale(curve: Curves.elasticOut),

                      const SizedBox(height: 28),

                      Center(
                        child: Text("Let's get you started! 🎉",
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                            textAlign: TextAlign.center),
                      ).animate().fadeIn(delay: 200.ms),

                      const SizedBox(height: 8),

                      Center(
                        child: Text('Tell us a bit about yourself',
                            style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: colorScheme.onSurface.withOpacity(0.55))),
                      ).animate().fadeIn(delay: 300.ms),

                      const SizedBox(height: 40),

                      Text('Your Name *',
                          style: GoogleFonts.poppins(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface.withOpacity(0.7)))
                          .animate().fadeIn(delay: 350.ms),
                      const SizedBox(height: 8),
                      AppTextField(
                        controller: _nameCtrl,
                        label: 'Full Name',
                        hint: 'e.g. Rahul Sharma',
                        prefixIcon: Icons.person_outline_rounded,
                        focusNode: _nameFocus,
                        maxLength: AppConstants.maxNameLength,
                        textInputAction: TextInputAction.next,
                        onEditingComplete: () => _bizFocus.requestFocus(),
                        validator: Validators.name,
                        onChanged: (_) => setState(() {}),
                      ).animate().fadeIn(delay: 400.ms),

                      const SizedBox(height: 20),

                      Text('Business Name (Optional)',
                          style: GoogleFonts.poppins(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface.withOpacity(0.7)))
                          .animate().fadeIn(delay: 450.ms),
                      const SizedBox(height: 8),
                      AppTextField(
                        controller: _businessCtrl,
                        label: 'Business / Shop Name',
                        hint: 'e.g. Sharma General Store',
                        prefixIcon: Icons.storefront_outlined,
                        focusNode: _bizFocus,
                        maxLength: AppConstants.maxNameLength,
                        textInputAction: TextInputAction.done,
                        onEditingComplete: _onSave,
                      ).animate().fadeIn(delay: 500.ms),

                      const SizedBox(height: 12),
                      Text(
                        'You can update this anytime from your profile.',
                        style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: colorScheme.onSurface.withOpacity(0.45)),
                      ).animate().fadeIn(delay: 550.ms),

                      const SizedBox(height: 32),

                      if (state.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ErrorDisplay(message: state.errorMessage!)
                              .animate().fadeIn().shakeX(amount: 4),
                        ),

                      AppButton(
                        label: 'Start Using LenDen',
                        onPressed: state.isLoading ? null : _onSave,
                        isLoading: state.isLoading,
                        leadingIcon: Icons.rocket_launch_outlined,
                      ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
