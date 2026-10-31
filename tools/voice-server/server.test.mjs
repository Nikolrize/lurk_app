import test from "node:test";
import assert from "node:assert/strict";
import http from "node:http";
import { createHandler } from "./server.mjs";
import agora from "agora-token";

test("token endpoint authenticates active membership and derives channel/account on the server", async () => {
  let active = true,
    open = true,
    issued = [];
  const server = http.createServer(
    createHandler({
      appId: "public-app-id",
      verifyToken: async (token) => {
        if (token !== "valid") throw Error("invalid");
        return { uid: "alice" };
      },
      readDocument: async (path, token) => {
        assert.equal(token, "valid");
        return path.endsWith("/members/alice")
          ? { role: "member", leftAt: active ? null : "removed" }
          : { status: open ? "open" : "closed" };
      },
      issueToken: (...args) => {
        issued = args;
        return "short-lived-token";
      },
    }),
  );
  await new Promise((resolve) => server.listen(0, "127.0.0.1", resolve));
  try {
    const url = "http://127.0.0.1:" + server.address().port + "/voice/token";
    const request = (body, token = "valid") =>
      fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(token ? { Authorization: "Bearer " + token } : {}),
        },
        body: JSON.stringify(body),
      });
    assert.equal((await request({ partyId: "squad" }, null)).status, 401);
    assert.equal((await request({ partyId: "squad" }, "invalid")).status, 401);
    assert.equal((await request({ partyId: "squad", uid: "bob" })).status, 400);
    assert.equal((await request({ partyId: "../private" })).status, 400);
    let response = await request({ partyId: "squad" });
    assert.equal(response.status, 200);
    const data = await response.json();
    assert.equal(data.account, "alice");
    assert.equal(data.expiresIn, 120);
    assert.match(data.channel, /^party_[a-f0-9]{40}$/);
    assert.deepEqual(issued, [data.channel, "alice", 120]);
    assert.equal("certificate" in data, false);
    active = false;
    assert.equal((await request({ partyId: "squad" })).status, 403);
    active = true;
    open = false;
    assert.equal((await request({ partyId: "squad" })).status, 403);
  } finally {
    server.closeAllConnections();
    await new Promise((resolve) => server.close(resolve));
  }
});

test("Agora builder generates a token without exposing its signing certificate", () => {
  const token = agora.RtcTokenBuilder.buildTokenWithUserAccount(
    "1".repeat(32),
    "2".repeat(32),
    "party_test",
    "alice",
    agora.RtcRole.PUBLISHER,
    120,
    120,
  );
  assert.match(token, /^007/);
  assert.ok(token.length > 80);
  assert.ok(!token.includes("2".repeat(32)));
});
