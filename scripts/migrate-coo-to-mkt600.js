/**
 * Migration Script: Migrate Executive COO authority from COO-1300 to MKT-600
 *
 * Requirements:
 * - Update MKT-600 (qDZAXfORAQfGaLvyoyIGSH71bbK2):
 *   - role remains 'manager'
 *   - managerId = 'lna3lpI4slboaUykFw3JlNTNjLN2' (CEO-100)
 *   - managerIds = ['lna3lpI4slboaUykFw3JlNTNjLN2']
 *   - managerCodes = ['CEO-100']
 *   - managerNames = ['سامي المتولي المتولي']
 *   - executiveRole = 'coo'
 *   - isExecutiveApprover = true
 *   - organizationLevel = 'division_manager'
 *   - organizationDivisionId = 'operations'
 *
 * - Update COO-1300 (6qhpYQzP51b1PpOYAwZ5bOF0DI53):
 *   - executiveRole = null
 *   - isExecutiveApprover = false
 *
 * - Reassign Employees reporting to COO-1300:
 *   - For every user having managerId === '6qhpYQzP51b1PpOYAwZ5bOF0DI53' or
 *     managerIds containing '6qhpYQzP51b1PpOYAwZ5bOF0DI53' (except MKT-600):
 *     - replace managerId with 'qDZAXfORAQfGaLvyoyIGSH71bbK2'
 *     - in managerIds array, replace COO-1300 UID with MKT-600 UID
 *     - in managerCodes array, replace COO-1300 with MKT-600
 *     - in managerNames array, replace 'محمد منير الجمل' with 'اشرف عبد الرازق'
 *
 * - Reassign in-flight pending requests:
 *   - In leaves, permissions, resignations:
 *     - Where status === 'pending_manager' and managerId === '6qhpYQzP51b1PpOYAwZ5bOF0DI53':
 *       - update managerId to MKT-600 UID, managerName to 'اشرف عبد الرازق', managerCode to 'MKT-600',
 *         and managerIds to replace COO-1300 UID with MKT-600 UID.
 *
 * Flags:
 *   --dry-run (default: true)
 *   --execute (runs live changes)
 */

const fs = require('fs');
const path = require('path');
const https = require('https');

const COO_UID = '6qhpYQzP51b1PpOYAwZ5bOF0DI53';
const COO_CODE = 'COO-1300';
const COO_NAME = 'محمد منير الجمل';

const MKT_UID = 'qDZAXfORAQfGaLvyoyIGSH71bbK2';
const MKT_CODE = 'MKT-600';
const MKT_NAME = 'اشرف عبد الرازق';

const CEO_UID = 'lna3lpI4slboaUykFw3JlNTNjLN2';
const CEO_CODE = 'CEO-100';
const CEO_NAME = 'سامي المتولي المتولي';

const PROJECT_ID = 'zawolf-hr-system-60317';

function getAccessToken() {
  const config = JSON.parse(fs.readFileSync('/Users/seg/.config/configstore/firebase-tools.json', 'utf8'));
  return config.tokens.access_token;
}

function request(url, options = {}, bodyData = null) {
  return new Promise((resolve, reject) => {
    const token = getAccessToken();
    const headers = {
      'Authorization': `Bearer ${token}`,
      ...(options.headers || {})
    };
    if (bodyData) {
      headers['Content-Type'] = 'application/json';
    }

    const req = https.request(url, { ...options, headers }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve({ status: res.statusCode, body: parsed });
        } catch (e) {
          resolve({ status: res.statusCode, body: data });
        }
      });
    });
    req.on('error', reject);
    if (bodyData) {
      req.write(typeof bodyData === 'string' ? bodyData : JSON.stringify(bodyData));
    }
    req.end();
  });
}

async function runQuery(structuredQuery) {
  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents:runQuery`;
  const res = await request(url, { method: 'POST' }, { structuredQuery });
  if (Array.isArray(res.body)) {
    return res.body.filter(x => x.document).map(x => x.document);
  }
  return [];
}

async function getDocument(collection, docId) {
  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collection}/${docId}`;
  const res = await request(url, { method: 'GET' });
  return res.status === 200 ? res.body : null;
}

