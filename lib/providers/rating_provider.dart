import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/rating_service.dart';
import '../features/ratings/models/teammate_rating.dart';
import 'auth_provider.dart';

final ratingServiceProvider = Provider((ref) => RatingService());
final ratingCandidatesProvider = FutureProvider.autoDispose
    .family<List<RatingCandidate>, String>((ref, partyId) {
      final uid = ref.watch(authStateProvider).asData?.value?.uid;
      if (uid == null) return Future.value(const []);
      return ref.watch(ratingServiceProvider).loadCandidates(partyId, uid);
    }, retry: (count, error) => null);
final ratingSummaryProvider = StreamProvider.autoDispose
    .family<RatingSummary, String>((ref, uid) {
      if (ref.watch(authStateProvider).asData?.value == null) {
        return Stream.value(const RatingSummary());
      }
      return ref.watch(ratingServiceProvider).watchSummary(uid);
    }, retry: (count, error) => null);
