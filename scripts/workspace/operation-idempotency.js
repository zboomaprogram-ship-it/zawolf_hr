const { asSafeOperationId } = require('./request-context');

function receiptRef(db, operationId) {
  return db.collection('workspaceOperationReceipts').doc(operationId);
}

/// Reads a prior terminal receipt or reserves an operation ID exactly once.
/// The actual mutation must run only after `kind: 'new'` is returned.
async function reserveWorkspaceOperation({ db, operationId, actorId, resourceId, now = new Date() }) {
  const safeId = asSafeOperationId(operationId);
  if (!safeId) {
    const error = new Error('معرّف العملية غير صالح.');
    error.code = 'validation';
    throw error;
  }
  const ref = receiptRef(db, safeId);
  const existing = await ref.get();
  if (existing.exists) {
    const receipt = existing.data();
    if (receipt.actorId !== actorId || receipt.resourceId !== resourceId) {
      const error = new Error('لا تتوفر لك صلاحية تنفيذ هذا الإجراء.');
      error.code = 'not_authorized';
      throw error;
    }
    return { kind: 'replay', receipt };
  }
  try {
    await ref.create({
      actorId,
      resourceId,
      state: 'pending',
      createdAt: now,
      updatedAt: now,
    });
    return { kind: 'new', ref };
  } catch (error) {
    const replay = await ref.get();
    if (replay.exists) return { kind: 'replay', receipt: replay.data() };
    throw error;
  }
}

async function completeWorkspaceOperation({ reservation, result, now = new Date() }) {
  if (reservation.kind !== 'new') return reservation.receipt;
  const receipt = {
    state: result.state,
    safeMessage: result.safeMessage || null,
    updatedAt: now,
  };
  await reservation.ref.update(receipt);
  return receipt;
}

module.exports = { reserveWorkspaceOperation, completeWorkspaceOperation };
