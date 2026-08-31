'use strict';

const { safeListEnvelope, validatePageLimit } = require('./safe-errors');

function parseDate(value, fallback) {
  const date = value ? new Date(value) : fallback;
  if (!(date instanceof Date) || Number.isNaN(date.getTime())) {
    const error = new Error('Invalid date');
    error.code = 'invalid_input';
    throw error;
  }
  return date;
}

async function financialLedger({ db, actor, query }) {
  const limit = validatePageLimit(query.limit || 25);
  const now = new Date();
  const from = parseDate(query.from, new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1)));
  const to = parseDate(query.to, now);
  if (from > to) {
    const error = new Error('Invalid period');
    error.code = 'invalid_input';
    throw error;
  }
  const requestedEmployee = String(query.employeeUid || '').trim();
  const employeeUid = actor.role === 'employee' ? actor.uid : requestedEmployee;
  let requestQuery = db.collection('administrativeRequests')
    .where('costBearing', '==', true)
    .where('executionDate', '>=', from)
    .where('executionDate', '<=', to)
    .orderBy('executionDate', 'desc')
    .limit(limit);
  if (employeeUid) requestQuery = db.collection('administrativeRequests')
    .where('requesterUid', '==', employeeUid)
    .where('costBearing', '==', true)
    .where('executionDate', '>=', from)
    .where('executionDate', '<=', to)
    .orderBy('executionDate', 'desc')
    .limit(limit);
  const snapshot = await requestQuery.get();
  const items = snapshot.docs.map((doc) => {
    const data = doc.data();
    return {
      id: `request:${doc.id}`,
      employeeUid: data.requesterUid || data.userId,
      entryType: data.requestType,
      sourceType: 'operational_request',
      sourceId: doc.id,
      effectiveDate: data.executionDate,
      amount: Number(data.amount || 0),
      currency: data.currency || 'EGP',
      direction: 'debit',
      status: data.operationalStatus || data.status,
      description: data.businessReason || data.notes || '',
    };
  });
  return safeListEnvelope({
    items,
    scope: actor.role === 'employee' ? 'self' : employeeUid ? 'employee' : 'company',
    filters: { from: from.toISOString(), to: to.toISOString(), employeeUid: employeeUid || null },
  });
}

async function payslip({ db, actor, employeeUid, period }) {
  const targetUid = actor.role === 'employee' ? actor.uid : String(employeeUid || '').trim();
  if (!targetUid || (actor.role === 'employee' && targetUid !== actor.uid)) {
    const error = new Error('Denied');
    error.code = 'access_denied';
    throw error;
  }
  const snapshot = await db.collection('payrollRecords')
    .where('userId', '==', targetUid)
    .where('period', '==', String(period || '').trim())
    .limit(1)
    .get();
  if (snapshot.empty) return { ok: true, data: null };
  const data = snapshot.docs[0].data();
  return { ok: true, data: {
    id: snapshot.docs[0].id,
    employeeUid: targetUid,
    period: data.period,
    gross: data.gross,
    net: data.net,
    deductions: data.deductions,
    currency: data.currency || 'EGP',
    source: 'payroll_read_model',
  } };
}

module.exports = { parseDate, financialLedger, payslip };
