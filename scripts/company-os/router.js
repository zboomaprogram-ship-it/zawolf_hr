'use strict';

const crypto = require('node:crypto');
const { resolveActiveActor, authorizeCapability } = require('./authorization');
const { evaluateCompanyOsFlag } = require('./feature-flags');
const { safeFailure, redactPrivateFields } = require('./safe-errors');
const { safeListEnvelope, validatePageLimit, validateOperationEnvelope } = require('./safe-errors');
const { employeePortalSummary, publicTicket } = require('./employee-portal');
const { createEmployeeTicket, listOwnTickets, assignTicket, transitionTicket, addPrivateNote, addPublicComment, createFirestoreTicketStore } = require('./tickets');
const { createAsset, updateAsset, assignAssetOperation, returnAssetOperation, openMaintenanceOperation, retireAssetOperation, createFirestoreAssetStore } = require('./assets');
const { createLicense, updateLicense, assignSeatOperation, revokeSeatOperation, createFirestoreSoftwareStore } = require('./software');
const { resolveCompanyOwner } = require('./owner-policy');
const { createRequest, decideRequest, completeStage, createFirestoreRequestStore, publicRequest } = require('./requests');
const { completeAccessProvisioning } = require('./access-requests');
const { financialLedger, payslip } = require('./finance');
const { operationsDashboard } = require('./dashboard');
const { boundedSearch, boundedAudit, boundedReport, safeCsv } = require('./operations');
const { enforceRateLimit, validateAttachmentReferences } = require('./security');
const { requireOrganizationRead, requireOrganizationManage, requireOrganizationTreeManage } = require('./organization-authorization');
const { createUnit, renameUnit, reorderUnits, moveDepartment, setUnitArchived, canonicalHierarchy } = require('./organization-structure');
const { assignPrimaryManager } = require('./organization-managers');
const { previewMembershipChange, applyMembershipChange } = require('./organization-membership');
const { createOrganizationFirestoreStore } = require('./organization-firestore-store');
const {
  buildOrganizationTreeBootstrapPlan,
  applyOrganizationTreeBootstrap,
} = require('./migrate-organization-trees');
const {
  createTree,
  cloneTree,
  addTreeMemberships,
  setPrimaryTreeMembership,
  archiveTreeMembership,
  archiveTree,
  setTreeActive,
  setTreeLeadership,
} = require('./organization-trees');

function bearerToken(req) {
  const header = String(req.headers.authorization || '');
  return header.startsWith('Bearer ') ? header.slice(7).trim() : '';
}

function serialize(value) {
  if (Array.isArray(value)) return value.map(serialize);
  if (value && typeof value.toDate === 'function') return value.toDate().toISOString();
  if (value instanceof Date) return value.toISOString();
  if (!value || typeof value !== 'object') return value;
  return Object.fromEntries(Object.entries(value).map(([key, child]) => [key, serialize(child)]));
}

function portalEnabled(flagConfig, actor) {
  return evaluateCompanyOsFlag('company_os_portal_v1', flagConfig, actor.uid).enabled;
}

function sliceEnabled(name, flagConfig, actor) {
  return evaluateCompanyOsFlag(name, flagConfig, actor.uid).enabled;
}

function denyUnless(actor, capability) {
  if (!authorizeCapability({ actor, capability })) { const error = new Error('Denied'); error.code = 'access_denied'; throw error; }
}

async function operationBody(req, readJsonBody) {
  if (typeof readJsonBody !== 'function') { const error = new Error('Body reader missing'); error.code = 'temporary_unavailable'; throw error; }
  const body = await readJsonBody(req, 16 * 1024);
  validateAttachmentReferences(body);
  const envelope = validateOperationEnvelope({ operationId: body.operationId || req.headers['x-operation-id'], expectedVersion: body.expectedVersion });
  return { ...body, ...envelope };
}

function docs(snapshot) { return snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() })); }

async function organizationBootstrapPlan(db) {
  const [divisions, departments, users, units, trees, memberships] = await Promise.all([
    db.collection('organization_divisions').orderBy('__name__').limit(500).get(),
    db.collection('departments').orderBy('__name__').limit(500).get(),
    db.collection('users').orderBy('__name__').limit(500).get(),
    db.collection('companyOsOrganizationUnits').orderBy('__name__').limit(500).get(),
    db.collection('companyOsOrganizationTrees').orderBy('order', 'asc').limit(100).get(),
    db.collection('companyOsOrganizationMemberships').orderBy('__name__').limit(500).get(),
  ]);
  return buildOrganizationTreeBootstrapPlan({
    divisions: docs(divisions),
    departments: docs(departments),
    users: docs(users),
    existingUnits: docs(units),
    existingTrees: docs(trees),
    existingMemberships: docs(memberships),
  });
}

function requestAttachmentIdFor(actorUid, operationId) {
  return `ora_${crypto.createHash('sha256').update(`${actorUid}:${operationId}`).digest('hex').slice(0, 32)}`;
}

async function assertRequestAttachmentOwnership({ db, actor, input }) {
  const references = validateAttachmentReferences(input);
  if (!references.length) return references;
  const documents = await db.getAll(...references.map((reference) =>
    db.collection('companyOsRequestAttachments').doc(reference.id)));
  if (documents.some((document, index) => !document.exists ||
      document.data()?.uploaderUid !== actor.uid ||
      document.data()?.status !== 'uploaded' ||
      document.data()?.displayName !== references[index].displayName ||
      document.data()?.contentType !== references[index].contentType ||
      Number(document.data()?.sizeBytes) !== references[index].sizeBytes)) {
    const error = new Error('Attachment unavailable'); error.code = 'access_denied'; throw error;
  }
  return references;
}

