// One-time migration for parties created before private history references existed.
// Uses the locally signed-in Firebase CLI account; never prints credentials.
const fs = require("node:fs");
const path = require("node:path");
const auth = require(
  path.join(process.env.APPDATA, "npm/node_modules/firebase-tools/lib/auth.js"),
);
const base =
  "https://firestore.googleapis.com/v1/projects/lurk-mae/databases/(default)/documents/";
(async () => {
  const account = auth.getGlobalDefaultAccount();
  if (!account) throw Error("Sign in with firebase login first.");
  const token = await auth.getAccessToken(account.tokens.refresh_token, []);
  const headers = {
    Authorization: "Bearer " + token.access_token,
    "Content-Type": "application/json",
  };
  const apply = process.argv.includes("--apply");
  async function list(collection) {
    const docs = [];
    let page;
    do {
      const url =
        base +
        collection +
        "?pageSize=100" +
        (page ? "&pageToken=" + encodeURIComponent(page) : "");
      const response = await fetch(url, { headers });
      if (!response.ok)
        throw Error("Cannot list collection: HTTP " + response.status);
      const body = await response.json();
      docs.push(...(body.documents || []));
      page = body.nextPageToken;
    } while (page);
    return docs;
  }
  const parties = await list("parties");
  let missing = 0,
    created = 0,
    existing = 0,
    skipped = 0;
  for (const party of parties) {
    const id = party.name.split("/").at(-1),
      data = party.fields || {};
    const members = await list(
      "parties/" + encodeURIComponent(id) + "/members",
    );
    for (const member of members) {
      const uid = member.name.split("/").at(-1),
        joinedAt = member.fields?.joinedAt;
      if (
        !joinedAt?.timestampValue ||
        !data.title?.stringValue ||
        !data.gameId?.stringValue ||
        !data.mode?.stringValue
      ) {
        skipped++;
        continue;
      }
      const collection =
        "players/" + encodeURIComponent(uid) + "/party_history";
      const check = await fetch(
        base + collection + "/" + encodeURIComponent(id),
        { headers },
      );
      if (check.ok) {
        existing++;
        continue;
      }
      if (check.status !== 404)
        throw Error("Cannot check existing history: HTTP " + check.status);
      missing++;
      if (apply) {
        const response = await fetch(
          base + collection + "?documentId=" + encodeURIComponent(id),
          {
            method: "POST",
            headers,
            body: JSON.stringify({
              fields: {
                title: data.title,
                gameId: data.gameId,
                mode: data.mode,
                joinedAt,
              },
            }),
          },
        );
        if (response.status === 409) {
          existing++;
          continue;
        }
        if (!response.ok)
          throw Error("Cannot create history: HTTP " + response.status);
        created++;
      }
    }
  }
  console.log(
    JSON.stringify({
      project: "lurk-mae",
      mode: apply ? "apply" : "preview",
      parties: parties.length,
      missing,
      created,
      existing,
      skipped,
    }),
  );
})().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
