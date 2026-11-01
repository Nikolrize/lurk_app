# Party chat

From an open party lobby, tap Chat to open the party's shared text conversation.
Current members can read and send, with live updates and 50-message pages.
Tap Load older messages to load more. Empty/whitespace-only messages and messages
longer than 2,000 characters are rejected. Failed sends preserve the draft.

Incoming avatars open the existing player profile with Report and Block actions.
Lobby avatars and direct-chat/inbox avatars open player profiles too.
Blocking hides that player's messages locally in your party conversation; it does
not remove either player from the squad or hide messages from other squad members.
The existing direct-message block protections remain in effect.

Party text lives in parties/{partyId}/messages/{messageId}. The sender identity and
profile name are validated by Firestore. Messages cannot be edited or deleted.
Only active members of an open party can access this chat; leaving, removal, or
ending the session removes access. Browsing a public party is not membership.
Existing party creation, invitation, removal, and voice behavior is preserved.

## Try it

1. Deploy the updated rules from the project root:
   `firebase deploy --only firestore:rules`.
2. Restart the app on two devices with different signed-in accounts.
3. Join the same open party, then tap Chat in each lobby.
4. Send messages both ways. Tap an incoming avatar to report/block the player.
5. Block a player and return to party chat: their messages should be hidden.
6. Leave the party or remove the member: the old chat should no longer accept
   messages or display its conversation to that member.

This uses the existing Spark Firestore quota. No paid backend is required.
The [Cloudflare notification Worker](../tools/notification-worker/README.md) sends
FCM alerts for new party messages after the sending app saves them to Firestore.
Rebuild the Android app after updating notification configuration or tap routing.
Recipients must be current members who had joined when the message was sent; the
sender receives no self-notification. Closed parties, departed members, blocks,
and the account Chat messages preference are respected. Tapping opens the party
chat only after checking live membership. Historical messages are not replayed.
Party-chat unread badges are not included. Direct-message counts are unchanged.

## Checks

```
flutter test test/party_chat_test.dart test/chat_test.dart test/party_lobby_test.dart
firebase emulators:exec --only firestore --project demo-lurk-party-chat "node --test --test-concurrency=1 test/firestore/party_chat_rules.test.mjs test/firestore/party_lifecycle_rules.test.mjs test/firestore/party_removal_rules.test.mjs"
```
