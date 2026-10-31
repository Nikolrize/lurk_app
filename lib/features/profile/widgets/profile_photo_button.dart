import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:lurk_app/core/widgets/player_avatar.dart';
import 'package:lurk_app/providers/auth_provider.dart';
import 'package:lurk_app/providers/profile_provider.dart';

class ProfilePhotoButton extends ConsumerStatefulWidget {
  const ProfilePhotoButton({
    super.key,
    required this.uid,
    this.photoPath,
    this.enabled = true,
    this.radius = 36,
  });

  final String uid;
  final String? photoPath;
  final bool enabled;
  final double radius;

  @override
  ConsumerState<ProfilePhotoButton> createState() => _ProfilePhotoButtonState();
}

class _ProfilePhotoButtonState extends ConsumerState<ProfilePhotoButton> {
  bool _uploading = false;
  bool _hovered = false;
  bool _focused = false;

  Future<void> _changePhoto() async {
    if (_uploading || !widget.enabled) return;

    final uid = widget.uid;
    final oldPath = widget.photoPath;
    final images = ref.read(profileImageServiceProvider);
    final profiles = ref.read(profileServiceProvider);

    setState(() => _uploading = true);

    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        requestFullMetadata: false,
      );

      if (image == null || !mounted) return;

      final newPath = await images.uploadPhoto(expectedUid: uid, image: image);

      await profiles.saveMyPhotoPath(expectedUid: uid, photoPath: newPath);

      if (oldPath != null && oldPath != newPath) {
        try {
          await images
              .deletePhoto(expectedUid: uid, path: oldPath)
              .timeout(const Duration(seconds: 10));
        } catch (_) {
          debugPrint('Profile photo saved; previous image cleanup failed.');
        }
      }

      if (!mounted) return;

      _message('Profile photo updated.');
    } on ArgumentError catch (error) {
      if (mounted) _message(error.message.toString());
    } on FirebaseException catch (error) {
      if (!mounted) return;

      _message(
        error.code == 'permission-denied'
            ? 'You do not have permission to save this photo.'
            : 'Unable to save your photo. '
                  'Check your connection and try again.',
      );
    } on StorageException catch (_) {
      if (mounted) {
        _message('Unable to upload your photo. Please try again.');
      }
    } on StateError catch (error) {
      if (mounted) _message(error.message);
    } catch (_) {
      if (mounted) {
        _message('Unable to change your photo. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).asData?.value;

    if (user?.uid != widget.uid) {
      return PlayerAvatar(photoPath: widget.photoPath, radius: widget.radius);
    }

    final canEdit = widget.enabled && !_uploading;
    final showOverlay = _hovered || _focused || _uploading;
    final touchPlatform =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    final label = _uploading
        ? 'Updating profile photo'
        : 'Change profile photo';

    return Semantics(
      button: true,
      enabled: canEdit,
      label: label,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: canEdit ? _changePhoto : null,
            onHover: (value) => setState(() => _hovered = value),
            onFocusChange: (value) => setState(() => _focused = value),
            child: ExcludeSemantics(
              child: SizedBox.square(
                dimension: widget.radius * 2,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PlayerAvatar(
                      photoPath: widget.photoPath,
                      radius: widget.radius,
                    ),
                    if (touchPlatform && canEdit)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: ColoredBox(
                          color: Colors.black54,
                          child: SizedBox(
                            height: 22,
                            width: double.infinity,
                            child: const Icon(
                              Icons.photo_camera_outlined,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    AnimatedOpacity(
                      opacity: showOverlay ? 1 : 0,
                      duration: const Duration(milliseconds: 150),
                      child: ColoredBox(
                        color: Colors.black54,
                        child: Center(
                          child: _uploading
                              ? const SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.photo_camera_outlined,
                                  color: Colors.white,
                                  size: 24,
                                ),
                        ),
                      ),
                    ),
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
