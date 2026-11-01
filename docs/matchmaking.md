# Matchmaking and party participation

- Home recommends open parties for saved games in the profile region, prioritizing the main matchmaking game. Own/current, full, blocked, and rating/rank-ineligible parties are excluded.
- Quick Match randomly chooses from eligible public parties for the main game and region, paging through the game-specific query. The preview still appears before joining. Eligibility is checked again in the join transaction and Firestore rules.
- A narrowed rank range requires a saved rank for that game. The complete range allows unranked players too. Minimum rating uses the unrounded review average; no reviews does not satisfy a positive minimum.
- Find loads 100 records initially and can load more. History starts at 50 and offers older records. Increasing these limits keeps the feeds live.
- Before rejoining, the completed membership is archived under parties/{partyId}/visits/{uid}_{joinedAtMilliseconds}. Archived visits are immutable and validated against the previous membership. History adds visit durations, excluding time away. Rating submissions can reference an archived ownVisitId or peerVisitId to prove overlap. One review per teammate per party remains unchanged.
- Existing overwritten visits cannot be recovered. Preserving visits starts with this app version. Teammates should pull the updated PartyService and RatingService together with the rules.
- Verification badges share the existing verification summary. Game labels say Main game, because this is a saved preference rather than live game detection.
- Notifications and the notification sender were not changed.
