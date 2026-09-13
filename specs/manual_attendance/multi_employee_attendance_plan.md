# Plan — Multi-employee manual attendance

1. Characterize the existing single-record operation and add a failing batch contract test.
2. Add a bounded batch server operation that delegates each employee to the existing idempotent record path using derived operation IDs.
3. Add repository batch models/results and a Cubit batch submit method without placing transport logic in presentation.
4. Replace single selection in the existing screen with checkbox selection, batch confirmation, and partial-result display while retaining safe state refresh.
5. Run attendance, Node, Flutter, and architecture/query guard checks.
