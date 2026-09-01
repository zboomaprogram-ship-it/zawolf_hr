# ZaWolf HR iOS App Store submission handoff

This is a release checklist, not a guarantee of App Store approval. Apple makes
the final decision after reviewing the exact uploaded build.

## Repository configuration

- Bundle identifier: `com.zbooma.zawolfhr`.
- `GoogleService-Info.plist` uses the same bundle identifier.
- `Info.plist` has purpose strings for camera, photos, Face ID, foreground
  attendance location, and optional automatic attendance.
- Automatic attendance is off by default. The `location` background mode is
  used only after the employee enables work-site boundary monitoring and grants
  iOS **Always** location permission. Turning the feature off stops monitoring.
- `ios/Runner/PrivacyInfo.xcprivacy` is included in the Runner target. It
  declares the app-owned UserDefaults required-reason use (`CA92.1`) and no
  tracking.
- Jailbreak-app URL queries are retained only because the attendance-security
  package uses them to reject compromised devices before an attendance action.

## Before archive and upload

1. Use **Xcode 26 or later** with the **iOS 26 SDK or later** for an App Store
   upload submitted from 28 April 2026 onward.
2. Set the `pubspec.yaml` build number above the last App Store Connect upload;
   App Store Connect never accepts a reused build number.
3. Open `ios/Runner.xcworkspace`, choose the Release scheme, confirm the
   signing team, distribution certificate, provisioning profile, and bundle ID,
   then Archive and Validate in Xcode.
4. Upload to TestFlight first and test sign-in, attendance, automatic-attendance
   opt-in/opt-out, notifications, requests, Drive attachments, and chat on a
   real iPhone.

## App Store Connect tasks

- Publish a public HTTPS privacy-policy URL and use that same URL in App Store
  Connect and in the app.
- Complete App Privacy with the exact production behavior: account/contact and
  employee data, attendance location, device identifiers, uploaded documents or
  photos, diagnostics, Firebase, OneSignal, and Google Drive when enabled.
- Supply an active reviewer account, test employee/site, and review instructions
  for role-protected features. The reviewer must not wait for an internal
  approval.
- The product is for existing employer-managed employee accounts. State this
  only if that remains the real access model when relying on the business-account
  exception to Sign in with Apple.

## Suggested Apple review note

> ZaWolf HR is an internal HR app for authenticated employees. Precise location
> verifies attendance at an assigned workplace. Manual check-in/check-out works
> while the app is open. Automatic attendance is optional, off by default,
> clearly explained, and requires the employee to grant Always Location. It
> monitors assigned workplace region boundaries only to register entry or exit
> events; it does not record routes or continuously track travel. The employee
> can disable it at any time from Profile. Denying location does not block login,
> requests, tasks, profile, reports, or chat. The attendance alarm and push
> notifications are optional user-facing HR reminders.

Provide the path `Login -> Home -> Attendance` and
`Login -> Profile -> Automatic attendance`, the test work-site address, and the
privacy-policy URL.

## Chat release gate

Department chat is user-generated content. Before submission, verify the
shipped app provides content moderation, reporting, a way to block or mute
abusive users, and published support contact information. Restricted employee
membership alone does not replace these safeguards.

## Apple references

- https://developer.apple.com/app-store/review/guidelines/
- https://developer.apple.com/news/upcoming-requirements/?id=02032026a
- https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
