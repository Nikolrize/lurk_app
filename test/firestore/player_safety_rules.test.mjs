import { readFileSync } from 'node:fs';
import test from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, deleteDoc, serverTimestamp, writeBatch } from 'firebase/firestore';
test('reports are private and blocks prevent messages in both directions', async () => {
  const env = await initializeTestEnvironment({projectId: 'demo-lurk-safety', firestore: {
    host: '127.0.0.1', port: 8080, rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8')}});
  try {
    await env.withSecurityRulesDisabled(async context => {
      for (const uid of ['alice', 'bob']) await setDoc(doc(context.firestore(), 'players/' + uid), {username: uid});
      await setDoc(doc(context.firestore(), 'chats/pair'), {type: 'direct', userIds: ['alice', 'bob'],
        createdAt: new Date(), updatedAt: new Date(), lastMessageId: '', lastMessagePreview: '', lastSenderId: ''});
    });
    const alice = env.authenticatedContext('alice').firestore();
    const bob = env.authenticatedContext('bob').firestore();
    const report = {reporterId: 'alice', playerId: 'bob', reporterUsername: 'alice', playerUsername: 'bob', reasons: ['Harassment', 'Cheating'], details: '', status: 'pending', createdAt: serverTimestamp()};
    await assertSucceeds(setDoc(doc(alice, 'player_reports/valid'), report));
    await assertFails(getDoc(doc(bob, 'player_reports/valid')));
    await assertFails(getDoc(doc(alice, 'player_reports/valid')));
    for (const patch of [{reporterId: 'bob'}, {playerId: 'alice'}, {reasons: ['fake']}, {reasons: []}, {reasons: ['Cheating', 'Cheating']}, {reasons: 'Harassment'}, {reporterUsername: 'forged'}, {playerUsername: 'forged'}, {details: 'x'.repeat(2001)}, {status: 'resolved'}]) {
      await assertFails(setDoc(doc(alice, 'player_reports/invalid'), {...report, ...patch}));
    }
    await assertSucceeds(setDoc(doc(alice, 'player_reports/single'), {...report, reasons: ['Other']}));
    const block = doc(alice, 'player_blocks/alice/blocked/bob');
    await assertSucceeds(setDoc(block, {createdAt: serverTimestamp()}));
    await assertFails(getDoc(doc(bob, 'player_blocks/alice/blocked/bob')));
    await assertFails(deleteDoc(doc(bob, 'player_blocks/alice/blocked/bob')));
    await assertFails(setDoc(doc(alice, 'player_blocks/alice/blocked/alice'), {createdAt: serverTimestamp()}));
    const send = (db, sender, id) => {
      const batch = writeBatch(db);
      batch.set(doc(db, 'chats/pair/messages/' + id), {senderId: sender, text: 'Hello', type: 'text', createdAt: serverTimestamp()});
      batch.update(doc(db, 'chats/pair'), {lastMessageId: id, lastMessagePreview: 'Hello', lastSenderId: sender, updatedAt: serverTimestamp()});
      return batch.commit();
    };
    await assertFails(send(alice, 'alice', 'blocked-a'));
    await assertFails(send(bob, 'bob', 'blocked-b'));
    await assertSucceeds(deleteDoc(block));
    await assertSucceeds(send(bob, 'bob', 'unblocked'));
  } finally { await env.cleanup(); }
});

