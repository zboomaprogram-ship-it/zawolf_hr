'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { createRemoteHarness } = require('./helpers/remote-work-fixtures');

test('emulator harness persists remote-work fixture data only in the explicit demo project', {
  skip: process.env.RUN_REMOTE_WORK_EMULATOR !== '1',
}, async () => {
  const harness = await createRemoteHarness({ backend: 'emulator' });
  try {
    assert.equal(harness.actor.uid, 'employee_test');
    await harness.seed('remoteWorkHarnessChecks', 'baseline', { value: 1 });
    await harness.db.runTransaction(async (transaction) => {
      const ref = harness.db.collection('remoteWorkHarnessChecks').doc('baseline');
      const snapshot = await transaction.get(ref);
      transaction.set(ref, { value: snapshot.data().value + 1 });
    });
    assert.deepEqual(await harness.read('remoteWorkHarnessChecks', 'baseline'), { value: 2 });
    assert.equal(await harness.count('remoteWorkHarnessChecks'), 1);
  } finally {
    await harness.close();
  }
});
