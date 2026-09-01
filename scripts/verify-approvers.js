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

async function verify() {
  const token = getAccessToken();
  const ids = [
    'lna3lpI4slboaUykFw3JlNTNjLN2',
    'KfvKBcZOzcPSj9KJEIJDT9DfLWA3',
    'JnkojVHPGFZO2Kk1JVzcMj9FY9p2',
    'Twb742HJQKg2zeIxU5vvRCKkNj72',
    'd4mIFgQZQKSTzj090TGWyLoM6kJ2'
  ];

  console.log('--- Verification Output ---');
  for (const id of ids) {
    const url = `https://firestore.googleapis.com/v1/projects/zawolf-hr-system-60317/databases/(default)/documents/users/${id}`;
    const doc = await request(url, { method: 'GET', headers: { 'Authorization': `Bearer ${token}` } });
    const f = doc.fields || {};
    const name = f.displayName?.stringValue || f.name?.stringValue;
    const email = f.email?.stringValue;
    const ceo = f.isAdvanceCeoApprover?.booleanValue;
    const acc = f.isAdvanceAccountsApprover?.booleanValue;
    console.log(`User: ${name} (${email}) | isAdvanceCeoApprover=${ceo} | isAdvanceAccountsApprover=${acc}`);
  }
}

verify().catch(console.error);
