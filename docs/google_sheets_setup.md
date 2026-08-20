# Google Sheets integration

ZaWolf HR accesses private company spreadsheets through the Hostinger backend.
The Flutter app never receives the Google service-account JSON or the original
Sheet URL, and employees do not need direct Google Drive access.

## مركز ملفات الشركة (النشر مرة واحدة)

بعد رفع حزمة Hostinger المرفقة، لا تضف متغير بيئة لكل Sheet أو مجلد. من
داخل النظام افتح **مركز ملفات الشركة** ثم أضف المصدر ومعرّف Google الخاص به.
المعرّف يُحفظ في `workspaceResourceSecrets` ولا يظهر للموظفين.

1. مسؤول النظام فقط يضيف Sheet أو مجلد Drive ويختار القسم والمديرين وتبويب
   الـSheet و`Schema Profile`.
2. المدير يمنح أفراد فريقه: عرض، تنزيل، أو تعديل.
3. الموظف لا يصل إلا للمصادر التي لها `workspaceAccessGrant` فعال باسمه.
4. كل عرض أو تعديل من الموصل يسجل في `workspaceAuditLogs`.

الموصل يقرأ المصدر بالمعرّف المحفوظ في Firestore بعد التحقق من Firebase ID
token وصلاحية المستخدم؛ لا تُرسل مفاتيح Google أو معرّفات المصدر إلى التطبيق.
يستخدم الموصل نفس متغير `GOOGLE_SHEETS_SERVICE_ACCOUNT` الموجود في إعداد
الاختبار، ويجب مشاركة كل Sheet أو مجلد مع بريد حساب الخدمة بصلاحية مناسبة.

المسارات الجديدة التي تعمل بعد النشر:

```text
GET   /company-workspace/resources/:resourceId/sheet
PATCH /company-workspace/resources/:resourceId/sheet/rows/:rowNumber
GET   /company-workspace/resources/:resourceId/files
```

## Test workbook

- Spreadsheet ID: `1h3eNfVdY5wTHszPN0w0gPNI-BGGauoGWSSal4fLnwIM`
- Default tab: `Employee_Test_Data`
- Service account: `zawolf-sheets@zawolf-hr-system-60317.iam.gserviceaccount.com`
- Drive test folder: create a dedicated restricted folder and use its ID below
- Required headers: `record_id`, `employee_id`, `employee_name`, `department`,
  `task_name`, `status`, `amount`, `notes`, `updated_at`

Keep **General access** set to **Restricted**. Share this workbook only with the
service-account email as **Editor**. If the actual tab has another name, use
that exact name in `GOOGLE_SHEETS_TEST_TAB`.

## Google Cloud setup

1. In project `zawolf-hr-system-60317`, enable **Google Sheets API** and
   **Google Drive API**.
2. Open **IAM & Admin > Service Accounts > zawolf-sheets > Keys**.
3. Create a JSON key and download it once.
4. Never upload the JSON to Git, Flutter assets, Firebase Hosting, or the app.
   Never paste it into chat.
5. After the first test, rotate/delete any key that was exposed elsewhere.

Create a new Drive folder named `ZaWolf HR Integration Test`, share that folder
with the service account as **Editor**, and copy its folder ID from the URL:
`https://drive.google.com/drive/folders/FOLDER_ID`. Only this test folder is
used by the test endpoint.

## Hostinger environment variables

Add these to the Node.js application settings and redeploy:

```text
GOOGLE_SHEETS_SERVICE_ACCOUNT={the complete downloaded JSON on one line}
GOOGLE_SHEETS_TEST_SPREADSHEET_ID=1h3eNfVdY5wTHszPN0w0gPNI-BGGauoGWSSal4fLnwIM
GOOGLE_SHEETS_TEST_TAB=Employee_Test_Data
GOOGLE_DRIVE_TEST_FOLDER_ID=your_restricted_test_folder_id
GOOGLE_HR_REPORTS_SPREADSHEET_ID=your_private_hr_reports_workbook_id
GOOGLE_WORKSPACE_ALLOWED_ORIGINS=https://your-custom-app-domain.example
GOOGLE_WORKSPACE_ROOT_FOLDER_ID=the_company_root_folder_id
```

