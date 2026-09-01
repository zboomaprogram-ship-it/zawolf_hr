# Google Play location-policy resubmission

## Public privacy-policy URL

Use this exact active HTTPS URL in Play Console:

`https://zawolf-hr-system-60317.web.app/privacy.html`

The policy now explicitly discloses precise location, manual attendance,
employee-opted-in automatic attendance while the app is closed or not in use,
the work-site geofence purpose, opt-out, no route tracking/advertising, sharing,
retention, and privacy contact details.

## App content / Data safety

Complete these declarations from the exact production release, not from a
generic template:

- Location: declare **Precise location** and **Approximate location** as
  collected because the Android manifest requests both fine and coarse location.
- State that location is used for app functionality (attendance at an assigned
  work site) and security/fraud prevention; it is not sold or used for ads.
- Mark data as shared only where it is actually transmitted to a third party in
  production. Review each enabled SDK and integration before answering.
- Use the same policy URL in the Store Listing and ensure the in-app policy
  continues to contain equivalent disclosure.

## Background location declaration

The current Android manifest includes `ACCESS_BACKGROUND_LOCATION` to support
the optional automatic-attendance geofence. In Play Console, complete the
Location permissions declaration and provide a short Android-device video that
shows, in order:

1. Profile → **Automatic attendance by location**.
2. The in-app disclosure dialog.
3. The Android system location permission flow.
4. Enabling the feature and a resulting entry/exit attendance event while the
   app is not in use.

Suggested declaration text:

> ZaWolf HR is an employee HR application. An employee can optionally enable
> automatic attendance for their assigned workplace. After explicit opt-in and
> Android permission, the app uses background location only to monitor the
> assigned work-site geofence and create an entry or exit attendance event. It
> does not record travel routes, sell location data, or use location for
> advertising. Employees can turn the feature off at any time in Profile; manual
> attendance and all non-attendance features work without location permission.

Ensure the Store Listing description also identifies automatic work-site
attendance as a feature. Google assesses whether background location is a core,
user-beneficial feature and can require its removal if the same experience can
be delivered in the foreground.

## References

- https://support.google.com/googleplay/android-developer/answer/9859455
- https://support.google.com/googleplay/android-developer/answer/9799150
