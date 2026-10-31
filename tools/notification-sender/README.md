# Lurk laptop notification sender (Spark)

Runs on your own laptop. No Cloud Functions, deployment, public endpoint, Blaze,
or paid hosting is involved. Keep the laptop awake, online, and this process running.
Both phones need internet access; they do not need the laptop's Wi-Fi network.
FCM is no-cost; Firestore reads/writes count against your existing Spark quotas.

## One-time setup

1. Install Node.js 22 or newer.
2. In Firebase Console, select **lurk-mae**, then **Project settings > Service accounts >
   Firebase Admin SDK > Generate new private key**. Save the downloaded JSON outside
   this repository, for example `C:\Users\zycho\FirebaseSecrets\lurk-sender.json`.
   Do not upload/paste the key into chat, commit it, or add it to Flutter assets.
   This is a privileged server credential; only run this tool on your own computer.
3. In PowerShell at the project root:

```powershell
cd tools/notification-sender
npm ci
$env:GOOGLE_APPLICATION_CREDENTIALS = 'C:\Users\zycho\FirebaseSecrets\lurk-sender.json'
npm start
```

Replace the credential path with your real downloaded file. Set the environment
variable again in a new terminal. The sender is pinned to project `lurk-mae`.
It should print **Lurk laptop sender ready (LIVE, project lurk-mae)**.
Stop it with **Ctrl+C**.

No Firebase deployment is needed for this sender. Existing device-token rules must
already be deployed so each phone can register. The Admin SDK uses IAM permissions,
not mobile-client Firestore rules. Do not loosen Firestore rules for the sender.

## Test with two accounts

1. On recipient B's Android phone, sign in, allow notification permission, and
   keep the relevant switches enabled under **Profile > Settings**.
2. Start the sender and wait for its ready message.
3. Put B's app in the background with the Home button (do not force-stop it).
4. From account A on another device, send B a new chat message. B should receive
   **New message**. Tap it to open that conversation.
5. Send a party invitation through the chat. B should receive **New party invitation**;
   tapping opens the chat containing the invitation card.
6. With B's app open, repeat to check its foreground banner.

For a read-only test, run `npm run dry-run` instead of `npm start`, then send new
messages. Dry run reports eligible devices but does not send FCM, create claims,
or delete tokens. Messages tested in dry run are not replayed when live mode starts.

## Behavior and limits

- Starts with server time and processes messages committed after startup. Messages
  sent while the sender was stopped are not pushed when it restarts. Chat history
  remains available normally in Lurk.
- Watches recently updated chats and reads new messages in ordered pages. This
  avoids loading historical messages or requiring a collection-group index.
- Checks direct-chat membership, supported message type, and blocks in both directions.
  The current app has no mute preference; none is inferred.
- Sends to the recipient's registered Android devices, never the author's devices.
  Lock-screen previews contain generic text, not private message content.
- Writes one deterministic claim per message/recipient in `notification_deliveries`.
  Claims suppress duplicates across callbacks, reconnects, and multiple sender copies.
  Mobile clients cannot read or write these claims under existing default-deny rules.
- Sending is at-most-once: a crash or network error after a claim may lose that push.
  Failed attempts are logged and not automatically retried. FCM acceptance does not
  guarantee delivery. Firestore chat history remains the source of truth.
- Claims remain stored. For an assignment this is small; monitor Spark storage and
  read/write quotas before extended use. No paid retention feature is configured.
- Invalid tokens are removed; transient errors retain device registration.
- Listener errors print a code and stop. Check connectivity/permissions and restart.
- No secrets, registration tokens, or message text are printed by the sender.

If registration is missing, reopen Lurk and sign in on B to register again. If startup fails, verify
the credential file, its project/IAM access, and that the Firebase Cloud Messaging
API is enabled in the project. If the phone misses a push, check notification
permission, battery restrictions, and the sender terminal. Firebase Console delivery
working is a useful first check. Never enable billing just to troubleshoot this tool.

## Local checks

```powershell
npm test
npm audit
```

The watcher integration test runs only with a Firestore emulator. From the project
root, with Java available:

```powershell
firebase emulators:exec --only firestore --project demo-lurk-sender "node --test tools/notification-sender/watcher.test.js"
```

This test verifies that old history is skipped and a burst of 105 messages with
identical timestamps is processed completely across query pages.

References: [Admin SDK setup](https://firebase.google.com/docs/admin/setup),
[Firestore listeners](https://firebase.google.com/docs/firestore/query-data/listen),
[FCM sending](https://firebase.google.com/docs/cloud-messaging/send/admin-sdk).
