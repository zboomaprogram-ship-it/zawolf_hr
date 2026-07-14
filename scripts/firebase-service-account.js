function parseFirebaseServiceAccount(rawValue) {
  if (!rawValue || typeof rawValue !== 'string') {
    throw new Error('FIREBASE_SERVICE_ACCOUNT is missing.');
  }

  try {
    let firebaseJson = rawValue.trim();

    // Hostinger may inject JSON with an extra leading backslash and escaped
    // quotation marks. Normalize only those invalid wrappers before parsing.
    if (firebaseJson.startsWith('\\{')) {
      firebaseJson = firebaseJson.slice(1);
    }
    firebaseJson = firebaseJson.replace(/\\"/g, '"');
    firebaseJson = firebaseJson.replace(/\\([^"\\/bfnrtu])/g, '$1');

    const serviceAccount = JSON.parse(firebaseJson);
    if (typeof serviceAccount.private_key === 'string') {
      serviceAccount.private_key = serviceAccount.private_key.replace(
        /\\n/g,
        '\n',
      );
    }

    if (
      !serviceAccount.project_id ||
      !serviceAccount.client_email ||
      !serviceAccount.private_key
    ) {
      throw new Error('Required Firebase service-account fields are missing.');
    }
    return serviceAccount;
  } catch (error) {
    throw new Error(
      `FIREBASE_SERVICE_ACCOUNT is invalid: ${error.message || error}`,
    );
  }
}

function getExistingFirebaseApp(admin) {
  const apps = typeof admin.getApps === 'function'
    ? admin.getApps()
    : (admin.apps || []);
  return apps.length > 0 ? apps[0] : null;
}

function installFirestoreCompatibility(admin) {
  if (typeof admin.firestore === 'function') return;
  const { FieldValue, Timestamp, getFirestore } = require('firebase-admin/firestore');
  admin.firestore = getFirestore;
  admin.firestore.FieldValue = FieldValue;
  admin.firestore.Timestamp = Timestamp;
}

module.exports = {
  getExistingFirebaseApp,
  installFirestoreCompatibility,
  parseFirebaseServiceAccount,
};
