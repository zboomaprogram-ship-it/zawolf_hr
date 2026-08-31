const { appendWorkspaceAudit, normalizeExternalActivity } = require('./audit');

/**
 * Reconciles an already bounded provider change page.  This intentionally does
 * not enumerate a whole Drive, and records no document contents.  Callers keep
 * the provider cursor and page size outside this pure, retry-safe boundary.
 */
async function reconcileExternalActivity({ db, changes = [], now = new Date() }) {
  const seen = new Set();
  const events = [];
  for (const change of changes.slice(0, 200)) {
    const activity = normalizeExternalActivity(change);
    if (!activity.resourceId) continue;
    const fingerprint = `${activity.resourceId}:${activity.providerUpdatedAt || ''}:${activity.details.activityType}`;
    if (seen.has(fingerprint)) continue;
    seen.add(fingerprint);
    events.push(await appendWorkspaceAudit({
      db,
      actorId: activity.actorId,
      resourceId: activity.resourceId,
      action: activity.action,
      details: activity.details,
      now,
    }));
  }
  return { reconciled: events.length, events };
}

module.exports = { reconcileExternalActivity };
