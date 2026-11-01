import test from 'node:test';
import assert from 'node:assert/strict';
import worker, {notify, readBody} from './src/worker.mjs';
import {verifyUser, googleAccessToken, firestore, messaging} from './src/google.mjs';

const now = Date.now();
const time = value => ({toMillis: () => value});
const request = {kind: 'direct', conversationId: 'chat', messageId: 'message'};
function fixture(overrides = {}) {
  const docs = {
    'chats/chat/messages/message': {senderId: 'alice', type: 'text', text: 'private', createdAt: time(now)},
    'chats/chat': {type: 'direct', userIds: ['alice', 'bob']},
    'parties/squad/messages/message': {senderId: 'alice', type: 'text', createdAt: time(now)},
    'parties/squad': {status: 'open'},
    'parties/squad/members/alice': {joinedAt: time(now - 1000), leftAt: null},
    'parties/squad/members/bob': {joinedAt: time(now - 1000), leftAt: null},
    ...overrides,
  };
  const claims = new Set(), sent = [];
  const db = {
    get: async path => path.startsWith('notification_deliveries/') ? (claims.has(path.split('/')[1]) ? {} : undefined) : docs[path],
    devices: async () => [{platform: 'android', id: 'device-token-long-enough', token: 'device-token-long-enough'}],
    claim: async id => { if (claims.has(id)) return false; claims.add(id); return true; },
    remove: async () => {},
  };
  const push = {sendEachForMulticast: async payload => {
    sent.push(payload);
    return {successCount: 1, failureCount: 0, responses: [{success: true}]};
  }};
  return {db, push, sent, claims, docs};
}

