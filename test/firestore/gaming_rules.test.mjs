import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

import {
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

test('gaming preferences ownership and validation', async () => {
  const environment = await initializeTestEnvironment({
    projectId: 'demo-lurk-profiles',
    firestore: {
      host: '127.0.0.1',
      port: 8080,
      rules: readFileSync(
        new URL('../../firestore.rules', import.meta.url),
        'utf8',
      ),
    },
  });

  try {
    await environment.clearFirestore();

    const alice =
      environment.authenticatedContext('alice').firestore();
    const bob =
      environment.authenticatedContext('bob').firestore();
    const guest =
      environment.unauthenticatedContext().firestore();

    const aliceProfile = doc(alice, 'players/alice');

    await assertSucceeds(setDoc(aliceProfile, {
      username: 'Alice',
      bio: 'Hello!',
      region: 'Malaysia',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }));

    const preferences = {
      games: ['valorant', 'fortnite'],
      currentGame: 'valorant',
      mode: 'competitive',
      playstyles: ['chill', 'fun'],
      communication: 'voice_optional',
      rank: 3,
    };

    await assertSucceeds(updateDoc(aliceProfile, {
      ...preferences,
      updatedAt: serverTimestamp(),
    }));

    const publicView = await assertSucceeds(
      getDoc(doc(bob, 'players/alice')),
    );

    assert.equal(publicView.data().currentGame, 'valorant');
    assert.equal(publicView.data().username, 'Alice');

    await assertFails(
      getDoc(doc(guest, 'players/alice')),
    );

    await assertFails(updateDoc(doc(bob, 'players/alice'), {
      rank: 7,
      updatedAt: serverTimestamp(),
    }));

    for (const invalid of [
      { games: ['unknown_game'] },
      { games: ['valorant', 'valorant'] },
      { games: [123] },
      { currentGame: 'mobile_legends' },
      { mode: 'invalid' },
      { playstyles: ['invalid'] },
      { communication: 'invalid' },
      { rank: 8 },
      { rank: 'Gold' },
      { currentGame: 'fortnite', rank: 3 },
      { rating: 5 },
      { isVerified: true },
      { createdAt: serverTimestamp() },
    ]) {
      await assertFails(updateDoc(aliceProfile, {
        ...invalid,
        updatedAt: serverTimestamp(),
      }));
    }

    // Changing game works when its incompatible rank is cleared.
    await assertSucceeds(updateDoc(aliceProfile, {
      currentGame: 'fortnite',
      rank: null,
      updatedAt: serverTimestamp(),
    }));

    // Existing profile editing still works after gaming fields exist.
    await assertSucceeds(updateDoc(aliceProfile, {
      bio: 'Updated bio',
      updatedAt: serverTimestamp(),
    }));
  } finally {
    await environment.cleanup();
  }
});