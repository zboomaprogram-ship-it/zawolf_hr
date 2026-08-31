# Sales Indicators Contract

The provider token is server-only in `SALES_API_KEY`; Flutter has no provider
credential. Rotate the test key shared outside secret storage before production.

## `POST /sales-indicators/query`

Body contains `operationId` and normalized filter: start/end date, company,
entry channel, optional local employee UID, and sales/tele targets. The runtime
resolves approved `idEmp`, verifies provider filter echo, persists a
filter-versioned result snapshot, and returns cards/charts/list plus safe source
health counts. The same `filterVersion` is required for every chart/list/export.
Raw unresolved rows are available only to authorized HR/admin reconciliation.

## `PUT /sales-indicators/mappings/{externalIdentity}`

HR/admin only. Body contains local employee UID/code, mapping state, review
reason, and operation ID. A transaction prevents multiple active mappings.
