'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { assertEmulatorEnvironment, createRemoteHarness } = require('./helpers/remote-work-fixtures');

// Unsigned identities are accepted only by the local Firestore emulator.
// No Firebase credential or production token is used by this test.
function emulatorIdentity(projectId, uid) {
  const issued = Math.floor(Date.now() / 1000);
  const encode = (value) => Buffer.from(JSON.stringify(value)).toString('base64url');
  return `${encode({ alg: 'none', typ: 'JWT' })}.${encode({
    iss: `https://securetoken.google.com/${projectId}`,
    aud: projectId, sub: uid, user_id: uid,
    iat: issued, exp: issued + 3600, auth_time: issued,
    firebase: { sign_in_provider: 'custom', identities: {} },
  })}.`;
}

async function clientRequest({ uid, path, method = 'PATCH', fields = {} }) {
  const { host, projectId } = assertEmulatorEnvironment();
  return fetch(`http://${host}/v1/projects/${projectId}/databases/(default)/documents/${path}`, {
    method,
    headers: {
      authorization: `Bearer ${emulatorIdentity(projectId, uid)}`,
      'content-type': 'application/json',
    },
    ...(method === 'GET' || method === 'DELETE' ? {} : { body: JSON.stringify({ fields }) }),
  });
}

const emulatorOptions = { skip: process.env.RUN_REMOTE_WORK_EMULATOR !== '1' };
const companyFields = {
  name: { stringValue: 'Rules fixture' },
  attendancePolicy: { mapValue: { fields: { defaultStartTime: { stringValue: '09:00' } } } },
  attendancePolicyRevision: { integerValue: '1' },
};

test('policy rules deny direct client access to server-owned policy records and grants', emulatorOptions, async () => {
  const harness = await createRemoteHarness({ backend: 'emulator' });
  const collections = [
    'attendancePolicyDrafts', 'attendancePolicyHeads', 'attendancePolicyRevisions',
    'attendancePolicyOperations', 'remoteWorkCapabilityGrants', 'remoteWorkQualifiedProfiles',
  ];
  try {
    for (const role of ['hr_admin', 'super_admin', 'employee']) {
      const uid = `policy_rules_${role}`;
      await harness.seed('users', uid, { role, isActive: true, companyId: 'zawolf' });
      for (const collection of collections) {
        const id = `rules_${role}`;
        await harness.seed(collection, id, { companyId: 'zawolf', version: 1 });
        for (const method of ['GET', 'PATCH', 'DELETE']) {
          const response = await clientRequest({ uid, path: `${collection}/${id}`, method,
            fields: { companyId: { stringValue: 'zawolf' }, version: { integerValue: '2' } } });
          assert.equal(response.status, 403, `${role} ${method} ${collection}: ${await response.text()}`);
        }
        const create = await clientRequest({ uid, path: `${collection}/${id}_new`,
          fields: { companyId: { stringValue: 'zawolf' } } });
        assert.equal(create.status, 403, `${role} create ${collection}: ${await create.text()}`);
      }
    }
  } finally { await harness.close(); }
});

test('company policy projection cannot be changed, erased, or deleted by a settings client', emulatorOptions, async () => {
  const harness = await createRemoteHarness({ backend: 'emulator' });
  try {
    for (const role of ['hr_admin', 'super_admin']) {
      const uid = `policy_projection_${role}`;
      const companyId = `policy_projection_${role}`;
      await harness.seed('users', uid, { role, isActive: true, companyId });
      await harness.seed('companies', companyId, {
        name: 'Rules fixture', attendancePolicy: { defaultStartTime: '09:00' }, attendancePolicyRevision: 1,
      });
      const safeUpdate = await clientRequest({ uid, path: `companies/${companyId}`, fields: {
        ...companyFields, securityPolicy: { mapValue: { fields: { forceUpdateEnabled: { booleanValue: false } } } },
      } });
      assert.equal(safeUpdate.status, 200, `unrelated settings: ${await safeUpdate.text()}`);
      for (const fields of [
        { ...companyFields, attendancePolicyRevision: { integerValue: '2' } },
        { ...companyFields, attendancePolicy: { mapValue: { fields: {} } } },
        { name: companyFields.name },
      ]) {
        const response = await clientRequest({ uid, path: `companies/${companyId}`, fields });
        assert.equal(response.status, 403, `policy replacement: ${await response.text()}`);
      }
      const remove = await clientRequest({ uid, path: `companies/${companyId}`, method: 'DELETE' });
      assert.equal(remove.status, 403, `policy deletion by ${role}: ${await remove.text()}`);
      const after = await harness.read('companies', companyId);
      assert.equal(after.attendancePolicy.defaultStartTime, '09:00');
      assert.equal(after.attendancePolicyRevision, 1);
    }
  } finally { await harness.close(); }
});
