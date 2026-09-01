const fs = require('fs');
const https = require('https');

function getAccessToken() {
  const config = JSON.parse(fs.readFileSync('/Users/seg/.config/configstore/firebase-tools.json', 'utf8'));
  return config.tokens.access_token;
}

function request(url, options) {
  return new Promise((resolve, reject) => {
    const req = https.request(url, options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve(JSON.parse(data)));
    });
    req.on('error', reject);
    req.end();
  });
}

async function findAcc300() {
  const token = getAccessToken();
  const baseUrl = 'https://firestore.googleapis.com/v1/projects/zawolf-hr-system-60317/databases/(default)/documents/users';
  let nextPageToken = '';
  const allDocs = [];

  do {
    const url = `${baseUrl}?pageSize=300${nextPageToken ? `&pageToken=${nextPageToken}` : ''}`;
    const res = await request(url, { method: 'GET', headers: { 'Authorization': `Bearer ${token}` } });
    if (res.documents) allDocs.push(...res.documents);
    nextPageToken = res.nextPageToken || '';
  } while (nextPageToken);

  console.log(`Searching across ${allDocs.length} users for ACC-300...`);
  const matches = [];
  for (const doc of allDocs) {
    const docId = doc.name.split('/').pop();
    const f = doc.fields || {};
    const empId = f.employeeId?.stringValue || f.employeeCode?.stringValue || '';
    const email = f.email?.stringValue || '';
    const name = f.displayName?.stringValue || f.name?.stringValue || '';
    const pos = f.position?.stringValue || '';
    const role = f.role?.stringValue || '';
    const active = f.isActive?.booleanValue !== false;
    const isCeo = f.isAdvanceCeoApprover?.booleanValue;
    const isAccounts = f.isAdvanceAccountsApprover?.booleanValue;

    if (empId.toLowerCase().includes('acc-300') || email.toLowerCase().includes('acc-300') || docId.includes('300')) {
      matches.push({ docId, empId, name, email, pos, role, active, isCeo, isAccounts });
    }
  }

  console.log('Matches found:', JSON.stringify(matches, null, 2));
}

findAcc300().catch(console.error);
