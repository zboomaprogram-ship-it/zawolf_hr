'use strict';
const ID = 'company:general';
async function ensureGeneral(db, now = new Date()) {
  const ref = db.collection('conversations').doc(ID);
  await db.runTransaction(async tx => {
    const current = await tx.get(ref);
    if (!current.exists) tx.create(ref, { kind: 'company', state: 'active', name: 'جروب الشركة', purposeAr: 'جروب الشركة', createdAt: now, updatedAt: now, latestActivityAt: now, latestActivityId: ID, revision: 1, changeSequence: 0 });
  });
  return ref;
}
module.exports = { ID, ensureGeneral };
