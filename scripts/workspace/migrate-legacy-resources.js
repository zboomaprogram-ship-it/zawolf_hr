/** Non-destructive legacy resource migration planner.  It never deletes,
 * moves, or changes a Google permission.  APPLY is deliberately opt-in and
 * needs a caller-supplied writer, which makes dry-run the production default. */
function buildMigrationPlan({ legacyResources = [], knownProviderIds = new Set() }) {
  const seen = new Set();
  return legacyResources.map((resource) => {
    const providerId = String(resource.providerId || resource.id || '');
    if (!providerId) return { action: 'skip', reason: 'missing_provider_id', resource };
    if (seen.has(providerId) || knownProviderIds.has(providerId)) {
      return { action: 'skip', reason: 'already_registered', providerId, resource };
    }
    seen.add(providerId);
    return {
      action: 'create', providerId,
      resource: {
        providerId,
        name: String(resource.name || 'Untitled'),
        type: resource.type || 'file',
        parentProviderId: resource.parentProviderId || null,
      },
    };
  });
}

async function runLegacyResourceMigration({ legacyResources, knownProviderIds, apply = false, writer }) {
  const plan = buildMigrationPlan({ legacyResources, knownProviderIds });
  if (!apply) return { dryRun: true, plan, applied: 0 };
  if (!writer || typeof writer.create !== 'function') throw new Error('Migration writer is required when APPLY=true.');
  let applied = 0;
  for (const item of plan) {
    if (item.action !== 'create') continue;
    await writer.create(item.resource);
    applied += 1;
  }
  return { dryRun: false, plan, applied };
}

module.exports = { buildMigrationPlan, runLegacyResourceMigration };
