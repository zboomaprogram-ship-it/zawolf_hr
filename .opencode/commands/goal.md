---
description: Set a goal and have the agent plan, track, and execute it against repo rules
---
# Goal

Work toward this goal until it is done or blocked:

**$ARGUMENTS**

## Procedure

1. **Clarify**: If the goal is ambiguous, ask up to 3 targeted questions before
   starting. Otherwise proceed.
2. **Plan**: Break the goal into small, independently verifiable steps using the
   todo list tool. Order them by dependency.
3. **Execute**: Work through steps one at a time.
   - Follow AGENTS.md rules (feature structure, Cubit limits, characterization
     tests for payroll/attendance changes).
   - Keep the app deployable after each step; no unrelated reorganization.
4. **Verify**: After each step run the relevant subset of:
   - `flutter analyze`
   - `flutter test test/architecture_guard_test.dart test/firestore_query_guard_test.dart`
   - `flutter test`
   - `(cd scripts && npm test)`
5. **Report**: Summarize what was completed, what remains, and any blockers.

Do not commit unless explicitly asked. Stop for review if an irreversible
operation (Firestore rules, destructive migration, git history rewrite) is
required.
