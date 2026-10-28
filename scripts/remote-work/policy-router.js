'use strict';

const { validateRemotePolicy } = require('./policy-schema');
const { resolveRemotePolicy } = require('./policy-resolution');
const { executeRemotePolicyCommand, policyError } = require('./policy-publication');
const { listRemoteDays } = require('./queries');
const { executeRemoteAttendance } = require('./attendance-commands');
const { executeRemoteSessionCommand } = require('./session-commands');
const { saveRemoteSchedule } = require('./schedules');
const { declareRemoteIncident, resolveRemoteFinancialHold } = require('./financial-holds');
const { correctRemoteDay } = require('./recovery');
const { evaluateRemoteEligibility } = require('./eligibility');

const COMPANY_POLICY_CAPABILITIES = ['manage_policy_drafts', 'approve_policy', 'publish_policy', 'view_company'];

function requireCapability(actor, capability) {
  if (actor?.active !== true) throw policyError('unauthenticated');
  if (!actor.capabilities?.includes(capability)) throw policyError('not_authorized', 'لا تملك صلاحية الوصول إلى سياسات العمل عن بُعد.');
}

function limitValue(value, fallback = 50) {
  const parsed = Number.parseInt(String(value ?? ''), 10);
  return Number.isInteger(parsed) ? Math.min(100, Math.max(1, parsed)) : fallback;
}

function schemaResponse() {
  return {
    schemaVersion: 1,
    companyId: 'zawolf',
    sections: [
      { id: 'eligibility', titleAr: 'الأهلية والأيام', fields: ['weekStartDay', 'daysPerWeek', 'allowedWeekdays', 'probationEligible', 'carryoverEnabled', 'carryoverCap'] },
      { id: 'schedule', titleAr: 'الساعات ونقاط المتابعة', fields: ['startTime', 'endTime', 'checkInOpenTime', 'latestCheckoutTime', 'graceMinutes', 'quarterDayUntilMinutes', 'halfDayUntilMinutes', 'endDayOffset', 'checkpoints'] },
      { id: 'channels', titleAr: 'قنوات الدوام', fields: ['remote_web', 'on_site_mobile'] },
      { id: 'devices', titleAr: 'الأجهزة', fields: ['maxCredentials', 'reviewIntervalDays'], limits: { maxCredentials: { min: 1, max: 3 }, reviewIntervalDays: { min: 1, max: 3650 } } },
      { id: 'approvals', titleAr: 'الموافقات', resolvers: ['manager', 'hr', 'it', 'ceo', 'specific_user', 'capability'] },
      { id: 'dailyWork', titleAr: 'خطة العمل والملخص', fields: ['planRequired', 'summaryRequired', 'minimumGoals', 'maximumGoals'], limits: { minimumGoals: { min: 0, max: 50 }, maximumGoals: { min: 0, max: 50 } } },
      { id: 'notifications', titleAr: 'التذكيرات', fields: ['enabled', 'reminderLeadMinutes', 'quietHours', 'escalationDelayMinutes'], limits: { reminderLeadMinutes: { min: 0, max: 1440 }, escalationDelayMinutes: { min: 0, max: 10080 } } },
      { id: 'review', titleAr: 'المراجعة والآثار المالية', fields: ['missingCheckpointAction', 'dailyFinancialCap'], actions: ['none', 'reminder', 'warning', 'review', 'pending_financial_review'] },
      { id: 'privacy', titleAr: 'الاحتفاظ والخصوصية', fields: ['retentionDays'], limits: { retentionDays: { min: 1, max: 3650 } } },
    ],
    guarantees: ['authentication', 'company_isolation', 'server_time', 'audit', 'financial_review'],
    verifiedComputerProfiles: [],
  };
}

