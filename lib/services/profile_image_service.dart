import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ProfileImageService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  static const bucketName = 'profile-images';
  static const maxFileBytes = 2 * 1024 * 1024;

  static const _extensions = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
  };

  void _checkAccount(String expectedUid) {
    if (_auth.currentUser?.uid != expectedUid) {
      throw StateError(
        'Your account changed. Reopen your profile and try again.',
      );
    }
  }

  Future<String> uploadPhoto({
    required String expectedUid,
    required XFile image,
  }) async {
    _checkAccount(expectedUid);

    final fileSize = await image.length();

    if (fileSize == 0 || fileSize > maxFileBytes) {
      throw ArgumentError('Choose a photo smaller than 2 MB.');
    }

    final bytes = await image.readAsBytes();

    if (bytes.isEmpty || bytes.length > maxFileBytes) {
      throw ArgumentError('Choose a photo smaller than 2 MB.');
    }

    final contentType = lookupMimeType('', headerBytes: bytes);
    final extension = _extensions[contentType];

    if (extension == null) {
      throw ArgumentError('Choose a JPEG, PNG or WebP photo.');
    }

    _checkAccount(expectedUid);

    final filename = '${const Uuid().v4()}.$extension';
    final path = '$expectedUid/$filename';

    await _supabase.storage.from(bucketName).uploadBinary( //uploads image bytes and can specify content type
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: contentType,
        upsert: false,
      ),
    );

    return path;
  }

  String publicUrl(String path) {
    return _supabase.storage.from(bucketName).getPublicUrl(path);
  }
}