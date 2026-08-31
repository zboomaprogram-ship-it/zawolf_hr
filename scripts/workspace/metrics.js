function createWorkspaceMetrics() {
  const counts = new Map();
  return {
    record(label, units = 1) {
      counts.set(label, (counts.get(label) || 0) + Math.max(0, Number(units) || 0));
    },
    snapshot() { return Object.fromEntries(counts); },
    assertBudget(label, limit) {
      if ((counts.get(label) || 0) > limit) throw new Error(`Workspace read budget exceeded: ${label}`);
    },
  };
}

async function meteredList(metrics, label, action) {
  const result = await action();
  metrics.record(label, Array.isArray(result) ? result.length : 1);
  return result;
}

module.exports = { createWorkspaceMetrics, meteredList };
