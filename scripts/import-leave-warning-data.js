const fs = require('fs');
const path = require('path');

const projectId = process.env.FIREBASE_PROJECT_ID || 'zawolf-hr-system-60317';
const dryRun = process.env.DRY_RUN !== 'false';
const verifyOnly = process.env.VERIFY_ONLY === 'true';
const annualAllowance = Number(process.env.ANNUAL_LEAVE_ALLOWANCE || 15);
const casualAllowance = Number(process.env.CASUAL_LEAVE_ALLOWANCE || 7);
const firestoreBase = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;

const rows = [
  ['سامي المتولي المتولي', 0, 2, ''],
  ['شيماء صبري عبدالعزيز', 8, 2, ''],
  ['مصطفي رضا الشربيني ابراهيم', 3, 0, ''],
  ['حازم ايمن على سيد احمد المنياوي', 0, 0, ''],
  ['احمد محمد الهادي حسين', 0, 0, ''],
  ['هدي احمد موسي عبد الفتاح النادي', 1, 2, 'warning:1'],
  ['محمود ابوالمجد ابراهيم', 0, 4, ''],
  ['احمد محمد العراقي الموجي', 0, 3, ''],
  ['محمود ابراهيم محمد', 2, 2, ''],
  ['اشرف عبد الرازق', 0, 2, ''],
  ['أحمد محمد عوض سليمان', 0, 3, ''],
  ['عبدالرحمن عماد حمدي', 2, 5, 'warning:1'],
  ['فؤاد رجب فؤاد', 1, 3, ''],
  ['السيد خالد مصطفى', 2, 0, 'warning:2'],
  ['صالح علي المصري', 0, 0, ''],
  ['خليل محمد خليل', 2, 2, ''],
  ['على محمد ابراهيم', 4, 1, ''],
  ['عمر طارق محمد عبدالهادي', 9, 0, ''],
  ['عمر فتحي محمود', 0, 0, ''],
  ['عبدالله لمعي محمد', 0, 0, ''],
  ['محمد احمد بهجت عبدالسلام', 5, 5, 'warning:3'],
  ['سالم فتحي سليم شريف', 0, 4, 'notice:1'],
  ['مريم محمد مصطفي', 8, 0, 'notice:1'],
  ['رنا حسن', 1, 5, ''],
  ['على نبيل علي محمد', 0, 2, ''],
  ['ميرنا إبراهيم مناويل معوض(بط وربحان)', 2, 0, ''],
  ['الاء السيد محمد عبد الحي (َضاد)', 0, 0, ''],
  ['عمر مجدى علي (بط)', 2, 0, ''],
  ['الاء السيد حسن(بط)', 0, 0, ''],
  ['ندي حمدي عبده أحمد(بط)', 1, 2, ''],
  ['مازن محمد ابراهيم ملح (ربحان)', 2, 0, ''],
  ['يارا اكرم (ربحان)', 3, 2, ''],
  ['امل ابراهيم حجازي (ربحان)', 2, 0, ''],
  ['ايه رضا عبد الحميد (ربحان)', 3, 0, ''],
  ['هناء عبدالرحمن عوض (ربحان)', 2, 0, ''],
  ['حنين محمد عبد العال (محرك)', 0, 0, ''],
  ['محمد منير جمال', 0, 0, ''],
  ['فاتن مجدي ماهر', 1, 0, ''],
  ['فريد يوسف', 2, 0, ''],
  ['جمال الدين محسن محمد', 0, 0, ''],
  ['ايه عادل البنداري', 10, 0, ''],
  ['رينال اشرف حجي', 5, 0, 'warning:1'],
  ['محمود علام محمود محمد', 4, 2, ''],
  ['احمد رضا المسلماني', 0, 0, ''],
  ['محمد خالد جمال', 5, 0, ''],
  ['ناديه علاء صافيه', 4, 0, ''],
  ['احمد امين حميد', 2, 0, ''],
  ['نوران وليد عبدالرحيم', 2, 0, ''],
  ['شيماء محمد حسن', 0, 0, ''],
  ['مريت كمال شوقي', 0, 0, ''],
  ['ريهام رفيق رجائي', 0, 0, ''],
  ['دينا محمد سعد', 2, 2, ''],
  ['فيروز جمال السيد احمد', 0, 0, ''],
  ['روينا السيد عبد الرحمن', 0, 0, ''],
  ['عمر محمود جوده', 4, 0, ''],
  ['ندي محمد شلبي منصور', 7, 0, ''],
  ['نورهان عمر عبد اللطيف', 8, 0, ''],
  ['حنان محمد اسماعيل سيف الدين', 2, 0, ''],
  ['اسراء عماد مصطفي مصطفي', 2, 0, ''],
  ['اسراء محمد عبد الحليم', 1, 0, ''],
  ['أسماء حامد عبده عطيه', 0, 0, ''],
  ['ياسمين رضا السيد', 0, 0, ''],
  ['عصام عادل شوقي محمود الغنام', 0, 0, ''],
];

