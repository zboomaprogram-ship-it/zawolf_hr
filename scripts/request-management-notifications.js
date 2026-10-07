'use strict';

const crypto = require('crypto');

const NOTIFICATION_TARGETS = new Set(['manager', 'employee']);

function cleanString(value, maxLength = 256) {
  const normalized = String(value || '').replace(/\s+/g, ' ').trim();
  if (!normalized || normalized.length > maxLength) return '';
  return normalized;
}

function normalizeRequestNotificationInput(payload = {}) {
  const collection = cleanString(payload.collection, 64);
  const requestId = cleanString(payload.requestId, 256);
  const target = cleanString(payload.target, 16).toLowerCase();
  const description = cleanString(payload.description, 700);
  const operationId = cleanString(payload.operationId, 256);
  if (!collection || !/^[A-Za-z0-9_-]+$/.test(collection) ||
      !requestId || !/^[A-Za-z0-9_-]+$/.test(requestId) ||
      !NOTIFICATION_TARGETS.has(target) || !description || !operationId) {
    return null;
  }
  return { collection, requestId, target, description, operationId };
}

function orderedUnique(values) {
  return [...new Set(values.map((value) => String(value || '').trim()).filter(Boolean))];
}

function employeeUserIdFromRequest(request = {}) {
  return orderedUnique([
    request.userId,
    request.employeeUid,
    request.employeeUserId,
    request.requestedBy,
    request.createdBy,
    // Custom requests use requesterId. Without this alias the notification
    // endpoint treats a valid custom request as an unlinked employee.
    request.requesterId,
  ])[0] || '';
}

function managerUserIds({ request = {}, employee = {} } = {}) {
  const currentApproverId = String(request.currentApproverId || '').trim();
  const isCeoStage = String(request.status || '').toLowerCase() === 'pending_ceo' ||
    String(request.stage || '').toLowerCase() === 'ceo' ||
    (currentApproverId && currentApproverId === String(request.ceoId || '').trim());
  const directManagerId = String(request.managerId || employee.managerId || request.directManagerId || employee.directManagerId || '').trim();
  const ceoId = String(request.ceoId || '').trim();

  // CEO only receives reminder notifications if the request is at the CEO approval stage,
  // or if the employee is directly assigned to the CEO.
  const includeCeo = Boolean(ceoId && (isCeoStage || directManagerId === ceoId));

  const allManagerCandidates = [
    // Route-based requests (including custom and CEO stages) name the person
    // who must act now. Prefer that recipient before legacy manager fields.
    request.currentApproverId,
    ...(includeCeo ? [ceoId] : []),
    ...(Array.isArray(request.managerIds) ? request.managerIds : []),
    request.managerId,
    request.directManagerId,
    request.teamLeaderId,
    ...(Array.isArray(employee.managerIds) ? employee.managerIds : []),
    employee.managerId,
    employee.directManagerId,
    employee.teamLeaderId,
  ];

  return orderedUnique(
    allManagerCandidates.filter((id) => {
      if (!id) return false;
      if (!includeCeo && ceoId && id === ceoId) {
        return false;
      }
      return true;
    })
  );
}

function requestEmployeeName(request = {}, employee = {}) {
  return cleanString(
    request.employeeName || request.userName || request.displayName ||
      employee.displayName || employee.name || employee.employeeName,
    160,
  ) || 'الموظف';
}

function recipientUserIds({ input, request = {}, employee = {} } = {}) {
  if (input?.target === 'employee') {
    return orderedUnique([employeeUserIdFromRequest(request)]);
  }
  return managerUserIds({ request, employee });
}

function notificationDocumentId({ operationId, recipientUserId }) {
  const digest = crypto.createHash('sha256')
    .update(`${operationId}\u001f${recipientUserId}`)
    .digest('hex');
  return `request-action-${digest.slice(0, 40)}`;
}

function managerCategoryForCollection(collection) {
  const value = cleanString(collection, 64).toLowerCase();
  return {
    leaves: 'leaves',
    permissions: 'permissions',
    advances: 'advances',
    administrativerequests: 'administrative',
    meetingrequests: 'meetings',
    attendancecorrectionrequests: 'attendance_corrections',
    manual_deductions: 'manual_deductions',
    complaints: 'complaints',
    resignations: 'resignations',
    customrequests: 'custom',
  }[value] || 'all';
}

function buildRequestNotification({ input, recipientUserId, employeeName }) {
  const toManager = input.target === 'manager';
  return {
    notificationId: notificationDocumentId({
      operationId: input.operationId,
      recipientUserId,
    }),
    type: toManager
      ? 'request_hr_manager_reminder'
      : 'request_hr_edit_required',
    title: toManager ? 'تذكير بمتابعة طلب موظف' : 'مطلوب تعديل الطلب',
    body: toManager
      ? `${employeeName}: ${input.description}`
      : input.description,
    data: {
      route: toManager
        ? `/manager/requests?category=${managerCategoryForCollection(input.collection)}&requestId=${encodeURIComponent(input.requestId)}`
        : `/employee/requests?requestId=${encodeURIComponent(input.requestId)}`,
      requestCollection: input.collection,
      requestId: input.requestId,
      actionRequired: toManager ? 'review_request' : 'edit_request',
    },
    isRead: false,
    pushSent: false,
  };
}

module.exports = {
  buildRequestNotification,
  employeeUserIdFromRequest,
  managerUserIds,
  managerCategoryForCollection,
  recipientUserIds,
  normalizeRequestNotificationInput,
  notificationDocumentId,
  requestEmployeeName,
};
