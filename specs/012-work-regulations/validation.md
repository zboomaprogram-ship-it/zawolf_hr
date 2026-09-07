# Work Regulations Validation Record

## Automated evidence — completed

- Flutter unit tests cover the late-arrival start-time/check-in boundary, advance eligibility boundaries, leave validation, and annual quota tiers.
- Node tests cover completed-service and age thresholds plus protection against renewing a current or probation entitlement period.
- `flutter analyze`, architecture/query guards, the full Flutter suite, and the complete Node suite pass.
- `flutter build web --release` completed successfully on 2026-09-07.

## Device and account acceptance — requires a non-production account

The local environment has Chrome and macOS available, plus shutdown iOS simulators. `flutter doctor -v` reports Xcode 14.2 while the installed Flutter version requires Xcode 15 or newer, so Flutter cannot discover the available iOS simulators. The Android SDK is installed but no Android emulator/device is available. There is also no authenticated non-production employee, manager, HR, or CEO account. Do not run the following against production:

1. Submit late-arrival permission at one minute before and exactly at scheduled start, then submit after a recorded check-in.
2. Submit salary advances at 89/90 days, on days 14/15, and at 50%/over-50% salary.
3. Submit casual, exam (with proof), birth, and sick-to-annual leave requests; verify balances and manager display.
4. Verify Arabic RTL on iOS, Android, and web, including Cairo midnight and entitlement anniversary boundaries.
5. Replay approval/retry flows and verify that each balance change occurs once.
