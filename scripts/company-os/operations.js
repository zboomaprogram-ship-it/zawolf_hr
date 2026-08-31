'use strict';

const { validatePageLimit, safeListEnvelope, redactPrivateFields } = require('./safe-errors');
const { stripPrivateNotes } = require('./private-notes');

const ALLOWED_TYPES = Object.freeze(['ticket', 'asset', 'license', 'request', 'employee']);
const COLLECTIONS = Object.freeze({
  ticket: 'companyOsTickets', asset: 'companyOsAssets', license: 'companyOsLicenses',
  request: 'administrativeRequests', employee: 'users',
});
const COMPANY_ROLES = new Set(['admin', 'super_admin', 'hr_admin']);

function invalidInput(message) {
  const error = new Error(message); error.code = 'invalid_input'; return error;
}

function optionalDate(value, field) {
  if (value == null || value === '') return null;
  const date = new Date(String(value));
  if (Number.isNaN(date.getTime())) throw invalidInput(`Invalid ${field}`);
  return date;
}

function normalizeOperationsQuery(input = {}) {
  const limit = validatePageLimit(input.limit || 25);
  const type = String(input.type || 'ticket').trim();
  if (!ALLOWED_TYPES.includes(type)) throw invalidInput('Unsupported type');
  const from = optionalDate(input.from, 'from');
  const to = optionalDate(input.to, 'to');
  if (from && to && from > to) throw invalidInput('Invalid date range');
  const cursor = String(input.cursor || '').trim();
  if (cursor && !/^[A-Za-z0-9_.:-]{1,128}$/.test(cursor)) throw invalidInput('Invalid cursor');
  return {
    limit, type,
    query: String(input.query || '').trim().slice(0, 120).toLocaleLowerCase('ar'),
    status: input.status ? String(input.status).trim().slice(0, 64) : null,
    departmentId: input.departmentId ? String(input.departmentId).trim().slice(0, 128) : null,
    from, to, cursor: cursor || null,
  };
}

function recordOwnerUid(record) {
  return record.requesterUid || record.userId || record.employeeUid || record.uid;
}

function recordInActorScope(actor, record) {
  if (!actor || actor.active !== true) return false;
  if (COMPANY_ROLES.has(actor.role)) return true;
  const ownerUid = recordOwnerUid(record);
  if (ownerUid === actor.uid || record.currentEmployeeUid === actor.uid) return true;
  if (actor.role === 'manager') return Array.isArray(actor.teamUserIds) && actor.teamUserIds.includes(ownerUid);
  if (actor.role === 'finance') return record.costBearing === true;
  if (['it_manager', 'it_support'].includes(actor.role)) {
    return Boolean(actor.departmentId) && actor.departmentId === String(record.departmentId || record.department || '');
  }
  return false;
}

function recordDate(record) {
  const value = record.updatedAt || record.submittedAt || record.createdAt || record.assignedAt;
  if (value && typeof value.toDate === 'function') return value.toDate();
  const date = value instanceof Date ? value : new Date(String(value || ''));
  return Number.isNaN(date.getTime()) ? null : date;
}

function matchesText(record, query) {
  if (!query) return true;
  return [record.subject, record.title, record.name, record.displayName, record.assetCode,
    record.employeeCode, record.employeeId, record.category]
    .map((value) => String(value || '')).join(' ').toLocaleLowerCase('ar').includes(query);
}

function safeProjection(type, record) {
  const id = String(record.id || '');
  const title = String(record.subject || record.title || record.name || record.displayName
    || record.assetCode || record.employeeCode || id).slice(0, 240);
  const safeSubtitle = String(record.status || record.category || record.department
    || record.departmentId || '').slice(0, 240);
  const routes = {
    ticket: `/company-os/it/tickets/${encodeURIComponent(id)}`,
    asset: `/company-os/it/assets/${encodeURIComponent(id)}`,
    license: `/company-os/it/licenses/${encodeURIComponent(id)}`,
    request: `/requests/operational/${encodeURIComponent(id)}`,
    employee: `/hr/employees/${encodeURIComponent(id)}`,
  };
  return { id, type, title, safeSubtitle, route: routes[type] };
}

