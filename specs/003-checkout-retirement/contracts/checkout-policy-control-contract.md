# Contract: Check-out Policy Control

## Read policy

`GET /attendance/checkout-policy`

```json
{
  "policy": {
    "enabled": false,
    "revision": 0,
    "effectiveAt": null
  },
  "canManage": false
}
```

Unavailable/missing configuration resolves to `enabled: false`, not an
employee-facing technical failure.

## Change policy

`POST /attendance/checkout-policy`

Authorized normal HR or super-admin only.

```json
{
  "enabled": true,
  "reason": "تشغيل تسجيل الانصراف للوردية المسائية",
  "expectedRevision": 4
}
```

Success returns the committed policy/revision. A conflict returns safe
`policy_conflict` guidance so the UI reloads. Unauthorized callers receive
`not_authorized` without configuration internals.

## Check-out while disabled

```json
{
  "action": "check_out",
  "status": "checkout_disabled",
  "attendanceId": "<caller>_YYYY-MM-DD",
  "messageAr": "تسجيل الانصراف غير مفعّل حالياً. تم حفظ حضورك ولا يلزم إجراء إضافي.",
  "policy": { "enabled": false, "revision": 5 }
}
```

No attendance, device-binding, deduction, payroll, approval, reminder, or
notification mutation is permitted for this outcome.

## Worker result

Every worker that could create check-out work evaluates the shared policy. When
disabled it returns a suppressed result, e.g.:

```json
{ "suppressed": true, "reason": "checkout_policy_disabled", "revision": 5 }
```

It must not queue retry work that later becomes a historic deduction.
