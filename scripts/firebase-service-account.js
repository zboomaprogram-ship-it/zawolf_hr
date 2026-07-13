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

module.exports = { parseFirebaseServiceAccount };
