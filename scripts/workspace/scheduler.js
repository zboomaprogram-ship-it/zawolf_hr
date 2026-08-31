'use strict';

// Workspace report generation is deliberately request-driven. Hostinger owns
// the live Node runtime; it must not create a second scheduled report worker.
// A manual authenticated request is the recovery path for a failed report run.
function workspaceSchedulerOwnership() {
  return {
    owner: 'hostinger_node_runtime',
    schedule: 'request_driven',
    duplicateSchedulerAllowed: false,
    recovery: 'rerun the same authenticated report request; the report key replays or resumes safely',
  };
}

module.exports = { workspaceSchedulerOwnership };
