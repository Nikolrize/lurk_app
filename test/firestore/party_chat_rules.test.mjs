import {readFileSync} from 'node:fs';
import test from 'node:test';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {doc, collection, setDoc, getDoc, getDocs, updateDoc, deleteDoc, serverTimestamp} from 'firebase/firestore';

test('party chat requires active membership, rejects forged authors and closes with the session', async () => {
  const env = await initializeTestEnvironment({projectId: 'demo-lurk-party-chat', firestore: {
    host: '127.0.0.1', port: 8080, rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
  }});
  try {
    await env.withSecurityRulesDisabled(async ctx => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'parties/squad'), {hostId: 'alice', visibility: 'public', status: 'open'});
      for (const uid of ['alice', 'bob', 'removed']) {
        await setDoc(doc(db, `players/${uid}`), {username: uid});
        await setDoc(doc(db, `parties/squad/members/${uid}`), {role: uid === 'alice' ? 'host' : 'member',
          leftAt: uid === 'removed' ? new Date(0) : null});
      }
    });
    const alice = env.authenticatedContext('alice').firestore();
    const bob = env.authenticatedContext('bob').firestore();
    const outsider = env.authenticatedContext('outsider').firestore();
    const removed = env.authenticatedContext('removed').firestore();
    const guest = env.unauthenticatedContext().firestore();
    const path = 'parties/squad/messages/one';
    const message = {senderId: 'alice', senderUsername: 'alice', text: 'Hello squad 🎮', type: 'text', createdAt: serverTimestamp()};
    await assertSucceeds(setDoc(doc(alice, path), message));
    await assertSucceeds(getDoc(doc(bob, path)));
    await assertSucceeds(getDocs(collection(bob, 'parties/squad/messages')));
    for (const db of [outsider, removed, guest]) {
      await assertFails(getDoc(doc(db, path)));
      await assertFails(setDoc(doc(db, 'parties/squad/messages/intrusion'), message));
    }
    for (const patch of [{senderId: 'bob'}, {senderUsername: 'forged'}, {text: '   '},
      {text: 'x'.repeat(2001)}, {type: 'admin'}, {createdAt: new Date(0)}, {extra: 'field'}]) {
      await assertFails(setDoc(doc(alice, 'parties/squad/messages/invalid'), {...message, ...patch}));
    }
    await assertFails(updateDoc(doc(alice, path), {text: 'Changed'}));
    await assertFails(deleteDoc(doc(alice, path)));
    await env.withSecurityRulesDisabled(ctx => updateDoc(doc(ctx.firestore(), 'parties/squad/members/bob'), {leftAt: new Date()}));
    await assertFails(getDoc(doc(bob, path)));
    await assertFails(setDoc(doc(bob, 'parties/squad/messages/after-leaving'), {...message, senderId: 'bob', senderUsername: 'bob'}));
    await env.withSecurityRulesDisabled(ctx => updateDoc(doc(ctx.firestore(), 'parties/squad'), {status: 'completed'}));
    await assertFails(getDoc(doc(alice, path)));
    await assertFails(setDoc(doc(alice, 'parties/squad/messages/ended'), message));
  } finally { await env.cleanup(); }
});
