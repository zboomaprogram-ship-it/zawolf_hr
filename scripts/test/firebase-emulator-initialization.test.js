'use strict';

const test = require('node:test');
const assert = require('node:assert/strict');

const {
  emulatorProjectId,
  firebaseAppOptions,
  installFirestoreCompatibility,
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

test('Firestore compatibility exposes FieldPath for firebase-admin v14 callers', () => {
  const admin = {};
  installFirestoreCompatibility(admin);
  assert.equal(typeof admin.firestore, 'function');
  assert.equal(typeof admin.firestore.FieldPath.documentId, 'function');
  assert.equal(typeof admin.firestore.FieldValue.serverTimestamp, 'function');
});

test('production Firebase options include project and modern Storage bucket', () => {
  const serviceAccount = { project_id: 'demo-project' };
  const credential = { kind: 'credential' };
  const options = firebaseAppOptions({ cert: (value) => {
    assert.equal(value, serviceAccount);
    return credential;
  } }, serviceAccount);
  assert.deepEqual(options, {
    credential,
    projectId: 'demo-project',
    storageBucket: 'demo-project.firebasestorage.app',
  });
});
