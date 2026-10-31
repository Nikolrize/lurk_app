import 'package:flutter/material.dart';

class VerificationRejectDialog extends StatefulWidget {
  const VerificationRejectDialog({super.key});

  @override
  State<VerificationRejectDialog> createState() =>
      _VerificationRejectDialogState();
}

class _VerificationRejectDialogState
    extends State<VerificationRejectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject submission'),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _reason,
          autofocus: true,
          minLines: 3,
          maxLines: 5,
          maxLength: 300,
          decoration: const InputDecoration(
            labelText: 'Reason for rejection',
            helperText: 'Explain what the player needs to correct.',
          ),
          validator: (value) {
            final length = value?.trim().length ?? 0;

            return length < 3 || length > 300
                ? 'Use 3–300 characters.'
                : null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(_reason.text.trim());
            }
          },
          child: const Text('Reject'),
        ),
      ],
    );
  }
}