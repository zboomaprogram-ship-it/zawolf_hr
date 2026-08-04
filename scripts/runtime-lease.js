const { randomUUID } = require('crypto');

const DEFAULT_LEASE_MS = 7 * 60 * 1000;

function createRuntimeLease(db, admin, options = {}) {
  const owner = options.owner || `${process.env.HOSTNAME || 'hostinger'}-${process.pid}-${randomUUID()}`;
  const leaseMs = Math.max(60 * 1000, Number(options.leaseMs || DEFAULT_LEASE_MS));

  async function acquire(name) {
    const ref = db.collection('systemRuntimeLocks').doc(name);
    const now = Date.now();
    const until = admin.firestore.Timestamp.fromDate(new Date(now + leaseMs));

    return db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      const current = snapshot.data() || {};
      const currentUntil = current.leaseUntil?.toDate?.().getTime() || 0;
      if (snapshot.exists && current.owner !== owner && currentUntil > now) {
        return false;
      }

      transaction.set(
        ref,
        {
          owner,
          leaseUntil: until,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return true;
    });
  }

  async function release(name) {
    const ref = db.collection('systemRuntimeLocks').doc(name);
    await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      if (snapshot.exists && snapshot.data()?.owner === owner) {
        transaction.update(ref, {
          leaseUntil: admin.firestore.Timestamp.fromDate(new Date(0)),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    });
  }

  return { owner, acquire, release };
}

module.exports = { createRuntimeLease, DEFAULT_LEASE_MS };
