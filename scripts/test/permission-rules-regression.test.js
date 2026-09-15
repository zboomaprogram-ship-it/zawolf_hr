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
