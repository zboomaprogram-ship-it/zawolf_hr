# Zawolf HR

Flutter/Firebase HR attendance app with Arabic RTL UI, role-based access,
geofenced attendance, biometric/device credential checks, HR approvals, reports,
notifications, suggestions, and manual company day-off controls.

## Run

```bash
flutter pub get
flutter run
```

## Verify

```bash
flutter analyze
flutter test
firebase deploy --only firestore:rules --dry-run
```

## Docs

- Arabic user manual for employee, manager, HR, and super admin:
  `docs/user_manual_ar.md`
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

This is still a no-Cloud-Functions setup. GitHub Actions sends scheduled push
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
- `.github/workflows/monthly-tasks.yml`: runs at 12:05 AM Egypt time and the
  script only resets permission balances when the Cairo date is day `01`.

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
