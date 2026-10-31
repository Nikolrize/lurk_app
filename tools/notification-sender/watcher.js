async function watchMessages({db, send, sendParty, log = console.log, onError = () => {}}) {
  const startedAt = (await db.collection('chats').limit(1).get()).readTime;
  const cursors = new Map();
  let queue = Promise.resolve();
  let stopping = false;
  const partyListeners = new Map();
  const stopParties = sendParty ? db.collection('parties').where('status', '==', 'open').onSnapshot(snapshot => {
    for (const change of snapshot.docChanges()) {
      const id = change.doc.id;
      if (change.type === 'removed') {
        partyListeners.get(id)?.();
        partyListeners.delete(id);
      } else if (!partyListeners.has(id)) {
        const unsubscribe = db.collection(`parties/${id}/messages`).where('createdAt', '>=', startedAt)
          .onSnapshot(messages => {
            for (const message of messages.docChanges()) {
              if (message.type !== 'added') continue;
              queue = queue.then(() => stopping ? undefined : sendParty(id, message.doc.id, message.doc.data()))
                .catch(error => log(`Party message processing failed (${error.code || 'unknown'}).`));
            }
          }, onError);
        partyListeners.set(id, unsubscribe);
      }
    }
  }, onError) : () => {};
  const processChat = async chatId => {
    let cursor = cursors.get(chatId);
    while (!stopping) {
      let query = db.collection(`chats/${chatId}/messages`)
        .where('createdAt', '>=', startedAt).orderBy('createdAt').orderBy('__name__').limit(100);
      if (cursor) query = query.startAfter(cursor);
      const page = await query.get();
      for (const doc of page.docs) {
        await send(chatId, doc.id, doc.data());
        cursor = doc;
        cursors.set(chatId, cursor);
      }
      if (page.size < 100) break;
    }
  };
  const unsubscribe = db.collection('chats').where('updatedAt', '>=', startedAt).onSnapshot(snapshot => {
    for (const change of snapshot.docChanges()) {
      if (change.type === 'removed') continue;
      queue = queue.then(() => processChat(change.doc.id)).catch(error => {
        log(`Message processing failed (${error.code || 'unknown'}). Check permissions and connectivity.`);
      });
    }
  }, error => { onError(error); });
  return async () => {
    stopping = true;
    unsubscribe();
    stopParties();
    for (const stop of partyListeners.values()) stop();
    partyListeners.clear();
    await queue;
  };
}
module.exports = {watchMessages};
