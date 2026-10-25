# Implementation Plan: Dynamic Requests Engine & Configurable Forms

**Feature**: `019-dynamic-requests-engine`
**Branch**: `main` (Strangler Fig migration beside existing slices)
**Status**: Ready for Owner Review

---

## 1. Architecture Alignment & Boundaries

Following the project constitution (`.specify/memory/constitution.md`) and engineering rules (`AGENTS.md`):
- **Domain**: Contracts for templates, custom fields, dynamic validation, and approval transitions live under `lib/features/request_approval_routing/domain/` and `lib/features/configurable_requests/domain/`. No Flutter, Firebase, or UI imports.
- **Data**: Firestore repository implementations under `data/`. Maps snapshot fields, enforces canonical conversions without mutating legacy collections.
- **Presentation**: Focused Cubits (< 300 lines) under `presentation/`. `employee_requests.dart` consumes domain abstractions to render dynamic form sections.
- **Strangler Fig Strategy**:
  - The live request collections (`leaves`, `permissions`, `customRequests`) remain active.
  - No database migration script will touch or alter existing request records.
  - New submissions store a snapshot of the template configuration (`subtypeConfigSnapshot`, `approvalChainSnapshot`, `fieldValues`) directly in the request document.

---

## 2. Technical Design

```
+-------------------------------------------------------------+
|                     HR Web Dashboard                        |
|   /hr/approval-chains-settings (ApprovalChainsSettingsPage)  |
|   - Add/Edit Request Types                                  |
|   - Subtypes (Quota Key, Deductible, Attachments, Limits)   |
|   - Custom Form Fields (Text, Number, Date, Select, File)   |
|   - Approval Chain Steps (1-4 Steps, Condition Thresholds)  |
+------------------------------+------------------------------+
                               |
                               v (Firestore: customRequestTypes)
+-------------------------------------------------------------+
|             Mobile App & Web (Employee Requests)            |
|   - Dynamic Catalog: Streams active CustomRequestType docs  |
|   - Dynamic Subtype Selector (ChoiceChips / Dropdown)       |
|   - Dynamic Form Renderer: Builds fields from template.fields|
|   - Validation Engine: Required checks, file attachments     |
|   - Snapshot on Submit: Retains subtype & chain rules        |
+-------------------------------------------------------------+
```

### Component Breakdown
1. **Dynamic Form Renderer (`DynamicFormFieldsWidget`)**:
   - Reusable widget that takes `List<CustomRequestField>` and a state map `Map<String, dynamic> values`.
   - Renders appropriate widgets (`WolfInputField` for text/numbers, Date picker for dates, Dropdown for selects, File upload button for attachments).
2. **Template Stream Synchronization**:
   - `CustomRequestTemplateRepository` provides a unified reactive stream of all active request types.
   - `employee_requests.dart` replaces hardcoded request types with this stream, gracefully combining core system types (leaves, permissions, advances) with custom types.
3. **Approval Chain Routing Service**:
   - Resolves next approver based on `template.approvalSteps` and request payload conditions (`minDays`, `minAmount`).
   - Ensures notifications route accurately to the required manager.

---

## 3. Data Integrity & Safety Invariant

- **Historical Request Safety**:
  - Existing requests in Firestore are read with safe fallback values (`deductsFromQuota ?? true`, `fieldValues ?? {}`).
  - No migration script is executed against existing documents.
- **Rules Compliance**:
  - Permissions always send canonical `permissionType` (`early_leave`, `late_arrival`, `mid_shift_exit`), preserving Firestore security rule validity.
  - Leaves continue to be written to `/leaves/` with appropriate status (`pending_manager`, `pending_hr`, etc.).
  - Custom requests continue to write to `/customRequests/` or `/employeeRequests/`.
