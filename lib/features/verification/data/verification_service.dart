import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/verification_request.dart';
import '../models/verification_status.dart';
import '../models/verification_summary.dart';

//firebase auth
import 'package:firebase_auth/firebase_auth.dart';

class VerificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _checkAccount(String expectedUid) {
    if (_auth.currentUser?.uid != expectedUid) {
      throw StateError(
        'Your account changed. Reopen verification and try again.',
      );
    }
  }

  Stream<bool> watchIsAdmin(String uid) { //checking whether logged in account is an admin
    return _db
        .collection('verification_admins')
        .doc(uid)
        .snapshots()
        .map((document) {
          return document.data()?['enabled'] == true;
        });
  }

  Stream<VerificationRequest?> watchRequest(String uid) { //showing a player's private submission and review result
    return _db
        .collection('verification_requests')
        .doc(uid)
        .snapshots()
        .map((document) {
          if (!document.exists) return null;

          return VerificationRequest.fromDocument(document);
        });
  }

  Stream<VerificationSummary?> watchSummary(String uid) { //showing verification status without retrieving ID details
    return _db
        .collection('verification_status')
        .doc(uid)
        .snapshots()
        .map((document) {
          if (!document.exists) return null;

          return VerificationSummary.fromDocument(document);
        });
  }

  Stream<List<VerificationRequest>> watchPendingRequests() { //loading admin's pending-review list
    return _db
        .collection('verification_requests')
        .where(
          'status',
          isEqualTo: VerificationStatus.pending.id,
        )
        .limit(100)
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs
              .map(VerificationRequest.fromDocument)
              .toList();

          requests.sort((a, b) {
            final first = a.submittedAt?.millisecondsSinceEpoch ?? 0;
            final second = b.submittedAt?.millisecondsSinceEpoch ?? 0;

            return first.compareTo(second);
          });

          return requests;
        });
  }


  Future<void> submitRequest({
    required String expectedUid,
    required String submissionId,
    required String fullName,
    required String idType,
    required String idNumber,
    required DateTime dateOfBirth,
    required String idPhotoPath,
    required bool confirmed,
  }) async {
    _checkAccount(expectedUid);

    final cleanName = fullName.trim();
    final cleanNumber = idNumber.trim();

    if (cleanName.length < 2 || cleanName.length > 100) {
      throw ArgumentError('Full name must contain 2–100 characters.');
    }

    if (!const {'nric', 'passport'}.contains(idType)) {
      throw ArgumentError('Please select a supported ID type.');
    }

    if (cleanNumber.length < 4 || cleanNumber.length > 40) {
      throw ArgumentError('ID number must contain 4–40 characters.');
    }

    if (!confirmed) {
      throw ArgumentError('Please confirm that your details are correct.');
    }

    if (!RegExp(r'^[a-f0-9-]{36}$').hasMatch(submissionId)) {
      throw ArgumentError('Invalid submission identifier.');
    }

    final parts = idPhotoPath.split('/');

    if (parts.length != 3 ||
        parts[0] != expectedUid ||
        parts[1] != submissionId ||
        !RegExp(r'^id\.(jpg|png|webp)$').hasMatch(parts[2])) {
      throw ArgumentError('Invalid ID photo path.');
    }

    final birthDate = DateTime.utc(
      dateOfBirth.year,
      dateOfBirth.month,
      dateOfBirth.day,
    );

    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);

    if (birthDate.year < 1900 || birthDate.isAfter(today)) {
      throw ArgumentError('Please select a valid birth date.');
    }

    final requestReference = _db
        .collection('verification_requests')
        .doc(expectedUid);

    final summaryReference = _db
        .collection('verification_status')
        .doc(expectedUid);

    await _db.runTransaction<void>((transaction) async {
      _checkAccount(expectedUid);

      final existingDocument = await transaction.get(requestReference);
      final existing = existingDocument.data();

      if (existing != null) {
        final status = VerificationStatus.fromId(
          existing['status'] as String,
        );

        if (status != VerificationStatus.rejected) {
          throw StateError(
            'Your verification is already pending or approved.',
          );
        }

        if (existing['submissionId'] == submissionId) {
          throw ArgumentError(
            'A resubmission must use a new submission identifier.',
          );
        }
      }

      _checkAccount(expectedUid);

      transaction.set(requestReference, {
        'submissionId': submissionId,
        'fullName': cleanName,
        'idType': idType,
        'idNumber': cleanNumber,
        'dateOfBirth': Timestamp.fromDate(birthDate),
        'idPhotoPath': idPhotoPath,
        'confirmed': true,
        'status': VerificationStatus.pending.id,
        'submittedAt': FieldValue.serverTimestamp(),
        'reviewedAt': null,
        'reviewedBy': null,
        'rejectionReason': '',
      });

      transaction.set(summaryReference, {
        'status': VerificationStatus.pending.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> reviewRequest({
    required String expectedAdminUid,
    required String playerUid,
    required String expectedSubmissionId,
    required bool approve,
    String rejectionReason = '',
  }) async {
    _checkAccount(expectedAdminUid); //prevents an operation continuing under a different logged in account

    if (playerUid.isEmpty ||
        playerUid.length > 128 ||
        playerUid.contains('/')) {
      throw ArgumentError('Invalid player identifier.');
    }

    if (playerUid == expectedAdminUid) {
      throw StateError('You cannot review your own submission.');
    }

    if (!RegExp(
      r'^[a-f0-9-]{36}$',
    ).hasMatch(expectedSubmissionId)) {
      throw ArgumentError('Invalid submission identifier.');
    }

    final reason = approve ? '' : rejectionReason.trim();

    if (!approve && (reason.length < 3 || reason.length > 300)) {
      throw ArgumentError(
        'Please provide a rejection reason containing 3–300 characters.',
      );
    }

    final newStatus = approve
        ? VerificationStatus.verified
        : VerificationStatus.rejected;

    final adminReference = _db
        .collection('verification_admins')
        .doc(expectedAdminUid);

    final requestReference = _db
        .collection('verification_requests')
        .doc(playerUid);

    final summaryReference = _db
        .collection('verification_status')
        .doc(playerUid);

    await _db.runTransaction<void>((transaction) async {
      _checkAccount(expectedAdminUid);

      final adminDocument = await transaction.get(adminReference);

      if (adminDocument.data()?['enabled'] != true) {
        throw StateError('Administrator access is required.');
      }

      final requestDocument = await transaction.get(requestReference);
      final data = requestDocument.data();

      if (data == null) {
        throw StateError('This verification request no longer exists.');
      }

      if (data['submissionId'] != expectedSubmissionId ||
          data['status'] != VerificationStatus.pending.id) {
        throw StateError(
          'This submission has changed or has already been reviewed. '
          'Please refresh the review list.',
        );
      }

      _checkAccount(expectedAdminUid);

      transaction.update(requestReference, {
        'status': newStatus.id,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': expectedAdminUid,
        'rejectionReason': reason,
      });

      transaction.set(summaryReference, {
        'status': newStatus.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}