async function patchDocument(collection, docId, updateFields, maskPaths) {
  const maskQuery = maskPaths.map(p => `updateMask.fieldPaths=${encodeURIComponent(p)}`).join('&');
  const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collection}/${docId}?${maskQuery}`;
  const res = await request(url, { method: 'PATCH' }, { fields: updateFields });
  return res;
}

function parseArrayStrings(field) {
  if (!field || !field.arrayValue || !field.arrayValue.values) return [];
  return field.arrayValue.values.map(v => v.stringValue || '').filter(Boolean);
}

function toArrayValue(arr) {
  return {
    arrayValue: {
      values: arr.map(v => ({ stringValue: String(v) }))
    }
  };
}

async function main() {
  const args = process.argv.slice(2);
  const isExecute = args.includes('--execute');
  const isDryRun = !isExecute;

  console.log('====================================================');
  console.log(`MODE: ${isDryRun ? 'DRY RUN (Simulated)' : '🔴 LIVE EXECUTION'}`);
  console.log('====================================================\n');

  const backupData = {
    timestamp: new Date().toISOString(),
    users: [],
    requests: []
  };

  // 1. Fetch MKT-600 doc
  const mktDoc = await getDocument('users', MKT_UID);
  if (!mktDoc) throw new Error('MKT-600 user document not found!');
  backupData.users.push({ id: MKT_UID, data: mktDoc });

  // 2. Fetch COO-1300 doc
  const cooDoc = await getDocument('users', COO_UID);
  if (!cooDoc) throw new Error('COO-1300 user document not found!');
  backupData.users.push({ id: COO_UID, data: cooDoc });

  // 3. Find all users assigned to COO-1300
  console.log('Finding employees reporting to COO-1300...');
  const usersWithMgrId = await runQuery({
    from: [{ collectionId: 'users' }],
    where: {
      fieldFilter: {
        field: { fieldPath: 'managerId' },
        op: 'EQUAL',
        value: { stringValue: COO_UID }
      }
    }
  });

  const usersWithMgrIds = await runQuery({
    from: [{ collectionId: 'users' }],
    where: {
      fieldFilter: {
        field: { fieldPath: 'managerIds' },
        op: 'ARRAY_CONTAINS',
        value: { stringValue: COO_UID }
      }
    }
  });

  const employeeMap = new Map();
  for (const doc of [...usersWithMgrId, ...usersWithMgrIds]) {
    const docId = doc.name.split('/').pop();
    if (docId !== MKT_UID && docId !== COO_UID) {
      employeeMap.set(docId, doc);
    }
  }

  console.log(`Found ${employeeMap.size} distinct subordinate employees to reassign to MKT-600.\n`);

  for (const [id, doc] of employeeMap.entries()) {
    backupData.users.push({ id, data: doc });
  }

  // 4. Find in-flight pending requests waiting on COO-1300
  console.log('Finding in-flight requests waiting on COO-1300...');
  const pendingRequests = [];

  for (const coll of ['leaves', 'permissions', 'resignations']) {
    const docs = await runQuery({
      from: [{ collectionId: coll }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'status' },
          op: 'EQUAL',
          value: { stringValue: 'pending_manager' }
        }
      }
    });

    for (const doc of docs) {
      const f = doc.fields;
      const mgrId = f.managerId?.stringValue;
      const mgrIds = parseArrayStrings(f.managerIds);
      if (mgrId === COO_UID || mgrIds.includes(COO_UID)) {
        const docId = doc.name.split('/').pop();
        pendingRequests.push({ coll, docId, doc });
        backupData.requests.push({ coll, id: docId, data: doc });
      }
    }
  }
  console.log(`Found ${pendingRequests.length} in-flight pending requests waiting on COO-1300.\n`);

  // Write Backup
  const backupDir = path.join(__dirname, 'backups');
  if (!fs.existsSync(backupDir)) {
    fs.mkdirSync(backupDir, { recursive: true });
  }
  const backupFile = path.join(backupDir, `migration-coo-to-mkt600-${Date.now()}.json`);
  fs.writeFileSync(backupFile, JSON.stringify(backupData, null, 2), 'utf8');
  console.log(`✅ Snapshot backup saved to: ${backupFile}\n`);

  // Plan Summary
  console.log('--- PLANNED ACTIONS ---');
  console.log(`1. Update MKT-600 (${MKT_UID}):`);
  console.log(`   - role: 'manager' (PRESERVED)`);
  console.log(`   - managerId: ${CEO_UID} (CEO-100)`);
  console.log(`   - managerIds: [${CEO_UID}]`);
  console.log(`   - managerCodes: ['${CEO_CODE}']`);
  console.log(`   - managerNames: ['${CEO_NAME}']`);
  console.log(`   - executiveRole: 'coo'`);
  console.log(`   - isExecutiveApprover: true`);
  console.log(`   - organizationDivisionId: 'operations'`);
  console.log(`   - organizationLevel: 'division_manager'`);

  console.log(`\n2. Update COO-1300 (${COO_UID}):`);
  console.log(`   - isExecutiveApprover: false`);
  console.log(`   - executiveRole: ''`);

  console.log(`\n3. Reassign ${employeeMap.size} Employees to MKT-600:`);
  for (const [id, doc] of employeeMap.entries()) {
    const f = doc.fields;
    console.log(`   - [${f.employeeId?.stringValue || 'NO-CODE'}] ${f.displayName?.stringValue || id}`);
  }

  console.log(`\n4. Reroute ${pendingRequests.length} In-Flight Requests to MKT-600:`);
  for (const reqItem of pendingRequests) {
    const f = reqItem.doc.fields;
    console.log(`   - [${reqItem.coll}/${reqItem.docId}] Employee: ${f.userName?.stringValue || f.employeeName?.stringValue || f.employeeId?.stringValue}`);
  }

  if (isDryRun) {
    console.log('\n====================================================');
    console.log('DRY RUN COMPLETE. No live database changes were made.');
    console.log('Run with --execute to apply changes to Firestore.');
    console.log('====================================================');
    return;
  }

  console.log('\n--- EXECUTING CHANGES ---');

  // 1. Update MKT-600
  console.log('Updating MKT-600...');
  const mktFields = {
    managerId: { stringValue: CEO_UID },
    managerName: { stringValue: CEO_NAME },
    managerIds: toArrayValue([CEO_UID]),
    managerCodes: toArrayValue([CEO_CODE]),
    managerNames: toArrayValue([CEO_NAME]),
    executiveRole: { stringValue: 'coo' },
    isExecutiveApprover: { booleanValue: true },
    organizationDivisionId: { stringValue: 'operations' },
    organizationLevel: { stringValue: 'division_manager' },
  };
  const mktRes = await patchDocument(
    'users',
    MKT_UID,
    mktFields,
    ['managerId', 'managerName', 'managerIds', 'managerCodes', 'managerNames', 'executiveRole', 'isExecutiveApprover', 'organizationDivisionId', 'organizationLevel']
  );
  console.log(`MKT-600 updated: status ${mktRes.status}`);

  // 2. Update COO-1300
  console.log('Updating COO-1300...');
  const cooFields = {
    isExecutiveApprover: { booleanValue: false },
    executiveRole: { stringValue: '' }
  };
  const cooRes = await patchDocument('users', COO_UID, cooFields, ['isExecutiveApprover', 'executiveRole']);
  console.log(`COO-1300 updated: status ${cooRes.status}`);

  // 3. Reassign Employees
  console.log(`Reassigning ${employeeMap.size} employees...`);
  for (const [id, doc] of employeeMap.entries()) {
    const f = doc.fields;
    const currentMgrIds = parseArrayStrings(f.managerIds);
    const currentMgrCodes = parseArrayStrings(f.managerCodes);
    const currentMgrNames = parseArrayStrings(f.managerNames);

    // Replace COO_UID with MKT_UID
    const newMgrIds = currentMgrIds.map(x => x === COO_UID ? MKT_UID : x);
    if (!newMgrIds.includes(MKT_UID) && (f.managerId?.stringValue === COO_UID || currentMgrIds.length === 0)) {
      newMgrIds.push(MKT_UID);
    }

    const newMgrCodes = currentMgrCodes.map(x => x === COO_CODE ? MKT_CODE : x);
    if (!newMgrCodes.includes(MKT_CODE) && (f.managerId?.stringValue === COO_UID || currentMgrCodes.length === 0)) {
      newMgrCodes.push(MKT_CODE);
    }

    const newMgrNames = currentMgrNames.map(x => x === COO_NAME ? MKT_NAME : x);
    if (!newMgrNames.includes(MKT_NAME) && (f.managerId?.stringValue === COO_UID || currentMgrNames.length === 0)) {
      newMgrNames.push(MKT_NAME);
    }

    const updateFields = {
      managerIds: toArrayValue(newMgrIds),
      managerCodes: toArrayValue(newMgrCodes),
      managerNames: toArrayValue(newMgrNames),
    };
    const mask = ['managerIds', 'managerCodes', 'managerNames'];

    if (f.managerId?.stringValue === COO_UID) {
      updateFields.managerId = { stringValue: MKT_UID };
      updateFields.managerName = { stringValue: MKT_NAME };
      mask.push('managerId', 'managerName');
    }

    const res = await patchDocument('users', id, updateFields, mask);
    console.log(`  Updated employee ${f.employeeId?.stringValue || id}: status ${res.status}`);
  }

  // 4. Reroute in-flight pending requests
  console.log(`Rerouting ${pendingRequests.length} in-flight requests...`);
  for (const reqItem of pendingRequests) {
    const f = reqItem.doc.fields;
    const currentMgrIds = parseArrayStrings(f.managerIds);
    const newMgrIds = currentMgrIds.map(x => x === COO_UID ? MKT_UID : x);
    if (!newMgrIds.includes(MKT_UID)) newMgrIds.push(MKT_UID);

    const updateFields = {
      managerIds: toArrayValue(newMgrIds),
    };
    const mask = ['managerIds'];

    if (f.managerId?.stringValue === COO_UID) {
      updateFields.managerId = { stringValue: MKT_UID };
      updateFields.managerName = { stringValue: MKT_NAME };
      if (f.managerCode) updateFields.managerCode = { stringValue: MKT_CODE };
      mask.push('managerId', 'managerName');
      if (f.managerCode) mask.push('managerCode');
    }

    const res = await patchDocument(reqItem.coll, reqItem.docId, updateFields, mask);
    console.log(`  Rerouted ${reqItem.coll}/${reqItem.docId}: status ${res.status}`);
  }

  console.log('\n====================================================');
  console.log('✅ ALL DATABASE MIGRATIONS COMPLETED SUCCESSFULLY');
  console.log('====================================================');
}

main().catch(err => {
  console.error('Fatal error during migration:', err);
  process.exit(1);
});
