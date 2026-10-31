import http from "node:http";
import { createHash } from "node:crypto";
import { pathToFileURL } from "node:url";
import { initializeApp, getApps } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import agora from "agora-token";

export function createHandler({
  verifyToken,
  readDocument,
  issueToken,
  appId,
}) {
  const attempts = new Map();
  return async (req, res) => {
    const respond = (status, body) => {
      res.writeHead(status, {
        "Content-Type": "application/json",
        "Cache-Control": "no-store",
      });
      res.end(JSON.stringify(body));
    };
    if (req.url === "/health" && req.method === "GET")
      return respond(200, { ready: true });
    if (req.url !== "/voice/token" || req.method !== "POST")
      return respond(404, { error: "Not found" });
    const authorization = req.headers.authorization || "";
    if (!authorization.startsWith("Bearer "))
      return respond(401, { error: "Sign in to use voice chat." });
    try {
      let raw = "";
      for await (const chunk of req) {
        raw += chunk;
        if (Buffer.byteLength(raw) > 4096)
          return respond(413, { error: "Request too large" });
      }
      let data;
      try {
        data = JSON.parse(raw);
      } catch {
        return respond(400, { error: "Invalid request" });
      }
      if (
        !data ||
        Object.keys(data).some((key) => key !== "partyId") ||
        typeof data.partyId !== "string" ||
        !/^[A-Za-z0-9_-]{1,128}$/.test(data.partyId)
      )
        return respond(400, { error: "Choose a valid party." });
      let user;
      try {
        user = await verifyToken(authorization.slice(7));
      } catch {
        return respond(401, { error: "Sign in again to use voice chat." });
      }
      const uid = user.uid;
      const now = Date.now();
      for (const [key, value] of attempts)
        if (now - value.start > 60000) attempts.delete(key);
      const attempt = attempts.get(uid) || { start: now, count: 0 };
      attempt.count++;
      attempts.set(uid, attempt);
      if (attempt.count > 20)
        return respond(429, { error: "Please wait before reconnecting." });
      const [party, member] = await Promise.all([
        readDocument("parties/" + data.partyId, authorization.slice(7)),
        readDocument(
          "parties/" + data.partyId + "/members/" + uid,
          authorization.slice(7),
        ),
      ]);
      if (
        !party ||
        party.status !== "open" ||
        !member ||
        member.leftAt !== null ||
        !["host", "member"].includes(member.role)
      )
        return respond(403, {
          error: "Only active party members can use voice chat.",
        });
      const channel =
        "party_" +
        createHash("sha256").update(data.partyId).digest("hex").slice(0, 40);
      const expiresIn = 120;
      const token = issueToken(channel, uid, expiresIn);
      respond(200, { appId, channel, account: uid, token, expiresIn });
    } catch {
      return respond(503, {
        error: "Cannot verify party access. Please try again.",
      });
    }
  };
}

async function firestoreDocument(project, path, idToken) {
  const url =
    "https://firestore.googleapis.com/v1/projects/" +
    encodeURIComponent(project) +
    "/databases/(default)/documents/" +
    path.split("/").map(encodeURIComponent).join("/");
  const response = await fetch(url, {
    headers: { Authorization: "Bearer " + idToken },
    signal: AbortSignal.timeout(8000),
  });
  if ([403, 404].includes(response.status)) return null;
  if (!response.ok) throw Error("Firestore unavailable");
  const { fields = {} } = await response.json();
  return Object.fromEntries(
    Object.entries(fields).map(([key, value]) => [
      key,
      "nullValue" in value
        ? null
        : (value.stringValue ??
          value.timestampValue ??
          value.integerValue ??
          value.booleanValue),
    ]),
  );
}

if (
  process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href
) {
  const appId = process.env.AGORA_APP_ID || "",
    certificate = process.env.AGORA_APP_CERTIFICATE || "";
  const project = process.env.FIREBASE_PROJECT_ID || "lurk-mae";
  if (!/^[a-f0-9]{32}$/i.test(appId) || !/^[a-f0-9]{32}$/i.test(certificate)) {
    console.error(
      "Set a valid Agora App ID and App Certificate in the local .env file.",
    );
    process.exit(1);
  }
  const app = getApps()[0] || initializeApp({ projectId: project });
  const handler = createHandler({
    appId,
    verifyToken: (token) => getAuth(app).verifyIdToken(token),
    readDocument: (path, token) => firestoreDocument(project, path, token),
    issueToken: (channel, uid, ttl) =>
      agora.RtcTokenBuilder.buildTokenWithUserAccount(
        appId,
        certificate,
        channel,
        uid,
        agora.RtcRole.PUBLISHER,
        ttl,
        ttl,
      ),
  });
  const server = http.createServer(
    { requestTimeout: 15000, headersTimeout: 10000 },
    handler,
  );
  server.listen(Number(process.env.PORT || 8787), "0.0.0.0", () =>
    console.log(
      "Lurk voice token server listening on port " + (process.env.PORT || 8787),
    ),
  );
}
