const { GoogleAuth } = require('google-auth-library');
const { initializeApp, getApps, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

// 1. Initialize Firebase Admin
let app;
if (!getApps().length) {
  // If FIREBASE_SERVICE_ACCOUNT is present, use it. Otherwise rely on default credentials.
  const saEnv = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (saEnv) {
    let json = saEnv.trim();
    if (json.startsWith('\\{')) json = json.slice(1);
    json = json.replace(/\\"/g, '"').replace(/\\([^"\\/bfnrtu])/g, '$1');
    const sa = JSON.parse(json);
    if (typeof sa.private_key === 'string') {
      sa.private_key = sa.private_key.replace(/\\n/g, '\n');
    }
    app = initializeApp({ credential: cert(sa) });
  } else {
    app = initializeApp();
  }
} else {
  app = getApps()[0];
}

const db = getFirestore(app);

// 2. Drive API details
const DRIVE_SCOPE = 'https://www.googleapis.com/auth/drive';
const DRIVE_API = 'https://www.googleapis.com/drive/v3/files';

function parseServiceAccount(rawValue) {
  if (!rawValue || typeof rawValue !== 'string') {
    throw new Error('GOOGLE_SHEETS_SERVICE_ACCOUNT is missing.');
  }
  let json = rawValue.trim();
  if (json.startsWith('\\{')) json = json.slice(1);
  json = json.replace(/\\"/g, '"').replace(/\\([^"\\/bfnrtu])/g, '$1');
  const account = JSON.parse(json);
  if (typeof account.private_key === 'string') {
    account.private_key = account.private_key.replace(/\\n/g, '\n');
  }
  return account;
}

async function createFolder(authClient, name, parents = []) {
  const url = DRIVE_API;
  const body = {
    name,
    mimeType: 'application/vnd.google-apps.folder',
  };
  if (parents.length > 0) {
    body.parents = parents;
  }

  const response = await authClient.request({
    method: 'POST',
    url,
    data: body,
  });

  return response.data;
}

async function main() {
  const saEnv = process.env.GOOGLE_SHEETS_SERVICE_ACCOUNT || process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!saEnv) {
    console.error('Missing GOOGLE_SHEETS_SERVICE_ACCOUNT environment variable');
    process.exit(1);
  }

  const credentials = parseServiceAccount(saEnv);
  
  console.log('Authenticating with Google Drive...');
  const auth = new GoogleAuth({
    credentials,
    scopes: [DRIVE_SCOPE],
  });
  const authClient = await auth.getClient();

  console.log('Creating Root Folder: ZaWolf Company Workspace');
  const rootFolder = await createFolder(authClient, 'ZaWolf Company Workspace');
  console.log(`Root Folder created. ID: ${rootFolder.id}`);

  const departments = [
    'CEO',
    'Human Resources',
    'Research and Development',
    'In-House Marketing',
    'Legal Affairs',
    'Programming',
    'AI',
    'Accounting',
    'IT',
    'Account Management',
    'BD',
    'General Manager',
    'Kitchen Marketing'
  ];

  const folderMap = {
    rootFolderId: rootFolder.id,
    departments: {},
    createdAt: FieldValue.serverTimestamp(),
  };

  console.log('Creating department subfolders...');
  for (const dept of departments) {
    const subFolder = await createFolder(authClient, dept, [rootFolder.id]);
    console.log(` - Created [${dept}] -> ${subFolder.id}`);
    folderMap.departments[dept] = subFolder.id;
  }

  console.log('Saving folder structure to Firestore workspaceSources/company_folders...');
  await db.collection('workspaceSources').doc('company_folders').set(folderMap, { merge: true });
  console.log('Successfully saved to Firestore!');
}

main().catch(err => {
  console.error('Failed to create company folder structure:', err);
  process.exit(1);
});
