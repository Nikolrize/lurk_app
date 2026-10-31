const test = require('node:test');
const assert = require('node:assert/strict');
const {watchMessages} = require('./watcher');

test('party watcher catches messages without parent updates, skips history and attaches to new parties', {
  skip: !process.env.FIRESTORE_EMULATOR_HOST,
}, async () => {
  const {initializeApp, deleteApp} = require('firebase-admin/app');
  const {getFirestore, Timestamp, FieldValue} = require('firebase-admin/firestore');
  const app = initializeApp({projectId: 'demo-lurk-party-sender'}, 'party-watcher-test');
  const db = getFirestore(app), seen = [], errors = [];
  const party = db.collection('parties').doc('existing');
  const newParty = db.collection('parties').doc('new-party');
  let stop;
  try {
    await party.set({status: 'open', updatedAt: Timestamp.fromMillis(1)});
    await party.collection('messages').doc('history').set({createdAt: Timestamp.fromMillis(1)});
    stop = await watchMessages({db, send: async () => assert.fail('Not a direct message'),
      sendParty: async (id, msgId) => seen.push([id, msgId]),
      log: error => errors.push(error), onError: error => errors.push(error)});
    const batch = db.batch();
    for (let i = 0; i < 3; i++) batch.set(party.collection('messages').doc(`message-${i}`), {createdAt: FieldValue.serverTimestamp()});
    await batch.commit(); // Deliberately no parent-party update.
    await newParty.set({status: 'open'});
    await newParty.collection('messages').doc('new-message').set({createdAt: FieldValue.serverTimestamp()});
    const deadline = Date.now() + 15000;
    while (seen.length < 4 && !errors.length && Date.now() < deadline) await new Promise(resolve => setTimeout(resolve, 50));
    assert.deepEqual(errors, []);
    assert.equal(seen.length, 4);
    assert.equal(seen.filter(([id]) => id === 'existing').length, 3);
    assert.ok(!seen.some(([, id]) => id === 'history'));
    assert.ok(seen.some(([id, msgId]) => id === 'new-party' && msgId === 'new-message'));
  } finally {
    if (stop) await stop();
    await db.recursiveDelete(party); await db.recursiveDelete(newParty);
    await db.terminate(); await deleteApp(app);
  }
});