async function handleRemotePolicyRequest({ db, actor, method, path, query = {}, body = {}, now = new Date() }) {
  if (path === '/attendance/remote-work/policy-schema' && method === 'GET') {
    if (!COMPANY_POLICY_CAPABILITIES.some((capability) => actor?.capabilities?.includes(capability))) throw policyError('not_authorized');
    return schemaResponse();
  }

  if (path === '/attendance/remote-work/policies/commands' && method === 'POST') {
    const command = body.command;
    return executeRemotePolicyCommand({ db, actor, command, now });
  }

  if (path === '/attendance/remote-work/days' && method === 'GET') {
    return listRemoteDays({ db, actor, query });
  }

  if (path === '/attendance/remote-work/commands' && method === 'POST') {
    const command = body.command || body;
    const kind = command.kind;
    if (kind === 'check_in' || kind === 'check_out') {
      return executeRemoteAttendance({ db, admin: {}, actor, command, now });
    }
    if (['save_plan', 'submit_update', 'save_summary'].includes(kind)) {
      return executeRemoteSessionCommand({ db, admin: {}, actor, command, now });
    }
    if (kind === 'save_schedule') {
      return saveRemoteSchedule({ db, admin: {}, actor, command, now });
    }
    if (kind === 'declare_incident') {
      return declareRemoteIncident({ db, admin: {}, actor, command, now });
    }
    if (kind === 'resolve_hold') {
      return resolveRemoteFinancialHold({ db, admin: {}, actor, command, now });
    }
    if (kind === 'correct_day') {
      return correctRemoteDay({ db, admin: {}, actor, command, now });
    }
    throw policyError('invalid_command', 'نوع الأمر غير معروف.');
  }

  if (path === '/attendance/remote-work/eligibility/evaluate' && method === 'POST') {
    const employeeId = body.employeeId || actor.uid;
    const date = body.date;
    const [employeeDoc, companyDoc, schedulesSnap] = await Promise.all([
      db.collection('users').doc(employeeId).get(),
      db.collection('companies').doc(actor.companyId).get(),
      db.collection('remoteWorkSchedules')
        .where('companyId', '==', actor.companyId)
        .where('employeeId', '==', employeeId)
        .where('status', '==', 'approved')
        .get(),
    ]);
    const empData = employeeDoc.exists ? (employeeDoc.data() || {}) : {};
    const companyData = companyDoc.exists ? (companyDoc.data() || {}) : {};
    const policy = companyData.attendancePolicy?.remoteWorkPolicy || {};

    const schedules = [];
    if (schedulesSnap && !schedulesSnap.empty) {
      schedulesSnap.forEach((doc) => {
        schedules.push({ id: doc.id, ...doc.data() });
      });
    }

    const profileDays = empData.workSchedule?.remoteWorkDays || empData.workSchedule?.remoteDays;
    if (Array.isArray(profileDays) && profileDays.length > 0 && schedules.length === 0) {
      schedules.push({
        id: `profile_${employeeId}`,
        companyId: actor.companyId,
        employeeId,
        startDate: '2020-01-01',
        endDate: '2099-12-31',
        weekdays: profileDays,
        status: 'approved',
        version: 1,
      });
    }

    return evaluateRemoteEligibility({
      employee: empData,
      companyId: actor.companyId,
      policy,
      date,
      schedules,
    });
  }

  if (path === '/attendance/remote-work/policies/current' && method === 'GET') {
    requireCapability(actor, 'manage_policy_drafts');
    const [company, head] = await Promise.all([
      db.collection('companies').doc(actor.companyId).get(),
      db.collection('attendancePolicyHeads').doc(actor.companyId).get(),
    ]);
    return {
      attendancePolicy: company.exists ? (company.data()?.attendancePolicy || {}) : {},
      head: head.exists ? head.data() : { revision: 0, activeRevision: 0, version: 0 },
    };
  }

  if (path === '/attendance/remote-work/policies/preview' && method === 'POST') {
    requireCapability(actor, 'manage_policy_drafts');
    const aggregate = body.aggregate;
    const shared = aggregate?.attendancePolicy;
    const remote = aggregate?.remoteWorkPolicy || shared?.remoteWorkPolicy;
    const validation = validateRemotePolicy(remote);
    if (!validation.valid) {
      const error = policyError('policy_validation_failed', 'راجع الحقول المحددة في السياسة.');
      error.validationErrors = validation.errors;
      throw error;
    }
    const current = await db.collection('companies').doc(actor.companyId).get();
    const currentAttendance = current.exists ? current.data()?.attendancePolicy || {} : {};
    const resolved = resolveRemotePolicy({
      sharedAttendancePolicy: shared,
      scopes: [{ scope: 'company', revisionId: 'preview', policy: remote }],
    });
    return {
      date: typeof body.date === 'string' ? body.date : null,
      employeeId: typeof body.employeeId === 'string' ? body.employeeId : null,
      currentSharedAttendancePolicy: currentAttendance,
      resolvedPolicy: resolved.policy,
      resolvedHash: resolved.hash,
      sourceRevisionIds: resolved.sourceRevisionIds,
      validation: { valid: true, errors: [] },
    };
  }

  if (path === '/attendance/remote-work/policies/history' && method === 'GET') {
    requireCapability(actor, 'manage_policy_drafts');
    const limit = limitValue(query.limit);
    let request = db.collection('attendancePolicyRevisions')
      .where('companyId', '==', actor.companyId)
      .orderBy('revision', 'desc')
      .limit(limit + 1);
    if (query.cursor) {
      const cursor = await db.collection('attendancePolicyRevisions').doc(String(query.cursor)).get();
      if (cursor.exists && cursor.data()?.companyId === actor.companyId) request = request.startAfter(cursor);
    }
    const snapshot = await request.get();
    const docs = snapshot.docs || [];
    const items = docs.slice(0, limit).map((document) => {
      const value = document.data() || {};
      return {
        revisionId: value.revisionId || String(value.revision),
        revision: value.revision,
        effectiveFrom: value.effectiveFrom,
        publishedAt: value.publishedAt,
        publishedBy: value.publishedBy,
        approvedBy: value.approvedBy,
        state: value.state,
        payloadHash: value.payloadHash,
        aggregate: value.aggregate,
      };
    });
    return { items, nextCursor: docs.length > limit ? docs[limit - 1].id : null, limit };
  }

  const draftMatch = path.match(/^\/attendance\/remote-work\/policies\/drafts\/([A-Za-z0-9_-]{1,128})$/);
  if (draftMatch && method === 'GET') {
    requireCapability(actor, 'manage_policy_drafts');
    const draft = await db.collection('attendancePolicyDrafts').doc(`${actor.companyId}_${draftMatch[1]}`).get();
    if (!draft.exists) throw policyError('draft_not_found');
    return draft.data();
  }

  const operationMatch = path.match(/^\/attendance\/remote-work\/operations\/([A-Za-z0-9_-]{1,128})$/);
  if (operationMatch && method === 'GET') {
    if (!COMPANY_POLICY_CAPABILITIES.some((capability) => actor?.capabilities?.includes(capability))) throw policyError('not_authorized');
    const operation = await db.collection('attendancePolicyOperations').doc(`${actor.companyId}_${actor.uid}_${operationMatch[1]}`).get();
    if (!operation.exists) throw policyError('operation_not_found');
    return operation.data().result;
  }

  throw policyError('not_found', 'مسار سياسات العمل عن بُعد غير موجود.');
}

module.exports = { handleRemotePolicyRequest, schemaResponse, limitValue };
