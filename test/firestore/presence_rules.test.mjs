//checks: owner can save their status choice
// other signed-in players can read presence
// another account cannot change or delete your sessions
//invalid data is rejected
//removing one session preserves another
//default initial preserves an existing preference

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import {
    assertFails,
    assertSucceeds,
    initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

test('presence ownership, preferences and sessions', async () => {
    const env = await initializeTestEnvironment({
        projectId: 'demo-lurk-profiles',
        database: {
        host: '127.0.0.1',
        port: 9000,
        rules: readFileSync(
            new URL('../../database.rules.json', import.meta.url),
            'utf8',
        ),
        },
    });

try {
    await env.clearDatabase();

    const alice = env.authenticatedContext('alice').database();
    const bob = env.authenticatedContext('bob').database();
    const guest = env.unauthenticatedContext().database();

    const preference = alice.ref('presence/alice/preference');
    const browser = alice.ref('presence/alice/sessions/browser');
    const android = alice.ref('presence/alice/sessions/android');

    // All four manual choices are supported.
    for (const status of [
        'online',
        'idle',
        'do_not_disturb',
        'offline',
    ]) {
        await assertSucceeds(preference.set(status));
    }

    await assertSucceeds(preference.set('online'));

    // Both devices can have separate entries.
    await assertSucceeds(browser.set('online'));
    await assertSucceeds(android.set('idle'));

    const publicView = await assertSucceeds(
        bob.ref('presence/alice').once('value'),
    );

    assert.equal(publicView.val().sessions.browser, 'online');
    assert.equal(publicView.val().sessions.android, 'idle');

    // Signing out one device must preserve the other.
    await assertSucceeds(browser.remove());

    const remaining = await android.once('value');
    assert.equal(remaining.val(), 'idle');

    // Another player cannot change Alice's data.
    await assertFails(
        bob.ref('presence/alice/preference').set('offline'),
    );

    await assertFails(
        bob.ref('presence/alice/sessions/android').remove(),
    );

    // Signed-out users cannot read or write presence.
    await assertFails(
        guest.ref('presence/alice').once('value'),
    );

    await assertFails(
        guest.ref('presence/alice/preference').set('online'),
    );

    // Invalid preferences and session values are rejected.
    for (const invalid of ['busy', 123, { status: 'online' }]) {
        await assertFails(preference.set(invalid));
    }

    for (const invalid of [
        'offline',
        'do_not_disturb',
        123,
        { status: 'online' },
    ]) {
        await assertFails(android.set(invalid));
    }

    await assertFails(
        alice.ref('presence/alice/isAdmin').set(true),
    );

    // Creating defaults must not overwrite an existing choice.
    await preference.set('do_not_disturb');

    await assertSucceeds(
        preference.transaction((current) => current ?? 'online'),
    );

    const preserved = await preference.once('value');
    assert.equal(preserved.val(), 'do_not_disturb');

    // An owner can register their own disconnect cleanup.
    await assertSucceeds(android.onDisconnect().remove());

    // Another account cannot register cleanup for Alice.
    await assertFails(
        bob.ref('presence/alice/sessions/android')
        .onDisconnect()
        .remove(),
    );

    await android.onDisconnect().cancel();
    await android.remove();
    } finally {
        await env.cleanup();
    }
});