'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  emulatorProjectId,
} = require('../firebase-service-account');

test('emulator initialization is allowed only when Auth and Firestore use local hosts', () => {
  assert.equal(emulatorProjectId({
    FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080',
    FIREBASE_AUTH_EMULATOR_HOST: 'localhost:9099',
    GCLOUD_PROJECT: 'zawolf-acceptance',
  }), 'zawolf-acceptance');
  assert.equal(emulatorProjectId({
    FIRESTORE_EMULATOR_HOST: 'localhost:8080',
    FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099',
    GOOGLE_CLOUD_PROJECT: 'zawolf-acceptance-alt',
  }), 'zawolf-acceptance-alt');
});

test('emulator initialization fails closed for missing, remote, or production hosts', () => {
  assert.equal(emulatorProjectId({
    FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080',
  }), null);
  assert.equal(emulatorProjectId({
    FIRESTORE_EMULATOR_HOST: 'firestore.example.com:8080',
    FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099',
  }), null);
  assert.equal(emulatorProjectId({
    FIRESTORE_EMULATOR_HOST: '127.0.0.1:8080',
    FIREBASE_AUTH_EMULATOR_HOST: '127.0.0.1:9099',
    GCLOUD_PROJECT: 'zawolf-hr-system-60317',
  }), null);
});