test('saved direct message sends generic preview and concurrent retries claim once', async () => {
  const f = fixture();
  await Promise.all(Array.from({length: 3}, () => notify(request, 'alice', f.db, f.push, now)));
  assert.equal(f.sent.length, 1);
  assert.equal(f.sent[0].data.recipientId, 'bob');
  assert.ok(!JSON.stringify(f.sent).includes('private'));
  assert.equal((await notify(request, 'alice', f.db, f.push, now)).status, 'already_processed');
});
test('forged author, outsiders, missing and old messages cannot send', async () => {
  for (const [changes, uid] of [
    [{}, 'mallory'],
    [{'chats/chat': {type: 'direct', userIds: ['bob', 'carol']}}, 'alice'],
    [{'chats/chat/messages/message': undefined}, 'alice'],
    [{'chats/chat/messages/message': {senderId: 'alice', createdAt: time(now - 301000)}}, 'alice'],
  ]) {
    const f = fixture(changes);
    await assert.rejects(notify(request, uid, f.db, f.push, now));
    assert.equal(f.sent.length, 0); assert.equal(f.claims.size, 0);
  }
});
test('blocks in either direction and disabled preferences suppress notifications', async () => {
  for (const path of ['player_blocks/alice/blocked/bob', 'player_blocks/bob/blocked/alice', 'notification_preferences/bob']) {
    const f = fixture({[path]: path.includes('preferences') ? {messages: false} : {}});
    await notify(request, 'alice', f.db, f.push, now);
    assert.equal(f.sent.length, 0);
  }
});
test('invitation routing respects invitation preference', async () => {
  const f = fixture({'chats/chat/messages/message': {senderId: 'alice', type: 'party_invite', createdAt: time(now)}});
  await notify(request, 'alice', f.db, f.push, now);
  assert.equal(f.sent[0].data.type, 'party_invite');
  f.claims.clear(); f.sent.length = 0; f.docs['notification_preferences/bob'] = {invitations: false};
  await notify(request, 'alice', f.db, f.push, now); assert.equal(f.sent.length, 0);
});
test('party sends only the requested eligible member and rejects departed/new members or closed party', async () => {
  const body = {kind: 'party', conversationId: 'squad', messageId: 'message', recipientId: 'bob'};
  const f = fixture(); await notify(body, 'alice', f.db, f.push, now);
  assert.equal(f.sent.length, 1); assert.equal(f.sent[0].data.type, 'party_message');
  for (const changes of [
    {'parties/squad': {status: 'closed'}},
    {'parties/squad/members/bob': {joinedAt: time(now - 1000), leftAt: time(now)}},
    {'parties/squad/members/bob': {joinedAt: time(now + 1), leftAt: null}},
    {'parties/squad/members/alice': undefined},
  ]) {
    const rejected = fixture(changes);
    await assert.rejects(notify(body, 'alice', rejected.db, rejected.push, now));
    assert.equal(rejected.claims.size, 0);
  }
});
test('HTTP rejects missing auth, invalid paths, oversized bodies and missing secrets', async () => {
  const env = {FIREBASE_PROJECT_ID: 'lurk-mae', FIREBASE_SERVICE_ACCOUNT_JSON: '{}'};
  assert.equal((await worker.fetch(new Request('https://example.com/notify', {method: 'POST'}), env)).status, 401);
  assert.equal((await worker.fetch(new Request('https://example.com/notify'), env)).status, 405);
  assert.equal((await worker.fetch(new Request('https://example.com/notify', {method: 'POST'}), {})).status, 503);
  for (const body of [{...request, conversationId: '../chat'}, {...request, messageId: '..'}, {...request, padding: 'x'.repeat(2048)}]) {
    await assert.rejects(readBody(new Request('https://example.com/notify', {
      method: 'POST', headers: {'content-type': 'application/json'}, body: JSON.stringify(body),
    })));
  }
});
test('Firebase JWT verification checks signature, audience, issuer and expiry', async () => {
  const keys = await crypto.subtle.generateKey({name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256'}, true, ['sign', 'verify']);
  const jwk = {...await crypto.subtle.exportKey('jwk', keys.publicKey), kid: 'test-key'};
  const fetcher = async () => Response.json({keys: [jwk]});
  const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  const seconds = Math.floor(Date.now() / 1000);
  const base = {sub: 'alice', aud: 'lurk-mae', iss: 'https://securetoken.google.com/lurk-mae', iat: seconds - 1, auth_time: seconds - 2, exp: seconds + 3600};
  async function sign(claims) {
    const data = `${encode({alg: 'RS256', kid: 'test-key'})}.${encode(claims)}`;
    const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', keys.privateKey, new TextEncoder().encode(data));
    return `${data}.${Buffer.from(signature).toString('base64url')}`;
  }
  assert.equal(await verifyUser(await sign(base), 'lurk-mae', fetcher), 'alice');
  for (const changes of [{aud: 'other'}, {iss: 'other'}, {exp: seconds - 1}, {sub: '../alice'}]) {
    await assert.rejects(verifyUser(await sign({...base, ...changes}), 'lurk-mae', fetcher), error => error.status === 401);
  }
  const token = await sign(base);
  await assert.rejects(verifyUser(`${token.slice(0, token.lastIndexOf('.') + 1)}AAAA`, 'lurk-mae', fetcher));
});
test('Firestore REST claims are atomic, timestamp fields decode, and excessive devices reject', async () => {
  const db = firestore('lurk-mae', 'secret', async url => {
    if (url.includes('notification_deliveries?')) return new Response('{}', {status: 409});
    if (url.includes('/devices?')) return Response.json({documents: [], nextPageToken: 'more'});
    return Response.json({fields: {createdAt: {timestampValue: '2026-11-01T00:00:00Z'}, userIds: {arrayValue: {values: [{stringValue: 'alice'}]}}}});
  });
  assert.equal(await db.claim('claim'), false);
  assert.equal((await db.get('chats/chat')).createdAt.toMillis(), Date.parse('2026-11-01T00:00:00Z'));
  await assert.rejects(db.devices('bob'));
});
test('service-account OAuth assertion signs correctly and access tokens are reused', async () => {
  const keys = await crypto.subtle.generateKey({name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256'}, true, ['sign', 'verify']);
  const pem = `-----BEGIN PRIVATE KEY-----\n${Buffer.from(await crypto.subtle.exportKey('pkcs8', keys.privateKey)).toString('base64')}\n-----END PRIVATE KEY-----\n`;
  const env = {FIREBASE_PROJECT_ID: 'lurk-mae', FIREBASE_SERVICE_ACCOUNT_JSON: JSON.stringify({
    type: 'service_account', project_id: 'lurk-mae', client_email: 'test@lurk-mae.iam.gserviceaccount.com', private_key: pem,
  })};
  let calls = 0;
  const fetcher = async (url, options) => {
    calls++;
    assert.equal(url, 'https://oauth2.googleapis.com/token');
    const [header, body, signature] = options.body.get('assertion').split('.');
    const claims = JSON.parse(Buffer.from(body, 'base64url'));
    assert.equal(claims.iss, 'test@lurk-mae.iam.gserviceaccount.com');
    assert.equal(claims.aud, url);
    assert.ok(claims.scope.includes('auth/datastore'));
    assert.ok(claims.scope.includes('auth/firebase.messaging'));
    assert.equal(await crypto.subtle.verify('RSASSA-PKCS1-v1_5', keys.publicKey, Buffer.from(signature, 'base64url'), new TextEncoder().encode(`${header}.${body}`)), true);
    return Response.json({access_token: 'fake-access-token', expires_in: 3600});
  };
  assert.equal(await googleAccessToken(env, fetcher), 'fake-access-token');
  assert.equal(await googleAccessToken(env, fetcher), 'fake-access-token');
  assert.equal(calls, 1);
});
test('FCM REST translates Android fields and removes only explicitly unregistered tokens', async () => {
  const requests = [];
  const push = messaging('lurk-mae', 'secret', async (_url, options) => {
    requests.push(JSON.parse(options.body));
    return Response.json({error: {details: [{errorCode: 'UNREGISTERED'}]}}, {status: 404});
  });
  const f = fixture();
  const removed = []; f.db.remove = async path => removed.push(path);
  await notify(request, 'alice', f.db, push, now);
  assert.equal(requests[0].message.android.ttl, '3600s');
  assert.equal(requests[0].message.android.notification.channel_id, 'lurk_messages');
  assert.equal(removed.length, 1);
});
