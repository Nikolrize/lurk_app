const {readFileSync} = require('node:fs');
const {initializeApp, cert} = require('firebase-admin/app');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {getMessaging} = require('firebase-admin/messaging');
const {createSender} = require('./sender');
const {watchMessages} = require('./watcher');

async function main() {
  const args = process.argv.slice(2);
  if (args.some(arg => arg !== '--dry-run')) throw new Error('Usage: node index.js [--dry-run]');
  if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    throw new Error('Set GOOGLE_APPLICATION_CREDENTIALS to your service-account JSON path. See README.md.');
  }
  let key;
  try {
    key = JSON.parse(readFileSync(process.env.GOOGLE_APPLICATION_CREDENTIALS, 'utf8'));
  } catch {
    throw new Error('Cannot read the Firebase key. Set GOOGLE_APPLICATION_CREDENTIALS to the actual downloaded JSON file, not C:\\path\\to\\your-key.json.');
  }
  if (key.type !== 'service_account' || key.project_id !== 'lurk-mae' ||
      typeof key.client_email !== 'string' || typeof key.private_key !== 'string') {
    throw new Error('Use a Firebase Admin SDK service-account key for project lurk-mae.');
  }
  let credential;
  try { credential = cert(key); } catch {
    throw new Error('The service-account key is invalid. Download a new key from Firebase Console.');
  }
  // Explicit project ID avoids accidentally targeting another Firebase project.
  initializeApp({credential, projectId: 'lurk-mae'});
  const db = getFirestore();
  const dryRun = args.includes('--dry-run');
  const store = {
    preferences: async uid => (await db.doc(`notification_preferences/${uid}`).get()).data() ?? {},
    chat: async id => (await db.doc(`chats/${id}`).get()).data(),
    blocked: async (sender, recipient) => {
      const docs = await db.getAll(
        db.doc(`player_blocks/${sender}/blocked/${recipient}`),
        db.doc(`player_blocks/${recipient}/blocked/${sender}`),
      );
      return docs.some(doc => doc.exists);
    },
    devices: async uid => (await db.collection(`notification_users/${uid}/devices`).get()).docs
      .map(doc => ({...doc.data(), id: doc.id})),
    removeDevice: (uid, device) => db.doc(`notification_users/${uid}/devices/${device.id}`).delete(),
    claim: async id => {
      try {
        await db.doc(`notification_deliveries/${id}`).create({createdAt: FieldValue.serverTimestamp()});
        return true;
      } catch (error) {
        if (error.code === 6 || error.code === 'already-exists') return false;
        throw error;
      }
    },
  };
  const send = createSender({store, messaging: getMessaging(), dryRun});
  let stopping = false;
  const stopWatching = await watchMessages({db, send, onError: error => {
    console.error(`Firestore listener stopped (${error.code || 'unknown'}). Fix the connection/permissions and restart.`);
    process.exitCode = 1;
    void stop();
  }});
  async function stop() {
    if (stopping) return;
    stopping = true;
    await stopWatching();
    await db.terminate();
    console.log('Laptop sender stopped.');
  }
  process.once('SIGINT', () => void stop());
  process.once('SIGTERM', () => void stop());
  console.log(`Lurk laptop sender ready (${dryRun ? 'DRY RUN' : 'LIVE'}, project lurk-mae). Keep this terminal open.`);
}

if (require.main === module) main().catch(error => {
  // Do not print credential files, tokens, message text, or raw request objects.
  console.error(`Could not start laptop sender: ${error.code || error.message}`);
  process.exitCode = 1;
});
