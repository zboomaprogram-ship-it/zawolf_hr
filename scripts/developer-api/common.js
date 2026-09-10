const crypto = require('crypto');

const DIRECTORY_READ_SCOPE = 'directory.read';
const DIRECTORY_INACTIVE_READ_SCOPE = 'directory.inactive.read';
const SUPPORTED_SCOPES = new Set([DIRECTORY_READ_SCOPE, DIRECTORY_INACTIVE_READ_SCOPE]);
const MAX_PAGE_SIZE = 100;
const RATE_WINDOW_MS = 60_000;
const RATE_LIMIT = 60;
const rateBuckets = new Map();

class DeveloperApiError extends Error {
  constructor(code, statusCode, message = 'Developer API request failed.') {
    super(message);
    this.code = code;
    this.statusCode = statusCode;
  }
}

function fail(code, statusCode, message) {
  throw new DeveloperApiError(code, statusCode, message);
}

function asText(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function parseScopes(value) {
  if (!Array.isArray(value) || value.length === 0 || value.length > SUPPORTED_SCOPES.size) {
    fail('invalid_scope', 400, 'At least one supported scope is required.');
  }
  const scopes = [...new Set(value.map(asText))];
  if (scopes.some((scope) => !SUPPORTED_SCOPES.has(scope))) {
    fail('invalid_scope', 400, 'Unsupported developer API scope.');
  }
  return scopes.sort();
}

function createCredential({ name, scopes, expiresAt }) {
  const clientName = asText(name);
  if (!clientName || clientName.length > 120) fail('invalid_name', 400, 'Client name is invalid.');
  const expiration = new Date(expiresAt);
  if (Number.isNaN(expiration.getTime()) || expiration.getTime() <= Date.now()) {
    fail('invalid_expiry', 400, 'Credential expiry must be in the future.');
  }
  if (expiration.getTime() > Date.now() + 366 * 24 * 60 * 60 * 1000) {
    fail('invalid_expiry', 400, 'Credential expiry must be within one year.');
  }
  const clientId = crypto.randomBytes(18).toString('hex');
  const secret = crypto.randomBytes(32).toString('base64url');
  const salt = crypto.randomBytes(16).toString('base64url');
  return {
    clientId,
    secret: `zwh_${clientId}_${secret}`,
    record: {
      name: clientName,
      scopes: parseScopes(scopes),
      status: 'active',
      expiresAt: expiration,
      secretSalt: salt,
      secretHash: hashSecret(secret, salt),
      hashAlgorithm: 'pbkdf2-sha256',
      hashIterations: 310000,
      createdAt: new Date(),
    },
  };
}

function hashSecret(secret, salt) {
  return crypto.pbkdf2Sync(secret, salt, 310000, 32, 'sha256').toString('base64url');
}

function parseBearerCredential(header) {
  const bearer = asText(header).match(/^Bearer\s+(.+)$/i)?.[1] || '';
  const match = bearer.match(/^zwh_([a-f0-9]{36})_([A-Za-z0-9_-]{32,128})$/);
  if (!match) fail('unauthenticated', 401, 'Invalid integration credential.');
  return { clientId: match[1], secret: match[2] };
}

function hasScope(client, scope) {
  return Array.isArray(client?.scopes) && client.scopes.includes(scope);
}

function requireScope(client, scope) {
  if (!hasScope(client, scope)) fail('scope_denied', 403, 'Credential does not have this scope.');
}

function timestampToDate(value) {
  if (value && typeof value.toDate === 'function') return value.toDate();
  return value instanceof Date ? value : new Date(value);
}

function safeEqual(left, right) {
  const a = Buffer.from(String(left));
  const b = Buffer.from(String(right));
  return a.length === b.length && crypto.timingSafeEqual(a, b);
}

async function authenticateCredential({ db, authorization, environment = process.env }) {
  const { clientId, secret } = parseBearerCredential(authorization);
  const credential = `zwh_${clientId}_${secret}`;
  const environmentSecret = asText(environment?.ZAWOLF_DEVELOPER_API_SECRET);

  // A single environment credential is useful when the owner needs to grant
  // a read-only integration without first retrieving a Firebase ID token. It
  // deliberately grants only the public directory scope. Removing/rotating
  // the Hostinger environment value and restarting revokes it immediately.
  if (environmentSecret && safeEqual(credential, environmentSecret)) {
    return {
      clientId,
      client: {
        name: asText(environment?.ZAWOLF_DEVELOPER_API_CLIENT_NAME) || 'Hostinger environment integration',
        scopes: [DIRECTORY_READ_SCOPE],
        status: 'active',
        source: 'environment',
      },
      cursorKey: secret,
      source: 'environment',
    };
  }

  const snapshot = await db.collection('developerApiClients').doc(clientId).get();
  const client = snapshot.exists ? (snapshot.data() || {}) : null;
  if (!client || client.status !== 'active') fail('unauthenticated', 401, 'Invalid integration credential.');
  const expiresAt = timestampToDate(client.expiresAt);
  if (Number.isNaN(expiresAt.getTime()) || expiresAt.getTime() <= Date.now()) {
    fail('unauthenticated', 401, 'Invalid integration credential.');
  }
  const candidate = hashSecret(secret, String(client.secretSalt || ''));
  if (!safeEqual(candidate, client.secretHash || '')) {
    fail('unauthenticated', 401, 'Invalid integration credential.');
  }
  return { clientId, client, cursorKey: secret, source: 'stored' };
}

function opaqueId(value) {
  return asText(value);
}

function serializeDirectoryUser(id, raw = {}) {
  // Do not spread a Firestore user document here. This is the external-data
  // allowlist and protects salaries, auth data, devices, locations and tokens.
  return {
    id: opaqueId(id),
    employeeId: asText(raw.employeeId || raw.employeeCode || raw.employee_id),
    displayName: asText(raw.displayName || raw.name),
    department: asText(raw.department || raw.departmentName || raw.departmentId),
    position: asText(raw.position || raw.jobTitle || raw.title),
    managerId: opaqueId(raw.managerId),
    active: raw.isActive !== false,
  };
}

function encodeCursor(payload, key) {
  const body = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const signature = crypto.createHmac('sha256', key).update(body).digest('base64url');
  return `${body}.${signature}`;
}

function decodeCursor(cursor, key) {
  if (!cursor) return null;
  const [body, signature, extra] = String(cursor).split('.');
  if (!body || !signature || extra) fail('invalid_cursor', 400, 'Cursor is invalid.');
  const expected = crypto.createHmac('sha256', key).update(body).digest('base64url');
  if (!safeEqual(signature, expected)) fail('invalid_cursor', 400, 'Cursor is invalid.');
  try {
    const parsed = JSON.parse(Buffer.from(body, 'base64url').toString('utf8'));
    if (!parsed || parsed.v !== 1 || !asText(parsed.name) || !asText(parsed.id)) throw new Error('invalid');
    return parsed;
  } catch (_) {
    fail('invalid_cursor', 400, 'Cursor is invalid.');
  }
}

function parseLimit(value) {
  if (value == null || value === '') return 50;
  if (!/^\d+$/.test(String(value))) fail('invalid_limit', 400, 'Limit is invalid.');
  const limit = Number(value);
  if (limit < 1 || limit > MAX_PAGE_SIZE) fail('invalid_limit', 400, 'Limit is invalid.');
  return limit;
}

function allowRequest({ clientId, ip, now = Date.now() }) {
  const key = `${clientId}:${ip || 'unknown'}`;
  if (rateBuckets.size >= 10_000 && !rateBuckets.has(key)) {
    for (const [bucketKey, bucket] of rateBuckets) {
      if (now - bucket.startedAt >= RATE_WINDOW_MS) rateBuckets.delete(bucketKey);
    }
    // A full current window is intentionally rejected instead of allowing an
    // unbounded number of attacker-controlled client/IP keys into memory.
    if (rateBuckets.size >= 10_000) return false;
  }
  const bucket = rateBuckets.get(key) || { startedAt: now, count: 0 };
  if (now - bucket.startedAt >= RATE_WINDOW_MS) {
    bucket.startedAt = now;
    bucket.count = 0;
  }
  bucket.count += 1;
  rateBuckets.set(key, bucket);
  return bucket.count <= RATE_LIMIT;
}

function resetRateLimitsForTest() {
  rateBuckets.clear();
}

function requestId() {
  return crypto.randomBytes(12).toString('base64url');
}

function redactIp(ip) {
  return crypto.createHash('sha256').update(String(ip || '')).digest('base64url').slice(0, 16);
}

module.exports = {
  DIRECTORY_READ_SCOPE, DIRECTORY_INACTIVE_READ_SCOPE, MAX_PAGE_SIZE,
  DeveloperApiError, fail, parseScopes, createCredential, hashSecret,
  parseBearerCredential, authenticateCredential, hasScope, requireScope,
  serializeDirectoryUser, encodeCursor, decodeCursor, parseLimit, allowRequest,
  resetRateLimitsForTest, requestId, redactIp,
};
