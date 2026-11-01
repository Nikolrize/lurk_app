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
    final archives = await party.collection('visits').get();
    final ended =
        own.data()['leftAt'] != null || snapshot.data()!['status'] == 'closed';
    if (!ended) return [];
    List<Map<String, dynamic>> visits(
      String id,
      Map<String, dynamic> current,
    ) => [
      current,
      ...archives.docs
          .where((doc) => doc.data()['uid'] == id)
          .map((doc) => doc.data()),
    ];
    final eligible = members.docs.where(
      (doc) =>
          doc.id != uid &&
          visits(uid, own.data()).any(
            (me) => visits(doc.id, doc.data()).any(
              (peer) => overlaps(me, peer, snapshot.data()!, DateTime.now()),
            ),
          ),
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
    final party = _db.collection('parties').doc(partyId);
    final session = (await party.get()).data();
    final own = (await party.collection('members').doc(uid).get()).data();
    final peer = (await party.collection('members').doc(target).get()).data();
    if (session == null ||
        own == null ||
        peer == null ||
        (own['leftAt'] == null && session['status'] != 'closed')) {
      throw StateError(
        'Ratings become available after your participation ends.',
      );
    }
    final archives = await party.collection('visits').get();
    final mine = <({Map<String, dynamic> data, String? id})>[
      (data: own, id: null),
      ...archives.docs
          .where((d) => d.data()['uid'] == uid)
          .map((d) => (data: d.data(), id: d.id)),
    ];
    final theirs = <({Map<String, dynamic> data, String? id})>[
      (data: peer, id: null),
      ...archives.docs
          .where((d) => d.data()['uid'] == target)
          .map((d) => (data: d.data(), id: d.id)),
    ];
    Map<String, String>? proof;
    for (final me in mine) {
      for (final other in theirs) {
        if (overlaps(me.data, other.data, session, DateTime.now())) {
          proof = {
            if (me.id != null) 'ownVisitId': me.id!,
            if (other.id != null) 'peerVisitId': other.id!,
          };
          break;
        }
      }
      if (proof != null) break;
    }
    if (proof == null) {
      throw StateError('You did not play together during this party.');
    }
    final visitProof = proof;
    final review = _reviews(target).doc('${partyId}_$uid');
    final summary = _db.collection('player_rating_summaries').doc(target);
    await _db.runTransaction((tx) async {
      if ((await tx.get(review)).exists) {
        throw StateError('You already rated this teammate for this party.');
      }
      final totals = (await tx.get(summary)).data();
      tx.set(summary, {
        'total': ((totals?['total'] as num?)?.toInt() ?? 0) + draft.stars,
        'count': ((totals?['count'] as num?)?.toInt() ?? 0) + 1,
        'lastReviewId': review.id,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.set(review, {
        'partyId': partyId,
        'raterId': uid,
        ...visitProof,
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
