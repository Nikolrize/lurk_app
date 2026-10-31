enum VerificationStatus {
  pending('pending', 'Pending review'),
  verified('verified', 'Verified'),
  rejected('rejected', 'Rejected');

  const VerificationStatus(this.id, this.label);

  final String id;
  final String label;

  static VerificationStatus fromId(String id) {
    for (final status in values) {
      if (status.id == id) {
        return status;
      }
    }

    throw FormatException('Unknown verification status.');
  }
}