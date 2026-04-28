import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/validators.dart';
import '../../common/widgets/common_widgets.dart';
import '../providers/phone_input_provider.dart';

/// Step 1 of auth flow: user enters their 10-digit Indian mobile number.
class PhoneInputPage extends ConsumerStatefulWidget {
  const PhoneInputPage({super.key});

  @override
  ConsumerState<PhoneInputPage> createState() => _PhoneInputPageState();
}

class _PhoneInputPageState extends ConsumerState<PhoneInputPage> {
  final _formKey    = GlobalKey<FormState>();
  final _phoneCtrl  = TextEditingController();
  final _focusNode  = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus for smooth UX
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _onSendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final phone = '${AppConstants.defaultCountryCode}${_phoneCtrl.text.trim()}';
    final notifier = ref.read(phoneInputProvider.notifier);

    final verificationId = await notifier.sendOtp(phone);

    if (!mounted) return;

    if (verificationId != null) {
      context.push(AppRoutes.otpVerify, extra: {
        'phoneNumber': phone,
        'verificationId': verificationId,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(phoneInputProvider);

    return KeyboardDismissWrapper(
      child: Scaffold(
        body: GradientBackground(
          child: SafeArea(
            child: LoadingOverlay(
              isLoading: state.isLoading,
              message: 'Sending OTP…',
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 48),

                      // ── Logo ───────────────────────────────────────────────
                      const Center(
                        child: LenDenLogo(size: 72, showTagline: true),
                      ).animate().fadeIn(duration: 600.ms).slideY(
                            begin: -0.2,
                            end: 0,
                            curve: Curves.easeOut,
                          ),

                      const SizedBox(height: 56),

                      // ── Heading ────────────────────────────────────────────
                      Text(
                        'Enter your\nmobile number',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                      ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),

                      const SizedBox(height: 8),

                      Text(
                        'We\'ll send you an OTP to verify.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                            ),
                      ).animate().fadeIn(delay: 300.ms),

                      const SizedBox(height: 40),

                      // ── Phone Input ────────────────────────────────────────
                      _PhoneInputField(
                        controller: _phoneCtrl,
                        focusNode: _focusNode,
                        onSubmitted: (_) => _onSendOtp(),
                      ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),

                      const SizedBox(height: 16),

                      // ── Error ──────────────────────────────────────────────
                      if (state.errorMessage != null)
                        ErrorDisplay(message: state.errorMessage!)
                            .animate()
                            .fadeIn()
                            .shakeX(amount: 4),

                      const SizedBox(height: 32),

                      // ── CTA Button ─────────────────────────────────────────
                      AppButton(
                        label: 'Send OTP',
                        onPressed: state.isLoading ? null : _onSendOtp,
                        isLoading: state.isLoading,
                        leadingIcon: Icons.send_rounded,
                      ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),

                      const SizedBox(height: 24),

                      // ── Terms ──────────────────────────────────────────────
                      Center(
                        child: Text(
                          'By continuing, you agree to our Terms & Privacy Policy',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.45),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ).animate().fadeIn(delay: 600.ms),

                      const SizedBox(height: 24),
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

// ── Phone Input Field ─────────────────────────────────────────────────────────

class _PhoneInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final void Function(String)? onSubmitted;

  const _PhoneInputField({
    required this.controller,
    required this.focusNode,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: onSubmitted,
      maxLength: AppConstants.phoneLength,
      style: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        letterSpacing: 2,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(AppConstants.phoneLength),
      ],
      validator: Validators.phone,
      decoration: InputDecoration(
        counterText: '',
        labelText: 'Mobile Number',
        hintText: '98765 43210',
        prefixIcon: Container(
          width: 72,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${AppConstants.defaultCountryFlag} ',
                style: const TextStyle(fontSize: 18),
              ),
              Text(
                AppConstants.defaultCountryCode,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 1,
                height: 20,
                color: AppColors.border,
              ),
            ],
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 80),
      ),
    );
  }
}
