const crypto = require('node:crypto');

const ALLOWED_ACTIONS = new Set([
  'resource_list', 'resource_open', 'file_create', 'file_upload',
  'file_download', 'file_rename', 'file_move', 'file_copy', 'file_trash',
  'file_restore', 'sheet_read', 'sheet_edit', 'sheet_paste', 'sheet_format',
  'sheet_structure', 'sheet_tab', 'access_change', 'report_generate',
  'external_activity', 'workspace_pilot_changed',
  // Request-management reminders are written by the Hostinger operations
  // service. They are governed events, not Workspace file operations.
  'request_manager_reminder_sent', 'request_employee_edit_notice_sent',
]);

function safeAuditDetails(details = {}) {
  const allowed = [
    'operationId',
    'range',
    'changeCount',
    'reportKey',
    'source',
    'activityType',
    'mode',
    'audienceCount',
    'reason',
    'collection',
    'requestId',
    'recipientCount',
    'target',
  ];
  return Object.fromEntries(
    Object.entries(details).filter(([key, value]) => allowed.includes(key) &&
      (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean')),
  );
}

// Provider change feeds do not reliably identify the human who made a change.
// Keep that distinction explicit: a reconciler may associate a resource and a
// provider timestamp, but never invent a ZaWolf actor or persist cell values.
function normalizeExternalActivity(change = {}) {
  return {
    actorId: 'external_unattributed',
    resourceId: String(change.resourceId || change.fileId || ''),
    action: 'external_activity',
    details: safeAuditDetails({
      source: 'google_drive',
      activityType: String(change.activityType || change.type || 'changed'),
    }),
    providerUpdatedAt: change.modifiedTime || change.updatedAt || null,
  };
}

async function appendWorkspaceAudit({ db, actorId, resourceId, action, details, now = new Date() }) {
  if (!ALLOWED_ACTIONS.has(action)) throw new Error('Unsupported workspace audit action.');
  const ref = db.collection('workspaceAuditLogs').doc(crypto.randomUUID());
  const event = {
    // External Drive changes may be observed without a ZaWolf session.  They
    // must remain visibly unattributed instead of being incorrectly assigned
    // to the user who later triggers reconciliation.
    actorId: String(actorId || 'external_unattributed'),
    resourceId,
    action,
    details: safeAuditDetails(details),
    createdAt: now,
  };
  await ref.create(event);
  return { id: ref.id, ...event };
}

module.exports = {
  ALLOWED_ACTIONS,
  safeAuditDetails,
  normalizeExternalActivity,
  appendWorkspaceAudit,
};
