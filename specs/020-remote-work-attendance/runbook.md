# Feature 020: Remote Work Attendance — Pilot Operations & Rollback Runbook

**Feature**: `020-remote-work-attendance`  
**Pilot Target**: 10–20 Qualified Employees  
**Authentication Profile**: `hr_approved_passkey` (Personal Computer with WebAuthn/Passkey bound by HR)  
**Location Requirement**: Explicitly None (GPS and hardware-binding dongles disabled)  
**Governing Documents**: `specs/020-remote-work-attendance/spec.md`, `specs/020-remote-work-attendance/plan.md`

---

## 1. Pilot Activation Checklist

### Step 1: Pre-requisites & Verification
1. Ensure all test suites pass:
   ```bash
   flutter test test/architecture_guard_test.dart test/firestore_query_guard_test.dart
   flutter test test/features/remote_work/
   (cd scripts && npm test)
   ```
2. Verify Hostinger worker is running `scripts/notification-web.js` with background scheduler enabled.
3. Verify that the production Firestore ruleset remains intact and unmodified until owner sign-off.

### Step 2: Employee Qualification & Enrollment
1. For each pilot employee:
   - HR logs into **إدارة الموظفين** (`/hr/employees`).
   - Registers the employee's personal computer passkey credential into `remoteWorkCredentials/{credentialId}` with status `active` and proof profile `hr_approved_passkey`.
   - Adds the employee to an active remote schedule (e.g. 1 or 2 days/week) via **سياسة الدوام** (`/hr/attendance-policy`).
2. Verify that the employee's schedule record in `remoteWorkSchedules/{companyId}_{employeeId}` reflects the approved days.

### Step 3: Shift Check-in & Monitoring
1. On the designated remote work day, the employee navigates to **العمل عن بعد** (`/employee/remote-attendance`).
2. The system checks eligibility:
   - Validates weekday matches approved schedule.
   - Verifies no conflicting approved full-day leaves.
   - Verifies day mode is not already locked to `office`.
3. Employee presses **تسجيل الحضور بالمفتاح الرقمي (Passkey)**.
4. Passkey ceremony completes, returning the challenge signature to `/attendance/remote-work/commands`.
5. Server creates atomic attendance row (`attendance/{id}` with `source: 'remote_work'`, `mode: 'remote'`) and linked session (`remoteWorkSessions/{id}`).

---

## 2. Day-to-Day Operations & Edge Cases

### Case A: Mid-Day Network Disconnection or Device Crash
- **Behavior**: Check-in is already locked to `mode: 'remote'`.
- **Action**: When device recovers, employee returns to `/employee/remote-attendance`.
- The active session is restored; checkout remains available. No penalty is applied for offline periods between checkpoints.

### Case B: Forgotten Check-out
- **Behavior**: Hostinger night cron calls `finalizeRemoteShift` at cycle cutoff.
- **Action**: Session is marked `missing_checkout_finalized`. An automated incident is logged with status `pending_review` for HR review. No direct salary deduction occurs without HR approval.

### Case C: Employee Must Report to Office After Remote Check-in
- **Behavior**: Day mode is locked to `remote`. Physical fingerprint or office GPS check-in will be rejected with `DAY_MODE_LOCKED_REMOTE`.
- **Action**: If emergency office presence is required, HR uses **تسجيل حضور يدوي** (`/hr/manual-attendance`) or Remote Work Recovery (`correctRemoteDay`) to adjust the record with an audit reason.

---

## 3. Incident Management & Recovery Procedures

### Incident Declaration:
- When security anomaly or passkey misuse is suspected:
  ```bash
  POST /attendance/remote-work/commands
  {
    "command": {
      "kind": "declare_incident",
      "companyId": "...",
      "employeeId": "...",
      "dateKey": "YYYY-MM-DD",
      "reason": "Suspected passkey misuse",
      "holdFinancial": true
    }
  }
  ```
- **Effect**: Halts active session, locks further remote commands for that employee on that day, and places a financial hold on the attendance record until HR reviews it.

### Financial Hold Resolution:
- HR navigates to the attendance correction screen, reviews supervisor notes and work output, and executes:
  ```bash
  POST /attendance/remote-work/commands
  {
    "command": {
      "kind": "resolve_financial_hold",
      "companyId": "...",
      "holdId": "...",
      "resolution": "approved_full_day" | "deduct_partial" | "convert_unpaid",
      "approvedBy": "HR_ADMIN_UID",
      "notes": "Reviewed and verified"
    }
  }
  ```

---

## 4. Emergency Rollback Plan

If an unexpected production defect occurs during the pilot:

### Level 1: Disable Remote Work for Specific Employee
1. Navigate to **سياسة الدوام** (`/hr/attendance-policy`).
2. Set employee allowance to `0` or deactivate schedule.
3. Existing office attendance remains 100% unaffected.

### Level 2: Pause Entire Pilot Company-Wide
1. In `scripts/notification-web.js` or via company policy setting, set `remoteWork.enabled = false`.
2. Existing remote sessions for that day complete normally.
3. Next check-in requests fail closed with Arabic message: `العمل عن بعد غير مفعل حالياً للشركة`.
4. No mobile apps or desktop builds need to be rolled back.

### Level 3: Code Rollback (Git Handoff)
- All remote work additions are isolated behind Strangler Fig vertical slices (`lib/features/remote_work/` and `scripts/remote-work/`).
- If full revert is required, revert the feature commit on `main`. The legacy attendance codebase in `lib/services/attendance_service.dart` and `scripts/attendance-gateway.js` was never deleted and will operate in standalone mode.
