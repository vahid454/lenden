import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/utils/validators.dart';

Future<String?> showContactEmailDialog(
  BuildContext context, {
  String? initialEmail,
  bool allowLater = true,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: allowLater,
    builder: (_) => _ContactEmailDialog(
      initialEmail: initialEmail,
      allowLater: allowLater,
    ),
  );
}

class _ContactEmailDialog extends StatefulWidget {
  final String? initialEmail;
  final bool allowLater;

  const _ContactEmailDialog({this.initialEmail, required this.allowLater});

  @override
  State<_ContactEmailDialog> createState() => _ContactEmailDialogState();
}

class _ContactEmailDialogState extends State<_ContactEmailDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_controller.text.trim().toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.alternate_email_rounded, size: 28),
      title: Text(
        'Add your email',
        style: GoogleFonts.poppins(fontSize: 19, fontWeight: FontWeight.w700),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Keep your contact details complete for important account communication.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.email],
              validator: Validators.email,
              onFieldSubmitted: (_) => _save(),
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.mail_outline_rounded, size: 20),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.allowLater)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Later'),
          ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text('Save email'),
        ),
      ],
    );
  }
}
