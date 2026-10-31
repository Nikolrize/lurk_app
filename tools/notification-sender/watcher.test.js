const test = require('node:test');
const assert = require('node:assert/strict');
const {watchMessages} = require('./watcher');

test('Firestore watcher skips history and reads every new message from a burst', {
  skip: !process.env.FIRESTORE_EMULATOR_HOST,
}, async () => {
  const {initializeApp, deleteApp} = require('firebase-admin/app');
  const {getFirestore, Timestamp, FieldValue} = require('firebase-admin/firestore');
  const app = initializeApp({projectId: 'demo-lurk-sender'}, 'watcher-test');
  const db = getFirestore(app);
  const chat = db.collection('chats').doc(`watcher-${Date.now()}`);
  const seen = [], errors = [];
  let stop;
  try {
    await chat.set({updatedAt: Timestamp.fromMillis(1)});
    await chat.collection('messages').doc('old').set({createdAt: Timestamp.fromMillis(1)});
    stop = await watchMessages({db,
      send: async (id, messageId) => { assert.equal(id, chat.id); seen.push(messageId); },
      log: error => errors.push(error), onError: error => errors.push(error),
    });
    // More than one page, with identical server timestamps and one chat update.
    const batch = db.batch();
    for (let i = 0; i < 105; i++) batch.set(chat.collection('messages').doc(`new-${String(i).padStart(3, '0')}`), {
      createdAt: FieldValue.serverTimestamp(), senderId: 'alice', type: 'text',
    });
    batch.update(chat, {updatedAt: FieldValue.serverTimestamp()});
    await batch.commit();
    const deadline = Date.now() + 15000;
    while (seen.length < 105 && !errors.length && Date.now() < deadline) {
      await new Promise(resolve => setTimeout(resolve, 50));
    }
    assert.deepEqual(errors, []);
    assert.equal(seen.length, 105);
    assert.equal(new Set(seen).size, 105);
    assert.ok(!seen.includes('old'));
  } finally {
    if (stop) await stop();
    await db.recursiveDelete(chat);
    await db.terminate(); await deleteApp(app);
  }
});
