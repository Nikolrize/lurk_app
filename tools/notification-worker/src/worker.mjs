import {createHash} from 'node:crypto';
import {createSender, createPartySender} from './sender.mjs';
import {HttpError, verifyUser, googleAccessToken, firestore, messaging} from './google.mjs';

const cors = {
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'POST, OPTIONS',
  'access-control-allow-headers': 'Authorization, Content-Type',
  'cache-control': 'no-store',
};
const reply = (status, data) => Response.json(data, {status, headers: cors});
const validId = value => typeof value === 'string' && value.length > 0 && value.length <= 512 &&
  value !== '.' && value !== '..' && !/[\/\x00-\x1f]/.test(value);

export async function readBody(request) {
  if (!request.headers.get('content-type')?.startsWith('application/json')) throw new HttpError(415, 'Use JSON.');
  const reader = request.body?.getReader();
  if (!reader) throw new HttpError(400, 'Missing request.');
  const chunks = []; let size = 0;
  while (true) {
    const {done, value} = await reader.read();
    if (done) break;
    size += value.length;
    if (size > 2048) { await reader.cancel(); throw new HttpError(413, 'Request too large.'); }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size); let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  let body;
  try { body = JSON.parse(new TextDecoder().decode(bytes)); } catch { throw new HttpError(400, 'Invalid JSON.'); }
  if (!body || !['direct', 'party'].includes(body.kind) || !validId(body.conversationId) || !validId(body.messageId) ||
      (body.kind === 'party' && !validId(body.recipientId))) throw new HttpError(400, 'Invalid message reference.');
  return body;
}

export async function notify(body, uid, db, push, now = Date.now()) {
  const {kind, conversationId: id, messageId, recipientId} = body;
  const collection = kind === 'party' ? 'parties' : 'chats';
  // Never accept sender, text, device tokens or notification content from the caller.
  const message = await db.get(`${collection}/${id}/messages/${messageId}`);
  if (!message || message.senderId !== uid) throw new HttpError(403, 'Message unavailable.');
  const created = message.createdAt?.toMillis();
  if (!Number.isFinite(created) || now - created > 5 * 60 * 1000 || created > now + 30000) {
    throw new HttpError(409, 'Message is too old for push delivery.');
  }
  let recipients;
  let chat;
  let party;
  let members;
  if (kind === 'direct') {
    chat = await db.get(`chats/${id}`);
    if (chat?.type !== 'direct' || !Array.isArray(chat.userIds) || chat.userIds.length !== 2 ||
        !chat.userIds.every(validId) || new Set(chat.userIds).size !== 2 || !chat.userIds.includes(uid)) {
      throw new HttpError(403, 'Conversation unavailable.');
    }
    recipients = chat.userIds.filter(value => value !== uid);
  } else {
    party = await db.get(`parties/${id}`);
    members = await Promise.all([...new Set([uid, recipientId])].map(async memberId => ({
      ...await db.get(`parties/${id}/members/${memberId}`), id: memberId,
    })));
    const eligible = member => member.leftAt == null && member.joinedAt && member.joinedAt.toMillis() <= created;
    if (party?.status !== 'open' || recipientId === uid || !members.every(eligible)) {
      throw new HttpError(403, 'Party membership unavailable.');
    }
    recipients = [recipientId];
  }
  const claimKey = kind === 'party' ? ['party', id, messageId, recipientId] : [id, messageId, recipients[0]];
  const claimId = createHash('sha256').update(JSON.stringify(claimKey)).digest('hex');
  if (await db.get(`notification_deliveries/${claimId}`)) return {status: 'already_processed'};
  const store = {
    chat: async () => chat, party: async () => party, partyMembers: async () => members,
    preferences: async target => await db.get(`notification_preferences/${target}`) ?? {},
    blocked: async (author, target) => (await Promise.all([
      db.get(`player_blocks/${author}/blocked/${target}`), db.get(`player_blocks/${target}/blocked/${author}`),
    ])).some(Boolean),
    devices: uid => db.devices(uid),
    removeDevice: (target, device) => db.remove(`notification_users/${target}/devices/${device.id}`),
    claim: key => db.claim(key),
  };
  const options = {store, messaging: push, log: () => {}, throwOnError: true};
  const send = kind === 'party' ? createPartySender(options) : createSender(options);
  await send(id, messageId, message);
  return {status: 'processed'};
}

export default {
  async fetch(request, env) {
    if (new URL(request.url).pathname !== '/notify') return reply(404, {error: 'Not found.'});
    if (request.method === 'OPTIONS') return new Response(null, {status: 204, headers: cors});
    if (request.method !== 'POST') return reply(405, {error: 'Use POST.'});
    try {
      if (env.FIREBASE_PROJECT_ID !== 'lurk-mae' || !env.FIREBASE_SERVICE_ACCOUNT_JSON) {
        throw new HttpError(503, 'Notification server is not configured.');
      }
      const token = request.headers.get('authorization')?.match(/^Bearer (\S+)$/)?.[1];
      if (!token) throw new HttpError(401, 'Sign in again.');
      const body = await readBody(request);
      const uid = await verifyUser(token, env.FIREBASE_PROJECT_ID);
      const access = await googleAccessToken(env);
      return reply(200, await notify(body, uid, firestore(env.FIREBASE_PROJECT_ID, access), messaging(env.FIREBASE_PROJECT_ID, access)));
    } catch (error) {
      // Never return/log credentials, tokens, message contents or Google error bodies.
      return reply(error.status ?? 503, {error: error instanceof HttpError ? error.message : 'Notification attempt failed.'});
    }
  },
};