const emailAliases = {
  [normalizeArabic('حازم ايمن على سيد احمد المنياوي')]: 'hazem.meniawy@seginvest.com',
};

const employeeIdAliases = {
  [normalizeArabic('مريت كمال شوقي')]: 'PRG-1113',
};

function normalizeArabic(value) {
  return String(value || '')
    .normalize('NFKD')
    .replace(/[\u064B-\u065F\u0670]/g, '')
    .replace(/[إأآٱ]/g, 'ا')
    .replace(/ى/g, 'ي')
    .replace(/ة/g, 'ه')
    .replace(/ؤ/g, 'و')
    .replace(/ئ/g, 'ي')
    .replace(/\([^)]*\)/g, ' ')
    .replace(/[^\p{L}\p{N}]+/gu, ' ')
    .trim()
    .replace(/\s+/g, ' ');
}

function decodeValue(value) {
  if (!value) return null;
  if ('stringValue' in value) return value.stringValue;
  if ('booleanValue' in value) return value.booleanValue;
  if ('integerValue' in value) return Number(value.integerValue);
  if ('doubleValue' in value) return value.doubleValue;
  if ('timestampValue' in value) return value.timestampValue;
  if ('nullValue' in value) return null;
  if ('arrayValue' in value) {
    return (value.arrayValue.values || []).map(decodeValue);
  }
  if ('mapValue' in value) {
    return Object.fromEntries(
      Object.entries(value.mapValue.fields || {}).map(([key, child]) => [key, decodeValue(child)]),
    );
  }
  return null;
}

function decodeDocument(document) {
  const fields = Object.fromEntries(
    Object.entries(document.fields || {}).map(([key, value]) => [key, decodeValue(value)]),
  );
  return { id: document.name.split('/').pop(), ...fields };
}

function stringValue(value) {
  return { stringValue: String(value || '') };
}

function integerValue(value) {
  return { integerValue: String(Math.trunc(value)) };
}

function arrayValue(values) {
  return { arrayValue: { values: values.map(stringValue) } };
}

function readFirebaseCliAccessToken() {
  const configPath = path.join(
    process.env.HOME || '',
    '.config',
    'configstore',
    'firebase-tools.json',
  );
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const token = process.env.FIREBASE_ACCESS_TOKEN || config.tokens?.access_token;
  const expiresAt = Number(config.tokens?.expires_at || 0);
  if (!token) throw new Error('No Firebase CLI access token is available. Run firebase login first.');
  if (!process.env.FIREBASE_ACCESS_TOKEN && expiresAt <= Date.now()) {
    throw new Error('Firebase CLI access token expired. Run firebase projects:list, then retry.');
  }
  return token;
}

async function request(token, url, options = {}) {
  const response = await fetch(url, {
    ...options,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      ...(options.headers || {}),
    },
  });
  const body = await response.text();
  const parsed = body ? JSON.parse(body) : {};
  if (!response.ok) {
    throw new Error(`${response.status} ${response.statusText}: ${JSON.stringify(parsed)}`);
  }
  return parsed;
}

async function loadUsers(token) {
  const users = [];
  let pageToken = '';
  do {
    const query = new URLSearchParams({ pageSize: '300' });
    if (pageToken) query.set('pageToken', pageToken);
    const result = await request(token, `${firestoreBase}/users?${query}`);
    users.push(...(result.documents || []).map(decodeDocument));
    pageToken = result.nextPageToken || '';
  } while (pageToken);
  return users;
}

function findMatches(users, sourceName) {
  const normalized = normalizeArabic(sourceName);
  const nameMatches = users.filter((user) => normalizeArabic(user.displayName) === normalized);
  if (nameMatches.length > 0) return nameMatches;
  const emailAlias = emailAliases[normalized];
  if (emailAlias) {
    const emailMatches = users.filter(
      (user) => String(user.email || '').trim().toLowerCase() === emailAlias,
    );
    if (emailMatches.length > 0) return emailMatches;
  }
  const employeeIdAlias = employeeIdAliases[normalized];
  if (!employeeIdAlias) return [];
  return users.filter(
    (user) => String(user.employeeId || '').trim().toUpperCase() === employeeIdAlias,
  );
}

