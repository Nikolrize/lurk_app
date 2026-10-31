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
  const deliver = createDelivery({store, messaging, dryRun, log});
  return async function processMessage(chatId, messageId, message) {
    if (!['text', 'party_invite'].includes(message.type)) return;
    const chat = await store.chat(chatId);
    const ids = chat?.userIds;
    if (chat?.type !== 'direct' || !Array.isArray(ids) || ids.length !== 2 ||
        ids.some(id => typeof id !== 'string' || !id || id.includes('/')) ||
        new Set(ids).size !== 2 || !ids.includes(message.senderId)) return;
    const recipientId = ids.find(id => id !== message.senderId);
    await deliver(message, recipientId, payloadFor(chatId, messageId, message, recipientId), [chatId, messageId, recipientId]);
  };
}
function createDelivery({store, messaging, dryRun, log}) {
  return async (message, recipientId, payload, claimKey) => {
    const preferences = await store.preferences(recipientId);
    if (preferences[message.type === 'party_invite' ? 'invitations' : 'messages'] === false) return;
    if (await store.blocked(message.senderId, recipientId)) return;
    const devices = (await store.devices(recipientId)).filter(device =>
      device.platform === 'android' && typeof device.token === 'string' &&
      device.token === device.id && device.token.length >= 20);
    if (!devices.length) { log('No registered Android devices; notification skipped.'); return; }
    if (dryRun) { log(`DRY RUN: ${payload.data.type}, ${devices.length} device(s); nothing sent or written.`); return; }
    const claimId = createHash('sha256').update(JSON.stringify(claimKey)).digest('hex');
    if (!await store.claim(claimId)) return;
    for (let offset = 0; offset < devices.length; offset += 500) {
      const batch = devices.slice(offset, offset + 500);
      const result = await messaging.sendEachForMulticast({
        ...payload, tokens: batch.map(device => device.token),
      });
      for (const [index, response] of result.responses.entries()) {
        const code = response.error?.code;
        if (['messaging/registration-token-not-registered', 'messaging/invalid-registration-token'].includes(code)) {
          await store.removeDevice(recipientId, batch[index]);
        } else if (code) {
          log(`FCM send failed: ${code}. This attempt will not be retried.`);
        }
      }
      log(`Sent ${payload.data.type}: ${result.successCount} delivered to FCM, ${result.failureCount} failed.`);
    }
  };
}

function createPartySender({store, messaging, dryRun = false, log = console.log}) {
  const deliver = createDelivery({store, messaging, dryRun, log});
  return async (partyId, messageId, message) => {
    if (message.type !== 'text' || typeof message.senderId !== 'string') return;
    const party = await store.party(partyId);
    if (party?.status !== 'open') return;
    const members = await store.partyMembers(partyId);
    const active = members.filter(member => member.leftAt == null && member.joinedAt &&
      message.createdAt && member.joinedAt.toMillis() <= message.createdAt.toMillis());
    if (!active.some(member => member.id === message.senderId)) return;
    for (const member of active) {
      if (member.id === message.senderId) continue;
      try {
        const payload = {
          notification: {title: 'New party message', body: 'Open Lurk to read your squad’s message.'},
          data: {type: 'party_message', partyId, messageId, recipientId: member.id},
          android: {priority: 'high', ttl: 60 * 60 * 1000,
            notification: {channelId: 'lurk_messages', icon: 'ic_notification', tag: 'party_' + partyId + '_' + messageId}},
        };
        await deliver(message, member.id, payload, ['party', partyId, messageId, member.id]);
      } catch (error) {
        log('Party notification attempt failed (' + (error.code || 'unknown') + ').');
      }
    }
  };
}
module.exports = {createSender, createPartySender, payloadFor};
