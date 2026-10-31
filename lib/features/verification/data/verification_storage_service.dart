import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class VerificationStorageService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  static const bucketName = 'identity-verification';
  static const maxFileBytes = 2 * 1024 * 1024;

  static const _extensions = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
  };

  String createSubmissionId() {
    return const Uuid().v4();
  }

  void _checkAccount(String expectedUid) {
    if (_auth.currentUser?.uid != expectedUid) {
      throw StateError(
        'Your account changed. Reopen verification and try again.',
      );
    }
  }

  void _validatePath(String path) {
    final parts = path.split('/');

    if (path.length > 200 ||
        parts.length != 3 ||
        parts[0].isEmpty ||
        parts[0].length > 128 ||
        !RegExp(r'^[a-f0-9-]{36}$').hasMatch(parts[1]) ||
        !RegExp(r'^id\.(jpg|png|webp)$').hasMatch(parts[2])) {
      throw ArgumentError('Invalid ID photo path.');
    }
  }

  Future<String> uploadIdPhoto({
    required String expectedUid,
    required String submissionId,
    required XFile image,
  }) async {
    _checkAccount(expectedUid);

    if (!RegExp(r'^[a-f0-9-]{36}$').hasMatch(submissionId)) {
      throw ArgumentError('Invalid submission identifier.');
    }

    final fileSize = await image.length();

    if (fileSize == 0 || fileSize > maxFileBytes) {
      throw ArgumentError('Choose an ID photo no larger than 2 MB.');
    }

    final bytes = await image.readAsBytes();

    if (bytes.isEmpty || bytes.length > maxFileBytes) {
      throw ArgumentError('Choose an ID photo no larger than 2 MB.');
    }

    final contentType = lookupMimeType('', headerBytes: bytes);
    final extension = _extensions[contentType];

    if (extension == null) {
      throw ArgumentError('Choose a JPEG, PNG or WebP image.');
    }

    final path = '$expectedUid/$submissionId/id.$extension';
    _validatePath(path);
    _checkAccount(expectedUid);

    await _supabase.storage.from(bucketName).uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(
        contentType: contentType,
        upsert: false,
      ),
    );

    _checkAccount(expectedUid);

    return path;
  }

  Future<Uint8List> downloadIdPhoto({
    required String expectedViewerUid,
    required String path,
  }) async {
    _checkAccount(expectedViewerUid);
    _validatePath(path);

    final bytes = await _supabase.storage
        .from(bucketName)
        .download(path);

    _checkAccount(expectedViewerUid);

    return bytes;
  }
}