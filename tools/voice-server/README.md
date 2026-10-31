# Party voice (free local development)

Agora carries audio; Firestore stores parties, not audio. This Android-first implementation uses a local token server, so Firebase can remain on Spark. It does not deploy a paid cloud service.

## Start

1. Keep `tools/voice-server/.env` private. Set `AGORA_APP_CERTIFICATE` from your secure Agora RTC project. The App ID is public; the certificate is never compiled into Flutter. `.env` and the device configuration below are ignored by Git.
2. In the project directory run `npm start --prefix tools/voice-server` and keep it running. Node 22+ is required. Dependencies are installed with `npm ci --prefix tools/voice-server`.
3. Put the computer's Wi-Fi IPv4 address into `config/voice.local.json` (copy `config/voice.example.json` on another computer). The endpoint is `http://COMPUTER_IP:8787/voice/token`. Both devices must be able to reach it. If Windows asks about Node network access, use the private network you are testing on.
4. Stop the previous Flutter run. Select **Lurk (Wi-Fi voice)** in VS Code, choose your device, and start debugging. Alternatively: `flutter run --dart-define-from-file=config/voice.local.json -d DEVICE_ID`.
5. Sign in with two different accounts, join the same party, and tap **Mic: OFF** on both devices. Grant microphone permission when asked. Use headphones or separate rooms for the two-device audio test.

SDK changes require a full stop/start; hot reload alone cannot load a new native plugin. Enable Windows Developer Mode if Flutter reports that plugin symlinks cannot be created.

## Behavior

- Voice starts only after tapping Mic and granting permission; joining a party never starts recording automatically.
- Mic ON/OFF toggles publishing and local microphone capture. Muting leaves remote squad audio connected.
- **Party options → Leave voice chat** disconnects audio without leaving the squad.
- Firebase membership and party listeners disconnect the client on removal, leaving, sign-out, or session end.
- This first version is foreground-only: backgrounding Lurk disconnects voice. Voice while using another game app requires a separate Android foreground-service implementation. iOS has not been built or device-tested here.
- Short-lived tokens are renewed after rechecking Firebase membership. Expired credentials are not replaced if access is lost. This prototype does not implement Agora REST-side immediate revocation against a modified client; current tokens have a 120-second lifetime.
- Release builds refuse a cleartext token endpoint. An HTTPS-hosted token service is needed for use beyond local development. The HTTP allowance is Android-debug-only.
- Changing Wi-Fi/IP requires updating the local config and restarting the Flutter run. Keep Agora usage within your account's free participant-minute allowance.

## Checks

`npm test --prefix tools/voice-server`

`flutter test --no-pub`

The token server verifies Firebase ID tokens, derives the room/user identity on the server, and checks open-party status plus active membership using the same user's Firestore permissions. No Firebase service-account key is needed. Do not place the certificate in Flutter, Firestore, Git, or screenshots.