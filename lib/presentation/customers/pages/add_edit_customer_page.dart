import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/customer_photo_providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/validators.dart';
import '../../../domain/entities/customer_entity.dart';
import '../../common/widgets/common_widgets.dart';
import '../providers/customer_form_provider.dart';
import '../widgets/customer_avatar_image.dart';

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
  late final TextEditingController _secondaryPhoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _notesCtrl;

  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _secondaryPhoneFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _notesFocus = FocusNode();
  Uint8List? _photoBytes;

  @override
  void initState() {
    super.initState();
    // Pre-fill for edit mode
    final c = widget.existingCustomer;
    _nameCtrl = TextEditingController(text: c?.name ?? '');
    _phoneCtrl = TextEditingController(text: c?.phone ?? '');
    _secondaryPhoneCtrl = TextEditingController(text: c?.secondaryPhone ?? '');
    _addressCtrl = TextEditingController(text: c?.address ?? '');
    _notesCtrl = TextEditingController(text: c?.notes ?? '');

  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _secondaryPhoneCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _secondaryPhoneFocus.dispose();
    _addressFocus.dispose();
    _notesFocus.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final notifier = ref.read(customerFormProvider.notifier);
    bool success;
    CustomerEntity? createdCustomer;

    if (widget.isEditing) {
      success = await notifier.updateCustomer(
        existing: widget.existingCustomer!,
        name: _nameCtrl.text,
        phone: _phoneCtrl.text,
        secondaryPhone: _secondaryPhoneCtrl.text,
        address: _addressCtrl.text,
        notes: _notesCtrl.text,
        photoBytes: _photoBytes,
      );
    } else {
      createdCustomer = await notifier.addCustomer(
        name: _nameCtrl.text,
        phone: _phoneCtrl.text,
        secondaryPhone: _secondaryPhoneCtrl.text,
        address: _addressCtrl.text,
        notes: _notesCtrl.text,
        photoBytes: _photoBytes,
      );
      success = createdCustomer != null;
    }

    if (success && mounted) {
      final notice = ref.read(customerFormProvider).noticeMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            notice ??
                (widget.isEditing
                    ? '${_nameCtrl.text.trim()} updated!'
                    : '${_nameCtrl.text.trim()} added!'),
          ),
          backgroundColor: notice == null
              ? const Color(0xFF16A34A)
              : const Color(0xFFD97706),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      if (widget.isEditing) {
        context.pop();
      } else {
        context.pushReplacement(
          AppRoutes.customerDetail(createdCustomer!.id),
          extra: createdCustomer,
        );
      }
    }
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Customer photo',
                  style: GoogleFonts.poppins(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final bytes =
          await ref.read(customerPhotoServiceProvider).pickAndCompress(source);
      if (bytes != null && mounted) setState(() => _photoBytes = bytes);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error.toString()),
        behavior: SnackBarBehavior.floating,
      ));
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
                      ? colorScheme.onSurface.withValues(alpha: 0.3)
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
                  _CustomerPhotoPicker(
                    nameController: _nameCtrl,
                    selectedBytes: _photoBytes,
                    photoPath: widget.existingCustomer?.photoPath,
                    onTap: _pickPhoto,
                  ).animate().fadeIn(),

                  const SizedBox(height: 28),

                  // ── Section: Basic Info ──────────────────────────────────
                  const _SectionLabel(label: 'Basic Information'),
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
                    label: 'Mobile Number *',
                    validator: Validators.phone,
                    onEditingComplete: () =>
                        _secondaryPhoneFocus.requestFocus(),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 14),

                  _PhoneField(
                    controller: _secondaryPhoneCtrl,
                    focusNode: _secondaryPhoneFocus,
                    label: 'Secondary Mobile Number',
                    validator: Validators.optionalPhone,
                    onEditingComplete: () => _addressFocus.requestFocus(),
                  ).animate().fadeIn(delay: 225.ms),

                  const SizedBox(height: 24),

                  // ── Section: Optional ────────────────────────────────────
                  const _SectionLabel(label: 'Optional Details'),
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
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      hintText: 'e.g. Shop owner, meets every Tuesday…',
                      prefixIcon: Padding(
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
class _CustomerPhotoPicker extends StatefulWidget {
  final TextEditingController nameController;
  final Uint8List? selectedBytes;
  final String? photoPath;
  final VoidCallback onTap;

  const _CustomerPhotoPicker({
    required this.nameController,
    required this.selectedBytes,
    required this.photoPath,
    required this.onTap,
  });

  @override
  State<_CustomerPhotoPicker> createState() => _CustomerPhotoPickerState();
}

class _CustomerPhotoPickerState extends State<_CustomerPhotoPicker> {
  @override
  void initState() {
    super.initState();
    widget.nameController.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.nameController.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Add customer photo',
            child: InkWell(
              onTap: widget.onTap,
              customBorder: const CircleBorder(),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  if (widget.selectedBytes != null)
                    Container(
                      width: 80,
                      height: 80,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: colorScheme.primary.withValues(alpha: 0.35),
                          width: 2,
                        ),
                      ),
                      child: Image.memory(
                        widget.selectedBytes!,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    )
                  else
                    CustomerAvatarImage(
                      initials: _initials,
                      photoPath: widget.photoPath,
                      color: colorScheme.primary,
                      size: 80,
                      fontSize: 26,
                      borderWidth: 2,
                    ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: colorScheme.surface, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt_outlined,
                          size: 15, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer photo',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.selectedBytes == null
                      ? 'Optional, compressed before upload'
                      : 'Photo ready to upload',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: widget.onTap,
                  icon: Icon(
                    widget.selectedBytes == null
                        ? Icons.add_a_photo_outlined
                        : Icons.edit_outlined,
                    size: 17,
                  ),
                  label: Text(widget.selectedBytes == null
                      ? 'Add photo'
                      : 'Change photo'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Phone Field ───────────────────────────────────────────────────────────────

class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final FormFieldValidator<String> validator;
  final VoidCallback onEditingComplete;

  const _PhoneField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.validator,
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
      style: GoogleFonts.poppins(fontSize: 15),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(AppConstants.phoneLength),
      ],
      validator: validator,
      decoration: InputDecoration(
        counterText: '',
        labelText: label,
        hintText: '98765 43210',
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '${AppConstants.defaultCountryFlag}  ',
                style: TextStyle(fontSize: 16),
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
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
      ),
    );
  }
}
