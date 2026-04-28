import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/customer_entity.dart';
import '../../common/widgets/common_widgets.dart';
import '../providers/customer_form_provider.dart';

/// Add/Edit customer screen — shared for both operations.
/// Pass [existingCustomer] via GoRouter `extra` to enter edit mode.
class AddEditCustomerPage extends ConsumerStatefulWidget {
  /// Non-null when editing an existing customer.
  final CustomerEntity? existingCustomer;

  const AddEditCustomerPage({super.key, this.existingCustomer});

  bool get isEditing => existingCustomer != null;

  @override
  ConsumerState<AddEditCustomerPage> createState() =>
      _AddEditCustomerPageState();
}

class _AddEditCustomerPageState extends ConsumerState<AddEditCustomerPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _notesCtrl;

  final _nameFocus    = FocusNode();
  final _phoneFocus   = FocusNode();
  final _addressFocus = FocusNode();
  final _notesFocus   = FocusNode();

  @override
  void initState() {
    super.initState();
    // Pre-fill for edit mode
    final c = widget.existingCustomer;
    _nameCtrl    = TextEditingController(text: c?.name ?? '');
    _phoneCtrl   = TextEditingController(text: c?.phone ?? '');
    _addressCtrl = TextEditingController(text: c?.address ?? '');
    _notesCtrl   = TextEditingController(text: c?.notes ?? '');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _addressFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final notifier = ref.read(customerFormProvider.notifier);
    bool success;

    if (widget.isEditing) {
      success = await notifier.updateCustomer(
        existing: widget.existingCustomer!,
        name:     _nameCtrl.text,
        phone:    _phoneCtrl.text,
        address:  _addressCtrl.text,
        notes:    _notesCtrl.text,
      );
    } else {
      success = await notifier.addCustomer(
        name:    _nameCtrl.text,
        phone:   _phoneCtrl.text,
        address: _addressCtrl.text,
        notes:   _notesCtrl.text,
      );
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? '${_nameCtrl.text.trim()} updated!'
                : '${_nameCtrl.text.trim()} added!',
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(customerFormProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final isEditing = widget.isEditing;

    return KeyboardDismissWrapper(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.close_rounded),
          ),
          title: Text(
            isEditing ? 'Edit Customer' : 'Add Customer',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          actions: [
            // Save button in app bar for quick access
            TextButton(
              onPressed: state.isLoading ? null : _onSave,
              child: Text(
                'Save',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: state.isLoading
                      ? colorScheme.onSurface.withOpacity(0.3)
                      : colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: LoadingOverlay(
          isLoading: state.isLoading,
          message: isEditing ? 'Updating customer…' : 'Adding customer…',
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Avatar preview ───────────────────────────────────────
                  Center(
                    child: _AvatarPreview(nameController: _nameCtrl),
                  ).animate().scale(curve: Curves.elasticOut),

                  const SizedBox(height: 28),

                  // ── Section: Basic Info ──────────────────────────────────
                  _SectionLabel(label: 'Basic Information'),
                  const SizedBox(height: 12),

                  // Name
                  AppTextField(
                    controller: _nameCtrl,
                    label: 'Full Name *',
                    hint: 'e.g. Ramesh Kumar',
                    prefixIcon: Icons.person_outline_rounded,
                    focusNode: _nameFocus,
                    maxLength: AppConstants.maxNameLength,
                    textInputAction: TextInputAction.next,
                    onEditingComplete: () => _phoneFocus.requestFocus(),
                    validator: Validators.name,
                    onChanged: (_) => setState(() {}), // refresh avatar preview
                  ).animate().fadeIn(delay: 150.ms),

                  const SizedBox(height: 14),

                  // Phone
                  _PhoneField(
                    controller: _phoneCtrl,
                    focusNode: _phoneFocus,
                    onEditingComplete: () => _addressFocus.requestFocus(),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 24),

                  // ── Section: Optional ────────────────────────────────────
                  _SectionLabel(label: 'Optional Details'),
                  const SizedBox(height: 12),

                  // Address
                  AppTextField(
                    controller: _addressCtrl,
                    label: 'Address',
                    hint: 'e.g. 12, Gandhi Nagar, Delhi',
                    prefixIcon: Icons.location_on_outlined,
                    focusNode: _addressFocus,
                    textInputAction: TextInputAction.next,
                    onEditingComplete: () => _notesFocus.requestFocus(),
                    validator: Validators.optionalName,
                  ).animate().fadeIn(delay: 250.ms),

                  const SizedBox(height: 14),

                  // Notes
                  TextFormField(
                    controller: _notesCtrl,
                    focusNode: _notesFocus,
                    maxLines: 3,
                    maxLength: 200,
                    textInputAction: TextInputAction.done,
                    onEditingComplete: _onSave,
                    style: GoogleFonts.poppins(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Notes',
                      hintText: 'e.g. Shop owner, meets every Tuesday…',
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 40),
                        child: Icon(Icons.note_outlined, size: 20),
                      ),
                      alignLabelWithHint: true,
                    ),
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: 8),

                  // ── Error ────────────────────────────────────────────────
                  if (state.errorMessage != null)
                    ErrorDisplay(message: state.errorMessage!)
                        .animate()
                        .fadeIn()
                        .shakeX(amount: 4),

                  const SizedBox(height: 28),

                  // ── Save Button ──────────────────────────────────────────
                  AppButton(
                    label: isEditing ? 'Update Customer' : 'Add Customer',
                    onPressed: state.isLoading ? null : _onSave,
                    isLoading: state.isLoading,
                    leadingIcon: isEditing
                        ? Icons.check_rounded
                        : Icons.person_add_alt_1_rounded,
                  ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.2),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Avatar Preview ─────────────────────────────────────────────────────────────

/// Shows initials from the name field in real-time as the user types.
class _AvatarPreview extends StatefulWidget {
  final TextEditingController nameController;

  const _AvatarPreview({required this.nameController});

  @override
  State<_AvatarPreview> createState() => _AvatarPreviewState();
}

class _AvatarPreviewState extends State<_AvatarPreview> {
  @override
  void initState() {
    super.initState();
    widget.nameController.addListener(() => setState(() {}));
  }

  String get _initials {
    final text = widget.nameController.text.trim();
    if (text.isEmpty) return '?';
    final parts = text.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return text.substring(0, text.length.clamp(0, 2)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Center(
        child: Text(
          _initials,
          style: GoogleFonts.poppins(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

// ── Phone Field ───────────────────────────────────────────────────────────────

class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onEditingComplete;

  const _PhoneField({
    required this.controller,
    required this.focusNode,
    required this.onEditingComplete,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      onEditingComplete: onEditingComplete,
      maxLength: AppConstants.phoneLength,
      style: GoogleFonts.poppins(fontSize: 15, letterSpacing: 1),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(AppConstants.phoneLength),
      ],
      validator: Validators.phone,
      decoration: InputDecoration(
        counterText: '',
        labelText: 'Mobile Number *',
        hintText: '98765 43210',
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${AppConstants.defaultCountryFlag}  ',
                style: const TextStyle(fontSize: 16),
              ),
              Text(
                AppConstants.defaultCountryCode,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 80),
      ),
    );
  }
}

// ── Section Label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.45),
        letterSpacing: 1.2,
      ),
    );
  }
}
