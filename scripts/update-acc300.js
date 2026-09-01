const fs = require('fs');
const https = require('https');

function getAccessToken() {
  const config = JSON.parse(fs.readFileSync('/Users/seg/.config/configstore/firebase-tools.json', 'utf8'));
  return config.tokens.access_token;
}

function request(url, options, bodyData) {
  return new Promise((resolve, reject) => {
    const req = https.request(url, options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          resolve(data);
        }
      });
    });
    req.on('error', reject);
    if (bodyData) req.write(typeof bodyData === 'string' ? bodyData : JSON.stringify(bodyData));
    req.end();
  });
}

async function run() {
  const token = getAccessToken();
  const docId = 'WhzEDqmHGiQXObOdgO0JHd9ccIX2'; // ACC-300: مصطفي رضا الشربيني ابراهيم
  const url = `https://firestore.googleapis.com/v1/projects/zawolf-hr-system-60317/databases/(default)/documents/users/${docId}?updateMask.fieldPaths=isAdvanceAccountsApprover&updateMask.fieldPaths=isActive`;

  const options = {
    method: 'PATCH',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    }
  };

  const body = {
    fields: {
      isAdvanceAccountsApprover: { booleanValue: true },
      isActive: { booleanValue: true }
    }
  };

  const res = await request(url, options, body);
  console.log('Update result for ACC-300:', res.name ? 'SUCCESS' : res);
}

run().catch(console.error);
