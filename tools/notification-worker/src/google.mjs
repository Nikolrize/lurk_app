const encoder = new TextEncoder();
const base64url = bytes => btoa(String.fromCharCode(...bytes))
  .replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
const decode = text => Uint8Array.from(atob(text.replaceAll('-', '+').replaceAll('_', '/')), c => c.charCodeAt(0));
const json64 = value => base64url(encoder.encode(JSON.stringify(value)));
let signingKeys;
let accessToken;

export class HttpError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}

export async function verifyUser(token, project, fetcher = fetch) {
  try {
    const parts = token.split('.');
    if (parts.length !== 3 || token.length > 8192) throw new Error();
    const header = JSON.parse(new TextDecoder().decode(decode(parts[0])));
    const claims = JSON.parse(new TextDecoder().decode(decode(parts[1])));
    const now = Date.now() / 1000;
    if (header.alg !== 'RS256' || typeof header.kid !== 'string' ||
        claims.aud !== project || claims.iss !== `https://securetoken.google.com/${project}` ||
        typeof claims.sub !== 'string' || !claims.sub || claims.sub.length > 128 || claims.sub.includes('/') ||
        !Number.isFinite(claims.exp) || claims.exp <= now ||
        !Number.isFinite(claims.iat) || claims.iat > now ||
        !Number.isFinite(claims.auth_time) || claims.auth_time > now) throw new Error();
    if (!signingKeys || signingKeys.expires <= Date.now()) {
      const response = await fetcher('https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com');
      if (!response.ok) throw new HttpError(503, 'Authentication temporarily unavailable.');
      const data = await response.json();
      const maxAge = Number(response.headers.get('cache-control')?.match(/max-age=(\d+)/)?.[1] ?? 300);
      signingKeys = {keys: data.keys, expires: Date.now() + Math.min(maxAge, 3600) * 1000};
    }
    const jwk = signingKeys.keys.find(key => key.kid === header.kid);
    if (!jwk) throw new Error();
    const key = await crypto.subtle.importKey('jwk', jwk, {name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256'}, false, ['verify']);
    if (!await crypto.subtle.verify('RSASSA-PKCS1-v1_5', key, decode(parts[2]), encoder.encode(`${parts[0]}.${parts[1]}`))) throw new Error();
    return claims.sub;
  } catch (error) {
    if (error instanceof HttpError) throw error;
    throw new HttpError(401, 'Sign in again.');
  }
}

export async function googleAccessToken(env, fetcher = fetch) {
  if (accessToken?.expires > Date.now() + 60000) return accessToken.value;
  const account = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON);
  if (account.type !== 'service_account' || account.project_id !== env.FIREBASE_PROJECT_ID ||
      !account.client_email || !account.private_key) throw new Error('Invalid server configuration');
  const now = Math.floor(Date.now() / 1000);
  const assertion = `${json64({alg: 'RS256', typ: 'JWT'})}.${json64({
    iss: account.client_email, scope: 'https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600,
  })}`;
  const pem = account.private_key.replace(/-----[^-]+-----/g, '').replace(/\s/g, '');
  const key = await crypto.subtle.importKey('pkcs8', decode(pem), {name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256'}, false, ['sign']);
  const signature = base64url(new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, encoder.encode(assertion))));
  const response = await fetcher('https://oauth2.googleapis.com/token', {
    method: 'POST', headers: {'content-type': 'application/x-www-form-urlencoded'},
    body: new URLSearchParams({grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion: `${assertion}.${signature}`}),
  });
  if (!response.ok) throw new Error('Server authorization failed');
  const data = await response.json();
  accessToken = {value: data.access_token, expires: Date.now() + data.expires_in * 1000};
  return accessToken.value;
}

function valueOf(value) {
  if ('nullValue' in value) return null;
  if ('timestampValue' in value) return {toMillis: () => Date.parse(value.timestampValue)};
  if ('arrayValue' in value) return (value.arrayValue.values ?? []).map(valueOf);
  if ('mapValue' in value) return fieldsOf(value.mapValue.fields);
  if ('integerValue' in value) return Number(value.integerValue);
  return value.stringValue ?? value.booleanValue ?? value.doubleValue;
}
const fieldsOf = fields => Object.fromEntries(Object.entries(fields ?? {}).map(([key, value]) => [key, valueOf(value)]));

export function firestore(project, token, fetcher = fetch) {
  const root = `https://firestore.googleapis.com/v1/projects/${project}/databases/(default)/documents`;
  const pathOf = path => path.split('/').map(encodeURIComponent).join('/');
  async function request(path, options = {}) {
    return fetcher(`${root}/${path}`, {...options, headers: {
      authorization: `Bearer ${token}`, 'content-type': 'application/json', ...options.headers,
    }});
  }
  return {
    async get(path) {
      const response = await request(pathOf(path));
      if (response.status === 404) return undefined;
      if (!response.ok) throw new Error('Database read failed');
      return fieldsOf((await response.json()).fields);
    },
    async devices(uid) {
      const response = await request(`${pathOf(`notification_users/${uid}/devices`)}?pageSize=17`);
      if (!response.ok) throw new Error('Device lookup failed');
      const data = await response.json();
      // Bound fan-out below the Workers Free 50 external subrequest limit.
      if (data.nextPageToken || data.documents?.length > 16) throw new Error('Too many registered devices');
      return (data.documents ?? []).map(doc => ({...fieldsOf(doc.fields), id: doc.name.split('/').at(-1)}));
    },
    async claim(id) {
      const response = await request(`notification_deliveries?documentId=${encodeURIComponent(id)}`, {
        method: 'POST', body: JSON.stringify({fields: {createdAt: {timestampValue: new Date().toISOString()}}}),
      });
      if (response.status === 409) return false;
      if (!response.ok) throw new Error('Delivery claim failed');
      return true;
    },
    async remove(path) {
      const response = await request(pathOf(path), {method: 'DELETE'});
      if (!response.ok && response.status !== 404) throw new Error('Device cleanup failed');
    },
  };
}

export function messaging(project, token, fetcher = fetch) {
  return {async sendEachForMulticast({tokens, android, ...payload}) {
    const responses = [];
    for (const deviceToken of tokens) {
      const response = await fetcher(`https://fcm.googleapis.com/v1/projects/${project}/messages:send`, {
        method: 'POST', headers: {authorization: `Bearer ${token}`, 'content-type': 'application/json'},
        body: JSON.stringify({message: {...payload, token: deviceToken, android: {
          priority: android.priority.toUpperCase(), ttl: `${android.ttl / 1000}s`,
          notification: {channel_id: android.notification.channelId, icon: android.notification.icon, tag: android.notification.tag},
        }}}),
      });
      if (response.ok) { await response.body?.cancel(); responses.push({success: true}); continue; }
      const error = await response.json();
      const unregistered = error.error?.details?.some(detail => detail.errorCode === 'UNREGISTERED');
      responses.push({success: false, error: {code: unregistered ? 'messaging/registration-token-not-registered' : 'messaging/send-failed'}});
    }
    const successCount = responses.filter(result => result.success).length;
    return {responses, successCount, failureCount: responses.length - successCount};
  }};
}

