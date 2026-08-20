const test = require('node:test');
const assert = require('node:assert/strict');
const {
  normalizePolicy,
  canManageCheckoutPolicy,
  checkoutDisabledResult,
  resolveCheckoutPolicyAt,
  updateCheckoutPolicy,
} = require('../checkout-policy');
const fs = require('node:fs');

test('checkout policy fails closed when configuration is missing or malformed', () => {
  assert.deepEqual(normalizePolicy(null), {
    enabled: false, revision: 0, effectiveAt: null,
    changedByUserId: null, changedByRole: null, reason: null,
  });
  assert.equal(normalizePolicy({ enabled: 'true', revision: -1 }).enabled, false);
  assert.equal(normalizePolicy({ enabled: true, revision: -1 }).revision, 0);
});

test('only HR and super-admin roles may manage checkout policy', () => {
  assert.equal(canManageCheckoutPolicy({ uid: 'hr', role: 'hr' }), true);
  assert.equal(canManageCheckoutPolicy({ uid: 'admin', role: 'super_admin' }), true);
  assert.equal(canManageCheckoutPolicy({ uid: 'manager', role: 'manager' }), false);
  assert.equal(canManageCheckoutPolicy({ role: 'hr' }), false);
});

test('disabled checkout is a safe business outcome without infrastructure detail', () => {
  const result = checkoutDisabledResult({
    attendanceId: 'employee-1_2026-08-20',
    policy: normalizePolicy({ enabled: false, revision: 4 }),
  });
  assert.equal(result.status, 'checkout_disabled');
  assert.equal(result.policy.revision, 4);
  assert.match(result.messageAr, /غير مفعّل/);
  assert.equal(JSON.stringify(result).includes('firestore'), false);
});

test('policy API exposes a stable nested policy payload for mobile clients', () => {
  const source = fs.readFileSync(require.resolve('../notification-web'), 'utf8');
  assert.match(source, /policy,\s*canManage/);
  assert.match(source, /url\.pathname === '\/attendance\/checkout-policy'/);
});

test('historical policy resolution uses the latest event at the attendance time', async () => {
  const first = { enabled: true, revision: 1, effectiveAt: new Date('2026-08-01T00:00:00Z') };
  const second = { enabled: false, revision: 2, effectiveAt: new Date('2026-08-10T00:00:00Z') };
  const events = [first, second];
  const db = {
    collection() {
      return {
        doc() {
          return {
            collection() {
              const query = {
                where() { return query; },
                orderBy() { return query; },
                limit() { return query; },
                async get() {
                  const cutoff = new Date('2026-08-05T12:00:00Z').getTime();
                  const matching = events.filter((event) => event.effectiveAt.getTime() <= cutoff);
                  return {
                    empty: matching.length === 0,
                    docs: matching.length ? [{ data: () => matching.at(-1) }] : [],
                  };
                },
              };
              return query;
            },
            async get() { return { exists: false, data: () => null }; },
          };
        },
      };
    },
  };
  const policy = await resolveCheckoutPolicyAt(db, new Date('2026-08-05T12:00:00Z'));
  assert.equal(policy.enabled, true);
  assert.equal(policy.revision, 1);
});

function policyTestStore(initial = {}) {
  const values = new Map(Object.entries(initial));
  let eventSequence = 0;
  const reference = (path) => ({
    path,
    async get() {
      const value = values.get(path);
      return { exists: value != null, data: () => value };
    },
    collection(name) {
      return {
        doc: () => reference(`${path}/${name}/event-${++eventSequence}`),
        where() { throw new Error('Not used by this transaction test.'); },
      };
    },
  });
  const db = {
    collection(name) {
      return { doc: (id) => reference(`${name}/${id}`) };
    },
    async runTransaction(callback) {
      return callback({
        get: (ref) => ref.get(),
        set(ref, value, { merge } = {}) {
          values.set(ref.path, merge ? { ...(values.get(ref.path) || {}), ...value } : value);
        },
      });
    },
  };
  return { db, values };
}

test('authorized changes are revisioned and write exactly one immutable event', async () => {
  const { db, values } = policyTestStore();
  const admin = { firestore: { FieldValue: { serverTimestamp: () => new Date('2026-08-20T10:00:00Z') } } };
  const actor = { uid: 'hr-1', role: 'hr_admin' };

  const policy = await updateCheckoutPolicy({
    db, admin, actor, enabled: true, expectedRevision: 0, reason: 'اختبار',
  });

  assert.equal(policy.enabled, true);
  assert.equal(policy.revision, 1);
  assert.equal([...values.keys()].filter((key) => key.includes('/events/')).length, 1);
  await assert.rejects(
    updateCheckoutPolicy({ db, admin, actor, enabled: false, expectedRevision: 0 }),
    (error) => error.code === 'policy_conflict',
  );
  await assert.rejects(
    updateCheckoutPolicy({ db, admin, actor: { uid: 'employee', role: 'employee' }, enabled: false }),
    (error) => error.code === 'not_authorized',
  );
});
