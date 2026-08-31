# Attendance and Request Read-Model Contract

## Request view

```text
RequestViewQuery {
  actorScope, role, tab, lifecycleFilters, employeeOrTeamScope,
  fromDate, toDate, searchTerm, pageCursor, pageSize
}
```

The authority/repository derives permitted scopes from the authenticated actor;
the client cannot widen them. Queries are bounded and paginated. Legacy fields
are normalized into display records without changing their source.

```text
RequestViewResult = loaded(records, nextCursor?) | empty |
                    retryableFailure(safeMessage) |
                    accessDenied(safeMessage)
```

## Approval decision

```text
RequestDecision {
  requestStableId, expectedRevision, decision, reason?
}
```

The authority validates actor, stage, ownership, and revision, returning only:
`advanced`, `finalized`, `already_final`, `conflict`, `denied`, or `retryable`.
Historic confirmed records remain immutable.

## Productivity query

```text
ProductivityQuery { actorScope, employeeOrTeamScope, periodStart, periodEnd }
```

The result includes typed input availability; missing KPI assignment differs
from unavailable source data.
