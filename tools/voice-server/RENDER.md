# Render deployment

Use a **Free Web Service** in Singapore. The server is already in the repository at tools/voice-server.

## Dashboard settings

- Repository: https://github.com/Nikolrize/lurk_app
- Branch: nicole_branch (must contain the deployed server code)
- Runtime: Node
- Root directory: tools/voice-server
- Build command: npm ci --omit=dev
- Start command: npm start
- Health check: /health
- Instance type: Free

When deploying through an API that cannot set a root directory, use these equivalent commands from the repository root:

- Build: npm ci --prefix tools/voice-server --omit=dev
- Start: node tools/voice-server/server.mjs

Set these environment variables in Render:

- NODE_VERSION=22
- NODE_ENV=production
- FIREBASE_PROJECT_ID=lurk-mae
- AGORA_APP_ID=8e12f857aa6641dc894b3a7b241d0b21
- AGORA_APP_CERTIFICATE: the private certificate from the local server .env

Do not commit the certificate or place it in a Flutter configuration file. Firebase service-account credentials are not required: the token server checks Firebase ID tokens and verifies membership through Firestore using the user's permissions.

## App configuration

Once deployment succeeds, verify https://lurk-voice-token.onrender.com/health returns {"ready":true}.
Put https://lurk-voice-token.onrender.com/voice/token into config/voice.json under VOICE_TOKEN_URL. This shared file is committed so a lecturer's fresh checkout works with plain flutter run. config/voice.local.json remains an optional, ignored per-computer override; remove or update its old local URL when switching to Render. Command-line values override both files.

The first connection waits up to 90 seconds for /health while Render Free wakes up. Authenticated token requests and token renewals have a separate 15-second timeout. Warmup does not send the user's Firebase token. Membership is rechecked before each short-lived Agora token is issued. Signing out or changing account during startup cancels the attempt.

Render Free services sleep after 15 minutes without incoming traffic; waking can take about a minute. No paid plan, database, or persistent disk is needed. While a party is connected, normal token-renewal traffic reaches this service; no artificial keep-alive service is configured.

Official references: https://render.com/docs/free and https://render.com/docs/web-services