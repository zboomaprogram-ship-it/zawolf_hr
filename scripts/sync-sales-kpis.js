const admin = require('firebase-admin');
const { fetchSalesAnalytics } = require('./sales-analytics-client');
const { initializeFirebase } = require('./dispatch-notifications');

const SOURCE = 'sales_analytics_api';
const SYSTEM_ACTOR = 'sales-analytics-sync';

function number(value) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function normalize(value) {
  return String(value || '')
    .trim()
    .toLocaleLowerCase('en')
    .replace(/[\s._-]+/g, '');
}

function dateKey(date) {
  return [
    date.getUTCFullYear(),
    String(date.getUTCMonth() + 1).padStart(2, '0'),
    String(date.getUTCDate()).padStart(2, '0'),
  ].join('-');
}

function cycleFor(date = new Date()) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Africa/Cairo',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);
  const value = Object.fromEntries(
    parts.filter((part) => part.type !== 'literal')
      .map((part) => [part.type, Number(part.value)]),
  );
  const cairoDate = new Date(Date.UTC(value.year, value.month - 1, value.day));
  const endMonth = cairoDate.getUTCDate() <= 25
    ? new Date(Date.UTC(cairoDate.getUTCFullYear(), cairoDate.getUTCMonth(), 1))
    : new Date(Date.UTC(cairoDate.getUTCFullYear(), cairoDate.getUTCMonth() + 1, 1));
  const start = new Date(Date.UTC(
    endMonth.getUTCFullYear(),
    endMonth.getUTCMonth() - 1,
    26,
  ));
  const end = new Date(Date.UTC(
    endMonth.getUTCFullYear(),
    endMonth.getUTCMonth(),
    25,
  ));
  return {
    monthKey: `${end.getUTCFullYear()}-${String(end.getUTCMonth() + 1).padStart(2, '0')}`,
    start,
    end,
    startDate: dateKey(start),
    endDate: dateKey(end),
  };
}

function agentIdentifiers(agent) {
  if (typeof agent === 'string') return [normalize(agent)];
  if (!agent || typeof agent !== 'object') return [];
  return [
    agent.id,
    agent.agentId,
    agent.employeeId,
    agent.employeeCode,
    agent.code,
    agent.key,
    agent.email,
    agent.name,
    agent.displayName,
    agent.label,
    agent.sales,
    agent.teleSales,
  ].map(normalize).filter(Boolean);
}

function agentsFrom(kpiData) {
  if (Array.isArray(kpiData?.agents)) return kpiData.agents;
  return Object.entries(kpiData?.agents || {}).map(([key, value]) => (
    value && typeof value === 'object' ? { key, ...value } : { key, actual: value }
  ));
}

function strongAgentIdentifiers(agent) {
  if (!agent || typeof agent !== 'object') return [];
  return [
    agent.id,
    agent.idEmp,
    agent.employeeId,
    agent.employeeCode,
  ].map(normalize).filter(Boolean);
}

function primaryAgentKey(agent) {
  if (!agent || typeof agent !== 'object') return normalize(agent);
  return normalize(
    agent.id || agent.idEmp || agent.employeeId || agent.employeeCode ||
    agent.code || agent.key || agent.agentId || agent.name,
  );
}

function normalizedPercent(value) {
  // The Sales Analytics API returns percentage fields as ratios. Ratios can
  // legitimately exceed 1 when an employee beats the target (1.88 = 188%).
  return Number((number(value) * 100).toFixed(8));
}

function agentActual(agent, counts) {
  if (typeof agent === 'number') return number(agent);
  if (typeof agent === 'string') {
    const expected = normalize(agent);
    const match = Object.entries(counts || {}).find(
      ([key]) => normalize(key) === expected,
    );
    return number(match?.[1]);
  }
  if (!agent || typeof agent !== 'object') {
    return 0;
  }
  const values = [
    agent.actual,
    agent.achieved,
    agent.value,
    agent.total,
    agent.amount,
    agent.count,
    agent.totalPrice,
    agent.confirmedMeetings,
  ];
  for (const value of values) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  const normalizedCounts = new Map(
    Object.entries(counts || {}).map(([key, value]) => [normalize(key), value]),
  );
  for (const id of agentIdentifiers(agent)) {
    if (normalizedCounts.has(id)) {
      return number(normalizedCounts.get(id));
    }
  }
  return 0;
}

