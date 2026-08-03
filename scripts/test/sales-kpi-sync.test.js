const test = require('node:test');
const assert = require('node:assert/strict');

const {
  agentActual,
  agentActualForRole,
  cycleFor,
  duplicateConfiguredAgentKeys,
  departmentAgentStats,
  findAgent,
  findAgentMatch,
  taskDueDates,
  eligibleTaskDates,
  dailyTaskState,
  providerDetailsForAgent,
} = require('../sync-sales-kpis');
const {
  analyzeIdentityContract,
  fetchSalesAnalytics,
} = require('../sales-analytics-client');

test('Sales Analytics requests aggregate duplicate source rows by default', async () => {
  const previousKey = process.env.SALES_API_KEY;
  process.env.SALES_API_KEY = 'test-key';
  let requestedUrl;
  try {
    await fetchSalesAnalytics(
      { startDate: '2026-07-01', endDate: '2026-07-31', idEmp: 'BD-1201' },
      async (url) => {
        requestedUrl = new URL(url);
        return new Response(JSON.stringify({ success: true, summary: {} }), {
          status: 200,
        });
      },
    );
  } finally {
    if (previousKey == null) {
      delete process.env.SALES_API_KEY;
    } else {
      process.env.SALES_API_KEY = previousKey;
    }
  }
  assert.equal(requestedUrl.searchParams.get('cumulative'), 'true');
  assert.equal(requestedUrl.searchParams.get('idEmp'), 'BD-1201');
});

test('cycleFor uses the company cycle from the 26th through the 25th', () => {
  const beforeClose = cycleFor(new Date('2026-07-15T08:00:00Z'));
  assert.equal(beforeClose.monthKey, '2026-07');
  assert.equal(beforeClose.startDate, '2026-06-26');
  assert.equal(beforeClose.endDate, '2026-07-25');

  const afterClose = cycleFor(new Date('2026-07-29T08:00:00Z'));
  assert.equal(afterClose.monthKey, '2026-08');
  assert.equal(afterClose.startDate, '2026-07-26');
  assert.equal(afterClose.endDate, '2026-08-25');
});

test('findAgent matches configured keys after safe normalization', () => {
  const kpi = {
    agents: [
      { name: 'Omar.Mahmoud', actual: 12 },
      { name: 'Other Agent', actual: 4 },
    ],
  };
  const match = findAgent(kpi, {
    salesAnalyticsAgentKey: 'omar mahmoud',
    employeeId: 'MKT-604',
  });
  assert.equal(match.name, 'Omar.Mahmoud');
});

test('findAgent only auto-links an employee id to a strong API id', () => {
  const kpi = {
    agents: [
      { name: 'BD-1205', code: 'S9' },
      { name: 'Real Agent', idEmp: 'BD-1205', code: 'S8' },
    ],
  };
  const match = findAgent(kpi, { employeeId: 'BD-1205' });
  assert.equal(match.name, 'Real Agent');
});

test('findAgentMatch can infer sales or telesales from API ids', () => {
  const match = findAgentMatch({
    salesKpi: { agents: [] },
    teleSalesKpi: { agents: [{ id: 'BD-1205', name: 'Agent' }] },
  }, { employeeId: 'BD-1205' });
  assert.equal(match.role, 'tele_sales');
});

test('blank provider ids are reported and never treated as employee matches', () => {
  const api = {
    filters: { idEmp: 'BD-1201' },
    salesKpi: {
      agents: [
        { id: '', name: 'S4' },
        { id: '', name: 'S8' },
      ],
    },
    teleSalesKpi: { agents: [] },
  };
  const diagnostics = analyzeIdentityContract(api, 'BD-1201');
  assert.equal(diagnostics.totalAgents, 2);
  assert.equal(diagnostics.missingAgentIds, 2);
  assert.equal(diagnostics.identityMappingReady, false);
  assert.equal(diagnostics.employeeFilterApplied, false);
  assert.equal(findAgent(api.salesKpi, { employeeId: 'BD-1201' }), undefined);
});

test('explicit provider agent keys remain available as a controlled mapping', () => {
  const agent = findAgent(
    { agents: [{ id: '', name: 'S8', totalPrice: 4500 }] },
    { employeeId: 'BD-1201', salesAnalyticsAgentKey: 'S8' },
  );
  assert.equal(agent.name, 'S8');
});

test('departmentAgentStats sums department targets and actuals', () => {
  const stats = departmentAgentStats({
    agents: [
      { target: 20000, totalPrice: 18000, finalKpi: 0.8 },
      { target: 20000, totalPrice: 22000, finalKpi: 1.0 },
    ],
  }, 'sales');
  assert.equal(stats.target, 40000);
  assert.equal(stats.actual, 40000);
  assert.equal(stats.averageKpi, 90);
});

test('agentActual reads normalized count-map keys', () => {
  assert.equal(
    agentActual('omar mahmoud', { 'Omar.Mahmoud': 19 }),
    19,
  );
});

test('agentActualForRole uses raw telesales meeting counts', () => {
  assert.equal(
    agentActualForRole(
      { achieved: 0.52, confirmedMeetings: 26 },
      {},
      'tele_sales',
    ),
    26,
  );
});

test('agentActualForRole uses invoiced sales value', () => {
  assert.equal(
    agentActualForRole(
      { achieved: 0.8, totalPrice: 12300 },
      {},
      'sales',
    ),
    12300,
  );
});

