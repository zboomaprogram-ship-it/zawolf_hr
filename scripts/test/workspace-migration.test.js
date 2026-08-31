const test = require('node:test');
const assert = require('node:assert/strict');
const { buildMigrationPlan, runLegacyResourceMigration } = require('../workspace/migrate-legacy-resources');

test('legacy migration dry-run is non-destructive and skips duplicates', async () => {
  const plan = buildMigrationPlan({ legacyResources: [
    { id: 'a', name: 'A' }, { id: 'a', name: 'A duplicate' }, { id: 'b', name: 'B' },
  ], knownProviderIds: new Set(['b']) });
  assert.deepEqual(plan.map((item) => item.action), ['create', 'skip', 'skip']);
  const result = await runLegacyResourceMigration({ legacyResources: [{ id: 'a', name: 'A' }] });
  assert.equal(result.dryRun, true);
  assert.equal(result.applied, 0);
});

test('migration apply requires an explicit writer and only creates planned entries', async () => {
  const created = [];
  const result = await runLegacyResourceMigration({ legacyResources: [{ id: 'a', name: 'A' }], apply: true, writer: { create: async (value) => created.push(value) } });
  assert.equal(result.applied, 1);
  assert.equal(created[0].providerId, 'a');
});