async function patchUserLeaveData(token, user, annualUsed, casualUsed) {
  const now = new Date().toISOString();
  const query = new URLSearchParams();
  [
    'leaveBalance.annual',
    'leaveBalance.daysOff',
    'leaveBalance.casual',
    'leaveUsageBaseline.annualUsed',
    'leaveUsageBaseline.casualUsed',
    'leaveUsageBaseline.totalUsed',
    'leaveUsageBaseline.source',
    'leaveUsageBaseline.importedAt',
    'updatedAt',
  ].forEach((field) => query.append('updateMask.fieldPaths', field));
  const fields = {
    leaveBalance: {
      mapValue: {
        fields: {
          annual: integerValue(Math.max(0, annualAllowance - annualUsed)),
          daysOff: integerValue(Math.max(0, annualAllowance - annualUsed)),
          casual: integerValue(Math.max(0, casualAllowance - casualUsed)),
        },
      },
    },
    leaveUsageBaseline: {
      mapValue: {
        fields: {
          annualUsed: integerValue(annualUsed),
          casualUsed: integerValue(casualUsed),
          totalUsed: integerValue(annualUsed + casualUsed),
          source: stringValue('seg_leave_warning_import_2026'),
          importedAt: { timestampValue: now },
        },
      },
    },
    updatedAt: { timestampValue: now },
  };
  await request(token, `${firestoreBase}/users/${user.id}?${query}`, {
    method: 'PATCH',
    body: JSON.stringify({ fields }),
  });
}

async function upsertWarning(token, user, kind, index) {
  const isNotice = kind === 'notice';
  const recordId = `historical-2026-${user.id}-${kind}-${index}`;
  const now = new Date().toISOString();
  const managerIds = Array.isArray(user.managerIds)
    ? user.managerIds
    : (user.managerId ? [user.managerId] : []);
  const fields = {
    userId: stringValue(user.id),
    employeeId: stringValue(user.employeeId),
    employeeName: stringValue(user.displayName),
    department: stringValue(user.department),
    managerId: stringValue(managerIds[0] || ''),
    managerIds: arrayValue(managerIds),
    type: stringValue('warning'),
    status: stringValue('issued'),
    title: stringValue(isNotice ? 'لفت نظر سابق' : 'إنذار سابق'),
    description: stringValue('سجل سابق تم ترحيله بواسطة إدارة الموارد البشرية.'),
    createdBy: stringValue('historical_import'),
    createdByName: stringValue('إدارة الموارد البشرية'),
    source: stringValue('historical_import'),
    amount: integerValue(0),
    currency: stringValue('EGP'),
    createdAt: { timestampValue: now },
  };
  await request(token, `${firestoreBase}/warningsRewards/${recordId}`, {
    method: 'PATCH',
    body: JSON.stringify({ fields }),
  });
}

async function promoteFaten(token, users) {
  const matches = users.filter(
    (user) => String(user.email || '').trim().toLowerCase() === 'faten.magdy@seginvest.com',
  );
  if (matches.length !== 1) {
    throw new Error(`Expected one Faten account, found ${matches.length}.`);
  }
  const user = matches[0];
  console.log(`${dryRun ? 'WOULD_PROMOTE' : 'PROMOTE'} | ${user.displayName} | ${user.email} | ${user.role} -> hr_manager`);
  if (dryRun) return;
  const query = new URLSearchParams();
  query.append('updateMask.fieldPaths', 'role');
  query.append('updateMask.fieldPaths', 'updatedAt');
  await request(token, `${firestoreBase}/users/${user.id}?${query}`, {
    method: 'PATCH',
    body: JSON.stringify({
      fields: {
        role: stringValue('hr_manager'),
        updatedAt: { timestampValue: new Date().toISOString() },
      },
    }),
  });
}

