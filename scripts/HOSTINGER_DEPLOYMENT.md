# ZaWolf HR Hostinger Backend

This package runs the notification dispatcher, attendance reminders,
automatic attendance processing, manager permission bypass processing, and
Sales KPI synchronization.

## Hostinger setup

- Framework: Node.js
- Node version: 22
- Package manager: npm
- Build command: `npm run build`
- Start command: `npm start`
- Port: leave Hostinger's `PORT` value unchanged (the app defaults to `3000`)

Upload every file in this ZIP into the same Node.js application root. Do not
upload `node_modules`; Hostinger installs dependencies with `npm install`.

## Required environment variables

- `FIREBASE_SERVICE_ACCOUNT`: complete Firebase service-account JSON
- `ONESIGNAL_APP_ID`: OneSignal application ID used by the Flutter app
- `ONESIGNAL_REST_API_KEY`: OneSignal REST API key
- `NOTIFICATION_DISPATCH_SECRET`: a long private value used by protected routes
- `SALES_API_KEY`: Sales Analytics API bearer key

For the optional private Google Sheets test, also set:

- `GOOGLE_SHEETS_SERVICE_ACCOUNT`: complete Google service-account JSON
- `GOOGLE_SHEETS_TEST_SPREADSHEET_ID`: the fixed test spreadsheet ID
- `GOOGLE_SHEETS_TEST_TAB=Employee_Test_Data`: exact test tab name
- `GOOGLE_DRIVE_TEST_FOLDER_ID`: dedicated restricted Drive test folder ID
- `GOOGLE_HR_REPORTS_SPREADSHEET_ID`: blank private workbook used for daily HR reports
- `GOOGLE_WORKSPACE_ALLOWED_ORIGINS`: optional comma-separated web domains
  allowed to call the Google Workspace routes. Firebase Hosting defaults are
  already included; add a custom website domain here when one is used.

This Google credential is different from `FIREBASE_SERVICE_ACCOUNT`. Never put
either credential in Flutter, Git, or a downloadable ZIP. See
`docs/google_sheets_setup.md` for the restricted sharing and smoke-test steps.

## Optional environment variables

- `NOTIFICATION_DISPATCH_BATCH_SIZE=100`
- `NOTIFICATION_DISPATCH_PER_USER_LIMIT=20`
- `NOTIFICATION_DISPATCH_MAX_ATTEMPTS=5`
- `NOTIFICATION_DISPATCH_INTERVAL_MS=300000`
- `NOTIFICATION_FALLBACK_INTERVAL_MS=3600000`
- `SALES_KPI_SYNC_INTERVAL_MS=86400000`
- `FIRESTORE_QUOTA_BACKOFF_MS=3600000`

The KPI interval cannot be lower than six hours. The default is once per day,
which avoids unnecessary Firestore reads.

## Verification

1. Open `https://notification.zawolf.ai/health` and confirm `ok` is `true`.
2. Call `POST https://notification.zawolf.ai/dispatch` with the header
   `Authorization: Bearer <NOTIFICATION_DISPATCH_SECRET>`.
3. Call `POST https://notification.zawolf.ai/sales-kpi/sync` with the same
   header to run a manual KPI synchronization.
4. Confirm `lastPushResult` and `lastSalesKpiResult` in `/health` have no error.

Notification events are created by the app in Firestore. This service listens
to that queue and sends them through OneSignal, so request approvals/rejections,
tasks, KPI events, warnings, suggestions, attendance, account-deletion requests,
and administrative events all use the same delivery path.

## One-time HR role migration

After deploying the unified HR-role release, run the migration first as a
preview and then apply it:

```text
DRY_RUN=true npm run migrate-hr-role
DRY_RUN=false npm run migrate-hr-role
```

It converts stored `hr_manager` users to `hr_admin`. The application and rules
continue accepting the legacy value during the rollout.