`GOOGLE_SHEETS_SERVICE_ACCOUNT` is a separate Google key. Do not replace the
existing `FIREBASE_SERVICE_ACCOUNT` value.

`GOOGLE_WORKSPACE_ROOT_FOLDER_ID` is the only new value required for automatic
discovery. Share that one root folder with the service account as **Editor**.
Then the system administrator selects **مزامنة ملفات Google** inside مركز
ملفات الشركة; the connector discovers up to 1,500 nested folders, Sheets and
files automatically. It never moves, deletes or changes Google sharing.

The `/health` response then shows:

```json
{"googleSheets":{"configured":true}}
```

It reports configuration presence only and never returns credentials.

For daily HR reports, the Google owner creates one private workbook named
`ZaWolf HR Daily Reports`, shares it with the service account as **Editor**, and
shares it with the company's HR Google accounts as **Viewer** or **Editor**.
Copy only the workbook ID into `GOOGLE_HR_REPORTS_SPREADSHEET_ID`. ZaWolf creates
or refreshes a tab named `Daily_YYYY-MM-DD` whenever HR selects a day and taps
the report button. No CSV download is involved.

The Drive test routes are:

```text
GET  /google-drive/test/files
GET  /google-drive/test/files/:fileId/content
POST /google-drive/test/file
```

The content route proxies a file only after confirming that its parent is the
configured restricted folder. Downloads are limited to 20 MB. Native Google
Sheets are exported as `.xlsx`; Google Docs and Slides are exported as PDF.
The browser never receives the service-account key or a public Drive link.

The POST route creates a small metadata-only text file in the restricted test
folder. It does not upload employee data. Delete that test file manually after
confirming it appears in Drive.

## Safe smoke test

The test routes accept the existing `NOTIFICATION_DISPATCH_SECRET` for a manual
Hostinger check. HR/admin requests from the future app use a Firebase ID token.

Read all test rows:

```bash
curl -H "Authorization: Bearer YOUR_NOTIFICATION_DISPATCH_SECRET" \
  "https://YOUR-HOSTINGER-APP-DOMAIN/google-sheets/test/rows"
```

Update only `TEST-001` status and notes:

```bash
curl -X PATCH \
  -H "Authorization: Bearer YOUR_NOTIFICATION_DISPATCH_SECRET" \
  -H "Content-Type: application/json" \
  -d '{"status":"completed","notes":"ZaWolf API test"}' \
  "https://YOUR-HOSTINGER-APP-DOMAIN/google-sheets/test/rows/TEST-001"
```

The test API deliberately prevents changing employee identity columns, rejects
unknown fields/formula-like input, limits body size, caches reads for 30 seconds,
and addresses updates by unique `record_id`. Allowed statuses are `pending`,
`in_progress`, and `completed`.

## Test Drive at the same time

List the files in the restricted test folder:

```bash
curl -H "Authorization: Bearer YOUR_NOTIFICATION_DISPATCH_SECRET" \
  "https://YOUR-HOSTINGER-APP-DOMAIN/google-drive/test/files"
```

Create one harmless test file:

```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_NOTIFICATION_DISPATCH_SECRET" \
  -H "Content-Type: application/json" \
  -d '{"name":"ZaWolf HR Drive API Test.txt","contents":"connection test"}' \
  "https://YOUR-HOSTINGER-APP-DOMAIN/google-drive/test/file"
```

The file should appear inside the shared test folder. This confirms Drive
authentication and write permission; it does not grant employees access.

## Production design for many employee sheets

Do not give every employee a different spreadsheet credential. Store an HR-only
mapping of `employeeId -> spreadsheetId/tab/header profile` in Firestore or the
backend database. The backend verifies the signed-in employee, selects only that
mapping, reads/writes only permitted columns, and returns a normalized response.
Managers and HR can receive broader access according to their application role.

For Drive, use one restricted shared folder and share it with the service
account. Store Drive file IDs, not public links. Add an audit record for every
write (`userId`, file ID, record ID, changed fields, and timestamp). Google
Sheets remains the source of truth during the pilot; add conflict/version checks
before allowing several users to edit the same row concurrently.
