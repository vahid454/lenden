import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pinput/pinput.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/router/app_router.dart';
import '../../common/widgets/common_widgets.dart';
import '../providers/otp_verification_provider.dart';

class OtpVerificationPage extends ConsumerStatefulWidget {
  final String phoneNumber;
  final String verificationId;

  const OtpVerificationPage({
    super.key,
    required this.phoneNumber,
    required this.verificationId,
  });

  @override
  ConsumerState<OtpVerificationPage> createState() =>
      _OtpVerificationPageState();
}

class _OtpVerificationPageState
    extends ConsumerState<OtpVerificationPage> {
  final _otpCtrl   = TextEditingController();
  late Timer _timer;
  int _secondsLeft = AppConstants.resendCooldown.inSeconds;
  late String _verificationId;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _startTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _secondsLeft = AppConstants.resendCooldown.inSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_secondsLeft <= 0) { t.cancel(); return; }
      setState(() => _secondsLeft--);
    });
  }

  Future<void> _verify(String otp) async {
    if (otp.length != AppConstants.otpLength) return;
    FocusScope.of(context).unfocus();

    final notifier = ref.read(otpVerificationProvider(_verificationId).notifier);
    final user     = await notifier.verifyOtp(otp: otp);

    if (!mounted) return;

    final errState = ref.read(otpVerificationProvider(_verificationId));
    if (errState.errorMessage != null) return;

    if (user != null && user.name.isNotEmpty) {
      // Existing user with complete profile
      context.go(AppRoutes.dashboard);
    } else {
      // New user or incomplete profile — go to profile setup
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && mounted) {
        context.go(AppRoutes.profileSetup, extra: {
          'userId': uid,
          'phone':  widget.phoneNumber,
        });
      }
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0) return;
    _otpCtrl.clear();

    final notifier = ref.read(otpVerificationProvider(_verificationId).notifier);
    final newId    = await notifier.resendOtp(widget.phoneNumber);
    if (newId != null && mounted) {
      setState(() => _verificationId = newId);
      _startTimer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state  = ref.watch(otpVerificationProvider(_verificationId));
    final cs     = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultTheme = PinTheme(
      width: 52, height: 60,
      textStyle: GoogleFonts.poppins(
          fontSize: 22, fontWeight: FontWeight.w600, color: cs.onSurface),
      decoration: BoxDecoration(
        color:        isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
    );
    final focusedTheme = defaultTheme.copyWith(
      decoration: defaultTheme.decoration!.copyWith(
          border: Border.all(color: cs.primary, width: 2),
          color: cs.primary.withOpacity(0.06)),
    );
    final errorTheme = defaultTheme.copyWith(
      decoration: defaultTheme.decoration!.copyWith(
          border: Border.all(color: AppColors.danger, width: 1.5),
          color: AppColors.dangerLight),
    );

    return KeyboardDismissWrapper(
      child: Scaffold(
        body: GradientBackground(
          child: SafeArea(
            child: LoadingOverlay(
              isLoading: state.isLoading,
              message:   'Verifying OTP…',
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 32),

                    Center(child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                          color: cs.primary.withOpacity(0.1),
                          shape: BoxShape.circle),
                      child: Icon(Icons.sms_outlined, size: 36, color: cs.primary),
                    ).animate().scale(curve: Curves.elasticOut, duration: 600.ms)),

                    const SizedBox(height: 24),
                    Center(child: Text('Verify your number',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w700))
                        .animate().fadeIn(delay: 150.ms)),
                    const SizedBox(height: 8),
                    Center(child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: GoogleFonts.poppins(fontSize: 14,
                            color: cs.onSurface.withOpacity(0.6)),
                        children: [
                          const TextSpan(text: 'Enter the 6-digit OTP sent to\n'),
                          TextSpan(text: widget.phoneNumber,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ).animate().fadeIn(delay: 200.ms)),

                    const SizedBox(height: 36),

                    Center(child: Pinput(
                      controller:  _otpCtrl,
                      length:      AppConstants.otpLength,
                      autofocus:   true,
                      defaultPinTheme:   defaultTheme,
                      focusedPinTheme:   focusedTheme,
                      submittedPinTheme: focusedTheme,
                      errorPinTheme:     errorTheme,
                      keyboardType: TextInputType.number,
                      onCompleted:  _verify,
                      hapticFeedbackType: HapticFeedbackType.mediumImpact,
                      closeKeyboardWhenCompleted: true,
                    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2)),

                    const SizedBox(height: 20),
                    if (state.errorMessage != null)
                      ErrorDisplay(message: state.errorMessage!)
                          .animate().fadeIn().shakeX(amount: 4),

                    const SizedBox(height: 32),
                    AppButton(
                      label:       'Verify OTP',
                      onPressed:   state.isLoading ? null : () => _verify(_otpCtrl.text),
                      isLoading:   state.isLoading,
                      leadingIcon: Icons.verified_outlined,
                    ).animate().fadeIn(delay: 400.ms),

                    const SizedBox(height: 24),
                    Center(child: Column(children: [
                      Text("Didn't receive the OTP?",
                          style: GoogleFonts.poppins(fontSize: 13,
                              color: cs.onSurface.withOpacity(0.5))),
                      const SizedBox(height: 4),
                      _secondsLeft > 0
                          ? Text('Resend in ${_secondsLeft}s',
                              style: GoogleFonts.poppins(fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: cs.onSurface.withOpacity(0.35)))
                          : GestureDetector(
                              onTap: state.isLoading ? null : _resend,
                              child: Text('Resend OTP',
                                  style: GoogleFonts.poppins(fontSize: 14,
                                      fontWeight: FontWeight.w600, color: cs.primary,
                                      decoration: TextDecoration.underline)),
                            ),
                    ])).animate().fadeIn(delay: 500.ms),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
