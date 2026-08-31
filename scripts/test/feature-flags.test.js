const test = require('node:test');
const assert = require('node:assert/strict');
const { isPhase007FlagEnabled, isAttendanceFlagEnabled } = require('../feature-flags');

test('phase 007 flags fail closed and can be targeted to a pilot', () => {
  assert.equal(isPhase007FlagEnabled('developer_tools_v2', {}, 'a'), false);
  assert.equal(isPhase007FlagEnabled('developer_tools_v2', { developer_tools_v2: { enabled: true, actorIds: ['a'] } }, 'a'), true);
  assert.equal(isPhase007FlagEnabled('developer_tools_v2', { developer_tools_v2: { enabled: true, actorIds: ['a'] } }, 'b'), false);
});

test('attendance multi-location flag fails closed and supports a pilot audience', () => {
  assert.equal(isAttendanceFlagEnabled('attendance_multi_location_v1', {}, 'u1'), false);
  assert.equal(isAttendanceFlagEnabled('attendance_multi_location_v1', {
    attendance_multi_location_v1: { enabled: true, actorIds: ['u1'] },
  }, 'u1'), true);
  assert.equal(isAttendanceFlagEnabled('attendance_multi_location_v1', {
    attendance_multi_location_v1: { enabled: true, actorIds: ['u1'] },
  }, 'u2'), false);
});
