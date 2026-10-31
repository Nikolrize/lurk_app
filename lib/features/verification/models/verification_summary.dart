import 'package:cloud_firestore/cloud_firestore.dart';

import 'verification_status.dart';

class VerificationSummary {
  const VerificationSummary({
    required this.uid,
    required this.status,
    required this.updatedAt,
  });

  final String uid;
  final VerificationStatus status;
  final DateTime? updatedAt;

  bool get isVerified => status == VerificationStatus.verified;

  factory VerificationSummary.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError('Verification status not found.');
    }

    return VerificationSummary(
      uid: document.id,
      status: VerificationStatus.fromId(
        data['status'] as String,
      ),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}