'use strict';

const crypto = require('node:crypto');
const { publicTicket } = require('./employee-portal');
const { executeOperation, payloadHash } = require('./operation-gateway');
const { validatePrivateNote } = require('./private-notes');

const TICKET_TRANSITIONS = Object.freeze({
  new: ['assigned'],
  assigned: ['in_progress'],
  in_progress: ['waiting_for_employee', 'resolved'],
  waiting_for_employee: ['in_progress', 'resolved'],
  resolved: ['closed'],
  closed: ['in_progress'],
});

function validateTicketTransition(current, next) {
  if (!(TICKET_TRANSITIONS[current] || []).includes(next)) {
    const error = new Error('Invalid ticket transition'); error.code = 'conflict'; throw error;
  }
  return next;
}

function slaDueAt(priority, now) {
  const hours = { low: 72, medium: 24, high: 8, critical: 2 }[priority] || 24;
  return new Date(now.getTime() + hours * 60 * 60 * 1000);
}

function validateNewTicket(input = {}) {
  const subject = String(input.subject || '').trim();
  const description = String(input.description || '').trim();
  const category = String(input.category || 'other');
  const priority = String(input.priority || 'medium');
  if (subject.length < 3 || subject.length > 160 || description.length < 5 || description.length > 5000) {
    const error = new Error('Invalid ticket'); error.code = 'invalid_input'; throw error;
  }
  return { subject, description, category, priority };
}

async function createEmployeeTicket({ store, actor, operationId, input, now = new Date() }) {
  if (!actor?.uid || actor.active !== true) { const error = new Error('Inactive'); error.code = 'access_denied'; throw error; }
  const payload = validateNewTicket(input);
  const ticketId = `ticket_${crypto.createHash('sha256').update(operationId).digest('hex').slice(0, 24)}`;
  const ticket = { id: ticketId, requesterUid: actor.uid, departmentId: actor.departmentId || '', ...payload, status: 'new', slaDueAt: slaDueAt(payload.priority, now), version: 1, createdAt: now, updatedAt: now };
  if (store.transact) {
    return executeOperation({
      store,
      operationId,
      actor,
      operationType: 'ticket_create',
      targetId: ticketId,
      payload,
      now,
      mutate: async (tx) => {
        await tx.createTicket(ticket);
        return { resourceId: ticketId, version: 1 };
      },
    });
  }
  const previous = await store.receipt(operationId);
  if (previous) return previous;
  return store.createOnce({ operationId, actorUid: actor.uid, payloadHash: payloadHash(payload), ticket, audit: { operationId, actorUid: actor.uid, action: 'ticket_create', targetType: 'ticket', targetId: ticket.id, createdAt: now } });
}

async function mutateTicket({ store, actor, operationId, ticketId, expectedVersion, operationType, payload, update, now = new Date() }) {
  return executeOperation({
    store,
    actor,
    operationId,
    operationType,
    targetId: ticketId,
    expectedVersion,
    payload,
    now,
    currentVersion: async (tx) => (await tx.getTicket(ticketId))?.version,
    mutate: async (tx) => {
      const current = await tx.getTicket(ticketId);
      if (!current) { const error = new Error('Ticket missing'); error.code = 'not_found'; throw error; }
      const changes = update(current);
      const version = Number(current.version || 0) + 1;
      await tx.updateTicket(ticketId, { ...changes, version, updatedAt: now });
      if (tx.createTicketHistory) {
        await tx.createTicketHistory({
          id: `${operationId}:history`,
          ticketId,
          action: operationType,
          actorUid: actor.uid,
          fromStatus: current.status,
          toStatus: changes.status || current.status,
          version,
          createdAt: now,
        });
      }
      return { resourceId: ticketId, version };
    },
  });
}

async function assignTicket(args) {
  const assigneeUid = String(args.assigneeUid || '').trim();
  if (!assigneeUid) { const error = new Error('Missing assignee'); error.code = 'invalid_input'; throw error; }
  return mutateTicket({ ...args, operationType: 'ticket_assign', payload: { assigneeUid }, update: (ticket) => {
    validateTicketTransition(ticket.status, 'assigned');
    return { assignedItUid: assigneeUid, status: 'assigned' };
  } });
}

async function transitionTicket(args) {
  const status = String(args.status || '');
  return mutateTicket({ ...args, operationType: 'ticket_transition', payload: { status, resolutionSummary: args.resolutionSummary || null }, update: (ticket) => {
    validateTicketTransition(ticket.status, status);
    if (status === 'resolved' && !String(args.resolutionSummary || '').trim()) {
      const error = new Error('Resolution required'); error.code = 'invalid_input'; throw error;
    }
    return { status, resolutionSummary: args.resolutionSummary || null, resolvedAt: status === 'resolved' ? (args.now || new Date()) : ticket.resolvedAt || null, closedAt: status === 'closed' ? (args.now || new Date()) : ticket.closedAt || null };
  } });
}

