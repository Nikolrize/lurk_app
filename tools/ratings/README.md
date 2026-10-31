# Rating totals and party requirements

Player reviews remain in `player_reviews/{uid}/reviews`. The app also maintains a protected `player_rating_summaries/{uid}` document with `total`, `count`, `lastReviewId` and `updatedAt`.

Every new review and its totals must be written in one transaction. Firestore rules validate the review independently and require an exact one-review increase. Older app versions that write only a review must update to the current `RatingService` before submitting ratings.

Party joins read the trusted totals and public profile region inside the membership transaction. Players must meet the unrounded average, match the party region, and fit within its maximum capacity. Invitations do not override these requirements. Unrated players can join parties whose minimum rating is zero.

Existing reviews can be checked/rebuilt using the project owner's Firebase CLI login. No private service-account key or hosted server is required. Run from the repository root:

```
node tools/ratings/backfill_summaries.mjs
node tools/ratings/backfill_summaries.mjs --apply
```

The first command is read-only. The second writes only aggregate documents and leaves reviews unchanged. Run the read-only command again to verify `summariesChanged` is zero. This maintenance helper expects the Firebase CLI installed globally on Windows, as on the current development machine. Normal app users do not need this helper or the Firebase CLI.
