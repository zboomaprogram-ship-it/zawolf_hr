'use strict';

function employeePortalSummary({ tickets = [], assets = [], requests = [], actorUid }) {
  return {
    openTicketCount: tickets.filter((item) => item.requesterUid === actorUid && !['resolved', 'closed'].includes(item.status)).length,
    assignedAssetCount: assets.filter((item) => item.currentEmployeeUid === actorUid && item.status === 'assigned').length,
    pendingRequestCount: requests.filter((item) => item.requesterUid === actorUid && item.status === 'pending').length,
  };
}

function publicTicket(ticket) {
  if (!ticket) return null;
  const { privateNotes, internalSla, ...safe } = ticket;
  return safe;
}

module.exports = { employeePortalSummary, publicTicket };

