# Sales Analytics Integration API

Version: `1.0`

This API exposes the Sales Analytics data, filters, KPI calculations, and
optional source rows for use by another server-side system.

## Endpoint

```text
GET /api/v1/sales-analytics
```

Local development URL:

```text
https://kpi.samielmetwali.com/api/v1/sales-analytics
```

Production URL:

```text
https://kpi.samielmetwali.com/api/v1/sales-analytics
```

## Authentication

Set a long random secret in the dashboard server environment:

```env
SALES_API_KEY=YOUR_LONG_RANDOM_SECRET
```

Generate one locally with:

```bash
npm run api:key
```

Send the same secret from the second system:

```http
Authorization: Bearer YOUR_LONG_RANDOM_SECRET
```

The legacy `X-API-Key` header is also accepted, but Bearer authentication is
recommended.

Never put this key in browser JavaScript, a public repository, or a frontend
environment variable. The second system must call this API from its server.

## Query parameters

| Parameter      | Type                 | Default                    | Description                         |
| -------------- | -------------------- | -------------------------- | ----------------------------------- |
| `startDate`    | `YYYY-MM-DD`         | First day of current month | Start of the reporting period       |
| `endDate`      | `YYYY-MM-DD`         | Last day of current month  | End of the reporting period         |
| `company`      | string               | `ALL`                      | Exact company filter                |
| `sales`        | string               | `ALL`                      | Exact Sales employee filter         |
| `teleSales`    | string               | `ALL`                      | Exact Tele Sales employee filter    |
| `entryChannel` | string               | `ALL`                      | Exact entry-channel filter          |
| `salesTarget`  | positive number      | Dashboard default          | Sales KPI target                    |
| `teleTarget`   | positive number      | Dashboard default          | Tele Sales KPI target               |
| `includeRows`  | boolean              | `false`                    | Include filtered source rows        |
| `offset`       | non-negative integer | `0`                        | Source-row pagination offset        |
| `limit`        | integer              | `100`                      | Source-row page size; maximum `500` |

The maximum date range is 366 days per request.

Use the values returned in `options` to build filter dropdowns. Send `ALL` to
disable a filter.

## Basic request

```bash
curl "https://kpi.samielmetwali.com/api/v1/sales-analytics?startDate=2026-07-01&endDate=2026-07-31" \
  -H "Authorization: Bearer YOUR_SALES_API_KEY"
```

## Filtered request

```bash
curl "https://kpi.samielmetwali.com/api/v1/sales-analytics?startDate=2026-07-01&endDate=2026-07-31&company=Rabhan&sales=MK-6000&teleSales=TK-100&entryChannel=Hot%20leads" \
  -H "Authorization: Bearer YOUR_SALES_API_KEY"
```

## Request including source rows

```bash
curl "https://kpi.samielmetwali.com/api/v1/sales-analytics?startDate=2026-07-01&endDate=2026-07-31&includeRows=true&limit=100&offset=0" \
  -H "Authorization: Bearer YOUR_SALES_API_KEY"
```

## Successful response

```json
{
  "success": true,
  "apiVersion": "1.0",
  "generatedAt": "2026-07-29T12:00:00.000Z",
  "source": {
    "type": "google_sheets",
    "spreadsheetId": "SOURCE_SPREADSHEET_ID",
    "tabs": ["total", "Confirm meetings"],
    "warnings": []
  },
  "filters": {
    "startDate": "2026-07-01",
    "endDate": "2026-07-31",
    "company": "ALL",
    "sales": "ALL",
    "teleSales": "ALL",
    "entryChannel": "ALL",
    "salesTarget": 20000,
    "teleTarget": 50
  },
  "options": {
    "companies": [],
    "salesAgents": [],
    "teleSalesAgents": [],
    "entryChannels": []
  },
  "summary": {
    "totalLeads": 0,
    "confirmedMeetings": 0,
    "closings": 0,
    "paidCustomers": 0,
    "totalPrice": 0,
    "downPayment": 0,
    "monthlyIncome": 0,
    "monthlyGrowthRate": 0,
    "teleConversionRate": 0,
    "salesConversionRate": 0
  },
  "breakdowns": {
    "leadsByCompany": [],
    "leadsByEntryChannel": [],
    "leadsByCompanyEntryChannel": [],
    "confirmedMeetingsByCompany": [],
    "confirmedMeetingsByEntryChannel": [],
    "paidCustomersByCompany": [],
    "paidCustomersByEntryChannel": [],
    "paidCustomersByNiche": [],
    "rejectionReasonsByTeleSales": [],
    "packages": []
  },
  "salesKpi": {
    "target": 20000,
    "counts": {},
    "agents": []
  },
  "teleSalesKpi": {
    "target": 50,
    "counts": {},
    "agents": []
  },
  "rows": null
}
```

Rates are returned as decimal ratios:

```text
0.1096 = 10.96%
```

Money values are numeric and use the same currency as the source sheet.

## Source-row pagination

When `includeRows=true`, `rows` has this shape:

```json
{
  "total": 1897,
  "offset": 0,
  "limit": 100,
  "hasMore": true,
  "items": []
}
```

Request the next page with:

```text
offset=100&limit=100
```

Summary, breakdown, and KPI fields always represent the complete filtered
dataset, not only the current source-row page.

## JavaScript server example

```js
const params = new URLSearchParams({
  startDate: "2026-07-01",
  endDate: "2026-07-31",
  company: "ALL",
  sales: "ALL",
  teleSales: "ALL",
  entryChannel: "ALL",
});

const response = await fetch(
  `${process.env.SALES_API_BASE_URL}/api/v1/sales-analytics?${params}`,
  {
    headers: {
      Authorization: `Bearer ${process.env.SALES_API_KEY}`,
    },
  },
);

const payload = await response.json();

if (!response.ok) {
  throw new Error(`${payload.error.code}: ${payload.error.message}`);
}

console.log(payload.summary);
```

Recommended environment variables in the second system:

```env
SALES_API_BASE_URL=https://kpi.samielmetwali.com
SALES_API_KEY=THE_SAME_INTEGRATION_SECRET
```

## Error responses

All errors use this shape:

```json
{
  "success": false,
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Provide a valid API key using the Authorization: Bearer header."
  }
}
```

| HTTP status | Code                   | Meaning                                  |
| ----------- | ---------------------- | ---------------------------------------- |
| `400`       | `INVALID_DATE`         | A date is not in `YYYY-MM-DD` format     |
| `400`       | `INVALID_DATE_RANGE`   | Start date is after end date             |
| `400`       | `DATE_RANGE_TOO_LARGE` | Requested range exceeds 366 days         |
| `400`       | `INVALID_NUMBER`       | Invalid pagination or target value       |
| `401`       | `UNAUTHORIZED`         | Missing or incorrect integration key     |
| `502`       | `DATA_SOURCE_ERROR`    | Google Sheets could not be loaded        |
| `503`       | `API_NOT_CONFIGURED`   | `SALES_API_KEY` is missing on the server |

## Deployment checklist

1. Generate a new high-entropy `SALES_API_KEY`.
2. Add it to the dashboard hosting environment.
3. Add the same key to the second system's server environment.
4. Keep Google credentials and Gemini keys only in the dashboard server.
5. Call the API from the second system's backend, not its browser.
6. Use HTTPS in production.
7. Rotate the integration key immediately if it is exposed.