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

test('availability ownership, schedules and validation', async () => {
  const env = await initializeTestEnvironment({
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
    await env.clearFirestore();

    const alice = env.authenticatedContext('alice').firestore();
    const bob = env.authenticatedContext('bob').firestore();
    const guest = env.unauthenticatedContext().firestore();

    const profile = doc(alice, 'players/alice');

    const profileData = () => ({
      username: 'Alice',
      bio: '',
      region: 'Asia',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });

    const slot = (weekday, startMinute = 1200, endMinute = 1320) => ({
      weekday,
      startMinute,
      endMinute,
    });

    const availability = {
      availableNow: true,
      preferredTimes: ['Evening', 'Night'],
      weeklySchedule: [slot(1), slot(7, 1320, 60)],
      timeZone: 'Asia/Kuala_Lumpur',
    };

    await assertSucceeds(setDoc(profile, profileData()));

    await assertSucceeds(updateDoc(profile, {
      availability,
      updatedAt: serverTimestamp(),
    }));

    const publicView = await assertSucceeds(
      getDoc(doc(bob, 'players/alice')),
    );

    assert.equal(publicView.data().availability.availableNow, true);
    assert.equal(
      publicView.data().availability.weeklySchedule[1].endMinute,
      60,
    );

    await assertFails(getDoc(doc(guest, 'players/alice')));

    await assertFails(updateDoc(doc(bob, 'players/alice'), {
      availability,
      updatedAt: serverTimestamp(),
    }));

    const invalidValues = [
      null,
      [],
      { ...availability, availableNow: 'yes' },
      { ...availability, timeZone: 'Europe/London' },
      { ...availability, preferredTimes: ['Unknown'] },
      { ...availability, preferredTimes: ['Night', 'Night'] },
      { ...availability, preferredTimes: [123] },
      { ...availability, weeklySchedule: [slot(0)] },
      { ...availability, weeklySchedule: [slot(8)] },
      { ...availability, weeklySchedule: [slot(1, -1, 1200)] },
      { ...availability, weeklySchedule: [slot(1, 1440, 1200)] },
      { ...availability, weeklySchedule: [slot(1, 1200, 1441)] },
      { ...availability, weeklySchedule: [slot(1, 1200, 1200)] },
      { ...availability, weeklySchedule: [slot(1), slot(1)] },
      { ...availability, weeklySchedule: [slot(2), slot(1)] },
      { ...availability, weeklySchedule: [null] },
      { ...availability, weeklySchedule: [{ weekday: 1 }] },
      { ...availability, weeklySchedule: Array(8).fill(slot(1)) },
      { ...availability, isVerified: true },
    ];

    for (const invalid of invalidValues) {
      await assertFails(updateDoc(profile, {
        availability: invalid,
        updatedAt: serverTimestamp(),
      }));
    }

    // Invalid availability must also fail on document creation.
    await assertFails(setDoc(doc(bob, 'players/bob'), {
      ...profileData(),
      availability: {
        ...availability,
        weeklySchedule: [slot(9)],
      },
    }));

    // All seven days, including a valid end-of-day value.
    await assertSucceeds(updateDoc(profile, {
      availability: {
        ...availability,
        weeklySchedule: [
          slot(1), slot(2), slot(3), slot(4),
          slot(5), slot(6), slot(7, 1200, 1440),
        ],
      },
      updatedAt: serverTimestamp(),
    }));

    // Removing selections and turning availability off must work.
    await assertSucceeds(updateDoc(profile, {
      availability: {
        availableNow: false,
        preferredTimes: [],
        weeklySchedule: [],
        timeZone: 'Asia/Kuala_Lumpur',
      },
      updatedAt: serverTimestamp(),
    }));

    // Normal profile editing still works afterwards.
    await assertSucceeds(updateDoc(profile, {
      bio: 'Updated introduction',
      updatedAt: serverTimestamp(),
    }));
  } finally {
    await env.cleanup();
  }
});