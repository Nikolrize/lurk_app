import 'package:cloud_firestore/cloud_firestore.dart';

import 'verification_status.dart';

class VerificationRequest {
  const VerificationRequest({
    required this.uid,
    required this.submissionId,
    required this.fullName,
    required this.idType,
    required this.idNumber,
    required this.dateOfBirth,
    required this.idPhotoPath,
    required this.confirmed,
    required this.status,
    required this.submittedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.rejectionReason = '',
  });

  final String uid;
  final String submissionId;

  final String fullName;
  final String idType;
  final String idNumber;
  final DateTime dateOfBirth;

  final String idPhotoPath;
  final bool confirmed;

  final VerificationStatus status;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String rejectionReason;

  factory VerificationRequest.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError('Verification request not found.');
    }

    return VerificationRequest(
      uid: document.id,
      submissionId: data['submissionId'] as String,
      fullName: data['fullName'] as String,
      idType: data['idType'] as String,
      idNumber: data['idNumber'] as String,
      dateOfBirth: (data['dateOfBirth'] as Timestamp).toDate().toUtc(),
      idPhotoPath: data['idPhotoPath'] as String,
      confirmed: data['confirmed'] as bool,
      status: VerificationStatus.fromId(data['status'] as String),
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedBy: data['reviewedBy'] as String?,
      rejectionReason: data['rejectionReason'] as String? ?? '',
    );
  }
}
