'use strict';

const crypto = require('node:crypto');
const { normalizedName } = require('./organization-structure');

function stableLegacyId(type, value) {
  const hash = crypto.createHash('sha256').update(`${type}:${String(value || '').trim()}`).digest('hex').slice(0, 24);
  return `${type}_${hash}`;
}

function buildMigrationPlan({ divisions = [], departments = [], users = [] }) {
  const issues = []; const seen = new Map(); const units = [];
  const divisionsByLegacy = new Map();
  for (const division of divisions) {
    const name = String(division.name || division.id || '').trim();
    if (!name) continue;
    const key = `sector:${normalizedName(name)}`;
    if (seen.has(key)) { issues.push({ code: 'duplicate_name', sourceId: division.id, conflictsWith: seen.get(key) }); continue; }
    const id = stableLegacyId('sector', division.id || name); seen.set(key, id); divisionsByLegacy.set(String(division.id || name), id);
    units.push({ id, type: 'sector', parentId: null, name, normalizedName: normalizedName(name), order: units.filter((u) => u.type === 'sector').length, archived: false, version: 1 });
  }
  let fallbackSector = units.find((unit) => unit.type === 'sector')?.id;
  if (!fallbackSector) {
    fallbackSector = stableLegacyId('sector', 'default');
    units.push({ id: fallbackSector, type: 'sector', parentId: null, name: 'الإدارة', normalizedName: normalizedName('الإدارة'), order: 0, archived: false, version: 1, inferred: true });
  }
  const departmentsByName = new Map();
  for (const department of departments) {
    const name = String(department.name || department.id || '').trim(); if (!name) continue;
    const parentId = divisionsByLegacy.get(String(department.divisionId || '')) || fallbackSector;
    const key = `department:${parentId}:${normalizedName(name)}`;
    if (seen.has(key)) { issues.push({ code: 'duplicate_name', sourceId: department.id, conflictsWith: seen.get(key) }); continue; }
    const id = stableLegacyId('department', department.id || name); seen.set(key, id); departmentsByName.set(normalizedName(name), id);
    units.push({ id, type: 'department', parentId, name, normalizedName: normalizedName(name), order: units.filter((u) => u.type === 'department' && u.parentId === parentId).length, archived: false, version: 1, managerUid: department.managerUid || null });
    if (department.managerUid && !users.some((u) => (u.uid || u.id) === department.managerUid && u.isActive === true)) issues.push({ code: 'unresolved_manager', sourceId: department.id, managerUid: department.managerUid });
  }
  const memberships = [];
  for (const user of users) {
    const uid = String(user.uid || user.id || ''); if (!uid || user.isActive === false) continue;
    const departmentId = user.departmentUnitId || departmentsByName.get(normalizedName(user.department || user.departmentId));
    if (!departmentId) issues.push({ code: 'orphan_employee', uid, department: user.department || user.departmentId || null });
    memberships.push({ uid, departmentUnitId: departmentId || null, directManagerId: user.directManagerId || user.managerId || null });
  }
  return { dryRun: true, units, memberships, issues, summary: { units: units.length, memberships: memberships.length, issues: issues.length } };
}

async function runMigration({ db, apply = false }) {
  async function readAll(collectionName, pageSize = 200) {
    const records = [];
    let cursor = null;
    while (true) {
      let query = db.collection(collectionName).orderBy('__name__').limit(pageSize);
      if (cursor) query = query.startAfter(cursor);
      const snapshot = await query.get();
      records.push(...snapshot.docs.map((doc) => ({ id: doc.id, ...doc.data() })));
      if (snapshot.docs.length < pageSize) break;
      cursor = snapshot.docs[snapshot.docs.length - 1];
    }
    return records;
  }
  const [divisionSnapshot, departmentSnapshot, userSnapshot] = await Promise.all([
    readAll('organization_divisions'),
    readAll('departments'),
    readAll('users'),
  ]);
  const plan = buildMigrationPlan({ divisions: divisionSnapshot, departments: departmentSnapshot, users: userSnapshot });
  if (!apply) return plan;
  const writes = [
    ...plan.units.map((unit) => ({ ref: db.collection('companyOsOrganizationUnits').doc(unit.id), value: unit })),
    ...plan.memberships.map((membership) => ({ ref: db.collection('users').doc(membership.uid), value: membership })),
  ];
  for (let offset = 0; offset < writes.length; offset += 400) {
    const batch = db.batch();
    for (const write of writes.slice(offset, offset + 400)) batch.set(write.ref, write.value, { merge: true });
    await batch.commit();
  }
  return { ...plan, dryRun: false, applied: true };
}

if (require.main === module) {
  if (process.env.APPLY === 'true') {
    console.error('Refusing standalone APPLY without an injected reviewed runtime. Import runMigration from the controlled migration runner.');
    process.exitCode = 2;
  } else {
    console.log(JSON.stringify({ ok: true, dryRun: true, message: 'استورد runMigration مع اتصال Firebase إداري لتنفيذ المعاينة.' }));
  }
}

module.exports = { stableLegacyId, buildMigrationPlan, runMigration };
