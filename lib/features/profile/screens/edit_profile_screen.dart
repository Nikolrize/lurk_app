import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lurk_app/models/player_profile.dart';
import 'package:lurk_app/providers/profile_provider.dart';

import '../widgets/profile_page_layout.dart';

import 'package:lurk_app/core/data/gaming_regions.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({
    super.key,
    required this.initialData,
    this.initialSetup = false,
  });

  final ProfileSetupData initialData;
  final bool initialSetup;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  String? _region;

  DateTime? _dateOfBirth;
  String? _gender;
  bool _isSaving = false;
  bool _showAge = false;
  bool _showGender = false;
  String? _errorMessage;

  static const _genders = {
    'male': 'Male',
    'female': 'Female',
    'other': 'Others',
    'prefer_not_to_say': 'Prefer not to say',
  };

  @override
  void initState() {
    super.initState();

    final data = widget.initialData;

    _usernameController = TextEditingController(text: data.profile.username);
    _bioController = TextEditingController(text: data.profile.bio);
    final savedRegion = data.profile.region.trim();
    _region = GamingRegions.values.contains(savedRegion) ? savedRegion : null;

    _dateOfBirth = data.privateInfo.dateOfBirth;
    _gender = data.privateInfo.gender.isEmpty ? null : data.privateInfo.gender;

    _showAge = data.profile.sharedAge != null;
    _showGender =
        data.profile.sharedGender != null &&
        data.privateInfo.gender != 'prefer_not_to_say';
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate(FormFieldState<DateTime> field) async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth == null
          ? DateTime(2000, 1, 1)
          : DateTime(
              _dateOfBirth!.year,
              _dateOfBirth!.month,
              _dateOfBirth!.day,
            ),
      firstDate: DateTime(1900, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDatePickerMode: DatePickerMode.year,
    );

    if (!mounted || selected == null) return;

    setState(() {
      _dateOfBirth = selected;
    });

    field.didChange(selected);
  }

  Future<void> _save() async {
    if (_isSaving || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(profileServiceProvider)
          .saveMyProfileDetails(
            expectedUid: widget.initialData.profile.uid,
            username: _usernameController.text,
            bio: _bioController.text,
            region: _region!,
            dateOfBirth: _dateOfBirth!,
            gender: _gender!,
            showAge: _showAge,
            showGender: _showGender,
          );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } on FirebaseException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.code == 'permission-denied'
            ? 'You do not have permission to save this profile.'
            : 'Unable to save. Check your connection and try again.';
      });
    } on ArgumentError catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.message.toString();
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Unable to save. Check your account and try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final birthday = _dateOfBirth == null
        ? 'Select your birth date'
        : MaterialLocalizations.of(context).formatMediumDate(
            DateTime(
              _dateOfBirth!.year,
              _dateOfBirth!.month,
              _dateOfBirth!.day,
            ),
          );

    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.initialSetup ? 'Complete your profile' : 'Edit profile',
          ),
        ),
        body: ProfilePageLayout(
          introduction: ProfileIntroduction(
            title: widget.initialSetup
                ? 'Build your player identity'
                : 'Keep your profile up to date',
            description:
                'Introduce yourself to other players and choose '
                'which personal details appear on your public profile.',
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Username, bio and region are visible to signed-in players. '
                  'Your full birth date stays private. '
                  'You can choose to share your age and pronouns below.',
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _usernameController,
                  enabled: !_isSaving,
                  maxLength: 30,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    helperText: 'Display name; not a unique login.',
                  ),
                  validator: (value) {
                    final name = value?.trim() ?? '';
                    if (name.length < 3 || name.length > 30) {
                      return 'Use 3-30 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bioController,
                  enabled: !_isSaving,
                  maxLength: 500,
                  minLines: 3,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Bio (optional)',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _region,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Preferred gaming region',
                    hintText: 'Select a region',
                  ),
                  items: [
                    for (final region in GamingRegions.values)
                      DropdownMenuItem(
                        value: region,
                        child: Text(region),
                      ),
                  ],
                  onChanged: _isSaving ? null : (value) {
                          setState(() {
                            _region = value;
                          });
                        },
                  validator: (value) {
                    if (value == null || !GamingRegions.values.contains(value)) {
                      return 'Please select your gaming region.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                FormField<DateTime>(
                  initialValue: _dateOfBirth,
                  validator: (value) {
                    if (value == null) {
                      return 'Please select your birth date.';
                    }
                    return null;
                  },
                  builder: (field) {
                    return InkWell(
                      onTap: _isSaving ? null : () => _pickBirthDate(field),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Birth date (private)',
                          errorText: field.errorText,
                          suffixIcon: const Icon(Icons.calendar_month),
                        ),
                        child: Text(birthday),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _gender,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: _genders.entries.map((entry) {
                    return DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          setState(() {
                            _gender = value;
                            if (value == 'prefer_not_to_say') {
                              _showGender = false;
                            }
                          });
                        },
                  validator: (value) {
                    if (value == null) {
                      return 'Please select a gender option.';
                    }
                    return null;
                  },
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Profile visibility',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show my age'),
                  subtitle: const Text(
                    'Shares your age when saved, with the sharing date. '
                    'Your full birth date stays private.',
                  ),
                  value: _showAge,
                  onChanged: _isSaving
                      ? null
                      : (value) {
                          setState(() {
                            _showAge = value;
                          });
                        },
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show my pronouns'),
                  subtitle: const Text(
                    'Displays He/him for Male, She/her for Female, '
                    'or They/them for Others.',
                  ),
                  value: _showGender,
                  onChanged:
                      _isSaving ||
                          _gender == null ||
                          _gender == 'prefer_not_to_say'
                      ? null
                      : (value) {
                          setState(() {
                            _showGender = value;
                          });
                        },
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: Text(_isSaving ? 'Saving...' : 'Save profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
