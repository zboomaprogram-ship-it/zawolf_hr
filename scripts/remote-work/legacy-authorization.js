'use strict';

const { isRemoteAlias } = require('./eligibility');

function canonicalizeLegacyKind(value) {
  return isRemoteAlias(value) ? 'remote_authorization' : 'leave';
}

function classifyLegacyLeave({ leave, pilotEnabled, activationDate }) {
  if (!leave || typeof leave !== 'object') return { kind: 'invalid', eligibleForAttendance: false };
  const remote = isRemoteAlias(leave.leaveType) || isRemoteAlias(leave.originalLeaveType);
  if (!remote) return { kind: 'real_leave', eligibleForAttendance: false };
  const date = String(leave.date || leave.startDate || '');
  if (!pilotEnabled || !activationDate || !/^\d{4}-\d{2}-\d{2}$/.test(activationDate) || date < activationDate) {
    return { kind: 'historical_remote_leave', eligibleForAttendance: false, requiresReview: true };
  }
  if (leave.status !== 'approved') return { kind: 'pending_legacy_remote', eligibleForAttendance: false };
  if (isRemoteAlias(leave.originalLeaveType) && !isRemoteAlias(leave.leaveType)) {
    return { kind: 'converted_remote_leave', eligibleForAttendance: false, requiresReview: true };
  }
  return {
    kind: 'remote_authorization',
    eligibleForAttendance: true,
    date,
    approvalSnapshot: Array.isArray(leave.approvalHistory) ? leave.approvalHistory : [],
  };
}

module.exports = { canonicalizeLegacyKind, classifyLegacyLeave };
