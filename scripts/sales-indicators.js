const crypto = require('crypto');

function normalizedList(value) {
  if (Array.isArray(value)) return [...new Set(value.map(String).map((v) => v.trim()).filter(Boolean))].sort();
  const text = String(value || '').trim();
  return !text || text === 'ALL' ? [] : [text];
}

function canonicalSalesFilters(input = {}) {
  return {
    startDate: String(input.startDate || '').slice(0, 10),
    endDate: String(input.endDate || '').slice(0, 10),
    company: String(input.company || 'ALL').trim() || 'ALL',
    sales: normalizedList(input.sales),
    teleSales: normalizedList(input.teleSales),
    entryChannel: String(input.entryChannel || 'ALL').trim() || 'ALL',
    salesTarget: Number(input.salesTarget || 20000),
    teleTarget: Number(input.teleTarget || 50),
    cumulative: input.cumulative !== false,
  };
}

function salesFilterVersion(input = {}) {
  const canonical = canonicalSalesFilters(input);
  return crypto.createHash('sha256')
    .update(JSON.stringify(canonical))
    .digest('hex')
    .slice(0, 24);
}

function mappingDocumentId(role, providerKey) {
  return crypto.createHash('sha256')
    .update(`${String(role || '').trim().toLowerCase()}:${String(providerKey || '').trim().toLowerCase()}`)
    .digest('hex');
}

function reconcileAgentMappings(agentRows = [], registry = []) {
  const byProvider = new Map();
  for (const row of registry) {
    const role = String(row.providerRole || '').toLowerCase();
    const pKey = String(row.providerKey || '').toLowerCase();
    const empId = String(row.employeeId || '').toLowerCase();
    if (row.active !== false) {
      if (pKey) {
        const key = `${role}:${pKey}`;
        const list = byProvider.get(key) || [];
        list.push(row);
        byProvider.set(key, list);
      }
      if (empId && empId !== pKey) {
        const key = `${role}:${empId}`;
        const list = byProvider.get(key) || [];
        list.push(row);
        byProvider.set(key, list);
      }
    }
  }
  return agentRows.map((agent) => {
    const role = String(agent.kind || '').toLowerCase();
    const candidates = [
      ...(byProvider.get(`${role}:${String(agent.key || '').toLowerCase()}`) || []),
      ...(byProvider.get(`${role}:${String(agent.externalId || '').toLowerCase()}`) || []),
    ];
    const uniqueCandidates = Array.from(new Set(candidates));

    if (uniqueCandidates.length === 1) {
      const mapping = uniqueCandidates[0];
      return {
        ...agent,
        mappingStatus: 'mapped',
        mappedUserId: String(mapping.userId || agent.mappedUserId || ''),
        mappedEmployeeId: String(mapping.employeeId || agent.mappedEmployeeId || ''),
        mappedEmployeeName: String(mapping.employeeName || agent.mappedEmployeeName || ''),
      };
    }
    if (uniqueCandidates.length > 1) {
      return {
        ...agent,
        mappingStatus: 'ambiguous',
        mappedUserId: '',
        mappedEmployeeId: '',
        mappedEmployeeName: '',
      };
    }

    const isAlreadyMapped = Boolean(agent.mappedUserId);
    return {
      ...agent,
      mappingStatus: isAlreadyMapped ? 'mapped' : 'unmapped',
      mappedUserId: agent.mappedUserId || '',
      mappedEmployeeId: agent.mappedEmployeeId || '',
      mappedEmployeeName: agent.mappedEmployeeName || '',
    };
  });
}

function sourceHealth({ apiOk = true, filterEchoMatches = true, ambiguous = 0, unmapped = 0 } = {}) {
  if (!apiOk) return 'unavailable';
  if (!filterEchoMatches || ambiguous > 0 || unmapped > 0) return 'partial';
  return 'healthy';
}

module.exports = {
  canonicalSalesFilters,
  salesFilterVersion,
  mappingDocumentId,
  reconcileAgentMappings,
  sourceHealth,
};
