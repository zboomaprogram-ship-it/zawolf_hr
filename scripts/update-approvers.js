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

async function setField(docId, fieldName, value) {
  const token = getAccessToken();
  const url = `https://firestore.googleapis.com/v1/projects/zawolf-hr-system-60317/databases/(default)/documents/users/${docId}?updateMask.fieldPaths=${fieldName}`;
  const options = {
    method: 'PATCH',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    }
  };
  const body = {
    fields: {
      [fieldName]: { booleanValue: value }
    }
  };

  const res = await request(url, options, body);
  return res;
}

async function run() {
  const ceoIds = [
    'lna3lpI4slboaUykFw3JlNTNjLN2', // سامي المتولي المتولي (sami.elmetwali@seginvest.com) - CEO
    'KfvKBcZOzcPSj9KJEIJDT9DfLWA3', // معاذ حسن (MoazHassan@SEG.com) - CEO
  ];

  const accountsIds = [
    'JnkojVHPGFZO2Kk1JVzcMj9FY9p2', // احمد محمد الهادي حسين (acc-302a@seg.com) - Accountant
    'Twb742HJQKg2zeIxU5vvRCKkNj72', // حازم ايمن على سيد احمد الميناوى (hazem.meniawy@seginvest.com) - Accountant
    'd4mIFgQZQKSTzj090TGWyLoM6kJ2', // هدي احمد موسي عبد الفتاح النادي (hoda@seginvest.com) - Accountant
  ];

  console.log('--- Setting isAdvanceCeoApprover = true ---');
  for (const id of ceoIds) {
    const res = await setField(id, 'isAdvanceCeoApprover', true);
    console.log(`Updated CEO user ${id}:`, res.name ? 'SUCCESS' : res);
  }

  console.log('\n--- Setting isAdvanceAccountsApprover = true ---');
  for (const id of accountsIds) {
    const res = await setField(id, 'isAdvanceAccountsApprover', true);
    console.log(`Updated Accounts user ${id}:`, res.name ? 'SUCCESS' : res);
  }
}

run().catch(console.error);
