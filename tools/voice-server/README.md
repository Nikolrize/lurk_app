# Lurk voice token server

Issues short-lived Agora tokens after verifying the user's Firebase ID token and active party membership. Audio is handled by Agora.

## Local development

Requires Node.js 22.9 or later.

From the project root:

```sh
cd tools/voice-server
npm ci
```

Create a local `.env` file:

```dotenv
AGORA_APP_ID=<app-id>
AGORA_APP_CERTIFICATE=<app-certificate>
FIREBASE_PROJECT_ID=lurk-mae
PORT=8787
```

Keep the certificate on the server and do not commit `.env`.

```sh
npm start
```

To connect Flutter to this server, launch from the project root with `flutter run --dart-define=VOICE_TOKEN_URL=http://<computer-ip>:8787/voice/token`. The device must be able to reach that address. Release builds require HTTPS.

## API

| Endpoint            | Description                                                  |
| ------------------- | ------------------------------------------------------------ |
| `GET /health`       | Server readiness check.                                      |
| `POST /voice/token` | Returns a 120-second Agora token for an active party member. |

Token requests require an `Authorization: Bearer <firebase-id-token>` header and a JSON body containing `partyId`.

## Deployment

`render.yaml` defines the Render service. Set the Agora credentials in the service environment. The Flutter app uses the hosted endpoint configured in `config/voice.json`; running the local server is optional. The first connection may take longer while the hosted service starts.

## Tests

From `tools/voice-server`:

```sh
npm test
```
