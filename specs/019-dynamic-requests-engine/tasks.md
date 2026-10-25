# Task Checklist: Dynamic Requests Engine & Configurable Forms

**Feature**: `019-dynamic-requests-engine`
**Status**: Completed & Verified

---

## Phase 1: Domain Entities & Validation Contracts
- [X] 1.1: Verify `CustomRequestType`, `CustomSubtypeConfig`, `CustomRequestField`, and `ApprovalChainStep` models in `lib/features/request_approval_routing/domain/entities/custom_request_template.dart` support all required fields (e.g. `options` for select fields, `fieldValues` map serialization).
- [X] 1.2: Add unit tests in `test/features/request_approval_routing/` validating serialization, fallback defaults, and quota exemption behavior.

## Phase 2: Web Dashboard Enhancements (`approval_chains_settings_page.dart`)
- [X] 2.1: Enhance Subtype dialog in the Web Dashboard to support quota binding (`daysOff`, `casual`, `permissions`, `none`), attachment requirements, and canonical timing for permissions.
- [X] 2.2: Enhance Custom Form Fields builder in the Web Dashboard allowing HR to add `select`, `date_range`, `number`, and `file` fields with custom labels and requirement flags.
- [X] 2.3: Enhance Approval Chain builder allowing HR to configure 1 to 4 steps with approver roles (`direct_manager`, `hr`, `accounting`, `ceo`, `specific_user`) and conditions (`minDays`, `minAmount`).

## Phase 3: Dynamic Form Renderer for Employee App
- [X] 3.1: Create a reusable `DynamicFormFieldsWidget` presentation component that takes `List<CustomRequestField>` and renders valid input fields matching ZaWolf design guidelines.
- [X] 3.2: Integrate `DynamicFormFieldsWidget` into `employee_requests.dart` so when an employee picks any request type, any custom fields configured on that template render automatically.

## Phase 4: Dynamic Subtype & Quota Resolution in Request Submissions
- [X] 4.1: Update `LeaveService` and `_submitLeave` in `employee_requests.dart` to read `template.subtypeConfigs` dynamically, respecting `deductsFromQuota: false` and `requiresAttachment: true` without hardcoded if/else checks.
- [X] 4.2: Update `PermissionService` and `_submitPermission` to dynamically respect `permissionCanonicalType` and `isQuotaExempt`.
- [X] 4.3: Ensure newly created custom request types seamlessly submit to `/customRequests/` or `/employeeRequests/` using `ApprovalChainStep` routing.

## Phase 5: Verification & Safety Guard Validation
- [X] 5.1: Verify zero data loss: confirm existing documents in `leaves`, `permissions`, `customRequests` load without errors.
- [X] 5.2: Run `flutter test test/architecture_guard_test.dart test/firestore_query_guard_test.dart` and ensure all guards pass.
- [X] 5.3: Run `flutter analyze` and verify zero errors/warnings.
