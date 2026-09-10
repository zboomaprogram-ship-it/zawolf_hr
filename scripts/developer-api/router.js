const C = require('./common');
const { isHrOrAdmin } = require('../phase007-authorization');
const openApi = require('./openapi.json');

function timestamp(admin) {
  return admin.firestore.FieldValue.serverTimestamp();
}

function safeIsoDate(value) {
  const date = value?.toDate ? value.toDate() : value ? new Date(value) : null;
  return date && !Number.isNaN(date.getTime()) ? date.toISOString() : null;
}

function safeClient(clientId, data = {}) {
  return {
    id: clientId,
    name: String(data.name || ''),
    scopes: Array.isArray(data.scopes) ? data.scopes : [],
    status: String(data.status || 'revoked'),
    expiresAt: safeIsoDate(data.expiresAt),
    createdAt: safeIsoDate(data.createdAt),
    revokedAt: safeIsoDate(data.revokedAt),
  };
}

function requestIp(req) {
  return String(req.headers['x-forwarded-for'] || req.socket?.remoteAddress || '')
    .split(',')[0].trim();
}

async function audit({ db, admin, requestId, clientId, route, outcome, count = 0, req }) {
  // No credential, authorization header, request body, or raw IP is retained.
  await db.collection('developerApiAudit').doc(requestId).set({
    clientId: String(clientId || ''), route, outcome, count,
    ipHash: C.redactIp(requestIp(req)), createdAt: timestamp(admin),
  });
}

function sendError({ res, sendJson, requestId, error }) {
  const known = error instanceof C.DeveloperApiError;
  sendJson(res, known ? error.statusCode : 500, {
    ok: false,
    requestId,
    code: known ? error.code : 'temporary_unavailable',
    error: known ? error.message : 'Developer API is temporarily unavailable.',
  });
}

async function listUsers({ db, auth, url }) {
  const includeInactive = url.searchParams.get('active') === 'false';
  C.requireScope(auth.client, C.DIRECTORY_READ_SCOPE);
  if (includeInactive) C.requireScope(auth.client, C.DIRECTORY_INACTIVE_READ_SCOPE);
  const limit = C.parseLimit(url.searchParams.get('limit'));
  const cursor = C.decodeCursor(url.searchParams.get('cursor'), auth.cursorKey);
  const department = String(url.searchParams.get('department') || '').trim();
  if (department.length > 120) C.fail('invalid_filter', 400, 'Department filter is invalid.');

  let query = db.collection('users');
  if (!includeInactive) query = query.where('isActive', '==', true);
  if (department) query = query.where('department', '==', department);
  query = query.orderBy('displayName').orderBy('__name__').limit(limit + 1);
  if (cursor) query = query.startAfter(cursor.name, cursor.id);
  const snapshot = await query.get();
  const docs = snapshot.docs.slice(0, limit);
  const data = docs.map((doc) => C.serializeDirectoryUser(doc.id, doc.data()));
  // Array.prototype.at is unavailable in some Hostinger Node runtimes.
  const last = docs.length ? docs[docs.length - 1] : null;
  const nextCursor = snapshot.docs.length > limit && last
    ? C.encodeCursor({ v: 1, name: String(last.data().displayName || last.data().name || '').trim() || ' ', id: last.id }, auth.cursorKey)
    : null;
  return { data, nextCursor };
}

async function getUser({ db, auth, userId }) {
  C.requireScope(auth.client, C.DIRECTORY_READ_SCOPE);
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(userId)) C.fail('not_found', 404, 'User was not found.');
  const snapshot = await db.collection('users').doc(userId).get();
  if (!snapshot.exists) C.fail('not_found', 404, 'User was not found.');
  const raw = snapshot.data() || {};
  if (raw.isActive === false) C.requireScope(auth.client, C.DIRECTORY_INACTIVE_READ_SCOPE);
  return { data: C.serializeDirectoryUser(snapshot.id, raw), nextCursor: null };
}

async function authenticateExternal({ req, db, admin }) {
  const auth = await C.authenticateCredential({ db, authorization: req.headers.authorization });
  if (!C.allowRequest({ clientId: auth.clientId, ip: requestIp(req) })) {
    C.fail('rate_limited', 429, 'Rate limit exceeded.');
  }
  if (auth.source !== 'environment') {
    await db.collection('developerApiClients').doc(auth.clientId).set({
      lastUsedAt: timestamp(admin),
    }, { merge: true });
  }
  return auth;
}

