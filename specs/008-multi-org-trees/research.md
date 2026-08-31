# Research: Multiple Organization Trees

## Decisions

### Many memberships, one employee identity

Use membership records rather than duplicated users. This preserves authentication,
attendance, payroll, deductions, notifications, and audit identity.

### One primary membership for authoritative HR routing

Multiple trees are intentionally non-authoritative by default. Exactly one primary
membership projects the legacy department/manager fields used by current services.
This avoids ambiguous approvals and allows gradual migration.

### Server-side tree capabilities

Global organization capability and tree-scoped grants are resolved by the server.
Root leaders receive no implicit global access. Employee codes remain data, not policy.

### Versioned change sets and immutable approval plans

Tree mutations use expected versions and idempotency keys. Primary changes affect
only future request-plan creation. Existing plans are historical business evidence.

### Non-destructive default-tree migration

The existing single tree is imported as the default through dry run and confirmed
apply. Legacy fields remain as a compatibility projection and rollback seam.

## Rejected Alternatives

- Copying employees into each tree: breaks identity and audit consistency.
- Combining all managers into `managerIds`: makes approvals non-deterministic.
- Hard-coding CEO codes per tree: cannot support managed replacement or history.
- Replacing the current tree in-place: lacks safe rollback and violates migration rules.

