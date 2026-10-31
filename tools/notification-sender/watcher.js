async function watchMessages({db, send, log = console.log, onError = () => {}}) {
  const startedAt = (await db.collection('chats').limit(1).get()).readTime;
  const cursors = new Map();
  let queue = Promise.resolve();
  let stopping = false;
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
    await queue;
  };
}
module.exports = {watchMessages};
