const fs = require('fs');

async function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function main() {
  const config = require('/Users/seg/.config/configstore/firebase-tools.json');
  const auth = require('/Users/seg/.nvm/versions/node/v22.19.0/lib/node_modules/firebase-tools/lib/auth');

  console.log('Fetching access token...');
  const tokenObj = await auth.getAccessToken(config.tokens.refresh_token, [
    'https://www.googleapis.com/auth/cloud-platform',
    'https://www.googleapis.com/auth/firebase'
  ]);
  const accessToken = tokenObj.access_token;
  console.log('Got access token, length:', accessToken.length);

  const rulesContent = fs.readFileSync('/Users/seg/Shemais/Shemais/zawolf_hr/firestore.rules', 'utf8');

  console.log('Creating ruleset on projects/zawolf-hr-system-60317/rulesets...');
  let rulesetData = null;
  for (let attempt = 1; attempt <= 5; attempt++) {
    console.log(`Ruleset creation attempt ${attempt}/5...`);
    const rulesetRes = await fetch('https://firebaserules.googleapis.com/v1/projects/zawolf-hr-system-60317/rulesets', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        source: {
          files: [
            {
              name: 'firestore.rules',
              content: rulesContent
            }
          ]
        }
      })
    });

    rulesetData = await rulesetRes.json();
    console.log('Ruleset HTTP status:', rulesetRes.status);
    if (rulesetRes.status === 200 && rulesetData.name) {
      console.log('Ruleset created successfully:', rulesetData.name);
      break;
    }
    console.log('Attempt failed with:', JSON.stringify(rulesetData));
    if (attempt < 5) {
      console.log('Waiting 3s before retry...');
      await sleep(3000);
    }
  }

  if (!rulesetData || !rulesetData.name) {
    console.error('Failed to create ruleset after 5 attempts');
    process.exit(1);
  }

  console.log('Updating release cloud.firestore to point to:', rulesetData.name);
  let releaseData = null;
  for (let attempt = 1; attempt <= 10; attempt++) {
    console.log(`Release update attempt ${attempt}/10...`);
    const releaseRes = await fetch('https://firebaserules.googleapis.com/v1/projects/zawolf-hr-system-60317/releases/cloud.firestore', {
      method: 'PATCH',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        release: {
          name: 'projects/zawolf-hr-system-60317/releases/cloud.firestore',
          rulesetName: rulesetData.name
        }
      })
    });
    releaseData = await releaseRes.json();
    console.log('Release HTTP status:', releaseRes.status);
    if (releaseRes.status === 200 && releaseData.name) {
      console.log('Release updated successfully!');
      break;
    }
    console.log('Attempt failed with:', JSON.stringify(releaseData));
    if (attempt < 10) {
      console.log('Waiting 3s before retry...');
      await sleep(3000);
    }
  }

  if (!releaseData || releaseData.error) {
    console.error('Failed to update release after 10 attempts');
    process.exit(1);
  }

  console.log('VERIFYING DEPLOYED RULESET...');
  const verifyRes = await fetch('https://firebaserules.googleapis.com/v1/projects/zawolf-hr-system-60317/releases/cloud.firestore', {
    headers: {
      'Authorization': `Bearer ${accessToken}`
    }
  });
  const verifyData = await verifyRes.json();
  console.log('Active release in production:', JSON.stringify(verifyData, null, 2));
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
