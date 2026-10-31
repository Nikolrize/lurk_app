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

test("Render startup works without a local .env file", async () => {
  const {spawn} = await import('node:child_process');
  const {mkdtemp, rmdir} = await import('node:fs/promises');
  const {tmpdir} = await import('node:os');
  const {join} = await import('node:path');
  const {fileURLToPath} = await import('node:url');
  const probe = http.createServer();
  await new Promise(resolve => probe.listen(0, '127.0.0.1', resolve));
  const port = probe.address().port;
  await new Promise(resolve => probe.close(resolve));
  const cwd = await mkdtemp(join(tmpdir(), 'lurk-render-test-'));
  const child = spawn(process.execPath, ['--env-file-if-exists=.env', fileURLToPath(new URL('./server.mjs', import.meta.url))], {
    cwd, env: {...process.env, AGORA_APP_ID: '1'.repeat(32), AGORA_APP_CERTIFICATE: '2'.repeat(32), FIREBASE_PROJECT_ID: 'demo-lurk-render', PORT: String(port)},
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  try {
    await new Promise((resolve, reject) => {
      const timeout = setTimeout(() => reject(Error('Test server startup timed out')), 10000);
      child.stdout.on('data', chunk => { if (chunk.toString().includes('listening')) {clearTimeout(timeout);resolve();} });
      child.once('error', error => {clearTimeout(timeout);reject(error);});
      child.once('exit', code => {clearTimeout(timeout);reject(Error('Test server exited: '+code));});
    });
    const response = await fetch('http://127.0.0.1:'+port+'/health');
    assert.equal(response.status, 200);
    assert.deepEqual(await response.json(), {ready:true});
  } finally {
    const stopped = new Promise(resolve => child.once('exit', resolve));
    if (child.exitCode === null) {child.kill();await stopped;}
    await rmdir(cwd);
  }
});