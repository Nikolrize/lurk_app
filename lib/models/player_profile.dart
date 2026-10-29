import 'package:cloud_firestore/cloud_firestore.dart';

class PlayerProfile {
  const PlayerProfile({
    required this.uid,
    required this.username,
    required this.bio,
    required this.region,
    required this.createdAt,
    required this.updatedAt,
    this.sharedAge,
    this.ageSharedAt,
    this.sharedGender,
  });

  final String uid;
  final String username;
  final String bio;
  final String region;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  //? null mean information is not shared
  final int? sharedAge;
  final DateTime? ageSharedAt;
  final String? sharedGender;

  factory PlayerProfile.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data()!;

    return PlayerProfile(
      uid: document.id,
      username: data['username'] as String,
      bio: data['bio'] as String,
      region: data['region'] as String,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      sharedAge: data['sharedAge'] as int?,
      ageSharedAt: (data['ageSharedAt'] as Timestamp?)?.toDate(),
      sharedGender: data['sharedGender'] as String?,
    );
  }
}

class PlayerPrivateInfo {
  const PlayerPrivateInfo({
    required this.uid,
    required this.dateOfBirth,
    required this.gender,
  });

  final String uid;
  final DateTime? dateOfBirth;
  final String gender;

  factory PlayerPrivateInfo.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data()!;

    return PlayerPrivateInfo(
      uid: document.id,
      dateOfBirth: (data['dateOfBirth'] as Timestamp?)?.toDate().toUtc(),
      gender: data['gender'] as String,
    );
  }
}

class ProfileSetupData {
  const ProfileSetupData({required this.profile, required this.privateInfo});

  final PlayerProfile profile;
  final PlayerPrivateInfo privateInfo;

  bool get isComplete =>
      profile.username.trim().length >= 3 &&
      profile.region.trim().isNotEmpty &&
      privateInfo.dateOfBirth != null &&
      privateInfo.gender.isNotEmpty;
}

int calculateAge(DateTime birthDate, DateTime onDate) {
  var age = onDate.year - birthDate.year;

  final birthdayHasNotPassed =
      onDate.month < birthDate.month ||
      (onDate.month == birthDate.month && onDate.day < birthDate.day);

  if (birthdayHasNotPassed) {
    age--;
  }

  return age;
}
