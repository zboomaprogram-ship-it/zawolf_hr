const DEFAULT_BASE_URL = 'https://kpi.samielmetwali.com';

class SalesAnalyticsError extends Error {
  constructor(message, statusCode = 0) {
    super(message);
    this.name = 'SalesAnalyticsError';
    this.statusCode = statusCode;
  }
}

function normalizeIdentifier(value) {
  return String(value || '')
    .trim()
    .toLocaleLowerCase('en')
    .replace(/[\s._-]+/g, '');
}

function agentsFrom(kpiData) {
  if (Array.isArray(kpiData?.agents)) return kpiData.agents;
  return Object.entries(kpiData?.agents || {}).map(([key, value]) => (
    value && typeof value === 'object' ? { key, ...value } : { key, actual: value }
  ));
}

function strongIdentifiers(agent) {
  if (!agent || typeof agent !== 'object') return [];
  return [agent.id, agent.idEmp, agent.employeeId, agent.employeeCode]
    .map(normalizeIdentifier)
    .filter(Boolean);
}

function analyzeIdentityContract(body, requestedIdEmp = '') {
  const agents = [
    ...agentsFrom(body?.salesKpi),
    ...agentsFrom(body?.teleSalesKpi),
  ];
  const identifiedAgents = agents.filter(
    (agent) => strongIdentifiers(agent).length > 0,
  );
  const requested = normalizeIdentifier(requestedIdEmp);
  const matchingAgents = requested
    ? agents.filter((agent) => strongIdentifiers(agent).includes(requested))
    : [];
  const filterEcho = normalizeIdentifier(body?.filters?.idEmp);
  const employeeFilterApplied = requested
    ? filterEcho === requested && matchingAgents.length === 1 && agents.length === 1
    : null;
  const warnings = [];
  if (agents.length > identifiedAgents.length) {
    warnings.push(
      `${agents.length - identifiedAgents.length} API agent row(s) have no stable employee id.`,
    );
  }
  if (requested && !employeeFilterApplied) {
    warnings.push(
      `The API did not return one employee row for idEmp=${requestedIdEmp}.`,
    );
  }
  return {
    totalAgents: agents.length,
    identifiedAgents: identifiedAgents.length,
    missingAgentIds: agents.length - identifiedAgents.length,
    identityMappingReady: agents.length > 0 && identifiedAgents.length === agents.length,
    requestedIdEmp: requestedIdEmp || '',
    employeeFilterApplied,
    warnings,
  };
}

function requiredConfig() {
  const apiKey = String(process.env.SALES_API_KEY || '').trim();
  if (!apiKey) {
    throw new SalesAnalyticsError('SALES_API_KEY is required.');
  }
  return {
    apiKey,
    baseUrl: String(process.env.SALES_API_BASE_URL || DEFAULT_BASE_URL)
      .replace(/\/+$/, ''),
    timeoutMs: Math.max(5000, Number(process.env.SALES_API_TIMEOUT_MS || 20000)),
  };
}

async function fetchSalesAnalytics(params, fetchImpl = globalThis.fetch) {
  if (typeof fetchImpl !== 'function') {
    throw new SalesAnalyticsError('This Node runtime does not provide fetch.');
  }
  const { apiKey, baseUrl, timeoutMs } = requiredConfig();
  const url = new URL(`${baseUrl}/api/v1/sales-analytics`);
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== null && value !== '') {
      url.searchParams.set(key, String(value));
    }
  }
  url.searchParams.set('includeRows', 'false');
  url.searchParams.set('limit', '100');
  url.searchParams.set('offset', '0');
  // The provider can expose more than one source row for an employee. Ask it
  // to aggregate those rows before the HR sync maps the result by employeeId.
  if (!url.searchParams.has('cumulative')) {
    url.searchParams.set('cumulative', 'true');
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetchImpl(url, {
      headers: {
        accept: 'application/json',
        authorization: `Bearer ${apiKey}`,
      },
      signal: controller.signal,
    });
    const text = await response.text();
    let body;
    try {
      body = text ? JSON.parse(text) : {};
    } catch (_) {
      throw new SalesAnalyticsError(
        `Sales Analytics returned invalid JSON (${response.status}).`,
        response.status,
      );
    }
    if (!response.ok) {
      const apiError = body?.error;
      throw new SalesAnalyticsError(
        body?.message ||
          apiError?.message ||
          (typeof apiError === 'string' ? apiError : '') ||
          `Sales Analytics failed (${response.status}).`,
        response.status,
      );
    }
    if (body?.success === false || !body?.summary) {
      throw new SalesAnalyticsError(
        body?.message || 'Sales Analytics returned an incomplete response.',
        response.status,
      );
    }
    body.integrationDiagnostics = analyzeIdentityContract(body, params.idEmp);
    return body;
  } catch (error) {
    if (error?.name === 'AbortError') {
      throw new SalesAnalyticsError('Sales Analytics request timed out.');
    }
    throw error;
  } finally {
    clearTimeout(timeout);
  }
}

module.exports = {
  fetchSalesAnalytics,
  SalesAnalyticsError,
  analyzeIdentityContract,
};
