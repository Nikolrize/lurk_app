import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/player_profile.dart';

import '../models/gaming_preferences.dart';

import 'package:lurk_app/core/data/gaming_regions.dart';

import 'package:lurk_app/features/player/models/player_availability.dart';

class ProfileService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _currentUid {
    final user = _auth.currentUser;

    if (user == null) {
      throw StateError('You must be signed in.');
    }

    return user.uid;
  }

  // creates missing documents
  Future<void> ensureMyProfile(String uid) async {
    if (_currentUid != uid) {
      throw StateError('The account changed. Please try again.');
    }

    final publicReference = _db.collection('players').doc(uid);
    final privateReference = _db.collection('player_private').doc(uid);

    await _db.runTransaction((transaction) async {
      // All reads happen before writes.
      final publicDocument = await transaction.get(publicReference);
      final privateDocument = await transaction.get(privateReference);

      if (!publicDocument.exists) {
        transaction.set(publicReference, {
          'username': '',
          'bio': '',
          'region': '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (!privateDocument.exists) {
        transaction.set(privateReference, {
          'dateOfBirth': null,
          'gender': '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Stream<PlayerProfile?> watchProfile(String uid) {
    return _db.collection('players').doc(uid).snapshots().map((document) {
      if (!document.exists) return null;

      return PlayerProfile.fromDocument(document);
    });
  }

  Stream<PlayerPrivateInfo?> watchPrivateInfo(String uid) {
    return _db.collection('player_private').doc(uid).snapshots().map((
      document,
    ) {
      if (!document.exists) return null;

      return PlayerPrivateInfo.fromDocument(document);
    });
  }

  Future<void> updateMyProfile({
    required String username,
    required String bio,
    required String region,
  }) {
    final uid = _currentUid;
    final cleanUsername = username.trim();
    final cleanBio = bio.trim();
    final cleanRegion = region.trim();

    if (cleanUsername.length < 3 || cleanUsername.length > 30) {
      throw ArgumentError('Username must contain 3–30 characters.');
    }

    if (cleanBio.length > 500) {
      throw ArgumentError('Bio must not exceed 500 characters.');
    }

    if (!GamingRegions.values.contains(cleanRegion)) {
      throw ArgumentError('Please select a supported gaming region.');
    }

    return _db.collection('players').doc(uid).update({
      'username': cleanUsername,
      'bio': cleanBio,
      'region': cleanRegion,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateMyPrivateInfo({
    required DateTime? dateOfBirth,
    required String gender,
  }) {
    final uid = _currentUid;

    const allowedGenders = {'', 'male', 'female', 'other', 'prefer_not_to_say'};

    if (!allowedGenders.contains(gender)) {
      throw ArgumentError('Invalid gender selection.');
    }

    // Birth date represents a calendar date, stored at midnight UTC.
    final birthDate = dateOfBirth == null
        ? null
        : DateTime.utc(dateOfBirth.year, dateOfBirth.month, dateOfBirth.day);

    final today = DateTime.now();
    final todayUtc = DateTime.utc(today.year, today.month, today.day);

    if (birthDate != null &&
        (birthDate.year < 1900 || birthDate.isAfter(todayUtc))) {
      throw ArgumentError('Please select a valid birth date.');
    }

    return _db.collection('player_private').doc(uid).update({
      'dateOfBirth': birthDate == null ? null : Timestamp.fromDate(birthDate),
      'gender': gender,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  //loading
  Future<ProfileSetupData> loadMyProfileSetup(String uid) async {
    if (_currentUid != uid) {
      throw StateError('The account changed. Please try again.');
    }

    await ensureMyProfile(uid);

    final publicDocument = await _db
        .collection('players')
        .doc(uid)
        .get(const GetOptions(source: Source.server));

    final privateDocument = await _db
        .collection('player_private')
        .doc(uid)
        .get(const GetOptions(source: Source.server));

    if (!publicDocument.exists || !privateDocument.exists) {
      throw StateError('Profile information is missing.');
    }

    return ProfileSetupData(
      profile: PlayerProfile.fromDocument(publicDocument),
      privateInfo: PlayerPrivateInfo.fromDocument(privateDocument),
    );
  }

  //atomic saving
  Future<void> saveMyProfileDetails({
    required String expectedUid,
    required String username,
    required String bio,
    required String region,
    required DateTime dateOfBirth,
    required String gender,
    bool showAge = false,
    bool showGender = false,
  }) async {
    final uid = _currentUid;

    if (uid != expectedUid) {
      throw StateError('The account changed. Reopen your profile.');
    }

    final cleanUsername = username.trim();
    final cleanBio = bio.trim();
    final cleanRegion = region.trim();

    if (cleanUsername.length < 3 || cleanUsername.length > 30) {
      throw ArgumentError('Username must contain 3-30 characters.');
    }

    if (cleanBio.length > 500) {
      throw ArgumentError('Bio must not exceed 500 characters.');
    }

    if (!GamingRegions.values.contains(cleanRegion)) {
      throw ArgumentError('Please select a supported gaming region.');
    }

    const allowedGenders = {'male', 'female', 'other', 'prefer_not_to_say'};

    if (!allowedGenders.contains(gender)) {
      throw ArgumentError('Please select a gender option.');
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

    final batch = _db.batch();

    batch.update(_db.collection('players').doc(uid), {
      'username': cleanUsername,
      'bio': cleanBio,
      'region': cleanRegion,
      'sharedAge': showAge ? calculateAge(birthDate, today) : null,
      'ageSharedAt': showAge ? FieldValue.serverTimestamp() : null,
      'sharedGender': showGender && gender != 'prefer_not_to_say'
          ? gender
          : null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.update(_db.collection('player_private').doc(uid), {
      'dateOfBirth': Timestamp.fromDate(birthDate),
      'gender': gender,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  Stream<GamingPreferences> watchGamingPreferences(String uid) {
    return _db.collection('players').doc(uid).snapshots().map((document){
      final data = document.data();

      if (data == null) {
        throw StateError('Player profile not found.');
      }

      return GamingPreferences.fromMap(data);
    });
  }

  Future<void> saveMyGamingPreferences({
    required String expectedUid,
    required GamingPreferences preferences,
  }) {
    final uid = _currentUid;
    if (uid != expectedUid) {
      throw StateError('The account changed. Reopen gaming preferences');
    }

    preferences.validate();

    return _db.collection('players').doc(uid).update({
      ...preferences.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // loading
  Stream<PlayerAvailability> watchAvailability(String uid) {
    return _db.collection('players').doc(uid).snapshots().map((document) {
      final data = document.data();

      if (data == null) {
        throw StateError('Player profile not found.');
      }

      final rawAvailability = data['availability'];

      if (rawAvailability == null) {
        return const PlayerAvailability();
      }

      return PlayerAvailability.fromMap(
        Map<String, dynamic>.from(rawAvailability as Map),
      );
    });
  }

  //saving
  Future<void> saveMyAvailability({
    required String expectedUid,
    required PlayerAvailability availability,
  }) {
    final uid = _currentUid;

    if (uid != expectedUid) {
      throw StateError('The account changed. Reopen availability.');
    }

    availability.validate();

    return _db.collection('players').doc(uid).update({
      'availability': availability.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