function applySupportedFilters(query, filter) {
  let scoped = query;
  if (filter.type === 'request') scoped = scoped.where('category', '==', 'company_os');
  if (filter.status) scoped = scoped.where('status', '==', filter.status);
  if (filter.departmentId) scoped = scoped.where('departmentId', '==', filter.departmentId);
  return scoped;
}

async function applyCursor({ db, query, collection, cursor }) {
  if (!cursor) return query;
  const cursorSnapshot = await db.collection(collection).doc(cursor).get();
  if (!cursorSnapshot.exists) throw invalidInput('Unknown cursor');
  return query.startAfter(cursorSnapshot);
}

async function boundedSearch({ db, actor, input = {} }) {
  const filter = normalizeOperationsQuery(input);
  const collection = COLLECTIONS[filter.type];
  let query = applySupportedFilters(db.collection(collection), filter);
  query = await applyCursor({ db, query, collection, cursor: filter.cursor });
  const readLimit = Math.min(filter.limit * 3, 100);
  const snapshot = await query.limit(readLimit).get();
  const scoped = snapshot.docs
    .map((doc) => stripPrivateNotes({ id: doc.id, ...doc.data() }))
    .filter((record) => recordInActorScope(actor, record))
    .filter((record) => {
      const date = recordDate(record);
      return (!filter.from || (date && date >= filter.from)) && (!filter.to || (date && date <= filter.to));
    })
    .filter((record) => matchesText(record, filter.query));
  const items = scoped.slice(0, filter.limit).map((record) => safeProjection(filter.type, record));
  const nextCursor = snapshot.docs.length === readLimit ? snapshot.docs[snapshot.docs.length - 1].id : null;
  return safeListEnvelope({
    items, scope: actor.role, nextCursor,
    filters: { ...filter, from: filter.from?.toISOString() || null, to: filter.to?.toISOString() || null },
  });
}

function safeAuditProjection(record) {
  const clean = redactPrivateFields(stripPrivateNotes(record));
  return {
    id: String(clean.id || clean.operationId || ''),
    operationId: String(clean.operationId || clean.id || ''),
    actorUid: String(clean.actorUid || ''), actorRole: String(clean.actorRole || ''),
    action: String(clean.action || ''), targetType: String(clean.targetType || ''),
    targetId: String(clean.targetId || ''),
    safeBefore: redactPrivateFields(clean.safeBefore || {}),
    safeAfter: redactPrivateFields(clean.safeAfter || {}), createdAt: clean.createdAt || null,
  };
}

async function boundedAudit({ db, actor, input = {} }) {
  const limit = validatePageLimit(input.limit || 25);
  const cursor = String(input.cursor || '').trim() || null;
  if (cursor && !/^[A-Za-z0-9_.:-]{1,128}$/.test(cursor)) throw invalidInput('Invalid cursor');
  let query = db.collection('companyOsAuditEvents').orderBy('createdAt', 'desc');
  query = await applyCursor({ db, query, collection: 'companyOsAuditEvents', cursor });
  const readLimit = Math.min(limit * 3, 100);
  const snapshot = await query.limit(readLimit).get();
  const items = snapshot.docs.map((doc) => safeAuditProjection({ id: doc.id, ...doc.data() }))
    .filter((record) => COMPANY_ROLES.has(actor.role) || record.actorUid === actor.uid
      || (actor.role === 'it_manager' && ['ticket', 'asset', 'license'].includes(record.targetType)))
    .slice(0, limit);
  const nextCursor = snapshot.docs.length === readLimit ? snapshot.docs[snapshot.docs.length - 1].id : null;
  return safeListEnvelope({ items, scope: actor.role, filters: {}, nextCursor });
}

async function boundedReport({ db, actor, input = {} }) {
  const page = await boundedSearch({ db, actor, input });
  return { ...page, reportType: String(input.reportType || input.type || 'ticket').slice(0, 64) };
}

function csvCell(value) { return `"${String(value == null ? '' : value).replaceAll('"', '""')}"`; }
function safeCsv(items) {
  const columns = ['id', 'type', 'title', 'safeSubtitle', 'route'];
  return [columns.join(','), ...items.map((item) => columns.map((key) => csvCell(item[key])).join(','))].join('\n');
}

module.exports = {
  ALLOWED_TYPES, COLLECTIONS, normalizeOperationsQuery, recordInActorScope,
  safeProjection, safeAuditProjection, boundedSearch, boundedAudit, boundedReport, safeCsv,
};
