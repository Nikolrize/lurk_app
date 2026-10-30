import { readFileSync } from 'node:fs';
import test from 'node:test';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocs, query, where, setDoc, updateDoc, deleteDoc, serverTimestamp, writeBatch, Timestamp } from 'firebase/firestore';

test('direct chat privacy, sender identity, immutable history and atomic previews', async () => {
  const env = await initializeTestEnvironment({ projectId: 'demo-lurk-chat', firestore: {
    host: '127.0.0.1', port: 8080,
    rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8') } });
  try {
    await env.clearFirestore();
    await env.withSecurityRulesDisabled(async context => {
      for (const uid of ['alice', 'bob', 'eve']) await setDoc(doc(context.firestore(), `players/${uid}`), {username: uid});
      for (const [id, hostId, visibility, status] of [
        ['owned', 'alice', 'public', 'open'], ['other', 'bob', 'public', 'open'],
        ['private', 'alice', 'private', 'open'], ['ended', 'alice', 'public', 'completed']]) {
        await setDoc(doc(context.firestore(), `parties/${id}`), {hostId, visibility, status});
      }
    });
    const alice = env.authenticatedContext('alice').firestore();
    const bob = env.authenticatedContext('bob').firestore();
    const eve = env.authenticatedContext('eve').firestore();
    const guest = env.unauthenticatedContext().firestore();
    const path = 'chats/direct';
    const chat = db => doc(db, path);
    const fresh = {type: 'direct', userIds: ['alice', 'bob'], createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(), lastMessageId: '', lastMessagePreview: '', lastSenderId: ''};
    await assertSucceeds(getDoc(chat(alice)));
    await assertFails(setDoc(chat(eve), fresh));
    await assertFails(setDoc(chat(guest), fresh));
    await assertFails(setDoc(doc(alice, 'chats/forged-names'), {...fresh, participantUsernames: {alice: 'bob', bob: 'alice'}}));
    await assertSucceeds(setDoc(doc(alice, 'chats/named'), {...fresh, participantUsernames: {alice: 'alice', bob: 'bob'}}));
    await assertSucceeds(setDoc(chat(alice), fresh));
    await assertSucceeds(getDoc(chat(bob)));
    await assertFails(getDoc(chat(eve)));
    await assertFails(getDoc(chat(guest)));
    await assertSucceeds(getDocs(query(collection(alice, 'chats'), where('userIds', 'array-contains', 'alice'))));
    await assertFails(getDocs(collection(alice, 'chats')));
    await assertFails(updateDoc(chat(alice), {userIds: ['alice', 'eve']}));
    const send = (db, id, senderId = 'alice', text = 'Hello', extra = {}) => {
      const batch = writeBatch(db);
      batch.set(doc(db, `${path}/messages/${id}`), {senderId, text, createdAt: serverTimestamp(), ...extra});
      batch.update(chat(db), {lastMessageId: id, lastMessagePreview: text,
        lastSenderId: senderId, updatedAt: serverTimestamp()});
      return batch.commit();
    };
    await assertFails(send(eve, 'intrusion', 'eve'));
    await assertFails(send(alice, 'spoof', 'bob'));
    await assertFails(send(alice, 'empty', 'alice', '   '));
    await assertFails(send(alice, 'long', 'alice', 'x'.repeat(2001)));
    await assertFails(send(alice, 'forged-name', 'alice', 'Hello', {senderUsername: 'bob'}));
    await assertSucceeds(send(alice, 'named-message', 'alice', 'Hello', {senderUsername: 'alice'}));
    await assertSucceeds(send(alice, 'first'));
    await assertSucceeds(send(bob, 'reply', 'bob', 'Hi Alice'));
    await assertFails(send(alice, 'disabled-photo', 'alice', 'Photo', {type: 'image'}));
    await assertFails(send(alice, 'disabled-video', 'alice', 'Video', {type: 'video'}));
    await assertSucceeds(send(alice, 'typed', 'alice', 'Typed text', {type: 'text'}));
    for (const [index, text] of ['😀', '👍🏽', '👨‍👩‍👧‍👦', '🇲🇾', 'Ready 😀\nLet’s play 🎮', '你好 😀'].entries()) {
      await assertSucceeds(send(alice, `unicode-${index}`, 'alice', text, {type: 'text'}));
    }
    await assertSucceeds(send(alice, 'invite', 'alice', 'Party invitation', {type: 'party_invite', partyId: 'owned'}));
    for (const partyId of ['other', 'private', 'ended', 'missing']) {
      await assertFails(send(alice, `bad-${partyId}`, 'alice', 'Party invitation', {type: 'party_invite', partyId}));
    }
    await assertFails(send(alice, 'fake-label', 'alice', 'Trust me', {type: 'party_invite', partyId: 'owned'}));
    await assertFails(send(alice, 'unknown-type', 'alice', 'Hello', {type: 'admin'}));
    await assertFails(send(alice, 'text-with-party', 'alice', 'Hello', {type: 'text', partyId: 'owned'}));
    await assertSucceeds(getDocs(collection(bob, `${path}/messages`)));
    await assertFails(getDocs(collection(eve, `${path}/messages`)));
    await assertFails(setDoc(doc(alice, `${path}/messages/alone`), {senderId: 'alice', text: 'Hello', createdAt: serverTimestamp()}));
    await assertFails(updateDoc(doc(alice, `${path}/messages/first`), {text: 'Edited'}));
    await assertFails(deleteDoc(doc(alice, `${path}/messages/first`)));
    await assertFails(updateDoc(chat(alice), {lastMessagePreview: 'Fake', updatedAt: serverTimestamp()}));
    await assertFails(setDoc(doc(alice, `${path}/settings/bob`), {clearedAt: serverTimestamp()}));
    await assertFails(setDoc(doc(alice, `${path}/settings/alice`), {clearedAt: Timestamp.fromMillis(0)}));
    await assertSucceeds(setDoc(doc(alice, `${path}/settings/alice`), {clearedAt: serverTimestamp()}));
    const clearedAt = (await getDoc(doc(alice, `${path}/settings/alice`))).data().clearedAt;
    const visible = () => getDocs(query(collection(alice, `${path}/messages`), where('createdAt', '>', clearedAt)));
    if ((await visible()).size !== 0) throw new Error('Old messages remain after clear cutoff');
    await assertFails(getDoc(doc(bob, `${path}/settings/alice`)));
    await assertSucceeds(send(bob, 'after-clear', 'bob', 'A new message'));
    if ((await visible()).size !== 1) throw new Error('New messages must appear after clear');
    if ((await getDocs(collection(bob, `${path}/messages`))).size <= 1) throw new Error('Other player lost history');

    await env.withSecurityRulesDisabled(context => setDoc(doc(context.firestore(), 'player_blocks/alice/users/bob'), {createdAt: new Date()}));
    await assertSucceeds(send(alice, 'legacy-block-ignored'));
    await assertSucceeds(send(bob, 'legacy-block-peer', 'bob'));
    await assertFails(setDoc(doc(alice, 'player_blocks/alice/users/bob'), {createdAt: serverTimestamp()}));
    await assertFails(setDoc(doc(alice, 'player_status/alice'), {updatedAt: serverTimestamp()}));
  } finally { await env.cleanup(); }
});

