import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/player_profile.dart';
import '../services/profile_service.dart';
import 'auth_provider.dart';

import '../models/gaming_preferences.dart';

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService();
});

final profileInitializationProvider = FutureProvider.autoDispose
    .family<void, String>((ref, uid) {
      final service = ref.watch(profileServiceProvider);

      return service.ensureMyProfile(uid);
    });

final playerProfileProvider = StreamProvider.autoDispose
    .family<PlayerProfile?, String>((ref, uid) {
      final service = ref.watch(profileServiceProvider);

      return service.watchProfile(uid);
    });

final myPrivateInfoProvider = StreamProvider.autoDispose<PlayerPrivateInfo?>((
  ref,
) {
  final authState = ref.watch(authStateProvider);
  final user = authState.asData?.value;

  if (user == null) {
    return Stream<PlayerPrivateInfo?>.value(null);
  }

  final service = ref.watch(profileServiceProvider);

  return service.watchPrivateInfo(user.uid);
});

final profileSetupProvider = FutureProvider.autoDispose
    .family<ProfileSetupData, String>((ref, uid) {
      return ref.watch(profileServiceProvider).loadMyProfileSetup(uid);
    });

final gamingPreferencesProvider = StreamProvider.autoDispose.family<GamingPreferences, String> ((ref,uid){
  return ref.watch(profileServiceProvider).watchGamingPreferences(uid);
});
