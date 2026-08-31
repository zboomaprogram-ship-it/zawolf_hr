const test = require('node:test');
const assert = require('node:assert/strict');

const {
  canonicalSalesFilters,
  salesFilterVersion,
  mappingDocumentId,
  reconcileAgentMappings,
  sourceHealth,
} = require('../sales-indicators');

test('equivalent sales filters have one deterministic version', () => {
  const a = { startDate: '2026-07-01', endDate: '2026-07-31', sales: ['S8', 'S4'] };
  const b = { startDate: '2026-07-01', endDate: '2026-07-31', sales: ['S4', 'S8', 'S4'] };
  assert.deepEqual(canonicalSalesFilters(a), canonicalSalesFilters(b));
  assert.equal(salesFilterVersion(a), salesFilterVersion(b));
});

test('different employee filters never share a snapshot version', () => {
  assert.notEqual(
    salesFilterVersion({ startDate: '2026-07-01', endDate: '2026-07-31', sales: ['S4'] }),
    salesFilterVersion({ startDate: '2026-07-01', endDate: '2026-07-31', sales: ['S8'] }),
  );
});

test('mapping registry is explicit and ambiguous rows fail closed', () => {
  const agents = [{ kind: 'sales', key: 'S4', mappedUserId: 'legacy' }];
  const mapped = reconcileAgentMappings(agents, [{
    providerRole: 'sales', providerKey: 'S4', userId: 'u1', employeeId: 'BD-1', employeeName: 'موظف',
  }]);
  assert.equal(mapped[0].mappingStatus, 'mapped');
  assert.equal(mapped[0].mappedUserId, 'u1');

  const ambiguous = reconcileAgentMappings(agents, [
    { providerRole: 'sales', providerKey: 'S4', userId: 'u1' },
    { providerRole: 'sales', providerKey: 'S4', userId: 'u2' },
  ]);
  assert.equal(ambiguous[0].mappingStatus, 'ambiguous');
  assert.equal(ambiguous[0].mappedUserId, '');
});

test('mapping ids are stable and source health reports partial data', () => {
  assert.equal(mappingDocumentId('sales', 'S4'), mappingDocumentId('SALES', 's4'));
  assert.equal(sourceHealth({ ambiguous: 1 }), 'partial');
  assert.equal(sourceHealth({ apiOk: false }), 'unavailable');
  assert.equal(sourceHealth(), 'healthy');
});
