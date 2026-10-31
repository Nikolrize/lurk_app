const {createHash} = require('node:crypto');

function payloadFor(chatId, messageId, message, recipientId) {
  const invitation = message.type === 'party_invite';
  return {
    notification: {
      title: invitation ? 'New party invitation' : 'New message',
      body: invitation ? 'Open Lurk to view your invitation.' : 'Open Lurk to read your message.',
    },
    data: {type: message.type, chatId, messageId, recipientId},
    android: {
      priority: 'high', ttl: 60 * 60 * 1000,
      notification: {channelId: 'lurk_messages', icon: 'ic_notification', tag: `${chatId}_${messageId}`},
    },
  };
}

function createSender({store, messaging, dryRun = false, log = console.log}) {
  return async function processMessage(chatId, messageId, message) {
    if (!['text', 'party_invite'].includes(message.type)) return;
    const chat = await store.chat(chatId);
    const ids = chat?.userIds;
    if (chat?.type !== 'direct' || !Array.isArray(ids) || ids.length !== 2 ||
        ids.some(id => typeof id !== 'string' || !id || id.includes('/')) ||
        new Set(ids).size !== 2 || !ids.includes(message.senderId)) return;
    const recipientId = ids.find(id => id !== message.senderId);
    const preferences = await store.preferences(recipientId);
    if (preferences[message.type === 'party_invite' ? 'invitations' : 'messages'] === false) return;
    if (await store.blocked(message.senderId, recipientId)) return;
    const devices = (await store.devices(recipientId)).filter(device =>
      device.platform === 'android' && typeof device.token === 'string' &&
      device.token === device.id && device.token.length >= 20);
    if (!devices.length) { log('No registered Android devices; notification skipped.'); return; }
    if (dryRun) { log(`DRY RUN: ${message.type}, ${devices.length} device(s); nothing sent or written.`); return; }
    const claimId = createHash('sha256').update(JSON.stringify([chatId, messageId, recipientId])).digest('hex');
    if (!await store.claim(claimId)) return;
    for (let offset = 0; offset < devices.length; offset += 500) {
      const batch = devices.slice(offset, offset + 500);
      const result = await messaging.sendEachForMulticast({
        ...payloadFor(chatId, messageId, message, recipientId), tokens: batch.map(device => device.token),
      });
      for (const [index, response] of result.responses.entries()) {
        const code = response.error?.code;
        if (['messaging/registration-token-not-registered', 'messaging/invalid-registration-token'].includes(code)) {
          await store.removeDevice(recipientId, batch[index]);
        } else if (code) {
          log(`FCM send failed: ${code}. This attempt will not be retried.`);
        }
      }
      log(`Sent ${message.type}: ${result.successCount} delivered to FCM, ${result.failureCount} failed.`);
    }
  };
}
module.exports = {createSender, payloadFor};
