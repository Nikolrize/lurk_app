import {readFileSync} from 'node:fs';
import test from 'node:test';
import {assertFails, assertSucceeds, initializeTestEnvironment} from '@firebase/rules-unit-testing';
import {doc, setDoc, getDoc, deleteDoc, serverTimestamp} from 'firebase/firestore';

test('device tokens are owner-only', async () => {
  const env = await initializeTestEnvironment({projectId: 'demo-lurk-notifications', firestore: {
    host: '127.0.0.1', port: 8080,
    rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
  }});
  try {
    const alice = env.authenticatedContext('alice').firestore();
    const bob = env.authenticatedContext('bob').firestore();
    const anon = env.unauthenticatedContext().firestore();
    const token = 'a-valid-device-token-for-testing';
    const path = `notification_users/alice/devices/${token}`;
    const data = {token, platform: 'android', updatedAt: serverTimestamp()};
    await assertSucceeds(setDoc(doc(alice, path), data));
    await assertSucceeds(getDoc(doc(alice, path)));
    for (const db of [bob, anon]) {
      await assertFails(getDoc(doc(db, path)));
      await assertFails(setDoc(doc(db, path), data));
      await assertFails(deleteDoc(doc(db, path)));
    }
    for (const patch of [{token: 'different'}, {platform: 'fake'}, {updatedAt: new Date(0)}, {admin: true}]) {
      await assertFails(setDoc(doc(alice, path), {...data, ...patch}));
    }
    await assertSucceeds(deleteDoc(doc(alice, path)));
  } finally { await env.cleanup(); }
});
