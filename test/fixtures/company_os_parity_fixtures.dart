/// Non-production parity cases used before enabling any Company OS slice.
/// They contain no credentials, production UIDs, or provider data.
const companyOsParityFixtures = <Map<String, Object?>>[
  {
    'slice': 'company_os_portal_v1',
    'actorRole': 'employee',
    'legacyRoute': '/employee/dashboard',
    'v2Route': '/company-os',
    'expectedScope': 'self',
  },
  {
    'slice': 'company_os_it_v1',
    'actorRole': 'it_manager',
    'legacyRoute': '/manager/requests',
    'v2Route': '/company-os/it',
    'expectedScope': 'department',
  },
  {
    'slice': 'company_os_requests_v1',
    'actorRole': 'manager',
    'legacyRoute': '/manager/requests',
    'v2Route': '/requests/operational/request-test-1',
    'expectedScope': 'team',
  },
  {
    'slice': 'company_os_operations_v1',
    'actorRole': 'super_admin',
    'legacyRoute': '/hr/dashboard',
    'v2Route': '/company-os/operations',
    'expectedScope': 'company',
  },
];

const companyOsRequiredMetrics = <String>[
  'request_count',
  'p95_latency_ms',
  'safe_error_rate',
  'denied_scope_attempts',
  'firestore_reads',
  'duplicate_operations',
];
