import test from 'node:test';
import assert from 'node:assert/strict';
import {createPartySender} from './src/sender.mjs';
const time = ms => ({toMillis: () => ms});
const member = (id, extra = {}) => ({id, leftAt: null, joinedAt: time(100), ...extra});
const message = {senderId: 'alice', type: 'text', text: 'secret message', createdAt: time(200)};
function fixture(options = {}) {
  const sent = [], claims = new Set(), removed = [];
  const store = {
    party: async () => ({status: options.status ?? 'open'}),
    partyMembers: async () => options.members ?? [member('alice'), member('bob'), member('carol')],
    preferences: async uid => options.muted === uid ? {messages: false} : {},
    blocked: async (_, uid) => options.blocked === uid,
    devices: async uid => {
      const token = 'registered-device-token-' + uid;
      return [{id: token, token, platform: 'android'}];
    },
    removeDevice: async uid => removed.push(uid),
    claim: async id => { if (claims.has(id)) return false; claims.add(id); return true; },
  };
  const messaging = {sendEachForMulticast: async payload => {
    sent.push(payload);
    if (options.fail === payload.data.recipientId) throw new Error('network');
    return {successCount: 1, failureCount: 0, responses: [{success: true}]};
  }};
  return {sent, claims, removed, send: createPartySender({store, messaging, dryRun: options.dryRun, log: () => {}})};
}
test('party sends to other active members with party-specific routing and private previews', async () => {
  const f = fixture(); await f.send('squad', 'one', message);
  assert.deepEqual(f.sent.map(m => m.data.recipientId), ['bob', 'carol']);
  assert.equal(f.sent[0].data.type, 'party_message'); assert.equal(f.sent[0].data.partyId, 'squad');
  assert.equal(f.sent[0].data.chatId, undefined);
  assert.equal(f.sent[0].notification.title, 'New party message');
  assert.ok(!JSON.stringify(f.sent).includes('secret message'));
});
test('left, removed and newly joined recipients are excluded', async () => {
  const f = fixture({members: [member('alice'), member('bob'), member('left', {leftAt: time(150)}), member('new', {joinedAt: time(300)})]});
  await f.send('squad', 'one', message); assert.deepEqual(f.sent.map(m => m.data.recipientId), ['bob']);
});
test('closed parties and authors without current membership cannot send', async () => {
  for (const options of [{status: 'closed'}, {members: [member('bob')]}, {members: [member('alice', {leftAt: time(150)}), member('bob')]}]) {
    const f = fixture(options); await f.send('squad', 'one', message); assert.equal(f.sent.length, 0);
  }
});
test('account mute and blocks are checked independently per recipient', async () => {
  for (const options of [{muted: 'bob'}, {blocked: 'bob'}]) {
    const f = fixture(options); await f.send('squad', 'one', message);
    assert.deepEqual(f.sent.map(m => m.data.recipientId), ['carol']);
  }
});
test('duplicate callbacks send once per recipient; dry runs make no claims', async () => {
  const f = fixture(); await f.send('squad', 'one', message); await f.send('squad', 'one', message);
  assert.equal(f.sent.length, 2);
  const dry = fixture({dryRun: true}); await dry.send('squad', 'one', message);
  assert.equal(dry.sent.length, 0); assert.equal(dry.claims.size, 0);
});
test('one recipient failure does not prevent other squad notifications', async () => {
  const f = fixture({fail: 'bob'}); await f.send('squad', 'one', message);
  assert.deepEqual(f.sent.map(m => m.data.recipientId), ['bob', 'carol']);
});
