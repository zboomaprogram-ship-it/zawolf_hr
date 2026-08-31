'use strict';

/**
 * Creates stable ZaWolf resource IDs for a discovered Drive tree and resolves
 * each item's parent to another resource in the same import.  This small pure
 * module deliberately has no Firestore or Google dependency, so importing a
 * large company tree stays deterministic and testable.
 */
function planWorkspaceSourceImport(nodes, existingByExternalId, createResourceId) {
  const resourceIdByExternalId = new Map(existingByExternalId || []);
  const sourceNodes = Array.isArray(nodes) ? nodes : [];

  for (const node of sourceNodes) {
    const externalId = String(node?.id || '').trim();
    if (!externalId) continue;
    if (!resourceIdByExternalId.has(externalId)) {
      resourceIdByExternalId.set(externalId, createResourceId());
    }
  }

  return sourceNodes
    .map((node) => {
      const externalId = String(node?.id || '').trim();
      if (!externalId) return null;
      const resourceId = resourceIdByExternalId.get(externalId);
      const parentExternalId = String(node?.parentExternalId || '').trim();
      const candidateParentId = resourceIdByExternalId.get(parentExternalId) || null;
      return {
        node,
        externalId,
        resourceId,
        parentResourceId: candidateParentId === resourceId ? null : candidateParentId,
        existed: Boolean((existingByExternalId || new Map()).has(externalId)),
      };
    })
    .filter(Boolean);
}

const SOURCE_IMPORT_LEASE_MS = 15 * 60 * 1000;

/// Returns the next safe run state without depending on Firestore. A stale
/// run is deliberately resumed by reconciling the same stable external IDs;
/// no Drive item is moved, renamed, shared, or deleted as part of recovery.
function nextSourceImportRun(existing = {}, { token, nowMs = Date.now() } = {}) {
  const leaseUntilMs = Number(existing.leaseUntilMs || 0);
  const running = existing.state === 'running' && leaseUntilMs > nowMs;
  if (running) return { kind: 'busy' };
  return {
    kind: existing.state === 'running' || existing.state === 'failed_retryable'
      ? 'resume'
      : 'new',
    value: {
      state: 'running',
      token,
      leaseUntilMs: nowMs + SOURCE_IMPORT_LEASE_MS,
      resumedCount: Number(existing.resumedCount || 0) +
        (existing.state === 'running' || existing.state === 'failed_retryable' ? 1 : 0),
      processed: 0,
      total: 0,
      phase: 'discovering',
    },
  };
}

module.exports = {
  planWorkspaceSourceImport,
  SOURCE_IMPORT_LEASE_MS,
  nextSourceImportRun,
};
