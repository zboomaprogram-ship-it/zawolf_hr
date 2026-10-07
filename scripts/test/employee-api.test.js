'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

test('GET /api/v1/employees token authorization logic', () => {
  const allowedTokens = [
    'custom_secret_key',
    'zawolf_api_2026',
  ].filter(Boolean);

  const checkAuth = (headerToken, queryToken) => {
    const token = (headerToken && headerToken.startsWith('Bearer '))
      ? headerToken.slice('Bearer '.length).trim()
      : (queryToken || '').trim();
    return Boolean(token && allowedTokens.includes(token));
  };

  assert.equal(checkAuth('Bearer zawolf_api_2026', ''), true);
  assert.equal(checkAuth('Bearer custom_secret_key', ''), true);
  assert.equal(checkAuth('', 'zawolf_api_2026'), true);
  assert.equal(checkAuth('Bearer wrong_token', ''), false);
  assert.equal(checkAuth('', 'wrong_token'), false);
  assert.equal(checkAuth('', ''), false);
});

test('Employee mapping outputs id, name, email, department, workLocation, organizationSector, jobTitle, manager, role, isActive, and assignedDate', () => {
  const sampleDate = new Date('2024-03-15T09:00:00Z');
  const sampleUserDoc = {
    id: 'usr_123',
    data: () => ({
      employeeId: 'EMP-01',
      displayName: 'Ahmed Ali',
      email: 'ahmed@zawolf.ai',
      department: 'Human Resources',
      locationName: 'فرع القاهرة - المعادي',
      organizationDivisionId: 'administration',
      position: 'HR Specialist',
      managerName: 'Sara Manager',
      managerId: 'usr_mgr_456',
      role: 'employee',
      isActive: true,
      joinDate: { toDate: () => sampleDate },
    }),
  };

  const formatDate = (val) => {
    if (!val) return null;
    const dt = typeof val?.toDate === 'function' ? val.toDate() : new Date(val);
    return dt instanceof Date && !Number.isNaN(dt.getTime())
      ? dt.toISOString().slice(0, 10)
      : null;
  };

  const DIVISION_NAMES = {
    administration: 'Administration',
    operations: 'Operations',
    sales: 'Sales',
  };

  const normalizeSectorEnglish = (val) => {
    if (!val) return '';
    const s = String(val).trim().toLowerCase();
    if (s.includes('مبيع') || s.includes('sales') || s.includes('bd') || s.includes('sdr') || s.includes('تطوير')) {
      return 'Sales';
    }
    if (s.includes('إدار') || s.includes('ادار') || s.includes('admin') || s.includes('hr') || s.includes('حسابات') || s.includes('accounting') || s.includes('it') || s.includes('legal')) {
      return 'Administration';
    }
    if (s.includes('تشغيل') || s.includes('operat')) {
      return 'Operations';
    }
    return DIVISION_NAMES[s] || (s.charAt(0).toUpperCase() + s.slice(1));
  };

  const inferDivision = (dept) => {
    if (!dept) return 'Operations';
    const s = String(dept).toLowerCase();
    if (['accounting', 'human resources', 'hr', 'it', 'legal', 'الحسابات', 'الموارد البشرية', 'الشؤون القانونية', 'تقنية المعلومات'].some((k) => s.includes(k))) {
      return 'Administration';
    }
    if (s.includes('sales') || s.includes('bd') || s.includes('sdr') || s.includes('المبيعات') || s.includes('تطوير الأعمال')) {
      return 'Sales';
    }
    return 'Operations';
  };

  const d = sampleUserDoc.data();
  const department = d.department || d.departmentName || '';
  const workLocation = d.locationName || d.locationId || d.branch || d.branchName || '';
  const jobTitle = d.position || d.jobTitle || d.title || '';
  const rawSector = d.organizationDivisionId
    || d.organizationDivisionName
    || d.sector
    || inferDivision(department);
  const sectorName = normalizeSectorEnglish(rawSector) || 'Operations';

  const mapped = {
    id: d.employeeId || d.employeeCode || sampleUserDoc.id,
    uid: sampleUserDoc.id,
    name: d.displayName || d.name || '',
    email: d.email || '',
    department,
    workLocation,
    locationName: workLocation,
    organizationSector: sectorName,
    jobTitle,
    position: jobTitle,
    manager: d.managerName || d.managerId || null,
    managerId: d.managerId || null,
    role: d.role || 'employee',
    isActive: d.isActive !== false,
    assignedDate: formatDate(d.joinDate || d.hiringDate || d.assignedDate || d.createdAt),
  };

  assert.equal(mapped.id, 'EMP-01');
  assert.equal(mapped.uid, 'usr_123');
  assert.equal(mapped.name, 'Ahmed Ali');
  assert.equal(mapped.email, 'ahmed@zawolf.ai');
  assert.equal(mapped.department, 'Human Resources');
  assert.equal(mapped.workLocation, 'فرع القاهرة - المعادي');
  assert.equal(mapped.locationName, 'فرع القاهرة - المعادي');
  assert.equal(mapped.organizationSector, 'Administration');
  assert.equal(mapped.jobTitle, 'HR Specialist');
  assert.equal(mapped.position, 'HR Specialist');
  assert.equal(mapped.manager, 'Sara Manager');
  assert.equal(mapped.role, 'employee');
  assert.equal(mapped.isActive, true);
  assert.equal(mapped.assignedDate, '2024-03-15');
});
