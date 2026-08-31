# Contract: Multiple Organization Trees API

All routes require Firebase bearer authentication, server-resolved capabilities,
bounded input, and safe Arabic error mapping.

- `GET /company-os/organization/trees?limit&cursor&includeArchived`
- `GET /company-os/organization/trees/:treeId/snapshot?limit&cursor`
- `POST /company-os/organization/trees/preview`
- `POST /company-os/organization/trees/apply`
- `GET /company-os/organization/operations/:operationId`
- `GET /company-os/organization/employees/search?q&treeId&limit`

Mutation envelope:

```json
{
  "operationId": "client-stable-id",
  "treeId": "tree-id",
  "expectedVersion": 4,
  "actions": [{"type": "set_primary_membership", "membershipId": "..."}]
}
```

Receipts return `saved`, `pending`, `conflict`, or `needs_status_check`; repeated
`operationId` returns the original receipt and does not append a second audit event.

