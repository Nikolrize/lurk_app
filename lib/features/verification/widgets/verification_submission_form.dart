import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lurk_app/providers/verification_provider.dart';
import '../models/verification_request.dart';

import '../models/verification_id_validator.dart';

class VerificationSubmissionForm extends ConsumerStatefulWidget {
  const VerificationSubmissionForm({
    super.key,
    required this.uid,
    this.previousRequest,
  });
  final String uid;
  final VerificationRequest? previousRequest;
  @override
  ConsumerState<VerificationSubmissionForm> createState() =>
      _VerificationSubmissionFormState();
}

class _VerificationSubmissionFormState
    extends ConsumerState<VerificationSubmissionForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name, _number, _dateText;
  DateTime? _birthDate;
  String _idType = 'nric';
  XFile? _image;
  Uint8List? _preview;
  bool _confirmed = false, _saving = false, _picking = false;
  String? _error;
  bool get _busy => _saving || _picking;
  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  @override
  void initState() {
    super.initState();
    final previous = widget.previousRequest;
    _name = TextEditingController(text: previous?.fullName ?? '');
    _number = TextEditingController(text: previous?.idNumber ?? '');
    _birthDate = previous?.dateOfBirth;
    _idType = previous?.idType ?? 'nric';
    _dateText = TextEditingController(
      text: _birthDate == null ? '' : _dateLabel(_birthDate!),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    _dateText.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (mounted) setState(() => _error = message);
  }

  Future<void> _pickDate() async {
    if (_busy) return;
    final now = DateTime.now(), current = _birthDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: current == null
          ? DateTime(2000, 1, 1)
          : DateTime(current.year, current.month, current.day),
      firstDate: DateTime(1900, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _birthDate = selected;
      _dateText.text = _dateLabel(selected);
    });
  }

  Future<void> _pickImage() async {
    if (_busy) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
        requestFullMetadata: false,
      );
      if (image == null || !mounted) return;
      final length = await image.length();
      if (length == 0 || length > 2 * 1024 * 1024) {
        throw ArgumentError('Choose an ID photo no larger than 2 MB.');
      }
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        _image = image;
        _preview = bytes;
      });
    } on ArgumentError catch (error) {
      _showError(error.message.toString());
    } catch (_) {
      _showError('Unable to select an image. Try again.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    final image = _image, birthDate = _birthDate;
    if (image == null || birthDate == null || !_confirmed) {
      _showError(
        image == null
            ? 'Choose an ID photo before submitting.'
            : 'Please confirm that your details are correct.',
      );
      return;
    }
    final uid = widget.uid,
        name = _name.text,
        number = _number.text,
        idType = _idType;
    final storage = ref.read(verificationStorageServiceProvider);
    final service = ref.read(verificationServiceProvider);
    final submissionId = storage.createSubmissionId();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final path = await storage.uploadIdPhoto(
        expectedUid: uid,
        submissionId: submissionId,
        image: image,
      );
      if (!mounted) return;
      await service.submitRequest(
        expectedUid: uid,
        submissionId: submissionId,
        fullName: name,
        idType: idType,
        idNumber: number,
        dateOfBirth: birthDate,
        idPhotoPath: path,
        confirmed: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Submitted for admin review.')),
      );
    } on ArgumentError catch (error) {
      _showError(error.message.toString());
    } on StateError catch (error) {
      _showError(error.message);
    } on FirebaseException catch (error) {
      _showError(
        error.code == 'permission-denied'
            ? 'You do not have permission to submit this verification.'
            : 'Unable to save your submission. Check your connection and retry.',
      );
    } on StorageException catch (_) {
      _showError('Unable to upload the ID photo. Try again.');
    } catch (_) {
      _showError('Unable to submit verification. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview;
    return PopScope(
      canPop: !_saving,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.previousRequest == null
                  ? 'Your identification details'
                  : 'Submit a new attempt',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'Your ID details and photo are private to you and authorized verification admins.',
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              enabled: !_busy,
              maxLength: 100,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full name (as on ID)',
              ),
              validator: (value) {
                final length = value?.trim().length ?? 0;
                return length < 2 || length > 100
                    ? 'Use 2-100 characters.'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _idType,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'ID type'),
              items: const [
                DropdownMenuItem(value: 'nric', child: Text('NRIC')),
                DropdownMenuItem(value: 'passport', child: Text('Passport')),
              ],
              onChanged: _busy
                  ? null
                  : (value) {
                      if (value != null) setState(() => _idType = value);
                    },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _dateText,
              enabled: !_busy,
              readOnly: true,
              onTap: _pickDate,
              decoration: const InputDecoration(
                labelText: 'Date of birth',
                suffixIcon: Icon(Icons.calendar_today_outlined),
              ),
              validator: (_) =>
                  _birthDate == null ? 'Select your date of birth.' : null,
            ),
            const SizedBox(height: 20),
            TextFormField(
              key: ValueKey('id-number:$_idType'),
              controller: _number,
              enabled: !_busy,
              maxLength: _idType == 'nric' ? 14 : 20,
              keyboardType: _idType == 'nric' ? TextInputType.number : TextInputType.text,
              textCapitalization: _idType == 'passport' ? TextCapitalization.characters : TextCapitalization.none,
              autocorrect: false,
              enableSuggestions: false,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: InputDecoration(
                labelText: _idType == 'nric' ? 'NRIC number' : 'Passport number',
                helperText: _idType == 'nric' ? '12 digits; hyphens are optional.': '6-20 letters/numbers, including a digit.',
                helperMaxLines: 2,
              ),
              validator: (value) {
                return VerificationIdValidator.validate(
                  idType: _idType,
                  value: value ?? '',
                );
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickImage,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(
                _picking ? 'Selecting photo...' : (_image == null ? 'Choose ID photo' : 'Change ID photo'),
              ),
            ),
            const SizedBox(height: 8),
            const Text('One clear ID photo · JPEG, PNG or WebP · Up to 2 MB'),
            if (preview != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  preview,
                  height: 200,
                  fit: BoxFit.contain,
                  semanticLabel: 'Selected ID photo preview',
                  errorBuilder: (_, error, stackTrace) => const Text(
                    'This image cannot be previewed. Choose a JPEG, PNG or WebP.',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _confirmed,
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _confirmed = value ?? false),
              title: const Text(
                'I confirm that the details and ID photo are correct.',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_outlined),
              label: Text(
                _saving ? 'Submitting...' : 'Submit for verification',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