async function handleAdmin({ req, res, url, db, admin, actor, readJsonBody, sendJson }) {
  const requestId = C.requestId();
  try {
    if (!actor || !isHrOrAdmin({ ...actor, active: true })) C.fail('access_denied', 403, 'Administrator access is required.');
    if (url.pathname === '/developer-api/v1/admin/clients' && req.method === 'POST') {
      const body = await readJsonBody(req, 8 * 1024);
      const credential = C.createCredential({ name: body.name, scopes: body.scopes, expiresAt: body.expiresAt });
      await db.collection('developerApiClients').doc(credential.clientId).create({
        ...credential.record, ownerUid: actor.uid, createdAt: timestamp(admin),
      });
      await audit({ db, admin, requestId, clientId: credential.clientId, route: 'admin/create', outcome: 'created', req });
      sendJson(res, 201, { ok: true, requestId, client: safeClient(credential.clientId, credential.record), secret: credential.secret });
      return true;
    }
    if (url.pathname === '/developer-api/v1/admin/clients' && req.method === 'GET') {
      const snapshot = await db.collection('developerApiClients').orderBy('createdAt', 'desc').limit(100).get();
      await audit({ db, admin, requestId, clientId: actor.uid, route: 'admin/list', outcome: 'listed', count: snapshot.docs.length, req });
      sendJson(res, 200, { ok: true, requestId, data: snapshot.docs.map((doc) => safeClient(doc.id, doc.data())) });
      return true;
    }
    const revoke = url.pathname.match(/^\/developer-api\/v1\/admin\/clients\/([a-f0-9]{36})\/revoke$/);
    if (revoke && req.method === 'POST') {
      const body = await readJsonBody(req, 4 * 1024);
      if (!String(body.reason || '').trim() || String(body.reason).trim().length > 500) C.fail('invalid_reason', 400, 'A revocation reason is required.');
      const ref = db.collection('developerApiClients').doc(revoke[1]);
      const existing = await ref.get();
      if (!existing.exists) C.fail('not_found', 404, 'Integration client was not found.');
      await ref.update({ status: 'revoked', revokedAt: timestamp(admin), revokedBy: actor.uid, revocationReason: String(body.reason).trim() });
      await audit({ db, admin, requestId, clientId: revoke[1], route: 'admin/revoke', outcome: 'revoked', req });
      sendJson(res, 200, { ok: true, requestId });
      return true;
    }
    return false;
  } catch (error) {
    await audit({ db, admin, requestId, clientId: actor?.uid, route: 'admin', outcome: error.code || 'failed', req }).catch(() => {});
    sendError({ res, sendJson, requestId, error });
    return true;
  }
}

async function handleDeveloperApiRequest({ req, res, url, db, admin, actor, readJsonBody, sendJson }) {
  if (url.pathname === '/developer-api/v1/openapi.json' && req.method === 'GET') {
    sendJson(res, 200, openApi);
    return;
  }
  if (url.pathname.startsWith('/developer-api/v1/admin/')) {
    return handleAdmin({ req, res, url, db, admin, actor, readJsonBody, sendJson });
  }
  const requestId = C.requestId();
  let auth;
  try {
    if (req.method !== 'GET') C.fail('not_found', 404, 'Route was not found.');
    auth = await authenticateExternal({ req, db, admin });
    let result;
    if (url.pathname === '/developer-api/v1/users') result = await listUsers({ db, auth, url });
    else {
      const match = url.pathname.match(/^\/developer-api\/v1\/users\/([A-Za-z0-9_-]{1,128})$/);
      if (!match) C.fail('not_found', 404, 'Route was not found.');
      result = await getUser({ db, auth, userId: match[1] });
    }
    await audit({ db, admin, requestId, clientId: auth.clientId, route: url.pathname, outcome: 'ok', count: Array.isArray(result.data) ? result.data.length : 1, req });
    sendJson(res, 200, { ok: true, requestId, ...result });
  } catch (error) {
    await audit({ db, admin, requestId, clientId: auth?.clientId, route: url.pathname, outcome: error.code || 'failed', req }).catch(() => {});
    sendError({ res, sendJson, requestId, error });
  }
}

module.exports = { handleDeveloperApiRequest, listUsers, getUser, safeClient };
