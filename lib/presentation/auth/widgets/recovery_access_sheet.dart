import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_providers.dart';

Future<bool?> showRecoveryAccessSheet(
  BuildContext context, {
  required bool configure,
  String? initialEmail,
}) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RecoveryAccessSheet(
        configure: configure,
        initialEmail: initialEmail,
      ),
    );

class _RecoveryAccessSheet extends ConsumerStatefulWidget {
  final bool configure;
  final String? initialEmail;

  const _RecoveryAccessSheet({
    required this.configure,
    this.initialEmail,
  });

  @override
  ConsumerState<_RecoveryAccessSheet> createState() =>
      _RecoveryAccessSheetState();
}

class _RecoveryAccessSheetState extends ConsumerState<_RecoveryAccessSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(accountRecoveryServiceProvider);
      if (widget.configure) {
        await service.configure(
          email: _emailController.text,
          password: _passwordController.text,
        );
      } else {
        await service.signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString().replaceFirst(RegExp(r'^.*?:\s*'), '');
        });
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter your recovery email first.');
      return;
    }
    try {
      await ref.read(accountRecoveryServiceProvider).sendPasswordReset(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Password reset email sent.'),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.configure ? 'Protect your ledger' : 'Recovery sign in',
                style: GoogleFonts.poppins(
                    fontSize: 19, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                widget.configure
                    ? 'Use this verified email if your SIM or phone is lost.'
                    : 'Access the same account without an OTP.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: cs.onSurface.withValues(alpha: 0.58),
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Recovery email',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
                validator: (value) => value != null && value.contains('@')
                    ? null
                    : 'Enter a valid email',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  labelText: 'Recovery password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                  ),
                ),
                validator: (value) => (value?.length ?? 0) >= 8
                    ? null
                    : 'Use at least 8 characters',
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: AppColors.danger)),
              ],
              if (!widget.configure)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _loading ? null : _resetPassword,
                    child: const Text('Forgot password?'),
                  ),
                )
              else
                const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(widget.configure
                          ? Icons.verified_user_outlined
                          : Icons.login_rounded),
                  label: Text(widget.configure
                      ? 'Send verification email'
                      : 'Sign in securely'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
