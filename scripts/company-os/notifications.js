'use strict';

const crypto = require('node:crypto');
const { redactPrivateFields } = require('./safe-errors');

function ticketNotification({ operationId, ticketId, recipientUid, audience = 'employee', status = 'updated' }) {
  const safeTicketId = String(ticketId || '').replace(/[^A-Za-z0-9_.:-]/g, '').slice(0, 128);
  const safeOperationId = String(operationId || '').replace(/[^A-Za-z0-9_.:-]/g, '').slice(0, 128);
  if (!safeTicketId || !safeOperationId || !String(recipientUid || '').trim()) {
    const error = new Error('Invalid notification'); error.code = 'invalid_input'; throw error;
  }
  const messages = {
    created: 'تم استلام تذكرة الدعم وسيتم متابعتها.',
    assigned: 'تم إسناد تذكرة الدعم إلى المختص.',
    in_progress: 'بدأ فريق الدعم العمل على التذكرة.',
    waiting_for_employee: 'تحتاج تذكرة الدعم إلى ردك.',
    resolved: 'تم حل تذكرة الدعم.',
    closed: 'تم إغلاق تذكرة الدعم.',
    updated: 'تم تحديث حالة تذكرة الدعم.',
  };
  return redactPrivateFields({
    id: `company_os_ticket_${crypto.createHash('sha256').update(`${safeOperationId}:${recipientUid}:${status}`).digest('hex').slice(0, 28)}`,
    recipientUid: String(recipientUid).trim(),
    title: audience === 'it' ? 'تذكرة دعم تحتاج متابعة' : 'تحديث تذكرة الدعم',
    body: messages[status] || messages.updated,
    type: 'company_os_ticket',
    data: { route: `/company-os?ticket=${encodeURIComponent(safeTicketId)}`, ticketId: safeTicketId },
  });
}

function requestStageNotification({ operationId, requestId, recipientUid, stage = 'manager', status = 'pending' }) {
  const safeRequestId = String(requestId || '').replace(/[^A-Za-z0-9_.:-]/g, '').slice(0, 128);
  const safeOperationId = String(operationId || '').replace(/[^A-Za-z0-9_.:-]/g, '').slice(0, 128);
  if (!safeRequestId || !safeOperationId || !String(recipientUid || '').trim()) {
    const error = new Error('Invalid notification'); error.code = 'invalid_input'; throw error;
  }
  const stageLabels = { manager: 'المدير', specialist: 'المختص', finance: 'المالية', owner: 'مالك الشركة', payment: 'الصرف', closure: 'الإغلاق' };
  const employeeFinal = ['approved', 'rejected', 'closed'].includes(status);
  const route = employeeFinal
    ? `/employee/requests/operational/${encodeURIComponent(safeRequestId)}`
    : `/requests/operational/${encodeURIComponent(safeRequestId)}`;
  return redactPrivateFields({
    id: `company_os_request_${crypto.createHash('sha256').update(`${safeOperationId}:${recipientUid}:${stage}:${status}`).digest('hex').slice(0, 28)}`,
    recipientUid: String(recipientUid).trim(),
    title: employeeFinal ? 'تحديث حالة الطلب' : 'طلب يحتاج إلى إجراء',
    body: employeeFinal
      ? status === 'rejected' ? 'تم رفض الطلب. افتح الطلب لمعرفة السبب.' : 'اكتملت مراجعة الطلب.'
      : `الطلب بانتظار مراجعة ${stageLabels[stage] || 'المسؤول'}.`,
    type: employeeFinal ? `company_os_request_${status}` : `company_os_request_pending_${stage}`,
    data: {
      route,
      requestId: safeRequestId,
      administrativeRequestId: safeRequestId,
    },
  });
}

function requestNotificationOutbox({ operationId, requestId, requesterUid, stage, status = 'pending' }) {
  const recipientUid = String(stage?.assigneeUid || '').trim();
  const recipientRole = String(stage?.role || '').trim();
  if (!recipientUid && !recipientRole) {
    const error = new Error('Notification target missing'); error.code = 'invalid_input'; throw error;
  }
  const route = status === 'pending'
    ? `/requests/operational/${encodeURIComponent(requestId)}`
    : `/employee/requests/operational/${encodeURIComponent(requestId)}`;
  return redactPrivateFields({
    id: `company_os_request_outbox_${crypto.createHash('sha256').update(`${operationId}:${requestId}:${stage?.type || status}`).digest('hex').slice(0, 28)}`,
    operationId,
    requestId,
    requesterUid,
    recipientUid: recipientUid || null,
    recipientRole: recipientRole || null,
    stage: stage?.type || null,
    status,
    route,
    data: { route, requestId, administrativeRequestId: requestId },
    dispatchStatus: 'pending',
  });
}

module.exports = { ticketNotification, requestStageNotification, requestNotificationOutbox };
