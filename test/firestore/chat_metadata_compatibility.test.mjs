import {readFileSync} from 'node:fs';
import test from 'node:test';
import {assertFails, assertSucceeds, initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {doc, setDoc, serverTimestamp, writeBatch} from 'firebase/firestore';

test('legacy sender metadata must be refreshed when the other player replies or changes name', async () => {
  const env = await initializeTestEnvironment({projectId: 'demo-lurk-chat-metadata', firestore: {
    host: '127.0.0.1', port: 8080, rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
  }});
  try {
    await env.withSecurityRulesDisabled(async ctx => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'players/alice'), {username: 'Alice'});
      await setDoc(doc(db, 'players/bob'), {username: 'Bob'});
      await setDoc(doc(db, 'chats/legacy'), {
        type: 'direct', userIds: ['alice', 'bob'], participantUsernames: {alice: 'Alice', bob: 'Bob'},
        lastSenderId: 'alice', lastSenderUsername: 'Alice', lastMessageId: 'old', lastMessagePreview: 'Hello',
        createdAt: new Date(0), updatedAt: new Date(0),
      });
    });
    const bob = env.authenticatedContext('bob').firestore();
    const send = (id, names) => {
      const batch = writeBatch(bob);
      batch.set(doc(bob, `chats/legacy/messages/${id}`), {
        senderId: 'bob', text: 'Reply', type: 'text', createdAt: serverTimestamp(),
        ...(names ? {senderUsername: names.bob} : {}),
      });
      batch.update(doc(bob, 'chats/legacy'), {
        lastMessageId: id, lastMessagePreview: 'Reply', lastSenderId: 'bob', updatedAt: serverTimestamp(),
        ...(names ? {lastSenderUsername: names.bob, participantUsernames: names} : {}),
      });
      return batch.commit();
    };
    // Reproduce the merged batch implementation leaving Alice's name behind.
    await assertFails(send('stale-sender'));
    await assertSucceeds(send('fixed-sender', {alice: 'Alice', bob: 'Bob'}));
    await env.withSecurityRulesDisabled(ctx => setDoc(doc(ctx.firestore(), 'players/bob'), {username: 'Bob renamed'}));
    await assertFails(send('stale-profile'));
    await assertSucceeds(send('fixed-profile', {alice: 'Alice', bob: 'Bob renamed'}));
  } finally { await env.cleanup(); }
});
