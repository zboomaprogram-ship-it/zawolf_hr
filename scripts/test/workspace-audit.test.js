const test = require('node:test');
const assert = require('node:assert/strict');
const { appendWorkspaceAudit, safeAuditDetails } = require('../workspace/audit');

function fakeDb() {
  const documents = new Map();
  return {
    documents,
    collection(name) {
      return {
        doc(id) {
          const path = `${name}/${id}`;
          return {
            id,
            async create(value) {
              if (documents.has(path)) throw new Error('duplicate audit event');
              documents.set(path, value);
            },
          };
        },
      };
    },
  };
}

test('audit preserves actor attribution and only stores safe summaries', async () => {
  const event = await appendWorkspaceAudit({
    db: fakeDb(),
    actorId: 'employee-1',
    resourceId: 'sheet-1',
    action: 'sheet_edit',
    details: {
      operationId: 'op-1',
      range: 'Sheet1!A2:B3',
      changeCount: 4,
      changedValue: 'salary and private notes must never be logged',
      formula: '=SECRET()',
    },
  });

  assert.equal(event.actorId, 'employee-1');
  assert.deepEqual(event.details, {
    operationId: 'op-1',
    range: 'Sheet1!A2:B3',
    changeCount: 4,
  });
});

test('external activity remains explicitly unattributed', async () => {
  const event = await appendWorkspaceAudit({
    db: fakeDb(),
    resourceId: 'sheet-1',
    action: 'external_activity',
    details: { source: 'google_drive', activityType: 'external_edit' },
  });

  assert.equal(event.actorId, 'external_unattributed');
  assert.equal(event.details.activityType, 'external_edit');
});

test('pilot changes retain only safe rollout evidence', async () => {
  const event = await appendWorkspaceAudit({
    db: fakeDb(),
    actorId: 'dynamic-it-manager',
    resourceId: 'company_workspace_v2',
    action: 'workspace_pilot_changed',
    details: {
      mode: 'limited_pilot',
      audienceCount: 2,
      reason: 'non-production acceptance',
      actorTokens: 'must not be stored',
    },
  });

  assert.deepEqual(event.details, {
    mode: 'limited_pilot',
    audienceCount: 2,
    reason: 'non-production acceptance',
  });
});

test('audit taxonomy rejects unknown actions and sensitive nested metadata', async () => {
  assert.deepEqual(safeAuditDetails({
    source: 'zawolf',
    nested: { rawProviderResponse: 'never store' },
  }), { source: 'zawolf' });
  await assert.rejects(
    appendWorkspaceAudit({
      db: fakeDb(),
      actorId: 'employee-1',
      resourceId: 'sheet-1',
      action: 'unknown_action',
    }),
    /Unsupported workspace audit action/,
  );
});
