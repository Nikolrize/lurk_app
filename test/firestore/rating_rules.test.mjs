import {readFileSync} from 'node:fs';
import test from 'node:test';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {doc, setDoc, getDoc, updateDoc, deleteDoc, serverTimestamp, Timestamp} from 'firebase/firestore';

test('ratings require overlapping participation, reject self/duplicate/forged reviews, and remain immutable', async () => {
  const env = await initializeTestEnvironment({projectId: 'demo-lurk-ratings', firestore: {
    host: '127.0.0.1', port: 8080, rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8'),
  }});
  const t = ms => Timestamp.fromMillis(ms);
  try {
    await env.withSecurityRulesDisabled(async ctx => {
      const db = ctx.firestore();
      for (const uid of ['alice', 'bob', 'late', 'zero']) await setDoc(doc(db, `players/${uid}`), {username: uid});
      for (const [id, status] of [['squad', 'open'], ['active', 'open'], ['closed', 'closed']]) {
        await setDoc(doc(db, `parties/${id}`), {status, updatedAt: t(5000), completedAt: status === 'closed' ? t(5000) : null});
        await setDoc(doc(db, `parties/${id}/members/alice`), {joinedAt: t(1000), leftAt: id === 'squad' ? t(3000) : null});
        await setDoc(doc(db, `parties/${id}/members/bob`), {joinedAt: t(2000), leftAt: null});
        await setDoc(doc(db, `players/alice/party_history/${id}`), {joinedAt: t(1000)});
      }
      await setDoc(doc(db, 'parties/squad/members/late'), {joinedAt: t(3500), leftAt: null});
      await setDoc(doc(db, 'parties/squad/members/zero'), {joinedAt: t(2000), leftAt: t(2000)});
    });
    const alice = env.authenticatedContext('alice').firestore();
    const outsider = env.authenticatedContext('outsider').firestore();
    const guest = env.unauthenticatedContext().firestore();
    const base = {partyId: 'squad', raterId: 'alice', stars: 5, tags: ['Friendly'], comment: 'Good teamwork', createdAt: serverTimestamp()};
    const path = 'player_reviews/bob/reviews/squad_alice';
    for (const patch of [{stars: 0}, {stars: 6}, {stars: 3.5}, {tags: ['fake']},
      {tags: ['Friendly', 'Friendly']}, {comment: 'x'.repeat(501)}, {raterId: 'bob'}, {createdAt: t(1)}, {extra: true}]) {
      await assertFails(setDoc(doc(alice, path), {...base, ...patch}));
    }
    await assertFails(setDoc(doc(alice, 'player_reviews/alice/reviews/squad_alice'), base));
    await assertFails(setDoc(doc(alice, 'player_reviews/late/reviews/squad_alice'), base));
    await assertFails(setDoc(doc(alice, 'player_reviews/zero/reviews/squad_alice'), base));
    await assertFails(setDoc(doc(alice, 'player_reviews/bob/reviews/active_alice'), {...base, partyId: 'active'}));
    await assertFails(setDoc(doc(outsider, 'player_reviews/bob/reviews/squad_outsider'), {...base, raterId: 'outsider'}));
    await assertFails(setDoc(doc(guest, path), base));
    await assertFails(setDoc(doc(alice, 'player_reviews/bob/reviews/arbitrary-id'), base));
    await assertSucceeds(setDoc(doc(alice, path), base));
    await assertSucceeds(getDoc(doc(outsider, path)));
    await assertFails(getDoc(doc(guest, path)));
    await assertFails(setDoc(doc(alice, path), base));
    await assertFails(updateDoc(doc(alice, path), {stars: 1}));
    await assertFails(deleteDoc(doc(alice, path)));
    await assertSucceeds(setDoc(doc(alice, 'player_reviews/bob/reviews/closed_alice'), {...base, partyId: 'closed', stars: 4, tags: [], comment: ''}));
  } finally { await env.cleanup(); }
});