async function verifyImport(token, resolved, users, missing) {
  const errors = [];
  for (const item of resolved) {
    const expectedAnnual = Math.max(0, annualAllowance - item.annualUsed);
    const expectedCasual = Math.max(0, casualAllowance - item.casualUsed);
    const balance = item.user.leaveBalance || {};
    const baseline = item.user.leaveUsageBaseline || {};
    if (
      balance.annual !== expectedAnnual ||
      balance.daysOff !== expectedAnnual ||
      balance.casual !== expectedCasual ||
      baseline.annualUsed !== item.annualUsed ||
      baseline.casualUsed !== item.casualUsed ||
      baseline.totalUsed !== item.annualUsed + item.casualUsed
    ) {
      errors.push(`Leave data mismatch for ${item.user.displayName}`);
    }
    if (item.warningSpec) {
      const [kind, rawCount] = item.warningSpec.split(':');
      const count = Number(rawCount || 1);
      for (let index = 1; index <= count; index += 1) {
        const recordId = `historical-2026-${item.user.id}-${kind}-${index}`;
        try {
          const document = await request(token, `${firestoreBase}/warningsRewards/${recordId}`);
          const warning = decodeDocument(document);
          if (warning.userId !== item.user.id || warning.status !== 'issued') {
            errors.push(`Warning data mismatch for ${item.user.displayName}, record ${index}`);
          }
        } catch (error) {
          errors.push(`Missing warning for ${item.user.displayName}, record ${index}: ${error.message}`);
        }
      }
    }
  }
  const faten = users.find(
    (user) => String(user.email || '').trim().toLowerCase() === 'faten.magdy@seginvest.com',
  );
  if (!faten || faten.role !== 'hr_manager') {
    errors.push('Faten is not stored as hr_manager.');
  }
  if (errors.length > 0) {
    errors.forEach((error) => console.error(`VERIFY_ERROR | ${error}`));
    throw new Error(`Verification failed with ${errors.length} error(s).`);
  }
  console.log(`Verification passed: ${resolved.length} leave records, 10 warning/notice records, Faten role hr_manager, ${missing.length} missing.`);
}

async function main() {
  const token = readFirebaseCliAccessToken();
  const users = await loadUsers(token);
  console.log(`Project: ${projectId}`);
  console.log(`Dry run: ${dryRun}`);
  console.log(`Loaded users: ${users.length}`);
  if (process.env.LIST_USERS === 'true') {
    users.forEach((user) => console.log(`USER | ${user.displayName} | ${user.email} | ${user.employeeId}`));
  }

  const resolved = [];
  const missing = [];
  const ambiguous = [];
  for (const [sourceName, annualUsed, casualUsed, warningSpec] of rows) {
    const matches = findMatches(users, sourceName);
    if (matches.length === 0) {
      missing.push(sourceName);
      continue;
    }
    if (matches.length > 1) {
      ambiguous.push({ sourceName, matches: matches.map((user) => `${user.displayName} <${user.email}>`) });
      continue;
    }
    resolved.push({ sourceName, annualUsed, casualUsed, warningSpec, user: matches[0] });
  }

  if (ambiguous.length > 0) {
    console.error('Import aborted because these rows match more than one user:');
    for (const problem of ambiguous) {
      console.error(`- ${problem.sourceName}: ${problem.matches.length} match(es)${problem.matches.length ? ` => ${problem.matches.join(', ')}` : ''}`);
    }
    process.exitCode = 2;
    return;
  }
  for (const sourceName of missing) {
    console.warn(`SKIP_MISSING | ${sourceName}`);
  }

  if (verifyOnly) {
    await verifyImport(token, resolved, users, missing);
    return;
  }

  for (const item of resolved) {
    const remainingAnnual = Math.max(0, annualAllowance - item.annualUsed);
    const remainingCasual = Math.max(0, casualAllowance - item.casualUsed);
    console.log(
      `${dryRun ? 'WOULD_UPDATE' : 'UPDATE'} | ${item.user.displayName} | used ${item.annualUsed}/${item.casualUsed} | remaining ${remainingAnnual}/${remainingCasual}${item.warningSpec ? ` | ${item.warningSpec}` : ''}`,
    );
    if (!dryRun) {
      await patchUserLeaveData(token, item.user, item.annualUsed, item.casualUsed);
      if (item.warningSpec) {
        const [kind, rawCount] = item.warningSpec.split(':');
        const count = Number(rawCount || 1);
        for (let index = 1; index <= count; index += 1) {
          await upsertWarning(token, item.user, kind, index);
        }
      }
    }
  }

  await promoteFaten(token, users);
  console.log(`${dryRun ? 'Dry run complete' : 'Import complete'}: ${resolved.length} leave records, ${missing.length} missing.`);
}

main().catch((error) => {
  console.error(error.stack || error.message || error);
  process.exitCode = 1;
});
