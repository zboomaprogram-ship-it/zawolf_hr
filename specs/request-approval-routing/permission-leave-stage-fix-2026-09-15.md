# Permission and leave approval-stage correction

## Incident evidence (read-only production audit)

- Permission `7mcq26P0w11gFiS1nQAn` for `BD-1204` listed two assigned managers (`BD-1200`, then `BD-1213`). Both manager-stage trail entries were written by `COO-1300`, who was not in the route.
- Permission `VdWwg4S108kw35idCxtX` for `KM-1407` listed `COO-1300` as its manager, but `CEO-100` wrote its manager-stage approval. The active employee profile currently says Programming while the account directory lists Kitchen Marketing. The correct department and supervisor need an HR data check; this change does not guess or rewrite them.
- The installed client accepts any `managerIds` member or executive in its decision precheck. The former Firestore update rule accepted any current-or-listed manager or HR user through an unrestricted fallback. This allowed the wrong actor to advance a stage, including the same actor twice.
- A read-only audit found 5 pending permissions and 2 pending leaves. None had duplicate manager IDs or a mismatched current stage. One pending permission (`wCplWHu10rwqodr1XXwh`, `MKT-605`) has a stored route that differs from the employee's current manager profile. It may reflect an assignment change after submission; HR must confirm the intended approver before any route amendment.

## Rule correction

- Only the manager ID at `managerApprovalIndex` may approve or reject that manager stage. A Super Admin can act there only when explicitly assigned to that stage.
- The actor who just reviewed a manager/CEO stage cannot immediately approve the following HR stage as a second role.
- The saved `managerId` must match the indexed manager; a route containing the same manager ID more than once cannot be advanced.
- Permission and leave updates use their scoped review predicates; the broad HR/manager update fallback is removed. Legitimate HR reviews, CEO leave escalation, cancellation, and approved early-leave policy snapshots remain allowed.
- Historical approved decisions and audit history remain unchanged. Correcting a misassigned employee supervisor is an independent HR directory action.

## Verification and production rollback

- Run the Firebase rules emulator scenarios for wrong Super Admin, next-stage manager, assigned first manager, repeat first manager, assigned second manager, and HR final review.
- The currently deployed production ruleset was saved at `/tmp/zawolf-firestore-rules-rollback-2026-09-15.rules` and matched `HEAD:firestore.rules` exactly (SHA-256 `9cd26ab860327459c388cceff014c3c2de823da76f88b7f4a875e65ccde853f9`). Recheck this immediately before deployment. Deploy only `firestore:rules` after owner approval. Watch denied-write and approval-stage logs, plus a known valid permission and leave canary.
- If valid approvals fail, restore the saved ruleset with `firebase deploy --only firestore:rules` from the rollback copy, or use the exact `HEAD:firestore.rules` Git revision recorded above. Do not rewrite request records; retain their audit history.