test('providerDetailsForAgent preserves the sales dashboard metrics', () => {
  assert.deepEqual(
    providerDetailsForAgent(
      {
        confirmedSales: 12,
        meetings: 8,
        conversion: 0.0635,
        totalPrice: 17100,
        downPayment: 11600,
        monthlyIncome: 13600,
        target: 20000,
        invoiceAchievement: 0.855,
        salesConversionAchieved: 0.0254,
        totalInvoiceAchieved: 0.513,
        finalKpi: 0.5384,
      },
      'sales',
      'SAR',
    ),
    {
      kind: 'sales',
      currency: 'SAR',
      confirmedSales: 12,
      meetings: 8,
      conversion: 6.35,
      totalPrice: 17100,
      downPayment: 11600,
      monthlyIncome: 13600,
      target: 20000,
      invoiceAchievement: 85.5,
      salesConversionAchieved: 2.54,
      totalInvoiceAchieved: 51.3,
      finalKpi: 53.84,
    },
  );
});

test('providerDetailsForAgent keeps telesales metrics separate', () => {
  const details = providerDetailsForAgent(
    {
      totalLeads: 592,
      confirmedMeetings: 94,
      conversion: 0.1588,
      target: 50,
      achieved: 1.88,
      confirmedSales: 5,
      vsMeetings: 0.0538,
      finalKpi: 0.7255,
    },
    'tele_sales',
    'SAR',
  );
  assert.equal(details.kind, 'tele_sales');
  assert.equal(details.totalLeads, 592);
  assert.equal(details.confirmedMeetings, 94);
  assert.equal(details.finalKpi, 72.55);
  assert.equal(details.totalPrice, undefined);
});

test('providerDetailsForAgent normalizes fractional API percentages', () => {
  const sales = providerDetailsForAgent(
    { conversion: 0.0635, invoiceAchievement: 0.855, finalKpi: 0.5384 },
    'sales',
    'SAR',
  );
  const teleSales = providerDetailsForAgent(
    { conversion: 0.1588, achieved: 1.88, finalKpi: 0.7255 },
    'tele_sales',
    'SAR',
  );

  assert.ok(Math.abs(sales.conversion - 6.35) < 0.000001);
  assert.equal(sales.invoiceAchievement, 85.5);
  assert.ok(Math.abs(sales.finalKpi - 53.84) < 0.000001);
  assert.ok(Math.abs(teleSales.conversion - 15.88) < 0.000001);
  assert.equal(teleSales.achieved, 188);
  assert.ok(Math.abs(teleSales.finalKpi - 72.55) < 0.000001);
});

test('providerDetailsForAgent preserves over-target percentages', () => {
  const details = providerDetailsForAgent(
    { conversion: 1.0833333333333333, achieved: 1.88, finalKpi: 0.7236666667 },
    'tele_sales',
    'SAR',
  );

  assert.ok(Math.abs(details.conversion - 108.33333333333333) < 0.000001);
  assert.equal(details.achieved, 188);
  assert.ok(Math.abs(details.finalKpi - 72.36666667) < 0.000001);
});

test('duplicateConfiguredAgentKeys detects unsafe employee mappings', () => {
  const docs = [
    { id: 'one', data: () => ({ salesAnalyticsAgentKey: 'S8' }) },
    { id: 'two', data: () => ({ salesAnalyticsAgentKey: 's-8' }) },
    { id: 'three', data: () => ({ salesAnalyticsAgentKey: 'TSR3' }) },
  ];
  assert.deepEqual([...duplicateConfiguredAgentKeys(docs)], ['s8']);
});

test('taskDueDates creates ordered milestones inside the cycle', () => {
  const cycle = cycleFor(new Date('2026-07-15T08:00:00Z'));
  const dates = taskDueDates(cycle, 4);
  assert.equal(dates.length, 4);
  assert.ok(dates.every((date, index) =>
    date >= cycle.start &&
    date <= cycle.end &&
    (index === 0 || date > dates[index - 1]),
  ));
});

test('eligibleTaskDates excludes non-working days, leave, and company days off', () => {
  const cycle = {
    startDate: '2026-08-01',
    endDate: '2026-08-08',
  };
  const dates = eligibleTaskDates(
    {
      uid: 'employee-1',
      workSchedule: { workDays: [6, 7, 1, 2, 3, 4] },
    },
    cycle,
    {
      companyDaysOff: new Set(['2026-08-03']),
      leaveDaysByUser: new Map([
        ['employee-1', new Set(['2026-08-04'])],
      ]),
    },
  ).map((date) => date.toISOString().slice(0, 10));

  assert.ok(!dates.includes('2026-08-03'));
  assert.ok(!dates.includes('2026-08-04'));
  assert.ok(!dates.includes('2026-08-07'));
  assert.ok(dates.includes('2026-08-01'));
});

test('dailyTaskState distinguishes exceeded and missed cumulative targets', () => {
  const ahead = dailyTaskState({
    date: new Date('2026-08-02T00:00:00Z'),
    index: 1,
    targetPerDay: 10,
    actual: 25,
    now: new Date('2026-08-02T12:00:00Z'),
  });
  assert.equal(ahead.status, 'done');
  assert.equal(ahead.performanceState, 'ahead');

  const missed = dailyTaskState({
    date: new Date('2026-08-01T00:00:00Z'),
    index: 0,
    targetPerDay: 10,
    actual: 5,
    now: new Date('2026-08-02T12:00:00Z'),
  });
  assert.equal(missed.status, 'late');
  assert.equal(missed.performanceState, 'behind');
});
