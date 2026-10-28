import { readFileSync } from 'node:fs';
import test from 'node:test';

import {
    assertFails,
    assertSucceeds,
    initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

import {
    deleteDoc,
    deleteField,
    doc,
    getDoc,
    serverTimestamp,
    setDoc,
    Timestamp,
    updateDoc,
} from 'firebase/firestore';

test('profile ownership, privacy, and validation', async () => {
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

    const publicData = () => ({
        username: '',
        bio: '',
        region: '',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
    });

    const privateData = () => ({
        dateOfBirth: null,
        gender: '',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
    });

    await assertSucceeds(
        setDoc(doc(alice, 'players/alice'), publicData()),    
    );

    await assertSucceeds(
        setDoc(doc(alice, 'player_private/alice'), privateData()),
    );

    await assertSucceeds(
        updateDoc(doc(alice, 'players/alice'), {
        username: 'Alice',
        updatedAt: serverTimestamp(),
    }),
    );

    await assertSucceeds(getDoc(doc(bob, 'players/alice')));
    await assertFails(getDoc(doc(guest, 'players/alice')));

    await assertFails(
        setDoc(doc(guest, 'players/guest'), publicData()),
    );

    await assertFails(
        setDoc(doc(bob, 'players/alice'), publicData()),
    );

    await assertFails(
        setDoc(doc(bob, 'player_private/alice'), privateData()),
    );

    await assertSucceeds(
        getDoc(doc(alice, 'player_private/alice')),
    );

    await assertFails(
        getDoc(doc(bob, 'player_private/alice')),
    );

    await assertSucceeds(
        updateDoc(doc(alice, 'player_private/alice'), {
        dateOfBirth: Timestamp.fromDate(
            new Date('2000-01-01T00:00:00Z'),
        ),
        gender: 'prefer_not_to_say',
        updatedAt: serverTimestamp(),
    }),
    );

    await assertFails(
    updateDoc(doc(bob, 'player_private/alice'), {
        gender: 'other',
        updatedAt: serverTimestamp(),
    }),
    );

    await assertFails(
    updateDoc(doc(alice, 'players/alice'), {
        isVerified: true,
        updatedAt: serverTimestamp(),
    }),
    );

    await assertFails(
    updateDoc(doc(alice, 'players/alice'), {
        createdAt: Timestamp.fromMillis(0),
        updatedAt: serverTimestamp(),
    }),
    );

    await assertFails(
    updateDoc(doc(alice, 'players/alice'), {
        bio: deleteField(),
        updatedAt: serverTimestamp(),
    }),
    );

    await assertFails(
    updateDoc(doc(alice, 'players/alice'), {
        username: 'a'.repeat(31),
        updatedAt: serverTimestamp(),
    }),
    );

    await assertFails(
    updateDoc(doc(alice, 'players/alice'), {
        username: 123,
        updatedAt: serverTimestamp(),
    }),
    );

    await assertFails(
    updateDoc(doc(alice, 'player_private/alice'), {
        gender: 'invalid',
        updatedAt: serverTimestamp(),
    }),
    );

    await assertFails(
    updateDoc(doc(alice, 'player_private/alice'), {
        dateOfBirth: Timestamp.fromDate(
            new Date('2100-01-01T00:00:00Z'),
        ),
        updatedAt: serverTimestamp(),
    }),
    );

    await assertFails(
        deleteDoc(doc(alice, 'players/alice')),
    );
        } finally {
    await environment.cleanup();
    }
});