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
      { rank: 9 },
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

    await assertSucceeds(updateDoc(aliceProfile, { rank: 8, gameRanks: { valorant: 'radiant' }, updatedAt: serverTimestamp() }));
    await assertSucceeds(updateDoc(aliceProfile, {
      games: ['valorant', 'fortnite', 'mobile_legends'], currentGame: 'mobile_legends',
      rank: 9, gameRanks: { valorant: 'radiant', mobile_legends: 'mythical_immortal' }, updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(aliceProfile, { rank: 10, updatedAt: serverTimestamp() }));
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

    //save two games' ranks while MLBB main game
    await assertSucceeds(updateDoc(aliceProfile, {
      games: ['valorant', 'mobile_legends', 'fortnite'],
      currentGame: 'mobile_legends',
      gameRanks: {
        valorant: 'gold',
        mobile_legends: 'epic',
      },
      rank: 4,
      updatedAt: serverTimestamp(),
    }));

    let saved = await getDoc(aliceProfile);
    assert.equal(saved.data().gameRanks.valorant, 'gold');
    assert.equal(saved.data().gameRanks.mobile_legends, 'epic');

    //switching the main game preserves both ranks
    await assertSucceeds(updateDoc(aliceProfile, {
      currentGame: 'valorant',
      rank: 3,
      updatedAt: serverTimestamp(),
    }));

    saved = await getDoc(aliceProfile);
    assert.equal(saved.data().gameRanks.mobile_legends, 'epic');

    //rank must agree with the main game's rank ID
    await assertFails(updateDoc(aliceProfile, {
      rank: 4,
      updatedAt: serverTimestamp(),
    }));

    //rank from another game is invalid
    await assertFails(updateDoc(aliceProfile, {
      gameRanks: {
        valorant: 'epic',
        mobile_legends: 'epic',
      },
      updatedAt: serverTimestamp(),
    }));

    //fortnite no rank entry
    await assertFails(updateDoc(aliceProfile, {
      gameRanks: {
        valorant: 'gold',
        fortnite: 'gold',
      },
      updatedAt: serverTimestamp(),
    }));

    //removing a game also requires removing its rank entry
    await assertFails(updateDoc(aliceProfile, {
      games: ['valorant'],
      updatedAt: serverTimestamp(),
    }));

    //other accounts cannot update the new rank map
    await assertFails(updateDoc(doc(bob, 'players/alice'), {
      gameRanks: {
        valorant: 'gold',
        mobile_legends: 'legend',
      },
      updatedAt: serverTimestamp(),
    }));

    // testin radiant
    await assertSucceeds(updateDoc(aliceProfile, {
      gameRanks: {
        valorant: 'radiant',
        mobile_legends: 'epic',
      },
      rank: 8,
      updatedAt: serverTimestamp(),
    }));

    //fornite as main game
    await assertSucceeds(updateDoc(aliceProfile, {
      currentGame: 'fortnite',
      rank: null,
      updatedAt: serverTimestamp(),
    }));

    saved = await getDoc(aliceProfile);
    assert.equal(saved.data().gameRanks.valorant, 'radiant');
    assert.equal(saved.data().gameRanks.mobile_legends, 'epic');

    // All ten selections and six independent ranks may coexist.
    const expanded = {
      games: ['valorant', 'mobile_legends', 'fortnite', 'apex_legends', 'cs2',
        'honor_of_kings', 'league_of_legends', 'minecraft', 'roblox', 'peak'],
      currentGame: 'cs2', rank: 17,
      gameRanks: {valorant: 'radiant', mobile_legends: 'mythical_immortal',
        apex_legends: 'apex_predator', cs2: 'global_elite',
        honor_of_kings: 'legend', league_of_legends: 'challenger'},
      updatedAt: serverTimestamp(),
    };
    await assertSucceeds(updateDoc(aliceProfile, expanded));
    for (const [gameId, rank] of [
      ['apex_legends', 7], ['honor_of_kings', 9], ['league_of_legends', 9],
    ]) {
      await assertSucceeds(updateDoc(aliceProfile, {
        currentGame: gameId, rank, updatedAt: serverTimestamp(),
      }));
    }
    for (const gameId of ['minecraft', 'roblox', 'peak']) {
      await assertSucceeds(updateDoc(aliceProfile, {
        currentGame: gameId, rank: null, updatedAt: serverTimestamp(),
      }));
      await assertFails(updateDoc(aliceProfile, {rank: 0, updatedAt: serverTimestamp()}));
    }
    await assertFails(updateDoc(aliceProfile, {
      gameRanks: {...expanded.gameRanks, apex_legends: 'challenger'},
      updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(aliceProfile, {
      gameRanks: {...expanded.gameRanks, minecraft: 'diamond'},
      updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(aliceProfile, {
      games: [...expanded.games, 'not_a_game'], updatedAt: serverTimestamp(),
    }));
  } finally {
    await environment.cleanup();
  }
});