async function addPrivateNote({ store, actor, operationId, ticketId, expectedVersion, body, now = new Date() }) {
  const text = validatePrivateNote(body);
  return executeOperation({
    store, actor, operationId, operationType: 'ticket_private_note', targetId: ticketId,
    expectedVersion, currentVersion: async (tx) => (await tx.getTicket(ticketId))?.version,
    payload: { bodyHash: crypto.createHash('sha256').update(text).digest('hex') }, now,
    mutate: async (tx) => {
      if (!(await tx.getTicket(ticketId))) { const error = new Error('Ticket missing'); error.code = 'not_found'; throw error; }
      await tx.createPrivateNote({ id: operationId, ticketId, authorUid: actor.uid, body: text, createdAt: now });
      return { resourceId: operationId, version: 1 };
    },
  });
}

async function addPublicComment({ store, actor, operationId, ticketId, expectedVersion, body, now = new Date() }) {
  const text = String(body || '').trim();
  if (!text || text.length > 2000) { const error = new Error('Invalid comment'); error.code = 'invalid_input'; throw error; }
  return executeOperation({
    store, actor, operationId, operationType: 'ticket_comment', targetId: ticketId,
    expectedVersion, currentVersion: async (tx) => (await tx.getTicket(ticketId))?.version,
    payload: { bodyHash: crypto.createHash('sha256').update(text).digest('hex') }, now,
    mutate: async (tx) => {
      const ticket = await tx.getTicket(ticketId);
      if (!ticket) { const error = new Error('Ticket missing'); error.code = 'not_found'; throw error; }
      if (ticket.requesterUid !== actor.uid && !['it_support', 'it_manager', 'super_admin'].includes(actor.role)) { const error = new Error('Denied'); error.code = 'access_denied'; throw error; }
      await tx.createPublicComment({ id: operationId, ticketId, authorUid: actor.uid, body: text, createdAt: now });
      return { resourceId: operationId, version: Number(ticket.version || 1) };
    },
  });
}

async function listOwnTickets({ store, actor, limit = 25, cursor = null }) {
  const result = await store.listByRequester(actor.uid, { limit, cursor });
  return { items: result.items.map(publicTicket), nextCursor: result.nextCursor || null };
}

function createFirestoreTicketStore(db) {
  return {
    transact(work) {
      return db.runTransaction(async (transaction) => work({
        async getReceipt(operationId) {
          const snapshot = await transaction.get(db.collection('companyOsOperationReceipts').doc(operationId));
          return snapshot.exists ? snapshot.data() : null;
        },
        async putReceipt(operationId, receipt) {
          transaction.create(db.collection('companyOsOperationReceipts').doc(operationId), receipt);
        },
        async putAudit(operationId, audit) {
          transaction.create(db.collection('companyOsAuditEvents').doc(operationId), audit);
        },
        async createTicket(ticket) {
          transaction.create(db.collection('companyOsTickets').doc(ticket.id), ticket);
        },
        async getTicket(ticketId) {
          const snapshot = await transaction.get(db.collection('companyOsTickets').doc(ticketId));
          return snapshot.exists ? { id: snapshot.id, ...snapshot.data() } : null;
        },
        async updateTicket(ticketId, changes) {
          transaction.update(db.collection('companyOsTickets').doc(ticketId), changes);
        },
        async createTicketHistory(history) {
          transaction.create(db.collection('companyOsTicketHistory').doc(history.id), history);
        },
        async createPrivateNote(note) {
          transaction.create(db.collection('companyOsTicketPrivateNotes').doc(note.id), note);
        },
        async createPublicComment(comment) {
          transaction.create(db.collection('companyOsTicketComments').doc(comment.id), comment);
        },
      }));
    },
    async listByRequester(uid, { limit }) {
      const snapshot = await db.collection('companyOsTickets').where('requesterUid', '==', uid).limit(Math.min(Number(limit) || 25, 100)).get();
      return { items: snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() })), nextCursor: null };
    },
  };
}

module.exports = { TICKET_TRANSITIONS, validateNewTicket, validateTicketTransition, slaDueAt, createEmployeeTicket, listOwnTickets, assignTicket, transitionTicket, addPrivateNote, addPublicComment, createFirestoreTicketStore };
