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

The app uses Firestore notification documents plus local notifications:

- App open/logged in: realtime Firestore listener shows local notification
  banners.
- App in background: Android background polling checks unread Firestore
  notifications about every 15 minutes when the OS allows it.
- App fully killed/offline: notifications may wait until the app opens again.

This is the best no-server/no-Cloud-Functions setup. True instant push while the
app is killed requires a trusted sender such as Cloud Functions, your own backend,
or manual Firebase Console campaigns.

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
