'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('permission creates accept the job title snapshot sent by installed clients', () => {
  const rules = fs.readFileSync(path.join(__dirname, '..', '..', 'firestore.rules'), 'utf8');
  const section = rules.slice(
    rules.indexOf('match /permissions/{permissionId}'),
    rules.indexOf('match /resignations/{resignationId}'),
  );
  assert.match(section, /'jobTitle'/);
});

test('permission and leave decisions require the assigned current manager stage', () => {
  const rules = fs.readFileSync(path.join(__dirname, '..', '..', 'firestore.rules'), 'utf8');
  const sequence = rules.slice(
    rules.indexOf('function sequentialManagerDecision()'),
    rules.indexOf('function isValidSelfCreate()'),
  );
  assert.match(sequence, /managerIds\[currentIndex\] == uid\(\)/);
  assert.match(sequence, /resource\.data\.get\('managerId', ''\) == managerIds\[currentIndex\]/);
  assert.match(sequence, /managerIds\.removeAll\(\[managerIds\[currentIndex\]\]\)\.size\(\)/);
  assert.doesNotMatch(sequence, /isSuperAdmin\(\)/);

  for (const [collection, next] of [
    ['leaves', 'permissions'],
    ['permissions', 'resignations'],
  ]) {
    const section = rules.slice(
      rules.indexOf(`match /${collection}/{`),
      rules.indexOf(`match /${next}/{`),
    );
    assert.match(section, new RegExp(`${collection === 'leaves' ? 'leave' : 'permission'}ManagerReview\\(\\)`));
    assert.doesNotMatch(section, /\(isHR\(\) \|\| isCurrentApprovalManager\(\)\)/);
  }

  for (const review of ['permissionHrReview', 'leaveHrReview']) {
    const section = rules.slice(rules.indexOf(`function ${review}()`));
    assert.match(section, /resource\.data\.get\('reviewedBy', ''\) != uid\(\)/);
  }
});
