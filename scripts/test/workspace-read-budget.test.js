const test = require('node:test');
const assert = require('node:assert/strict');
const { createWorkspaceMetrics, meteredList } = require('../workspace/metrics');

test('workspace list metrics are bounded and report a budget breach', async () => {
  const metrics = createWorkspaceMetrics();
  await meteredList(metrics, 'resource_discovery', async () => [1, 2, 3]);
  assert.equal(metrics.snapshot().resource_discovery, 3);
  assert.throws(() => metrics.assertBudget('resource_discovery', 2), /budget exceeded/);
  assert.doesNotThrow(() => metrics.assertBudget('resource_discovery', 3));
});