async function routeCompanyOsRequest({ req, res, url, db, verifyToken, flagConfig = {}, sendJson, readJsonBody, uploadRequestAttachment }) {
  if (!url.pathname.startsWith('/company-os/')) return false;
  try {
    const token = bearerToken(req);
    if (!token) {
      sendJson(res, 401, safeFailure({ code: 'session_expired' }));
      return true;
    }
    const decoded = await verifyToken(token);
    const actor = await resolveActiveActor({ db, uid: decoded.uid });
    if (!actor) {
      sendJson(res, 403, safeFailure({ code: 'access_denied' }));
      return true;
    }
    enforceRateLimit({ actorUid: actor.uid, route: url.pathname });
    if (url.pathname === '/company-os/me' && req.method === 'GET') {
      const flags = Object.fromEntries(
        ['company_os_portal_v1', 'company_os_it_v1', 'company_os_requests_v1', 'company_os_operations_v1', 'company_os_organization_v1', 'company_os_multi_tree_v1']
          .map((name) => [name, evaluateCompanyOsFlag(name, flagConfig, actor.uid).enabled]),
      );
      sendJson(res, 200, { ok: true, actor: redactPrivateFields(actor), flags });
      return true;
    }
    if (url.pathname === '/company-os/requests/attachments' && req.method === 'POST') {
      if (!sliceEnabled('company_os_requests_v1', flagConfig, actor)) {
        sendJson(res, 404, { ok: false, code: 'feature_disabled' });
        return true;
      }
      const body = await readJsonBody(req, 15 * 1024 * 1024);
      const operationId = String(body.operationId || req.headers['x-operation-id'] || '').trim();
      const displayName = String(body.displayName || body.name || '').trim();
      const contentType = String(body.contentType || body.mimeType || '').trim().toLowerCase();
      const contentsBase64 = String(body.contentsBase64 || '').trim();
      if (!/^[A-Za-z0-9_.:-]{1,128}$/.test(operationId) || !displayName || displayName.length > 240 ||
          !/^[a-z0-9.+-]+\/[a-z0-9.+-]+$/.test(contentType) || !contentsBase64 ||
          contentsBase64.length > 14 * 1024 * 1024 || typeof uploadRequestAttachment !== 'function') {
        const error = new Error('Invalid attachment'); error.code = 'invalid_input'; throw error;
      }
      const resourceId = requestAttachmentIdFor(actor.uid, operationId);
      const attachment = await uploadRequestAttachment({
        db, actor, resourceId, payload: { displayName, contentType, contentsBase64 },
      });
      sendJson(res, 200, { ok: true, data: attachment });
      return true;
    }
    const isItTicketRead = url.pathname === '/company-os/tickets' && req.method === 'GET'
      && url.searchParams.get('scope') !== 'self'
      && authorizeCapability({ actor, capability: 'manage_tickets' });
    const isItRoute = isItTicketRead
      || /^\/company-os\/(?:it\/|assets(?:\/|$)|licenses(?:\/|$))/.test(url.pathname)
      || /\/(?:assign|transition|private-notes)$/.test(url.pathname)
      || (/\/comments$/.test(url.pathname) && authorizeCapability({ actor, capability: 'manage_tickets' }));
    const isRequestRoute = /^\/company-os\/(?:requests|finance)(?:\/|$)/.test(url.pathname);
    const isOperationsRoute = /^\/company-os\/operations(?:\/|$)/.test(url.pathname);
    const isOrganizationRoute = /^\/company-os\/organization(?:\/|$)/.test(url.pathname);
    const requiredFlag = isItRoute
      ? 'company_os_it_v1'
      : isRequestRoute
        ? 'company_os_requests_v1'
        : isOperationsRoute ? 'company_os_operations_v1'
          : isOrganizationRoute ? 'company_os_organization_v1' : 'company_os_portal_v1';
    if (!sliceEnabled(requiredFlag, flagConfig, actor)) {
      sendJson(res, 404, { ok: false, code: 'feature_disabled', message: 'هذه الميزة غير مفعلة حالياً.' });
      return true;
    }

    if (url.pathname === '/company-os/me/summary' && req.method === 'GET') {
      const [tickets, assets, requests] = await Promise.all([
        db.collection('companyOsTickets').where('requesterUid', '==', actor.uid).limit(100).get(),
        db.collection('companyOsAssets').where('currentEmployeeUid', '==', actor.uid).limit(100).get(),
        db.collection('administrativeRequests').where('requesterUid', '==', actor.uid).limit(100).get(),
      ]);
      sendJson(res, 200, { ok: true, data: employeePortalSummary({
        tickets: tickets.docs.map((doc) => doc.data()),
        assets: assets.docs.map((doc) => doc.data()),
        requests: requests.docs.map((doc) => doc.data()),
        actorUid: actor.uid,
      }) });
      return true;
    }

    if (isOrganizationRoute) {
      requireOrganizationRead(actor);
      const isMultiTreeRoute = /^\/company-os\/organization\/(?:trees|tree-memberships|bootstrap)(?:\/|$)/.test(url.pathname);
      if (isMultiTreeRoute && !sliceEnabled('company_os_multi_tree_v1', flagConfig, actor)) {
        sendJson(res, 404, { ok: false, code: 'feature_disabled', message: 'إدارة الأشجار التنظيمية غير مفعلة حالياً.' });
        return true;
      }
      const store = createOrganizationFirestoreStore(db);
      const operationStatusMatch = url.pathname.match(
        /^\/company-os\/organization\/operations\/([A-Za-z0-9_.:-]{1,128})$/,
      );
      if (operationStatusMatch && req.method === 'GET') {
        requireOrganizationManage(actor);
        const snapshot = await db
          .collection('companyOsOperationReceipts')
          .doc(operationStatusMatch[1])
          .get();
        const receipt = snapshot.exists ? snapshot.data() : null;
        if (!receipt || receipt.actorUid !== actor.uid) {
          sendJson(res, 200, { ok: true, data: null });
          return true;
        }
        sendJson(res, 200, { ok: true, data: serialize(receipt.result) });
        return true;
      }
      if (url.pathname === '/company-os/organization/trees' && req.method === 'GET') {
        const limit = validatePageLimit(url.searchParams.get('limit') || 25);
        const includeArchived = url.searchParams.get('includeArchived') === 'true';
        const snapshot = await db.collection('companyOsOrganizationTrees').orderBy('order', 'asc').limit(Math.min(limit, 100)).get();
        const items = docs(snapshot).filter((tree) => includeArchived || tree.status !== 'archived');
        sendJson(res, 200, safeListEnvelope({ items: serialize(items), scope: 'authorized', filters: { includeArchived } }));
        return true;
      }
      if (url.pathname === '/company-os/organization/trees' && req.method === 'POST') {
        requireOrganizationManage(actor);
        const body = await operationBody(req, readJsonBody);
        sendJson(res, 200, serialize(await createTree({ store, actor, operationId: body.operationId, input: body })));
        return true;
      }
      if (url.pathname === '/company-os/organization/bootstrap/preview' && req.method === 'GET') {
        requireOrganizationManage(actor);
        const plan = await organizationBootstrapPlan(db);
        sendJson(res, 200, { ok: true, data: serialize(plan) });
        return true;
      }
      if (url.pathname === '/company-os/organization/bootstrap/apply' && req.method === 'POST') {
        requireOrganizationManage(actor);
        const body = await operationBody(req, readJsonBody);
        const plan = await organizationBootstrapPlan(db);
        const result = await applyOrganizationTreeBootstrap({
          db,
          plan,
          approvedFingerprint: body.approvedFingerprint,
        });
        await db.collection('companyOsMigrationReceipts').doc(body.operationId).set({
          actorUid: actor.uid,
          operationType: 'organization_tree_bootstrap',
          fingerprint: plan.fingerprint,
          result: { applied: true, summary: result.summary },
          createdAt: new Date(),
        }, { merge: true });
        sendJson(res, 200, { ok: true, operationId: body.operationId, data: serialize(result) });
        return true;
      }
      const treeSnapshotMatch = url.pathname.match(/^\/company-os\/organization\/trees\/([A-Za-z0-9_.:-]{1,128})\/snapshot$/);
      if (treeSnapshotMatch && req.method === 'GET') {
        const treeId = treeSnapshotMatch[1];
        // Viewing an organization tree is available to every active employee;
        // editing remains protected by requireOrganizationTreeManage on all
        // mutation routes. HR users were incorrectly denied read access here.
        requireOrganizationRead(actor);
        const limit = validatePageLimit(url.searchParams.get('limit') || 100);
        const [treeDocument, unitSnapshot, membershipSnapshot] = await Promise.all([
          db.collection('companyOsOrganizationTrees').doc(treeId).get(),
          db.collection('companyOsOrganizationUnits').where('treeId', '==', treeId).limit(Math.min(limit, 500)).get(),
          db.collection('companyOsOrganizationMemberships').where('treeId', '==', treeId).limit(Math.min(limit, 500)).get(),
        ]);
        if (!treeDocument.exists) { const error = new Error('Unknown tree'); error.code = 'invalid_input'; throw error; }
        const memberships = docs(membershipSnapshot);
        const employeeIds = [...new Set(memberships.map((membership) => String(membership.employeeUid || '')).filter(Boolean))];
        // `getAll` is available on the production Firestore client. Keep the
        // snapshot readable for lightweight/emulator stores that do not expose
        // it; the memberships are still returned, just without profile labels.
        const employeeDocuments = employeeIds.length && typeof db.getAll === 'function'
          ? await db.getAll(...employeeIds.map((uid) => db.collection('users').doc(uid)))
          : [];
        const employeesById = new Map(employeeDocuments.filter((document) => document.exists).map((document) => [document.id, document.data()]));
        const enrichedMemberships = memberships.map((membership) => {
          const employee = employeesById.get(String(membership.employeeUid || '')) || {};
          return {
            ...membership,
            employeeName: employee.name || employee.displayName || '',
            employeeCode: employee.employeeId || employee.code || '',
          };
        });
        sendJson(res, 200, { ok: true, data: serialize({ tree: { id: treeDocument.id, ...treeDocument.data() }, units: docs(unitSnapshot), memberships: enrichedMemberships }) });
        return true;
      }
      const cloneTreeMatch = url.pathname.match(/^\/company-os\/organization\/trees\/([A-Za-z0-9_.:-]{1,128})\/clone$/);
      if (cloneTreeMatch && req.method === 'POST') {
        const body = await operationBody(req, readJsonBody);
        sendJson(res, 200, serialize(await cloneTree({ store, actor, operationId: body.operationId, sourceTreeId: cloneTreeMatch[1], input: body })));
        return true;
      }
      const treeMembershipsMatch = url.pathname.match(/^\/company-os\/organization\/trees\/([A-Za-z0-9_.:-]{1,128})\/memberships$/);
      if (treeMembershipsMatch && req.method === 'POST') {
        const body = await operationBody(req, readJsonBody);
        sendJson(res, 200, serialize(await addTreeMemberships({ store, actor, operationId: body.operationId, treeId: treeMembershipsMatch[1], unitId: body.unitId, employeeUids: body.employeeUids, directManagerUid: body.directManagerUid, title: body.title })));
        return true;
      }
      const primaryMembershipMatch = url.pathname.match(/^\/company-os\/organization\/tree-memberships\/([A-Za-z0-9_.:-]{1,128})\/primary$/);
      if (primaryMembershipMatch && req.method === 'POST') {
        const body = await operationBody(req, readJsonBody);
        sendJson(res, 200, serialize(await setPrimaryTreeMembership({ store, actor, operationId: body.operationId, membershipId: primaryMembershipMatch[1], expectedVersion: body.expectedVersion })));
        return true;
      }
      const archiveMembershipMatch = url.pathname.match(/^\/company-os\/organization\/tree-memberships\/([A-Za-z0-9_.:-]{1,128})\/archive$/);
      if (archiveMembershipMatch && req.method === 'POST') {
        const body = await operationBody(req, readJsonBody);
        sendJson(res, 200, serialize(await archiveTreeMembership({ store, actor, operationId: body.operationId, membershipId: archiveMembershipMatch[1], expectedVersion: body.expectedVersion })));
        return true;
      }
      const archiveTreeMatch = url.pathname.match(/^\/company-os\/organization\/trees\/([A-Za-z0-9_.:-]{1,128})\/archive$/);
      if (archiveTreeMatch && req.method === 'POST') {
        const body = await operationBody(req, readJsonBody);
        sendJson(res, 200, serialize(await archiveTree({ store, actor, operationId: body.operationId, treeId: archiveTreeMatch[1], expectedVersion: body.expectedVersion })));
        return true;
      }
      const activateTreeMatch = url.pathname.match(/^\/company-os\/organization\/trees\/([A-Za-z0-9_.:-]{1,128})\/(?:activate|restore)$/);
      if (activateTreeMatch && req.method === 'POST') {
        const body = await operationBody(req, readJsonBody);
        sendJson(res, 200, serialize(await setTreeActive({ store, actor, operationId: body.operationId, treeId: activateTreeMatch[1], expectedVersion: body.expectedVersion })));
        return true;
      }
      const leadershipMatch = url.pathname.match(/^\/company-os\/organization\/trees\/([A-Za-z0-9_.:-]{1,128})\/leadership$/);
      if (leadershipMatch && req.method === 'POST') {
        const body = await operationBody(req, readJsonBody);
        sendJson(res, 200, serialize(await setTreeLeadership({ store, actor, operationId: body.operationId, treeId: leadershipMatch[1], rootLeaderUid: body.rootLeaderUid, treeAdminUids: body.treeAdminUids, expectedVersion: body.expectedVersion })));
        return true;
      }
      if (url.pathname === '/company-os/organization/hierarchy' && req.method === 'GET') {
        const limit = validatePageLimit(url.searchParams.get('limit') || 100);
        const includeArchived = url.searchParams.get('includeArchived') === 'true';
        const cursor = String(url.searchParams.get('cursor') || '').trim();
        if (cursor && !/^[A-Za-z0-9_.:-]{1,128}$/.test(cursor)) { const error = new Error('Invalid cursor'); error.code = 'invalid_input'; throw error; }
        let query = db.collection('companyOsOrganizationUnits').orderBy('order', 'asc');
        if (cursor) {
          const cursorDocument = await db.collection('companyOsOrganizationUnits').doc(cursor).get();
          if (!cursorDocument.exists) { const error = new Error('Unknown cursor'); error.code = 'invalid_input'; throw error; }
          query = query.startAfter(cursorDocument);
        }
        const snapshot = await query.limit(limit).get();
        const items = canonicalHierarchy(docs(snapshot)).filter((unit) => includeArchived || unit.archived !== true);
        const nextCursor = snapshot.docs.length === limit ? snapshot.docs[snapshot.docs.length - 1].id : null;
        sendJson(res, 200, safeListEnvelope({ items: serialize(items), nextCursor, scope: actor.role === 'employee' ? 'self' : 'authorized', filters: { includeArchived } }));
        return true;
      }
      if (url.pathname === '/company-os/organization/employees' && req.method === 'GET') {
        const limit = validatePageLimit(url.searchParams.get('limit') || 25);
        const queryText = String(url.searchParams.get('query') || '').trim().toLocaleLowerCase('ar');
        const cursor = String(url.searchParams.get('cursor') || '').trim();
        if (cursor && !/^[A-Za-z0-9_.:-]{1,128}$/.test(cursor)) { const error = new Error('Invalid cursor'); error.code = 'invalid_input'; throw error; }
        let query = db.collection('users').where('isActive', '==', true).orderBy('__name__');
        if (cursor) {
          const cursorDocument = await db.collection('users').doc(cursor).get();
          if (!cursorDocument.exists) { const error = new Error('Unknown cursor'); error.code = 'invalid_input'; throw error; }
          query = query.startAfter(cursorDocument);
        }
        const readLimit = Math.min(limit * 2, 100);
        const snapshot = await query.limit(readLimit).get();
        const items = docs(snapshot).filter((user) => !queryText || `${user.name || ''} ${user.email || ''} ${user.employeeId || user.code || ''}`.toLocaleLowerCase('ar').includes(queryText)).slice(0, limit).map((user) => ({ uid: user.id, name: user.name || user.displayName || '', employeeId: user.employeeId || user.code || '', departmentUnitId: user.departmentUnitId || null, directManagerId: user.directManagerId || null }));
        const nextCursor = snapshot.docs.length === readLimit ? snapshot.docs[snapshot.docs.length - 1].id : null;
        sendJson(res, 200, safeListEnvelope({ items: serialize(items), nextCursor, scope: 'authorized', filters: { query: queryText } })); return true;
      }
      if (url.pathname === '/company-os/organization/impact-preview' && req.method === 'POST') {
        requireOrganizationManage(actor); const body = await operationBody(req, readJsonBody);
        sendJson(res, 200, serialize(await previewMembershipChange({ store, actor, employeeUids: body.employeeUids, destinationDepartmentId: body.destinationDepartmentId, directManagerUid: body.directManagerUid }))); return true;
      }
      if (url.pathname === '/company-os/organization/units' && req.method === 'POST') {
        requireOrganizationManage(actor); const body = await operationBody(req, readJsonBody);
        sendJson(res, 200, serialize(await createUnit({ store, actor, operationId: body.operationId, input: body }))); return true;
      }
      if (url.pathname === '/company-os/organization/reorder' && req.method === 'POST') {
        requireOrganizationManage(actor); const body = await operationBody(req, readJsonBody);
        sendJson(res, 200, serialize(await reorderUnits({ store, actor, operationId: body.operationId, parentId: body.parentId, orderedIds: body.orderedIds }))); return true;
      }
      if (url.pathname === '/company-os/organization/memberships' && req.method === 'POST') {
        requireOrganizationManage(actor); const body = await operationBody(req, readJsonBody);
        sendJson(res, 200, serialize(await applyMembershipChange({ store, actor, operationId: body.operationId, employeeUids: body.employeeUids, destinationDepartmentId: body.destinationDepartmentId, sourceDepartmentId: body.sourceDepartmentId, directManagerUid: body.directManagerUid, expectedVersion: body.expectedVersion }))); return true;
      }
      const organizationUnitAction = url.pathname.match(/^\/company-os\/organization\/units\/([A-Za-z0-9_.:-]{1,128})\/(rename|move|archive|restore|manager)$/);
      if (organizationUnitAction && req.method === 'POST') {
        requireOrganizationManage(actor); const body = await operationBody(req, readJsonBody);
        const common = { store, actor, operationId: body.operationId, unitId: organizationUnitAction[1], expectedVersion: body.expectedVersion };
        const action = organizationUnitAction[2];
        const result = action === 'rename' ? await renameUnit({ ...common, name: body.name })
          : action === 'move' ? await moveDepartment({ ...common, destinationSectorId: body.destinationSectorId })
          : action === 'manager' ? await assignPrimaryManager({ ...common, managerUid: body.managerUid })
            : await setUnitArchived({ ...common, archived: action === 'archive' });
        sendJson(res, 200, serialize(result)); return true;
      }
    }

    if (url.pathname === '/company-os/tickets' && req.method === 'GET') {
      const limit = validatePageLimit(url.searchParams.get('limit') || 25);
      if (sliceEnabled('company_os_it_v1', flagConfig, actor) && authorizeCapability({ actor, capability: 'manage_tickets' }) && url.searchParams.get('scope') !== 'self') {
        let query = db.collection('companyOsTickets').orderBy('updatedAt', 'desc').limit(limit);
        const status = String(url.searchParams.get('status') || '').trim();
        if (status) query = db.collection('companyOsTickets').where('status', '==', status).orderBy('updatedAt', 'desc').limit(limit);
        const snapshot = await query.get();
        sendJson(res, 200, safeListEnvelope({ items: serialize(docs(snapshot).map(publicTicket)), scope: 'company', filters: { status: status || null } }));
        return true;
      }
      const result = await listOwnTickets({ store: createFirestoreTicketStore(db), actor, limit, cursor: url.searchParams.get('cursor') });
      sendJson(res, 200, safeListEnvelope({ items: serialize(result.items), scope: 'self', nextCursor: result.nextCursor, filters: { scope: 'self' } }));
      return true;
    }

    if (url.pathname === '/company-os/tickets' && req.method === 'POST') {
      if (typeof readJsonBody !== 'function') { const error = new Error('Body reader missing'); error.code = 'temporary_unavailable'; throw error; }
      const body = await readJsonBody(req, 8 * 1024);
      validateAttachmentReferences(body);
      const envelope = validateOperationEnvelope({ operationId: body.operationId || req.headers['x-operation-id'] });
      const result = await createEmployeeTicket({ store: createFirestoreTicketStore(db), actor, operationId: envelope.operationId, input: body });
      sendJson(res, 200, serialize(result));
      return true;
    }

    const ticketMatch = url.pathname.match(/^\/company-os\/tickets\/([A-Za-z0-9_.:-]{1,128})$/);
    if (ticketMatch && req.method === 'GET') {
      const snapshot = await db.collection('companyOsTickets').doc(ticketMatch[1]).get();
      const ticket = snapshot.exists ? { id: snapshot.id, ...snapshot.data() } : null;
      const canManage = sliceEnabled('company_os_it_v1', flagConfig, actor) && authorizeCapability({ actor, capability: 'manage_tickets' });
      if (!ticket || (ticket.requesterUid !== actor.uid && !canManage)) {
        sendJson(res, 404, { ok: false, code: 'access_denied', message: 'التذكرة غير متاحة.' });
        return true;
      }
      sendJson(res, 200, { ok: true, data: serialize(publicTicket(ticket)) });
      return true;
    }

    const ticketActionMatch = url.pathname.match(/^\/company-os\/tickets\/([A-Za-z0-9_.:-]{1,128})\/(assign|transition|private-notes)$/);
    if (ticketActionMatch && req.method === 'POST') {
      denyUnless(actor, 'manage_tickets');
      const body = await operationBody(req, readJsonBody);
      const store = createFirestoreTicketStore(db);
      const common = { store, actor, operationId: body.operationId, ticketId: ticketActionMatch[1], expectedVersion: body.expectedVersion };
      const result = ticketActionMatch[2] === 'assign'
        ? await assignTicket({ ...common, assigneeUid: body.assigneeUid })
        : ticketActionMatch[2] === 'transition'
          ? await transitionTicket({ ...common, status: body.status, resolutionSummary: body.resolutionSummary })
          : await addPrivateNote({ ...common, body: body.body });
      sendJson(res, 200, serialize(result));
      return true;
    }
    const privateNotesMatch = url.pathname.match(/^\/company-os\/tickets\/([A-Za-z0-9_.:-]{1,128})\/private-notes$/);
    if (privateNotesMatch && req.method === 'GET') {
      denyUnless(actor, 'manage_tickets'); const limit = validatePageLimit(url.searchParams.get('limit') || 25);
      const snapshot = await db.collection('companyOsTicketPrivateNotes').where('ticketId', '==', privateNotesMatch[1]).orderBy('createdAt', 'desc').limit(limit).get();
      sendJson(res, 200, safeListEnvelope({ items: serialize(docs(snapshot)), scope: 'it_private', filters: { ticketId: privateNotesMatch[1] } })); return true;
    }

    const commentMatch = url.pathname.match(/^\/company-os\/tickets\/([A-Za-z0-9_.:-]{1,128})\/comments$/);
    if (commentMatch && req.method === 'POST') {
      const body = await operationBody(req, readJsonBody);
      const result = await addPublicComment({ store: createFirestoreTicketStore(db), actor, operationId: body.operationId, ticketId: commentMatch[1], expectedVersion: body.expectedVersion, body: body.body });
      sendJson(res, 200, serialize(result));
      return true;
    }

    if (url.pathname === '/company-os/knowledge' && req.method === 'GET') {
      const limit = validatePageLimit(url.searchParams.get('limit') || 25);
      const queryText = String(url.searchParams.get('query') || '').trim().toLocaleLowerCase('ar');
      const snapshot = await db.collection('companyOsKnowledge').where('published', '==', true).limit(Math.min(limit * 2, 100)).get();
      const items = snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() })).filter((item) => !queryText || `${item.title || ''} ${item.category || ''} ${item.content || ''}`.toLocaleLowerCase('ar').includes(queryText)).slice(0, limit);
      sendJson(res, 200, safeListEnvelope({ items: serialize(items), scope: 'published', filters: { query: queryText } }));
      return true;
    }

    if (url.pathname === '/company-os/requests' && req.method === 'GET') {
      const limit = validatePageLimit(url.searchParams.get('limit') || 25);
      const canManage = authorizeCapability({ actor, capability: 'manage_requests' });
      const selfOnly = !canManage || url.searchParams.get('scope') === 'self';
      let appliedScope = 'self';
      let query = db.collection('administrativeRequests').where('requesterUid', '==', actor.uid).where('category', '==', 'company_os').orderBy('submittedAt', 'desc').limit(limit);
      if (!selfOnly && ['admin', 'super_admin', 'hr_admin'].includes(actor.role)) {
        appliedScope = 'company';
        query = db.collection('administrativeRequests').where('category', '==', 'company_os').orderBy('submittedAt', 'desc').limit(limit);
      } else if (!selfOnly && actor.role === 'manager') {
        appliedScope = 'team';
        query = db.collection('administrativeRequests').where('managerIds', 'array-contains', actor.uid).where('category', '==', 'company_os').orderBy('submittedAt', 'desc').limit(limit);
      } else if (!selfOnly && actor.role === 'finance') {
        appliedScope = 'finance';
        query = db.collection('administrativeRequests').where('costBearing', '==', true).where('category', '==', 'company_os').orderBy('submittedAt', 'desc').limit(limit);
      } else if (!selfOnly && actor.role === 'it_manager') {
        appliedScope = 'specialist';
        query = db.collection('administrativeRequests').where('specialistRole', '==', 'it_manager').where('category', '==', 'company_os').orderBy('submittedAt', 'desc').limit(limit);
      }
      const snapshot = await query.get();
      sendJson(res, 200, safeListEnvelope({ items: serialize(docs(snapshot).map(publicRequest)), scope: appliedScope, filters: {} }));
      return true;
    }
    if (url.pathname === '/company-os/requests' && req.method === 'POST') {
      const body = await operationBody(req, readJsonBody);
      const ownerPolicy = await resolveCompanyOwner(db);
      const attachments = await assertRequestAttachmentOwnership({ db, actor, input: body });
      const result = await createRequest({ store: createFirestoreRequestStore(db), actor, operationId: body.operationId, input: { ...body, attachments }, ownerPolicy });
      sendJson(res, 200, serialize(result));
      return true;
    }
    const requestReadMatch = url.pathname.match(/^\/company-os\/requests\/([A-Za-z0-9_.:-]{1,128})$/);
    if (requestReadMatch && req.method === 'GET') {
      const snapshot = await db.collection('administrativeRequests').doc(requestReadMatch[1]).get();
      const request = snapshot.exists ? { id: snapshot.id, ...snapshot.data() } : null;
      const isRequester = request && (request.requesterUid === actor.uid || request.userId === actor.uid);
      const isCompanyReviewer = request && ['admin', 'super_admin', 'hr_admin'].includes(actor.role);
      const isAssignedManager = request && actor.role === 'manager' && Array.isArray(request.managerIds) && request.managerIds.includes(actor.uid);
      const isFinanceReviewer = request && actor.role === 'finance' && request.costBearing === true;
      const isSpecialistReviewer = request && actor.role === 'it_manager' && request.specialistRole === 'it_manager';
      if (!request || !(isRequester || isCompanyReviewer || isAssignedManager || isFinanceReviewer || isSpecialistReviewer)) {
        sendJson(res, 404, { ok: false, code: 'access_denied', message: 'الطلب غير متاح.' });
        return true;
      }
      sendJson(res, 200, { ok: true, data: serialize(publicRequest(request)) });
      return true;
    }
    const requestActionMatch = url.pathname.match(/^\/company-os\/requests\/([A-Za-z0-9_.:-]{1,128})\/(decision|payment|closure|provisioning)$/);
    if (requestActionMatch && req.method === 'POST') {
      const body = await operationBody(req, readJsonBody);
      const common = { store: createFirestoreRequestStore(db), actor, operationId: body.operationId, requestId: requestActionMatch[1], expectedVersion: body.expectedVersion };
      const action = requestActionMatch[2];
      const result = action === 'decision'
        ? await decideRequest({ ...common, approved: body.approved, reason: body.reason })
        : action === 'provisioning'
          ? await completeAccessProvisioning({ ...common, note: body.note })
          : await completeStage({ ...common, stageType: action, details: { reference: String(body.reference || body.note || '').trim().slice(0, 1000) } });
      sendJson(res, 200, serialize(result));
      return true;
    }
    if (url.pathname === '/company-os/finance/ledger' && req.method === 'GET') {
      if (actor.role !== 'employee') denyUnless(actor, 'review_finance');
      sendJson(res, 200, serialize(await financialLedger({ db, actor, query: Object.fromEntries(url.searchParams.entries()) })));
      return true;
    }
    if (url.pathname === '/company-os/finance/payslip' && req.method === 'GET') {
      if (actor.role !== 'employee') denyUnless(actor, 'review_finance');
      sendJson(res, 200, serialize(await payslip({ db, actor, employeeUid: url.searchParams.get('employeeUid'), period: url.searchParams.get('period') })));
      return true;
    }

    if (isOperationsRoute && req.method === 'GET') {
      denyUnless(actor, 'view_operations');
      const input = Object.fromEntries(url.searchParams.entries());
      if (url.pathname === '/company-os/operations/dashboard') {
        sendJson(res, 200, { ok: true, data: serialize(await operationsDashboard({ db, actor })) });
        return true;
      }
      if (url.pathname === '/company-os/operations/search') {
        sendJson(res, 200, serialize(await boundedSearch({ db, actor, input })));
        return true;
      }
      if (url.pathname === '/company-os/operations/report') {
        sendJson(res, 200, serialize(await boundedReport({ db, actor, input })));
        return true;
      }
      if (url.pathname === '/company-os/operations/audit') {
        sendJson(res, 200, serialize(await boundedAudit({ db, actor, input })));
        return true;
      }
      if (url.pathname === '/company-os/operations/export') {
        const report = await boundedReport({ db, actor, input });
        sendJson(res, 200, { ok: true, format: 'csv', data: safeCsv(report.items) });
        return true;
      }
    }

    if (url.pathname === '/company-os/assets' && req.method === 'GET') {
      denyUnless(actor, 'manage_assets');
      const limit = validatePageLimit(url.searchParams.get('limit') || 25);
      const snapshot = await db.collection('companyOsAssets').orderBy('updatedAt', 'desc').limit(limit).get();
      sendJson(res, 200, safeListEnvelope({ items: serialize(docs(snapshot)), scope: 'company', filters: {} }));
      return true;
    }
    if (url.pathname === '/company-os/assets' && req.method === 'POST') {
      denyUnless(actor, 'manage_assets'); const body = await operationBody(req, readJsonBody);
      sendJson(res, 200, serialize(await createAsset({ store: createFirestoreAssetStore(db), actor, operationId: body.operationId, input: body })));
      return true;
    }
    const assetReadMatch = url.pathname.match(/^\/company-os\/assets\/([A-Za-z0-9_.:-]{1,128})$/);
    if (assetReadMatch && req.method === 'GET') {
      denyUnless(actor, 'manage_assets'); const snapshot = await db.collection('companyOsAssets').doc(assetReadMatch[1]).get();
      if (!snapshot.exists) { const error = new Error('Missing'); error.code = 'invalid_input'; throw error; }
      sendJson(res, 200, { ok: true, data: serialize({ id: snapshot.id, ...snapshot.data() }) }); return true;
    }
    const assetHistoryMatch = url.pathname.match(/^\/company-os\/assets\/([A-Za-z0-9_.:-]{1,128})\/history$/);
    if (assetHistoryMatch && req.method === 'GET') {
      denyUnless(actor, 'manage_assets'); const limit = validatePageLimit(url.searchParams.get('limit') || 25);
      const snapshot = await db.collection('companyOsAssetAssignments').where('assetId', '==', assetHistoryMatch[1]).orderBy('assignedAt', 'desc').limit(limit).get();
      sendJson(res, 200, safeListEnvelope({ items: serialize(docs(snapshot)), scope: 'company', filters: { assetId: assetHistoryMatch[1] } })); return true;
    }
    const assetMaintenanceMatch = url.pathname.match(/^\/company-os\/assets\/([A-Za-z0-9_.:-]{1,128})\/maintenance-history$/);
    if (assetMaintenanceMatch && req.method === 'GET') {
      denyUnless(actor, 'manage_assets'); const limit = validatePageLimit(url.searchParams.get('limit') || 25);
      const snapshot = await db.collection('companyOsAssetMaintenance').where('assetId', '==', assetMaintenanceMatch[1]).orderBy('openedAt', 'desc').limit(limit).get();
      sendJson(res, 200, safeListEnvelope({ items: serialize(docs(snapshot)), scope: 'company', filters: { assetId: assetMaintenanceMatch[1] } })); return true;
    }
    const assetMatch = url.pathname.match(/^\/company-os\/assets\/([A-Za-z0-9_.:-]{1,128})(?:\/(assign|return|maintenance|retire))?$/);
    if (assetMatch && ['PATCH', 'POST'].includes(req.method)) {
      denyUnless(actor, 'manage_assets'); const body = await operationBody(req, readJsonBody);
      const common = { store: createFirestoreAssetStore(db), actor, operationId: body.operationId, assetId: assetMatch[1], expectedVersion: body.expectedVersion };
      const action = assetMatch[2];
      const result = !action ? await updateAsset({ ...common, input: body })
        : action === 'assign' ? await assignAssetOperation({ ...common, employeeUid: body.employeeUid, condition: body.condition })
          : action === 'return' ? await returnAssetOperation({ ...common, reason: body.reason, condition: body.condition })
            : action === 'maintenance' ? await openMaintenanceOperation({ ...common, input: body })
              : await retireAssetOperation(common);
      sendJson(res, 200, serialize(result)); return true;
    }

    if (url.pathname === '/company-os/licenses' && req.method === 'GET') {
      denyUnless(actor, 'manage_software'); const limit = validatePageLimit(url.searchParams.get('limit') || 25);
      const snapshot = await db.collection('companyOsLicenses').orderBy('updatedAt', 'desc').limit(limit).get();
      sendJson(res, 200, safeListEnvelope({ items: serialize(docs(snapshot)), scope: 'company', filters: {} })); return true;
    }
    if (url.pathname === '/company-os/licenses' && req.method === 'POST') {
      denyUnless(actor, 'manage_software'); const body = await operationBody(req, readJsonBody);
      sendJson(res, 200, serialize(await createLicense({ store: createFirestoreSoftwareStore(db), actor, operationId: body.operationId, input: body }))); return true;
    }
    const licenseAssignmentsMatch = url.pathname.match(/^\/company-os\/licenses\/([A-Za-z0-9_.:-]{1,128})\/assignments$/);
    if (licenseAssignmentsMatch && req.method === 'GET') {
      denyUnless(actor, 'manage_software'); const limit = validatePageLimit(url.searchParams.get('limit') || 25);
      const snapshot = await db.collection('companyOsLicenseSeats').where('licenseId', '==', licenseAssignmentsMatch[1]).orderBy('assignedAt', 'desc').limit(limit).get();
      sendJson(res, 200, safeListEnvelope({ items: serialize(docs(snapshot)), scope: 'company', filters: { licenseId: licenseAssignmentsMatch[1] } })); return true;
    }
    const licenseReadMatch = url.pathname.match(/^\/company-os\/licenses\/([A-Za-z0-9_.:-]{1,128})$/);
    if (licenseReadMatch && req.method === 'GET') {
      denyUnless(actor, 'manage_software'); const snapshot = await db.collection('companyOsLicenses').doc(licenseReadMatch[1]).get();
      if (!snapshot.exists) { const error = new Error('Missing'); error.code = 'invalid_input'; throw error; }
      sendJson(res, 200, { ok: true, data: serialize({ id: snapshot.id, ...snapshot.data() }) }); return true;
    }
    const licenseMatch = url.pathname.match(/^\/company-os\/licenses\/([A-Za-z0-9_.:-]{1,128})(?:\/(assign-seat|revoke-seat))?$/);
    if (licenseMatch && ['PATCH', 'POST'].includes(req.method)) {
      denyUnless(actor, 'manage_software'); const body = await operationBody(req, readJsonBody);
      const common = { store: createFirestoreSoftwareStore(db), actor, operationId: body.operationId, licenseId: licenseMatch[1], expectedVersion: body.expectedVersion };
      const result = !licenseMatch[2] ? await updateLicense({ ...common, input: body })
        : licenseMatch[2] === 'assign-seat' ? await assignSeatOperation({ ...common, employeeUid: body.employeeUid })
          : await revokeSeatOperation({ ...common, employeeUid: body.employeeUid });
      sendJson(res, 200, serialize(result)); return true;
    }
    sendJson(res, 404, { ok: false, safeCode: 'invalid_input', retryable: false, status: 'not_found', message: 'المسار المطلوب غير متاح.' });
    return true;
  } catch (error) {
    const failure = safeFailure(error);
    const status = failure.safeCode === 'session_expired' ? 401
      : failure.safeCode === 'access_denied' ? 403
        : failure.safeCode === 'rate_limited' ? 429
        : failure.safeCode === 'conflict' || failure.safeCode === 'capacity_reached' ? 409
          : failure.safeCode === 'invalid_input' ? 400 : 503;
    sendJson(res, status, failure);
    return true;
  }
}

module.exports = { bearerToken, routeCompanyOsRequest, sliceEnabled, requestAttachmentIdFor, assertRequestAttachmentOwnership };
