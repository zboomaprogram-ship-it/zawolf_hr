'use strict';

const { completeStage } = require('./requests');

function completeAccessProvisioning({ store, actor, operationId, requestId, expectedVersion, note, now = new Date() }) {
  return completeStage({
    store,
    actor,
    operationId,
    requestId,
    expectedVersion,
    stageType: 'closure',
    details: {
      note: String(note || 'تم تأكيد منح الوصول يدوياً').trim().slice(0, 1000),
      externalProvisioning: false,
    },
    now,
  });
}

module.exports = { completeAccessProvisioning };
