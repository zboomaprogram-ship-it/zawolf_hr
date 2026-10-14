'use strict';

const REQUEST_COLLECTIONS = Object.freeze([
  // Hiring/accounting history is the first live repair target. Subsequent
  // collections advance one bounded page per scheduler pass.
  'hiringRequests',
  'customRequests',
  'meetingRequests',
  'leaves',
  'permissions',
  'advances',
  'attendanceCorrectionRequests',
  'administrativeRequests',
  'resignations',
  'employeeDeletionRequests',
]);

function cleanId(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function deriveApprovalActorIds(data = {}) {
  const ids = new Set();
  const add = (value) => {
    const id = cleanId(value);
    if (id) ids.add(id);
  };

  for (const value of Array.isArray(data.approvalActorIds) ? data.approvalActorIds : []) add(value);
  for (const field of [
    'reviewedBy',
    'managerReviewedBy',
    'finalApproverId',
    'finalApprovedBy',
    'approvedBy',
    'rejectedBy',
  ]) add(data[field]);

  for (const event of Array.isArray(data.approvalHistory) ? data.approvalHistory : []) {
    if (!event || typeof event !== 'object') continue;
    const action = cleanId(event.action || event.status).toLowerCase();
    if (!['approve', 'approved', 'reject', 'rejected'].includes(action)) continue;
    add(event.actorId);
    add(event.approverId);
    add(event.managerId);
    add(event.decidedBy);
  }
  for (const stage of Array.isArray(data.approvalRoute) ? data.approvalRoute : []) {
    if (!stage || typeof stage !== 'object') continue;
    add(stage.decidedBy);
    add(stage.actedBy);
  }
  for (const event of Array.isArray(data.managerApprovalTrail) ? data.managerApprovalTrail : []) {
    if (!event || typeof event !== 'object') continue;
    add(event.managerId);
    add(event.actorId);
  }
  return [...ids];
}

function withApprovalActor(data, actorId) {
  return [...new Set([...deriveApprovalActorIds(data), cleanId(actorId)].filter(Boolean))];
}

async function reconcileRequestApprovalHistory({ db, admin, batchSize = 75 } = {}) {
  if (!db || !admin) throw new Error('db_and_admin_required');
  const markerRef = db.collection('systemJobs').doc('requestApprovalActorBackfillV1');
  const marker = (await markerRef.get()).data() || {};
  const completed = new Set(Array.isArray(marker.completedCollections) ? marker.completedCollections : []);
  const cursors = marker.cursors && typeof marker.cursors === 'object' ? marker.cursors : {};
  const collection = REQUEST_COLLECTIONS.find((name) => !completed.has(name));
  if (!collection) return { completed: true, scanned: 0, updated: 0 };

  const limit = Math.max(1, Math.min(Number(batchSize) || 75, 200));
  let query = db.collection(collection)
    .orderBy(admin.firestore.FieldPath.documentId())
    .limit(limit);
  if (cleanId(cursors[collection])) query = query.startAfter(cursors[collection]);
  const snapshot = await query.get();
  const batch = db.batch();
  let updated = 0;
  for (const doc of snapshot.docs) {
    const data = doc.data() || {};
    const derived = deriveApprovalActorIds(data);
    const existing = (Array.isArray(data.approvalActorIds) ? data.approvalActorIds : [])
      .map(cleanId).filter(Boolean);
    if (derived.length !== existing.length || derived.some((id) => !existing.includes(id))) {
      batch.set(doc.ref, { approvalActorIds: derived }, { merge: true });
      updated += 1;
    }
  }

  const nextCursors = { ...cursors };
  const nextCompleted = new Set(completed);
  if (snapshot.empty || snapshot.size < limit) {
    nextCompleted.add(collection);
    delete nextCursors[collection];
  } else {
    nextCursors[collection] = snapshot.docs[snapshot.docs.length - 1].id;
  }
  batch.set(markerRef, {
    cursors: nextCursors,
    completedCollections: [...nextCompleted],
    lastCollection: collection,
    lastRunAt: admin.firestore.FieldValue.serverTimestamp(),
    version: 1,
  }, { merge: true });
  await batch.commit();
  return { completed: nextCompleted.size === REQUEST_COLLECTIONS.length, collection, scanned: snapshot.size, updated };
}

module.exports = {
  REQUEST_COLLECTIONS,
  deriveApprovalActorIds,
  withApprovalActor,
  reconcileRequestApprovalHistory,
};
