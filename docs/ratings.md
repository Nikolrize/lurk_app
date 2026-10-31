# Teammate ratings

From Parties > Party History (or My Profile > Party History), tap Rate, choose a
teammate, select 1–5 stars, optionally select feedback tags and add up to 500
characters, then Submit. The teammate becomes Rated for that party. You may rate
other eligible teammates individually or return without rating everyone.

Both player-profile and My Profile screens show the calculated average and number
of submitted reviews. Reviews are immutable and one reviewer can rate each other
player only once per party. The review comments/tags are saved with the rating;
this first version displays the average/count rather than a public review feed.

## Eligibility

- Your own participation must have ended (you left/were removed, or the host closed
  the session), matching how existing Party History works.
- Both players must have recorded membership intervals that overlap. Joining after
  another person left does not allow rating them. Self-ratings are rejected.
- Missing or incomplete historical membership data does not grant rating rights.
- Membership records currently describe the latest join/leave interval. If a player
  rejoins the same party, older overwritten intervals are not reconstructed.
- Blocking and reporting remain separate safety actions; a shared session can still
  be reviewed after a block.

## Storage and security

Reviews live at player_reviews/{targetUid}/reviews/{partyId}_{raterUid}, containing
partyId, raterId, stars, tags, comment, and a server creation timestamp. Firestore
checks membership overlap, history, score range, allowed tags, comment length, and
review identity. Updates and deletes are rejected, preventing score changes or
duplicate reviews. Reviews are readable by signed-in users. Existing party/history
writes and rules are preserved; this feature adds a separate review collection.

The profile summary is calculated from these protected reviews, not a client-written
rating total. There is no paid aggregation service. Loading reviews uses Spark
Firestore read quotas; aggregate storage can be considered if usage grows. Existing
discovery/matchmaking fields are not rewritten by this profile-summary feature.

## Enable and demonstrate

1. From the project root deploy the updated rules:
   `firebase deploy --only firestore:rules`.
2. Restart Lurk on two devices, sign in with different accounts, and join one party.
3. End the party or leave it. Open Party History > Rate.
4. Rate the other player, choose tags/comment, and submit.
5. Check Rated on the teammate list, then open their profile to see its new average.
6. Reopen the session: the same teammate must remain Rated. The other account can
   separately review you when its own participation has ended.

No laptop notification/voice server or Blaze upgrade is needed for ratings. Feedback
does not generate a push notification in this version.

## Verification

```
flutter test test/rating_test.dart test/party_history_test.dart test/player_profile_merge_test.dart
firebase emulators:exec --only firestore --project demo-lurk-ratings "node --test --test-concurrency=1 test/firestore/rating_rules.test.mjs test/firestore/party_history_rules.test.mjs"
```
