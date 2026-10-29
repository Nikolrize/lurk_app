import 'package:cloud_firestore/cloud_firestore.dart';

class PlayerProfile {
  const PlayerProfile({
    required this.uid,
    required this.username,
    required this.bio,
    required this.region,
    required this.createdAt,
    required this.updatedAt,
  });

  final String uid;
  final String username;
  final String bio;
  final String region;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