function agentActualForRole(agent, counts, role) {
  if (!agent || typeof agent !== 'object') {
    return agentActual(agent, counts);
  }
  const preferredValues = role.includes('tele')
    ? [agent.confirmedMeetings, agent.meetings, agent.totalMeetings]
    : [agent.totalPrice, agent.monthlyIncome, agent.downPayment];
  for (const value of preferredValues) {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return agentActual(agent, counts);
}

function providerDetailsForAgent(agent, role, currency) {
  const teleSales = role.includes('tele');
  const value = (key) => number(agent?.[key]);
  const percent = (key) => normalizedPercent(agent?.[key]);
  if (teleSales) {
    return {
      kind: 'tele_sales',
      currency,
      totalLeads: value('totalLeads'),
      confirmedMeetings: value('confirmedMeetings'),
      conversion: percent('conversion'),
      conversionWeighted: percent('conversionWeighted'),
      target: value('target'),
      achieved: percent('achieved'),
      achievedWeighted: percent('achievedWeighted'),
      confirmedSales: value('confirmedSales'),
      vsMeetings: percent('vsMeetings'),
      closingWeighted: percent('closingWeighted'),
      finalKpi: percent('finalKpi'),
    };
  }
  return {
    kind: 'sales',
    currency,
    confirmedSales: value('confirmedSales'),
    meetings: value('meetings'),
    conversion: percent('conversion'),
    totalPrice: value('totalPrice'),
    downPayment: value('downPayment'),
    monthlyIncome: value('monthlyIncome'),
    target: value('target'),
    invoiceAchievement: percent('invoiceAchievement'),
    salesConversionAchieved: percent('salesConversionAchieved'),
    totalInvoiceAchieved: percent('totalInvoiceAchieved'),
    finalKpi: percent('finalKpi'),
  };
}

function duplicateConfiguredAgentKeys(userDocs) {
  const owners = new Map();
  for (const userDoc of userDocs) {
    const user = userDoc.data();
    const key = normalize(user.salesAnalyticsAgentKey);
    if (!key) continue;
    const ids = owners.get(key) || [];
    ids.push(userDoc.id);
    owners.set(key, ids);
  }
  return new Set(
    [...owners.entries()]
      .filter(([, userIds]) => userIds.length > 1)
      .map(([key]) => key),
  );
}

function findAgent(kpiData, user) {
  const agents = agentsFrom(kpiData);
  const configuredKey = normalize(user.salesAnalyticsAgentKey);
  if (configuredKey) {
    return agents.find((agent) => agentIdentifiers(agent).includes(configuredKey));
  }
  const employeeId = normalize(user.employeeId);
  if (!employeeId) return undefined;
  return agents.find((agent) => strongAgentIdentifiers(agent).includes(employeeId));
}

function findAgentMatch(api, user) {
  const configuredRole = String(user.salesAnalyticsRole || '').toLowerCase();
  const sources = configuredRole.includes('tele')
    ? [
        { role: 'tele_sales', kpiData: api.teleSalesKpi },
        { role: 'sales', kpiData: api.salesKpi },
      ]
    : [
        { role: 'sales', kpiData: api.salesKpi },
        { role: 'tele_sales', kpiData: api.teleSalesKpi },
      ];
  for (const source of sources) {
    const agent = findAgent(source.kpiData, user);
    if (agent) return { ...source, agent };
  }
  return null;
}

function departmentAgentStats(kpiData, role) {
  const agents = agentsFrom(kpiData);
  const target = agents.reduce(
    (sum, agent) => sum + number(agent?.target || kpiData?.target),
    0,
  );
  const actual = agents.reduce(
    (sum, agent) => sum + agentActualForRole(agent, kpiData?.counts, role),
    0,
  );
  const scores = agents
    .map((agent) => normalizedPercent(agent?.finalKpi))
    .filter(Number.isFinite);
  return {
    agents,
    target,
    actual,
    averageKpi: scores.length
      ? scores.reduce((sum, score) => sum + score, 0) / scores.length
      : 0,
  };
}

function weightedProgress(metrics) {
  const totalWeight = metrics.reduce((sum, metric) => sum + number(metric.weight), 0);
  if (!totalWeight) return 0;
  const weighted = metrics.reduce((sum, metric) => {
    if (!metric.target) return sum;
    const completion = Math.min(150, Math.max(0, (metric.actual / metric.target) * 100));
    return sum + completion * number(metric.weight);
  }, 0);
  return Math.min(100, weighted / totalWeight);
}

function taskDueDates(cycle, count) {
  const range = cycle.end.getTime() - cycle.start.getTime();
  return Array.from({ length: count }, (_, index) => new Date(
    cycle.start.getTime() + Math.round(range * ((index + 1) / count)),
  ));
}

function parseDateKey(value) {
  const [year, month, day] = String(value).split('-').map(Number);
  return new Date(Date.UTC(year, month - 1, day));
}

function datesInRange(startDate, endDate) {
  const dates = [];
  for (
    let date = parseDateKey(startDate);
    date <= parseDateKey(endDate);
    date = new Date(date.getTime() + 86400000)
  ) {
    dates.push(new Date(date));
  }
  return dates;
}

function dartWeekday(date) {
  return date.getUTCDay() === 0 ? 7 : date.getUTCDay();
}

function eligibleTaskDates(user, cycle, context = {}) {
  const workDays = Array.isArray(user.workSchedule?.workDays) &&
    user.workSchedule.workDays.length
    ? user.workSchedule.workDays.map(Number)
    : [6, 7, 1, 2, 3, 4];
  const companyDaysOff = context.companyDaysOff || new Set();
  const leaveDays = context.leaveDaysByUser?.get(user.uid) || new Set();
  return datesInRange(cycle.startDate, cycle.endDate).filter((date) => {
    const key = dateKey(date);
    return workDays.includes(dartWeekday(date)) &&
      !companyDaysOff.has(key) &&
      !leaveDays.has(key);
  });
}

function dailyTaskState({ date, index, targetPerDay, actual, now = new Date() }) {
  const today = dateKey(now);
  const dueKey = dateKey(date);
  const cumulativeTarget = targetPerDay * (index + 1);
  const delta = actual - cumulativeTarget;
  const tolerance = Math.max(0.01, targetPerDay * 0.02);
  const performanceState = delta > tolerance
    ? 'ahead'
    : delta >= -tolerance
      ? 'on_track'
      : 'behind';
  let status = 'new';
  if (dueKey < today) status = actual >= cumulativeTarget ? 'done' : 'late';
  if (dueKey === today) status = actual >= cumulativeTarget ? 'done' : 'in_progress';
  return { status, performanceState, cumulativeTarget, delta };
}

function valuesChanged(previous, next) {
  const keys = [
    'status', 'performanceState', 'targetValue', 'actualValue',
    'cumulativeTarget', 'cumulativeActual', 'performanceDelta',
  ];
  return !previous || keys.some((key) => previous[key] !== next[key]);
}

function notificationData(type, title, body, data) {
  return {
    type,
    title,
    body,
    data,
    isRead: false,
    pushSent: false,
    pushAttemptCount: 0,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

async function upsertEmployeeKpi(db, userDoc, api, cycle, options, context) {
  const user = { uid: userDoc.id, ...userDoc.data() };
  const match = findAgentMatch(api, user);
  if (!match) return { matched: false, userId: user.uid };
  const { role, kpiData, agent } = match;

  const metricKey = role.includes('tele') ? 'tele_sales_target' : 'sales_target';
  const agentKey = primaryAgentKey(agent);
  const currency = String(options.currency || 'SAR').trim().toUpperCase();
  const metric = {
    key: metricKey,
    source: SOURCE,
    editable: false,
    name: role.includes('tele') ? 'تحقيق هدف المبيعات الهاتفية' : 'تحقيق هدف المبيعات',
    unit: role.includes('tele') ? 'اجتماع' : currency,
    currency: role.includes('tele') ? '' : currency,
    target: number(agent.target || kpiData?.target),
    actual: agentActualForRole(agent, kpiData?.counts, role),
    weight: 100,
    direction: 'higher_is_better',
    evidenceUrl: '',
    managerComment: 'يتم تحديث هذا المؤشر تلقائياً من نظام المبيعات.',
    externalAgentKey: agentKey,
  };
  const providerDepartment = role.includes('tele') ? 'tele_sales' : 'sales';
  const providerDetails = providerDetailsForAgent(agent, role, currency);
  const kpiId = `${user.uid}_${cycle.monthKey}`;
  const kpiRef = db.collection('employeeKpis').doc(kpiId);
  const existing = await kpiRef.get();
  const existingData = existing.data() || {};
  const manualMetrics = (existingData.metrics || []).filter(
    (item) => item.source !== SOURCE,
  );
  const metrics = [...manualMetrics, metric];
  const now = admin.firestore.FieldValue.serverTimestamp();
  await kpiRef.set({
    templateId: existingData.templateId || SOURCE,
    userId: user.uid,
    employeeId: user.employeeId || '',
    employeeName: user.displayName || '',
    department: user.department || '',
    managerId: user.managerId || user.managerIds?.[0] || '',
    managerIds: user.managerIds || (user.managerId ? [user.managerId] : []),
    teamLeaderId: user.teamLeaderId || '',
    monthKey: cycle.monthKey,
    status: existingData.status || 'active',
    metrics,
    overallProgress: weightedProgress(metrics),
    createdBy: existingData.createdBy || SYSTEM_ACTOR,
    createdAt: existingData.createdAt || now,
    updatedAt: now,
    externalSource: SOURCE,
    periodStart: cycle.startDate,
    periodEnd: cycle.endDate,
    lastSyncedAt: now,
    syncStatus: 'synced',
    providerType: 'sales_analytics',
    providerDepartment,
    providerAgentKey: agentKey,
    providerDetails,
  }, { merge: true });

  let createdTasks = 0;
  let lateTasks = 0;
  if (options.tasksEnabled) {
    const dueDates = eligibleTaskDates(user, cycle, context);
    const targetPerTask = dueDates.length ? metric.target / dueDates.length : metric.target;
    const existingTasks = await db.collection('tasks')
      .where('sourceId', '==', kpiId)
      .get();
    const existingById = new Map(existingTasks.docs.map((doc) => [doc.id, doc.data()]));
    for (let index = 0; index < dueDates.length; index++) {
      const dueKey = dateKey(dueDates[index]);
      const taskId = `sales_kpi_daily_${cycle.monthKey}_${user.uid}_${metricKey}_${dueKey}`;
      const taskRef = db.collection('tasks').doc(taskId);
      const previous = existingById.get(taskId);
      const state = dailyTaskState({
        date: dueDates[index],
        index,
        targetPerDay: targetPerTask,
        actual: metric.actual,
        now: context.now,
      });
      const progress = {
        status: state.status,
        performanceState: state.performanceState,
        targetValue: targetPerTask,
        actualValue: metric.actual,
        cumulativeTarget: state.cumulativeTarget,
        cumulativeActual: metric.actual,
        performanceDelta: state.delta,
      };
      const payload = {
        title: `${metric.name} - هدف يوم ${dueKey}`,
        description:
          `مهمة KPI يومية ضمن دورة ${cycle.startDate} إلى ${cycle.endDate}. ` +
          `الهدف اليومي: ${targetPerTask.toFixed(2)} ${metric.unit}. ` +
          `التقييم تراكمي حتى لا تنسب مبيعات يوم إلى يوم آخر.`,
        assigneeId: user.uid,
        assigneeName: user.displayName || '',
        assigneeEmployeeId: user.employeeId || '',
        department: user.department || '',
        managerId: user.managerId || user.managerIds?.[0] || '',
        managerIds: user.managerIds || (user.managerId ? [user.managerId] : []),
        createdBy: SYSTEM_ACTOR,
        createdByName: 'نظام مؤشرات المبيعات',
        priority: 'high',
        ...progress,
        dueDate: admin.firestore.Timestamp.fromDate(dueDates[index]),
        createdAt: previous?.createdAt || now,
        updatedAt: now,
        isRead: previous?.isRead || false,
        source: SOURCE,
        sourceId: kpiId,
        sourceMetricKey: metricKey,
        periodKey: cycle.monthKey,
        milestoneNumber: index + 1,
        targetUnit: metric.unit,
        progressMode: 'cumulative_daily',
        providerType: 'sales_analytics',
        metricKind: role.includes('tele') ? 'tele_sales' : 'sales',
      };
      if (valuesChanged(previous, payload)) {
        await taskRef.set(payload, { merge: true });
      }
      if (!previous) {
        createdTasks++;
        if (dueKey === dateKey(context.now)) {
          await db.collection('notifications').doc(user.uid).collection('items')
            .doc(`task_${taskId}`)
            .set(notificationData(
              'task_assigned',
              'مهمة KPI اليوم',
              `هدفك اليوم ${targetPerTask.toFixed(2)} ${metric.unit}.`,
              { taskId, employeeKpiId: kpiId, route: '/employee/tasks' },
            ));
        }
      }
      if (state.status === 'late' && previous?.status !== 'late') {
        lateTasks++;
        await db.collection('notifications').doc(user.uid).collection('items')
          .doc(`task_late_${taskId}`)
          .set(notificationData(
            'task_late',
            'هدف KPI يحتاج متابعة',
            `لم يتحقق الهدف التراكمي حتى ${dueKey}. يمكنك تعويضه خلال بقية الدورة.`,
            { taskId, employeeKpiId: kpiId, route: '/employee/tasks' },
          ));
      }
    }
    await kpiRef.set({
      milestonesGenerated: dueDates.length,
      milestonePeriodKey: cycle.monthKey,
      taskFrequency: 'daily',
      eligibleTaskDays: dueDates.length,
      updatedAt: now,
    }, { merge: true });
  }
  return {
    matched: true,
    userId: user.uid,
    kpiId,
    createdTasks,
    lateTasks,
    metricKind: role.includes('tele') ? 'tele_sales' : 'sales',
    employeeId: user.employeeId || '',
    employeeName: user.displayName || '',
    department: user.department || '',
    providerDetails,
    target: metric.target,
    actual: metric.actual,
    providerAgentKey: agentKey,
  };
}

async function loadTaskCalendarContext(db, cycle, userIds, now) {
  const [daysOffSnap, leavesSnap] = await Promise.all([
    db.collection('companyDayOffs').where('isActive', '==', true).get(),
    db.collection('leaves').where('status', '==', 'approved').get(),
  ]);
  const companyDaysOff = new Set(daysOffSnap.docs.map((doc) => {
    const value = doc.data().date;
    return value?.toDate ? dateKey(value.toDate()) : String(value || '').slice(0, 10);
  }).filter(Boolean));
  const leaveDaysByUser = new Map();
  const allowedUsers = new Set(userIds);
  for (const doc of leavesSnap.docs) {
    const leave = doc.data();
    if (!allowedUsers.has(leave.userId)) continue;
    const start = leave.startDate?.toDate?.();
    const end = leave.endDate?.toDate?.();
    if (!start || !end) continue;
    const days = leaveDaysByUser.get(leave.userId) || new Set();
    for (const date of datesInRange(dateKey(start), dateKey(end))) {
      const key = dateKey(date);
      if (key >= cycle.startDate && key <= cycle.endDate) days.add(key);
    }
    leaveDaysByUser.set(leave.userId, days);
  }
  return { companyDaysOff, leaveDaysByUser, now };
}

async function syncSalesKpis(input = {}) {
  initializeFirebase();
  const db = admin.firestore();
  const periodDoc = await db.collection('salesKpiSettings').doc('current').get();
  const configuredPeriod = periodDoc.data() || {};
  const requestedPeriod = input.startDate && input.endDate
    ? input
    : configuredPeriod;
  const cycle = requestedPeriod?.startDate && requestedPeriod?.endDate
    ? {
        ...cycleFor(),
        startDate: requestedPeriod.startDate,
        endDate: requestedPeriod.endDate,
        start: parseDateKey(requestedPeriod.startDate),
        end: parseDateKey(requestedPeriod.endDate),
        monthKey: requestedPeriod.periodKey || requestedPeriod.endDate.slice(0, 7),
      }
    : cycleFor(input.now);
  const configuredValue = (key, fallback) => {
    if (input[key] !== undefined && input[key] !== null && input[key] !== '') {
      return input[key];
    }
    if (configuredPeriod[key] !== undefined && configuredPeriod[key] !== null && configuredPeriod[key] !== '') {
      return configuredPeriod[key];
    }
    return fallback;
  };
  const filters = {
    startDate: cycle.startDate,
    endDate: cycle.endDate,
    company: configuredValue('company', process.env.SALES_API_COMPANY || 'ALL'),
    sales: configuredValue('sales', 'ALL'),
    teleSales: configuredValue('teleSales', 'ALL'),
    entryChannel: configuredValue('entryChannel', 'ALL'),
    salesTarget: configuredValue(
      'salesTarget',
      process.env.SALES_API_SALES_TARGET || 20000,
    ),
    teleTarget: configuredValue(
      'teleTarget',
      process.env.SALES_API_TELE_TARGET || 50,
    ),
    idEmp: configuredValue('idEmp', ''),
    cumulative: configuredValue('cumulative', true) !== false,
  };
  const api = await fetchSalesAnalytics(filters);
  const usersSnap = await db.collection('users').get();
  const activeUserDocs = usersSnap.docs.filter((doc) => doc.data().isActive !== false);
  const candidateUserDocs = activeUserDocs.filter((doc) => {
    const user = doc.data();
    return user.salesAnalyticsEnabled === true ||
      Boolean(normalize(user.salesAnalyticsAgentKey)) ||
      Boolean(findAgentMatch(api, user));
  });
  const options = {
    tasksEnabled: String(process.env.SALES_KPI_TASKS_ENABLED || 'true') !== 'false',
    currency: String(process.env.SALES_KPI_CURRENCY || 'SAR').trim().toUpperCase(),
  };
  const context = await loadTaskCalendarContext(
    db,
    cycle,
    candidateUserDocs.map((doc) => doc.id),
    input.now || new Date(),
  );
  const duplicateKeys = duplicateConfiguredAgentKeys(candidateUserDocs);
  const results = [];
  for (const userDoc of candidateUserDocs) {
    const configuredKey = normalize(userDoc.data().salesAnalyticsAgentKey);
    if (configuredKey && duplicateKeys.has(configuredKey)) {
      results.push({
        matched: false,
        userId: userDoc.id,
        reason: 'duplicate_agent_key',
      });
      continue;
    }
    results.push(await upsertEmployeeKpi(db, userDoc, api, cycle, options, context));
  }
  const matched = results.filter((item) => item.matched);
  const salesResults = matched.filter((item) => item.metricKind === 'sales');
  const teleSalesResults = matched.filter((item) => item.metricKind === 'tele_sales');
  const salesDepartment = departmentAgentStats(api.salesKpi, 'sales');
  const teleDepartment = departmentAgentStats(api.teleSalesKpi, 'tele_sales');
  const mappedByAgent = new Map(
    matched.map((item) => [`${item.metricKind}:${normalize(item.providerAgentKey)}`, item]),
  );
  const agentSummaries = [
    ...salesDepartment.agents.map((agent) => ({ role: 'sales', agent })),
    ...teleDepartment.agents.map((agent) => ({ role: 'tele_sales', agent })),
  ].map(({ role, agent }) => {
    const key = primaryAgentKey(agent);
    const mapped = mappedByAgent.get(`${role}:${key}`);
    return {
      kind: role,
      key,
      externalId: strongAgentIdentifiers(agent)[0] || '',
      name: String(agent?.name || agent?.displayName || agent?.label || key),
      target: number(agent?.target || (role === 'sales' ? api.salesKpi?.target : api.teleSalesKpi?.target)),
      actual: agentActualForRole(
        agent,
        role === 'sales' ? api.salesKpi?.counts : api.teleSalesKpi?.counts,
        role,
      ),
      finalKpi: normalizedPercent(agent?.finalKpi),
      mappedUserId: mapped?.userId || '',
      mappedEmployeeId: mapped?.employeeId || '',
      mappedEmployeeName: mapped?.employeeName || '',
      providerDetails: providerDetailsForAgent(agent, role, options.currency),
    };
  });
  const summary = api.summary || {};
  const snapshot = {
    periodKey: cycle.monthKey,
    periodStart: cycle.startDate,
    periodEnd: cycle.endDate,
    filters: api.filters || filters,
    options: api.options || {},
    totalLeads: number(summary.totalLeads),
    confirmedMeetings: number(summary.confirmedMeetings),
    closings: number(summary.closings),
    paidCustomers: number(summary.paidCustomers),
    totalPrice: number(summary.totalPrice),
    downPayment: number(summary.downPayment),
    monthlyIncome: number(summary.monthlyIncome),
    monthlyGrowthRate: number(summary.monthlyGrowthRate),
    teleConversionRate: number(summary.teleConversionRate),
    salesConversionRate: number(summary.salesConversionRate),
    generatedAt: api.generatedAt || '',
    sourceWarnings: Array.isArray(api.source?.warnings)
      ? api.source.warnings.map(String).slice(0, 10)
      : [],
    integrationWarnings: Array.isArray(api.integrationDiagnostics?.warnings)
      ? api.integrationDiagnostics.warnings.map(String).slice(0, 10)
      : [],
    apiAgentCount: number(api.integrationDiagnostics?.totalAgents),
    apiIdentifiedAgentCount: number(api.integrationDiagnostics?.identifiedAgents),
    apiMissingAgentIdCount: number(api.integrationDiagnostics?.missingAgentIds),
    apiIdentityMappingReady: api.integrationDiagnostics?.identityMappingReady === true,
    salesTarget: number(api.salesKpi?.target),
    teleSalesTarget: number(api.teleSalesKpi?.target),
    salesDepartmentTarget: salesDepartment.target,
    teleSalesDepartmentTarget: teleDepartment.target,
    salesDepartmentActual: salesDepartment.actual,
    teleSalesDepartmentActual: teleDepartment.actual,
    salesAverageKpi: salesDepartment.averageKpi,
    teleSalesAverageKpi: teleDepartment.averageKpi,
    availableSalesAgents: salesDepartment.agents.length,
    availableTeleSalesAgents: teleDepartment.agents.length,
    agentSummaries,
    salesActual: salesResults.reduce((sum, item) => sum + number(item.actual), 0),
    teleSalesActual: teleSalesResults.reduce((sum, item) => sum + number(item.actual), 0),
    salesEmployeeTarget: salesResults.reduce((sum, item) => sum + number(item.target), 0),
    teleSalesEmployeeTarget: teleSalesResults.reduce((sum, item) => sum + number(item.target), 0),
    salesMappedEmployees: salesResults.length,
    teleSalesMappedEmployees: teleSalesResults.length,
    currency: options.currency,
    mappedEmployees: matched.length,
    unmatchedEmployees: results.length - matched.length,
    duplicateAgentKeys: [...duplicateKeys],
    unmatchedEmployeeIds: results
      .filter((item) => !item.matched)
      .map((item) => item.userId),
    unmappedApiAgentKeys: agentSummaries
      .filter((agent) => !agent.mappedUserId)
      .map((agent) => agent.key)
      .filter(Boolean),
    createdTasks: matched.reduce((sum, item) => sum + item.createdTasks, 0),
    lateTasks: matched.reduce((sum, item) => sum + item.lateTasks, 0),
    syncedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  await db.collection('salesKpiSummaries').doc(cycle.monthKey).set(snapshot);
  await db.collection('salesKpiSummaries').doc('current').set(snapshot);
  return {
    periodKey: cycle.monthKey,
    users: results.length,
    matched: matched.length,
    unmatched: results.length - matched.length,
    createdTasks: snapshot.createdTasks,
  };
}

if (require.main === module) {
  syncSalesKpis()
    .then((result) => console.log('Sales KPI sync complete:', result))
    .catch((error) => {
      console.error('Sales KPI sync failed:', error.message || error);
      process.exitCode = 1;
    });
}

module.exports = {
  syncSalesKpis,
  cycleFor,
  normalize,
  agentIdentifiers,
  agentActual,
  agentActualForRole,
  providerDetailsForAgent,
  duplicateConfiguredAgentKeys,
  agentsFrom,
  strongAgentIdentifiers,
  primaryAgentKey,
  findAgent,
  findAgentMatch,
  departmentAgentStats,
  taskDueDates,
  eligibleTaskDates,
  dailyTaskState,
};
