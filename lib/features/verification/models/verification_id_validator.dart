class VerificationIdValidator {
  static String? validate({
    required String idType,
    required String value,
  }) {
    final number = value.trim();

    if (idType == 'nric') {
      final valid = RegExp(
        r'^(?:[0-9]{12}|[0-9]{6}-[0-9]{2}-[0-9]{4})$',
      ).hasMatch(number);

      return valid
          ? null
          : 'Enter 12 digits, with optional hyphens.';
    }

    if (idType == 'passport') {
      final valid =
          RegExp(r'^[A-Za-z0-9]{6,20}$').hasMatch(number) &&
          RegExp(r'[0-9]').hasMatch(number);

      return valid
          ? null
          : 'Use 6-20 letters/numbers, including at least one digit.';
    }

    return 'Select a supported ID type.';
  }

  static String normalize({
    required String idType,
    required String value,
  }) {
    final error = validate(idType: idType, value: value);

    if (error != null) {
      throw ArgumentError(error);
    }

    final number = value.trim();

    return idType == 'nric'
        ? number.replaceAll('-', '')
        : number.toUpperCase();
  }
}