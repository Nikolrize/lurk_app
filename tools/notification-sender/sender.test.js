const test = require('node:test');
const assert = require('node:assert/strict');
const {createSender} = require('./sender');

function fixture(options = {}) {
  const sent = [], removed = [], logs = [], claims = new Set();
  let claimCalls = 0;
  const token = 'registered-device-token-for-bob';
  const store = {
    preferences: async () => options.preferences ?? {},
    chat: async () => options.chat ?? {type: 'direct', userIds: ['alice', 'bob']},
    blocked: async (sender, recipient) => {
      assert.equal(sender, 'alice'); assert.equal(recipient, 'bob');
      return options.blocked ?? false;
    },
    devices: async () => options.devices ?? [{id: token, token, platform: 'android'}],
    claim: async id => { claimCalls++; if (claims.has(id)) return false; claims.add(id); return true; },
    removeDevice: async (uid, device) => removed.push({uid, device}),
  };
  const messaging = {sendEachForMulticast: async payload => {
    sent.push(payload);
    if (options.throwSend) throw new Error('network error');
    return {successCount: options.errorCode ? 0 : payload.tokens.length,
      failureCount: options.errorCode ? payload.tokens.length : 0,
      responses: payload.tokens.map(() => options.errorCode ? {error: {code: options.errorCode}} : {success: true})};
  }};
  const send = createSender({store, messaging, dryRun: options.dryRun, log: value => logs.push(value)});
  return {send, sent, removed, logs, claimCalls: () => claimCalls};
}
const message = {senderId: 'alice', type: 'text', text: 'private text'};

test('account preferences independently disable message and invitation pushes', async () => {
  const f = fixture({preferences: {messages: false, invitations: true}});
  await f.send('chat', 'one', message);
  assert.equal(f.sent.length, 0);
  await f.send('chat', 'two', {...message, type: 'party_invite'});
  assert.equal(f.sent.length, 1);
  const disabled = fixture({preferences: {invitations: false}});
  await disabled.send('chat', 'three', {...message, type: 'party_invite'});
  assert.equal(disabled.sent.length, 0);
});

test('new messages notify only the recipient and carry authenticated chat routing', async () => {
  const f = fixture(); await f.send('chat', 'one', message);
  assert.equal(f.sent.length, 1);
  assert.deepEqual(f.sent[0].data, {chatId: 'chat', messageId: 'one', recipientId: 'bob', type: 'text'});
  assert.equal(f.sent[0].android.notification.channelId, 'lurk_messages');
  assert.ok(!JSON.stringify(f.sent).includes('private text'));
});
test('party invitations get a distinct notification and open their chat', async () => {
  const f = fixture(); await f.send('chat', 'invite', {...message, type: 'party_invite', partyId: 'party'});
  assert.equal(f.sent[0].notification.title, 'New party invitation');
  assert.equal(f.sent[0].data.chatId, 'chat');
});
test('duplicate processing and concurrent callbacks send once', async () => {
  const f = fixture(); await Promise.all([f.send('chat', 'one', message), f.send('chat', 'one', message)]);
  assert.equal(f.sent.length, 1);
  await f.send('chat', 'two', message); assert.equal(f.sent.length, 2);
});
test('blocks prevent any claim or send', async () => {
  const f = fixture({blocked: true}); await f.send('chat', 'one', message);
  assert.equal(f.sent.length, 0); assert.equal(f.claimCalls(), 0);
});
test('unknown types and forged/non-direct participants cannot trigger sends', async () => {
  for (const chat of [{type: 'direct', userIds: ['bob', 'outsider']},
    {type: 'group', userIds: ['alice', 'bob']}, {type: 'direct', userIds: ['alice', 'alice']}]) {
    const f = fixture({chat}); await f.send('chat', 'one', message); assert.equal(f.sent.length, 0);
  }
  const f = fixture(); await f.send('chat', 'one', {...message, type: 'fake'});
  assert.equal(f.sent.length, 0);
});
test('dry run performs no FCM sends, claims, or deletions', async () => {
  const f = fixture({dryRun: true}); await f.send('chat', 'one', message);
  assert.equal(f.sent.length, 0); assert.equal(f.claimCalls(), 0); assert.equal(f.removed.length, 0);
  assert.match(f.logs[0], /DRY RUN/);
});
test('invalid tokens are removed but transient failures keep registration', async () => {
  for (const errorCode of ['messaging/registration-token-not-registered', 'messaging/server-unavailable']) {
    const f = fixture({errorCode}); await f.send('chat', 'one', message);
    assert.equal(f.removed.length, errorCode.includes('not-registered') ? 1 : 0);
  }
});
test('empty and malformed device registrations do not send or claim', async () => {
  for (const devices of [[], [{id: 'different', token: 'registered-device-token', platform: 'android'}]]) {
    const f = fixture({devices}); await f.send('chat', 'one', message);
    assert.equal(f.sent.length, 0); assert.equal(f.claimCalls(), 0);
  }
});
test('multicast batches stay within 500 tokens and cover all devices', async () => {
  const devices = Array.from({length: 501}, (_, i) => {
    const token = `registered-device-token-${i}`; return {id: token, token, platform: 'android'};
  });
  const f = fixture({devices}); await f.send('chat', 'one', message);
  assert.deepEqual(f.sent.map(payload => payload.tokens.length), [500, 1]);
});
test('ambiguous send failure is not retried to avoid duplicate pushes', async () => {
  const f = fixture({throwSend: true}); await assert.rejects(f.send('chat', 'one', message));
  await f.send('chat', 'one', message); assert.equal(f.sent.length, 1);
});
