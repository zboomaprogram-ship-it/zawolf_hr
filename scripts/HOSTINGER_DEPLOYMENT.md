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

Upload every file in this ZIP into the same Node.js application root, including
the `workspace/` directory. Do not upload `node_modules`; Hostinger installs
dependencies with `npm install`.

The `workspace/` directory is required by the governed Company Files / Google
Workspace API. Uploading only `notification-web.js` will make `/health` work
but causes Company Files requests to fail with a module-not-found error.

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
- `GOOGLE_HR_REPORTS_SPREADSHEET_ID`: the company-owned master Google Sheet for
  Workspace audit and HR reports. Put this workbook inside `04_التقارير` and
  share it with the service account as **Editor**. Reports are written to named
  tabs in this workbook so they do not consume the service account's zero Drive
  storage quota.
- `GOOGLE_WORKSPACE_ALLOWED_ORIGINS`: optional comma-separated web domains
  allowed to call the Google Workspace routes. Firebase Hosting defaults are
  already included; add a custom website domain here when one is used.

For the governed Company Workspace V2 pilot, also set:

- `GOOGLE_WORKSPACE_ROOT_FOLDER_ID`: the restricted company root-folder ID. This
  is required for **Workspace Audit** and governed HR reports: the server creates
  their Sheets inside `04_التقارير` below this folder.
- `GOOGLE_CONVERSATIONS_FOLDER_ID`: optional existing Drive folder dedicated to
  chat attachments. When omitted, the server creates or reuses
  `05_ملفات_مشتركة/مرفقات_المحادثات` below
  `GOOGLE_WORKSPACE_ROOT_FOLDER_ID` on the first attachment. The resolved folder
  ID is retained server-side in `integrationConfig/conversationAttachmentsDrive`.
  An HR/admin can explicitly initialize it with
  `POST /conversations/attachments/bootstrap`; the authenticated response returns
  the Folder ID for the Hostinger operator.
- `GOOGLE_OPERATIONAL_REQUESTS_FOLDER_ID`: optional existing Drive folder for
  employee request attachments. When omitted, the server creates or reuses
  `05_ملفات_مشتركة/مرفقات_الطلبات` on the first upload. The app receives only
  opaque attachment ids; Drive file ids remain server-side.

After setting `GOOGLE_WORKSPACE_ROOT_FOLDER_ID`, open that Google Drive folder
and share it with the exact `client_email` inside Hostinger's
`GOOGLE_SHEETS_SERVICE_ACCOUNT` JSON as **Editor**. Do not assume it is the
same account used in another environment. That permission is required not only
for the folder itself, but also to create the `04_التقارير` child folder and the
report Sheets. For a Google Shared Drive, grant that exact account **Content
manager** (or a higher appropriate role) at the Shared Drive level. A configured
environment variable without that Drive share will correctly return a safe
permission error.

Keep the V2 Flutter feature switch disabled until a named pilot user and the
test folder have completed the acceptance checklist. Deploying this package
does not enable the new route for everyone.

## Company OS production configuration

The approved Company OS surfaces are enabled by default in the production
package. Server-side role and capability checks still apply to every action.
`COMPANY_OS_FEATURE_FLAGS_JSON` is optional and is used to narrow or disable a
slice as an immediate rollback control.

```json
{
  "company_os_portal_v1": {"enabled": true, "everyone": true},
  "company_os_it_v1": {"enabled": true, "everyone": true},
  "company_os_requests_v1": {"enabled": true, "everyone": true},
  "company_os_operations_v1": {"enabled": true, "everyone": true},
  "company_os_organization_v1": {"enabled": true, "everyone": true},
  "company_os_multi_tree_v1": {"enabled": true, "everyone": true}
}
```

Save the environment variable and restart the Node application. To roll back
without data loss, restore `{}` and restart; the established legacy routes stay
available.

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
- `PHASE007_FEATURE_FLAGS_JSON={}` (all Phase 007 slices disabled)
- `COMPANY_OS_FEATURE_FLAGS_JSON={}` (optional Company OS rollback/override;
  all approved Company OS slices are enabled by the production defaults)

## Company OS scheduler ownership and recovery

Company OS portal, IT, request, dashboard, report, export, and audit operations
are request-driven. They own no background scheduler. The existing notification
dispatcher remains the single notification scheduler; do not enable a second
Company OS dispatcher.

Manual recovery is owned by the Super Admin with engineering support: disable
the affected `company_os_*` flag, verify `/health`, restart the Hostinger Node
application if needed, and use the retained legacy route. Replaying a mutation
must reuse its original operation ID. Read-only reports may be regenerated.

## Phase 007 pilot and rollback

The server is the rollout authority. Keep every slice disabled initially. A
named pilot uses a Firebase UID, never an employee code or email:

```json
{
  "diagnostics_v2": {
    "enabled": true,
    "everyone": false,
    "actorIds": ["FIREBASE_UID_OF_PILOT"]
  }
}
```

Add one slice at a time to `PHASE007_FEATURE_FLAGS_JSON`, save the environment,
restart the Node application, and sign in again or refresh the app token. To
roll back immediately set that slice's `enabled` to `false` (or restore `{}`),
restart Node, and refresh the client. The Flutter client fails closed if the
registry cannot be authenticated or fetched, so legacy screens remain the
fallback. Do not set `everyone: true` before owner-reviewed pilot evidence.

The KPI interval cannot be lower than six hours. The default is once per day,
which avoids unnecessary Firestore reads.

## Verification

1. Open `https://notification.zawolf.ai/health` and confirm `ok` is `true`.
2. Call `POST https://notification.zawolf.ai/dispatch` with the header
   `Authorization: Bearer <NOTIFICATION_DISPATCH_SECRET>`.
3. Call `POST https://notification.zawolf.ai/sales-kpi/sync` with the same
   header to run a manual KPI synchronization.
4. Confirm `lastPushResult` and `lastSalesKpiResult` in `/health` have no error.
5. Confirm `diagnostics.workspace.lastFailureCode` is `null`, then open a
   permitted Company Files resource from the pilot account.

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
