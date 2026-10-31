import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../features/ratings/models/teammate_rating.dart';

class RatingService {
  RatingService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  static bool overlaps(
    Map<String, dynamic> me,
    Map<String, dynamic> peer,
    Map<String, dynamic> party,
    DateTime now,
  ) {
    final mine = (me['joinedAt'] as Timestamp?)?.toDate();
    final theirs = (peer['joinedAt'] as Timestamp?)?.toDate();
    final closed = party['status'] == 'closed';
    final sessionEnd =
        ((party['completedAt'] ?? party['updatedAt']) as Timestamp?)?.toDate();
    final myEnd =
        (me['leftAt'] as Timestamp?)?.toDate() ?? (closed ? sessionEnd : null);
    final theirEnd =
        (peer['leftAt'] as Timestamp?)?.toDate() ?? (closed ? sessionEnd : now);
    return mine != null &&
        theirs != null &&
        myEnd != null &&
        theirEnd != null &&
        mine.isBefore(myEnd) &&
        theirs.isBefore(theirEnd) &&
        mine.isBefore(theirEnd) &&
        theirs.isBefore(myEnd);
  }

  Future<List<RatingCandidate>> loadCandidates(
    String partyId,
    String uid,
  ) async {
    final party = _db.collection('parties').doc(partyId);
    final snapshot = await party.get();
    final members = await party.collection('members').get();
    final own = members.docs.where((doc) => doc.id == uid).firstOrNull;
    if (own == null || snapshot.data() == null) return [];
    final eligible = members.docs.where(
      (doc) =>
          doc.id != uid &&
          overlaps(own.data(), doc.data(), snapshot.data()!, DateTime.now()),
    );
    return Future.wait(
      eligible.map((member) async {
        final review = await _reviews(member.id).doc('${partyId}_$uid').get();
        return RatingCandidate(member.id, rated: review.exists);
      }),
    );
  }

  CollectionReference<Map<String, dynamic>> _reviews(String target) =>
      _db.collection('player_reviews').doc(target).collection('reviews');

  Future<void> submit(
    String partyId,
    String uid,
    String target,
    RatingDraft draft,
  ) async {
    draft.validate();
    if (uid == target || FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError('Choose another teammate and sign in again.');
    }
    final review = _reviews(target).doc('${partyId}_$uid');
    await _db.runTransaction((tx) async {
      if ((await tx.get(review)).exists) {
        throw StateError('You already rated this teammate for this party.');
      }
      tx.set(review, {
        'partyId': partyId,
        'raterId': uid,
        'stars': draft.stars,
        'tags': draft.tags,
        'comment': draft.comment.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Stream<RatingSummary> watchSummary(String uid) =>
      _reviews(uid).snapshots().map((snapshot) {
        var total = 0;
        for (final doc in snapshot.docs) {
          total += (doc.data()['stars'] as num).toInt();
        }
        return RatingSummary(total: total, count: snapshot.docs.length);
      });
}
