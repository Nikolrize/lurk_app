# Lurk notifications on Cloudflare Workers Free

Sends notifications through authenticated HTTP requests after messages are
committed to Firestore. Supports direct messages, party invitations and party chat.
The Android receiving app continues using FCM and its existing notification routes.
No paid Cloudflare features, database bindings, Firebase Functions, or Blaze upgrade
are used. Keep Cloudflare on **Workers Free** and Firebase on **Spark**.

## What you need

- A free Cloudflare account (no payment card or billing subscription).
- Node.js 22 or newer.
- Your existing **lurk-mae Firebase service-account JSON file**, stored outside this
  repository. It needs Firestore read/write and FCM sending permissions.
  Never paste it into chat, Flutter assets or source control.
- After deployment, the public URL ending in `/notify`. This URL is safe to share.

## Deploy from PowerShell

From `tools/notification-worker`:

```powershell
npm install
npx wrangler login
npm run deploy
```

Choose only the Free plan. The initial deployment returns 503 until its secret is
installed. Upload the entire existing service-account file directly to the Worker:

```powershell
Get-Content -LiteralPath 'C:\Users\zycho\FirebaseSecrets\lurk-sender.json' -Raw | npx wrangler secret put FIREBASE_SERVICE_ACCOUNT_JSON
```

Replace that example with the actual path. This uploads to Cloudflare; it does not
print the private key or put it in the app. Alternatively add a secret named
`FIREBASE_SERVICE_ACCOUNT_JSON` in the Worker's Cloudflare dashboard, paste the
entire JSON file as its value, and deploy the update. Do not use a plaintext variable.
The project ID is already pinned to `lurk-mae` in the Worker configuration.

The app now defaults to this deployed endpoint, so normal `flutter run` and
`flutter build apk` commands use it without extra arguments:

```text
https://lurk-notifications.zychong1121.workers.dev/notify
```

`config/notification.json` also contains this public endpoint. To override the
default deployment, use:

```powershell
flutter run --dart-define=NOTIFICATION_WORKER_URL=https://lurk-notifications.YOUR-SUBDOMAIN.workers.dev/notify
```

Use the same `--dart-define` with `flutter build apk` for installed builds. Or put
the public URL in `config/notification.local.json` and use
`--dart-define-from-file=config/notification.local.json`.
For VS Code, add that argument to the Dart launch configuration's `toolArgs`.
Restart/rebuild the sending app after changing the URL. To disable cloud triggers,
explicitly pass `--dart-define=NOTIFICATION_WORKER_URL=`.

The Worker contains its own notification delivery logic and uses atomic Firestore
claims to suppress duplicate requests. No local notification process is required.

## Verify with two accounts

1. Rebuild the sending app with the Worker URL. Open the recipient's Android app,
   sign in, and allow notifications. Put that app in the background.
2. Send a direct message and a party invitation.
   Each should produce a generic push that opens the correct chat.
3. Join an open party with both accounts and send a party message. The other active
   member should receive it. Check that notification switches and blocks suppress
   pushes, and departed members receive none.
4. A POST to `/notify` without an Authorization header must return 401. A GET
   returns 405. A server missing its secret returns 503.
5. Check Cloudflare's invocation/CPU metrics and Firebase usage on the free plans.
   Actual free-plan CPU consumption and delivery must be checked on deployment;
   local tests do not establish Cloudflare's production CPU cost.

## Security and limits

- Verifies Firebase ID-token signatures, issuer, project audience and timestamps.
  The caller must be the saved message's author. Content and device tokens are
  loaded from Firestore; callers cannot choose notification text or arbitrary tokens.
- Requires direct-chat membership, or an open party with both sender and recipient
  currently active and joined before the message. Checks both-direction blocks and
  recipient preferences using the same sender logic as the laptop tool.
- Party fan-out uses one bounded invocation per recipient. Supports up to **16
  registered device documents per recipient**, rejecting larger accounts before
  claiming delivery. This keeps external calls below the Free plan's 50-subrequest
  limit, including invalid-token deletion. Remove stale registrations if exceeded.
- Workers Free allows 100,000 requests/day and 10 ms CPU per invocation. Network
  wait is not CPU time. Quota exhaustion stops requests; do not enable a paid plan.
  Firestore reads, device cleanup, and claim writes still consume Spark quotas.
- Requests accept only messages from the last five minutes. Each recipient/message
  has an atomic claim. Duplicate requests do not send again. Claims are retained.
- Delivery remains **at most once**. A crash/FCM failure after claiming can lose a
  push. FCM acceptance is not proof of delivery. A failed trigger never makes a
  committed chat message appear unsent. The client retries transport/5xx failures
  once; it has no persistent offline notification queue. If the sending app closes
  between saving and requesting delivery, that push can be missed.
- Firebase token verification does not check token revocation. Revoked tokens may
  remain valid until expiry. Valid users can consume quotas; this is a small project
  endpoint without dedicated per-user rate limiting or App Check enforcement.
- No secrets, message text, registration tokens or raw upstream errors are logged.
  The service-account secret is privileged: restrict Cloudflare account access.

## Local checks

```powershell
npm test
npx wrangler deploy --dry-run
```

References: [Workers Free limits](https://developers.cloudflare.com/workers/platform/limits/),
[Worker secrets](https://developers.cloudflare.com/workers/configuration/secrets/),
[FCM HTTP v1](https://firebase.google.com/docs/cloud-messaging/send/v1-api),
[Firebase ID tokens](https://firebase.google.com/docs/auth/admin/verify-id-tokens).
