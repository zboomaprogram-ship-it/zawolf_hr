'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { workspaceSchedulerOwnership } = require('../workspace/scheduler');

test('workspace reports have one request-driven scheduler owner', () => {
  const ownership = workspaceSchedulerOwnership();
  assert.equal(ownership.owner, 'hostinger_node_runtime');
  assert.equal(ownership.duplicateSchedulerAllowed, false);
});
