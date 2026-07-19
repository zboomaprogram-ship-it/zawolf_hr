# Zawolf HR

Flutter/Firebase HR attendance app with Arabic RTL UI, role-based access,
geofenced attendance, biometric/device credential checks, HR approvals, reports,
notifications, suggestions, and manual company day-off controls.

## Run

```bash
flutter pub get
flutter run
```

## HR Web Portal

The same Firebase project now supports an optimized desktop web portal for
manager, HR, and super-admin accounts. The browser layout uses a persistent
role-based sidebar and keeps employee self-service views out of the management
navigation.

```bash
flutter run -d chrome
flutter build web --release
firebase deploy --only hosting --project zawolf-hr-system-60317
```

The production hosting target is:
`https://zawolf-hr-system-60317.web.app`.

Employees can technically authenticate on the web, but the desktop management
shell is intentionally enabled only for manager, HR, and super-admin roles.

## Payroll Cycle

ZaWolf uses a company cycle from day `26` through day `25`, not a calendar
month. The cycle key is the month in which the cycle ends. For example,
`2026-08` covers `2026-07-26` through `2026-08-25`.

At the start of day 26 in Cairo, `.github/workflows/monthly-tasks.yml`:

- finalizes a `payrollCycles/{YYYY-MM}` summary;
- creates draft payroll rows for the closed cycle;
- records pending HR deductions and pending permissions in the close summary;
- resets each active user's used permission hours/count for the new cycle;
- leaves payroll as `draft` so HR can review it before locking or payment.

The job is idempotent and will not close the same cycle twice. For a controlled
manual recovery, run the workflow with a `cycle_key` such as `2026-08` and set
`force` to true. Do not force-close an active cycle during normal operation.

## Verify

```bash
flutter analyze
flutter test
firebase deploy --only firestore:rules --dry-run
```

## Docs

- Arabic user manual for employee, manager, HR, and super admin:
  `docs/user_manual_ar.md`
- Full Arabic audit and role behavior report:
  `docs/app_audit_report_ar.md`
- Google Sheets setup notes: `docs/google_sheets_setup.md`
- Role and permission reference: `docs/roles_permissions.md`

## Admin Bootstrap

Use application default Firebase credentials, then provide admin credentials via
environment variables. Do not commit real passwords.

```bash
ADMIN_EMAIL="admin@example.com" \
ADMIN_PASSWORD="replace-with-strong-password" \
ADMIN_ROLE="super_admin" \
ADMIN_DISPLAY_NAME="Super Admin" \
node scripts/create_admin.js
```

## Notifications Without Cloud Functions

The app uses Firestore notification documents, local notifications, and optional
OneSignal push:

- App open/logged in: realtime Firestore listener shows local notification
  banners.
- App in background: Android background polling checks unread Firestore
  notifications about every 15 minutes when the OS allows it.
- App fully killed/offline: OneSignal can deliver push notifications if the app
  was built with `ONESIGNAL_APP_ID` and the user has logged in at least once.

This is still a no-Cloud-Functions setup. Hostinger sends scheduled push
notifications through OneSignal for daily HR tasks. Instant push for every
in-app event still needs a trusted sender to call the OneSignal REST API at the
moment the event happens.

Build the app with:

```bash
flutter build ipa --release --dart-define=ONESIGNAL_APP_ID=your-onesignal-app-id
```

GitHub repository secrets for scheduled OneSignal pushes:

```text
FIREBASE_SERVICE_ACCOUNT
ONESIGNAL_APP_ID
ONESIGNAL_REST_API_KEY
```

Notification documents are written under:

```text
notifications/{userId}/items/{notificationId}
```

Each item should include:

```json
{
  "notificationId": "generated-id",
  "type": "permission_pending_hr",
  "title": "عنوان التنبيه",
  "body": "نص التنبيه",
  "data": {},
  "isRead": false,
  "createdAt": "serverTimestamp"
}
```

## GitHub Actions Automation

Cloud Functions are not required for the current scheduled HR tasks. GitHub
Actions runs the Node scripts in `scripts/` using Firebase Admin SDK:

- `.github/workflows/daily-tasks.yml`: runs daily at 11:55 PM Egypt time to
  mark absences, auto-close missed checkouts, mark overdue tasks, and create HR
  review notifications.
- `.github/workflows/monthly-tasks.yml`: handles both Cairo UTC offsets and
  closes the 26-to-25 cycle only when the Cairo date is day `26`.
- `.github/workflows/attendance-reminders.yml`: runs every five minutes,
  creates policy-aware check-in/check-out reminders, then dispatches them.

Create one GitHub repository secret:

```text
FIREBASE_SERVICE_ACCOUNT
```

Its value must be the full Firebase service-account JSON for the project. Keep
repo access tight and rotate the key immediately if it is ever exposed.

## V2 Productivity Core

The first V2 module is task management:

- Employees can view their assigned tasks and update status.
- Managers can assign tasks to their direct team and review completed work.
- HR/super admin can manage task assignments across the company.
- The daily GitHub Action marks overdue tasks as `late`.

Task notifications are stored in Firestore like the rest of the app
notifications. If OneSignal push is enabled for production, use these same
notification documents/events as the source for the OneSignal sender.

## Production Checklist

- Deploy `firestore.rules` and `firestore.indexes.json` after review.
- Firebase App Check was removed from the client by request. App Check
  enforcement must also be turned off in Firebase Console or protected
  products will reject the app.
- Restrict Firebase and Google Maps API keys by bundle ID/package name/SHA.
- Replace any shared fixed passwords after first login and enforce password
  reset/change flows for real users.
- Test notifications on real Android/iOS devices, especially Android 13+
  permission prompts and iOS permission prompts.
- Test attendance on real devices with GPS, biometrics, offline mode, and
  background notification polling.
- Configure Android signing, iOS certificates/profiles, app icons, splash,
  privacy labels, and store metadata.
- Confirm HR policy text, salary deduction formulas, official holidays, and
  report exports with the company owner before first payroll use.
