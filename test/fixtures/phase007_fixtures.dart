const phase007SafeDiagnosticFixture = <String, Object?>{
  'feature': 'attendance_checkin',
  'safeCode': 'temporarily_unavailable',
  'release': 'pilot-007',
  'count': 2,
  'lastSeenAt': '2026-08-23T10:00:00Z',
};

const phase007SalesMappingFixtures = <Map<String, Object?>>[
  {'providerRole': 'sales', 'providerKey': 'S1', 'status': 'mapped'},
  {'providerRole': 'sales', 'providerKey': 'S2', 'status': 'unmapped'},
  {'providerRole': 'tele_sales', 'providerKey': 'TS1', 'status': 'ambiguous'},
];

const phase007HistoricRequestFixture = <String, Object?>{
  'id': 'historic-request-1',
  'requestType': 'salary_deduction',
  'businessEffectiveAt': '2026-07-22T14:00:00Z',
  'approvedAt': '2026-08-02T08:28:00Z',
  'status': 'approved',
};
