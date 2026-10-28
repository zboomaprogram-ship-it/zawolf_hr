'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { createRemoteHarness } = require('./helpers/remote-work-fixtures');
const { listRemoteDays } = require('../remote-work/queries');

test('listRemoteDays enforces actor scope, bounds limits, and serializes clean items', async () => {
  const harness = await createRemoteHarness({
    now: '2026-11-02T12:00:00.000Z',
    fixtures: {
      'attendance/u1_2026-11-01': {
        userId: 'u1',
        date: '2026-11-01',
        attendanceMode: 'remote_web',
        isRemote: true,
        status: 'present',
      },
      'attendance/u1_2026-11-02': {
        userId: 'u1',
        date: '2026-11-02',
        attendanceMode: 'remote_web',
        isRemote: true,
        status: 'present',
      },
      'attendance/u2_2026-11-02': {
        userId: 'u2',
        date: '2026-11-02',
        attendanceMode: 'remote_web',
        isRemote: true,
        status: 'present',
      },
    },
  });

  const empActor = {
    uid: 'u1',
    active: true,
    companyId: 'zawolf',
    capabilities: [],
  };

  const hrActor = {
    uid: 'hr1',
    active: true,
    companyId: 'zawolf',
    capabilities: ['hr_admin'],
  };

  // 1. Employee queries own days
  const empRes = await listRemoteDays({
    db: harness.db,
    actor: empActor,
    filters: {},
  });
  assert.equal(empRes.items.length, 2);
  assert.ok(empRes.items.every(i => i.userId === 'u1'));

  // 2. Employee attempting to query u2 is rejected
  await assert.rejects(async () => {
    await listRemoteDays({
      db: harness.db,
      actor: empActor,
      filters: { userId: 'u2' },
    });
  }, (err) => err.code === 'not_authorized');

  // 3. HR queries u2 days
  const hrRes = await listRemoteDays({
    db: harness.db,
    actor: hrActor,
    filters: { userId: 'u2' },
  });
  assert.equal(hrRes.items.length, 1);
  assert.equal(hrRes.items[0].userId, 'u2');

  // 4. Limit capping (e.g. limit: 500 is capped at 100)
  const cappedRes = await listRemoteDays({
    db: harness.db,
    actor: hrActor,
    limit: 500,
  });
  assert.equal(cappedRes.limit, 100);

  await harness.close();
});
