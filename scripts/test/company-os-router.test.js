'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');
const { routeCompanyOsRequest } = require('../company-os/router');

function fakeDb(user) {
  return { collection: () => ({ doc: () => ({ get: async () => ({ exists: Boolean(user), data: () => user || {} }) }) }) };
}

async function request({ token = 'valid-token', user = { isActive: true, role: 'employee' } } = {}) {
  const replies = [];
  const handled = await routeCompanyOsRequest({
    req: { method: 'GET', headers: { authorization: token ? `Bearer ${token}` : '' } },
    res: {},
    url: new URL('https://example.test/company-os/me'),
    db: fakeDb(user),
    verifyToken: async () => ({ uid: 'employee-1' }),
    flagConfig: {},
    sendJson: (_res, status, body) => replies.push({ status, body }),
  });
  return { handled, reply: replies.single || replies[0] };
}

test('authenticated active employee receives only safe identity and disabled flags', async () => {
  const { handled, reply } = await request();
  assert.equal(handled, true);
  assert.equal(reply.status, 200);
  assert.equal(reply.body.actor.uid, 'employee-1');
  assert.equal(Object.values(reply.body.flags).every((value) => value === false), true);
});

test('missing session and inactive accounts fail closed with safe envelopes', async () => {
  assert.equal((await request({ token: '' })).reply.status, 401);
  const inactive = await request({ user: { isActive: false, role: 'employee' } });
  assert.equal(inactive.reply.status, 403);
  assert.equal(JSON.stringify(inactive.reply.body).includes('Firebase'), false);
});

