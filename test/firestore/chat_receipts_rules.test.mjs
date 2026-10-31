import {readFileSync} from 'node:fs';
import test from 'node:test';
import {assertFails, assertSucceeds, initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {doc, setDoc, getDoc, Timestamp} from 'firebase/firestore';

test('receipts are member-only, monotonic, and cannot claim unseen/future messages; preferences are private', async () => {
  const env = await initializeTestEnvironment({projectId: 'demo-lurk-receipts', firestore: {
    host: '127.0.0.1', port: 8080, rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
  }});
  const first = Timestamp.fromMillis(1000), second = Timestamp.fromMillis(2000);
  try {
    await env.withSecurityRulesDisabled(async ctx => {
      await setDoc(doc(ctx.firestore(), 'chats/pair'), {type: 'direct', userIds: ['alice', 'bob']});
      for (const [id, createdAt] of [['first', first], ['second', second]]) {
        await setDoc(doc(ctx.firestore(), `chats/pair/messages/${id}`), {createdAt, senderId: 'bob'});
      }
    });
    const alice = env.authenticatedContext('alice').firestore();
    const bob = env.authenticatedContext('bob').firestore();
    const outsider = env.authenticatedContext('outsider').firestore();
    const path = 'chats/pair/receipts/alice';
    await assertSucceeds(setDoc(doc(alice, path), {messageId: 'first', readThrough: first}));
    await assertSucceeds(getDoc(doc(bob, path)));
    await assertFails(getDoc(doc(outsider, path)));
    await assertFails(setDoc(doc(bob, path), {messageId: 'second', readThrough: second}));
    await assertFails(setDoc(doc(alice, path), {messageId: 'missing', readThrough: second}));
    await assertFails(setDoc(doc(alice, path), {messageId: 'first', readThrough: second}));
    await assertSucceeds(setDoc(doc(alice, path), {messageId: 'second', readThrough: second}));
    await assertFails(setDoc(doc(alice, path), {messageId: 'first', readThrough: first}));
    const pref = 'notification_preferences/alice';
    await assertSucceeds(setDoc(doc(alice, pref), {messages: false, invitations: true}));
    await assertFails(getDoc(doc(bob, pref)));
    await assertFails(setDoc(doc(alice, pref), {messages: 'false', invitations: true}));
  } finally { await env.cleanup(); }
});
