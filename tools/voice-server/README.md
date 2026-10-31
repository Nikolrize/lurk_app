# Party voice

Agora carries audio; Firestore stores party membership. The token server is hosted on Render Free, so the app can connect from any internet connection and Firebase can remain on Spark.

## Normal app launch

1. Run `flutter run` or select **Lurk** in VS Code. No local Node server or extra voice flags are needed.
2. The shared public settings in `config/voice.json` use `https://lurk-voice-token.onrender.com/voice/token`.
3. Sign in, join a party, and voice connects automatically with your microphone muted. Tap **Mic: OFF** to unmute and grant microphone permission. Test with two different accounts and headphones.

Settings precedence is: explicit `--dart-define` values, then optional `config/voice.local.json`, then the shared `config/voice.json`. The local file is ignored by Git; a lecturer's fresh checkout uses the shared settings. Commit and push the shared configuration and startup-loader changes before distributing the project.

Render Free sleeps after 15 minutes without requests. The first voice connection can take about a minute while the server wakes. Lurk waits up to 90 seconds for the initial health check; token requests and renewals use a separate 15-second timeout. Warmup does not send Firebase credentials.

## Voice behavior

- Lobby entry connects voice as a listener. Microphone capture stays disabled until the player unmutes and grants permission.
- Mic toggles publishing and local capture. Muting keeps incoming squad audio connected.
- Players leave voice by leaving the party. **Join voice** is available after a connection failure.
- Membership listeners disconnect on removal, leaving, sign-out, or session end.
- This version is foreground-only: backgrounding Lurk disconnects voice. Background voice needs an Android foreground service. iOS has not been device-tested.
- The server verifies Firebase ID tokens and active membership before issuing/renewing 120-second Agora tokens. Modified clients are not immediately revoked through Agora's REST API; already-issued tokens expire after their short lifetime.
- Release builds require an HTTPS token endpoint. HTTP is allowed only for Android debug.

## Server management

Render dashboard: https://dashboard.render.com/web/srv-dbj0m4ec6qcc73b54olg

See RENDER.md for deploy settings. Render runs the server from nicole_branch using `npm ci --prefix tools/voice-server --omit=dev` and `node tools/voice-server/server.mjs`. Pushes to that branch deploy automatically. Only the Node server runs on Render; Flutter builds and Firestore rules are not deployed by this service.

The App Certificate is stored in Render's private environment settings. Keep it out of Flutter, Git, Firestore and screenshots. Only public client settings belong in config/, because Flutter bundles that directory.

## Optional local development

To test a local server, set its private `.env` values and run `npm start --prefix tools/voice-server` (Node 22.9+). Set `config/voice.local.json` to `http://COMPUTER_IP:8787/voice/token`, then fully restart Flutter. This local mode requires devices to reach that PC. Remove the override or change it back to the hosted URL when finished.

## Checks

`npm test --prefix tools/voice-server`

`flutter test --no-pub`

## Leaving on logout

Logging out leaves the current party before Firebase signs the user out. If the user is the host, the session ends; a regular member leaves while the party stays open. If leaving fails, the user stays signed in and can retry. This runs in the Flutter app and does not depend on the voice server. Closing or backgrounding the app keeps party membership; voice still disconnects when the app backgrounds. No Firebase service-account key is needed for logout.
