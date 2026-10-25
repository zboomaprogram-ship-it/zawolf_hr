# Feature Specification: Dynamic Requests Engine & Configurable Forms (محرك الطلبات الديناميكي)

**Feature**: `019-dynamic-requests-engine`
**Created**: 2026-10-25
**Status**: Under Review (Spec & Plan Phase)
**User Input**: "i want all request to be dynmaic - make subtypes, quotas, attachments, custom fields, new request types, and approval chains dynamic, but leave the data i have for requests don't change anything"

---

## 1. Executive Summary & Core Mandate

The objective is to make the entire request system dynamically configurable from the HR Web Dashboard (`/hr/approval-chains-settings`) without requiring hardcoded code deployments or database rewrites whenever HR wants to add or adjust a request type, subtype, or approval route.

### Zero-Data-Loss Invariant (مبدأ الحفاظ على البيانات التاريخية)
- **Zero destructive migrations**: Existing collections (`leaves`, `permissions`, `salaryAdvances`, `customRequests`, `employeeRequests`, `administrativeRequests`) and all historical documents remain 100% untouched.
- **Backward compatibility**: Legacy request records continue to render and resolve in all existing screens, reports, and payroll calculations.
- **Rule compliance**: New submissions continue to conform to Firestore security rules (e.g., canonical permission types, manager approval bindings).

---

## 2. Core Functional Capabilities

### 2.1 Dynamic Subtypes, Quota Rules & Attachments
- **Subtypes Management**: HR can add, edit, reorder, or deactivate any subtype across all request categories (Leaves, Permissions, Advances, Administrative, and Custom).
- **Quota Association**: Each subtype specifies whether it deducts from balance, and binds to:
  - `daysOff` (رصيد الإجازات السنوية / الاعتيادية)
  - `casual` (رصيد الإجازات العارضة)
  - `permissions` (رصيد ساعات الأذونات الشهرية)
  - `none` (بدون خصم / معفى)
- **Mandatory Attachments**: Toggle per subtype whether uploading an attachment (medical report, exam schedule, bill receipt) is mandatory before submission.
- **Limits**: Maximum allowed days or hours per request can be enforced per subtype.
- **Permission Canonical Behavior**: Subtypes under permissions can be configured as `flexible` (مرن يحدده الموظف), `early_leave`, `late_arrival`, or `mid_shift_exit`.

### 2.2 Dynamic Custom Form Fields (حقول النماذج الديناميكية)
- HR can define custom fields for any request template:
  - Text (`text`): Single or multi-line text.
  - Number (`number`): Decimal or integer amounts (e.g., hours, amounts).
  - Date (`date`): Single date picker.
  - Date Range (`date_range`): Start and end date pickers.
  - Dropdown (`select`): List of predefined options.
  - Attachment (`file`): Document or image upload.
- The Mobile (Flutter iOS/Android) and Web apps dynamically render these fields when the employee selects the request type, auto-validates required entries, and stores key-value answers into the request document.

### 2.3 Creation of New Custom Request Types (أنواع طلبات مخصصة جديدة)
- HR can create entirely new request types from the Web Dashboard (e.g., "طلب تدريب وتطوير", "طلب شراء مستلزمات مكتبية", "طلب بدل انتقال").
- The new request type immediately shows up in the employee app request catalog with its custom icon, label, fields, and subtypes without requiring an app store release or Shorebird patch.

### 2.4 Dynamically Configurable Approval Chains (مسارات الاعتماد الديناميكية)
- Each request type defines a multi-step approval chain (1 to 4 steps).
- Approver types supported:
  - `direct_manager` (المدير المباشر للموظف)
  - `hr` (مسؤول الموارد البشرية)
  - `accounting` (الإدارة المالية / الحسابات)
  - `ceo` (الرئيس التنفيذي)
  - `specific_user` (شخص محدد بالاسم)
- Condition rules supported:
  - `days_threshold`: Only activates if requested days exceed a threshold (e.g., CEO approval needed only if leave > 3 days).
  - `amount_threshold`: Only activates if monetary amount exceeds a threshold (e.g., CEO approval needed only if advance > 5,000 EGP).
  - `always`: Step always required.

---

## 3. User Scenarios & Acceptance Criteria

### User Story 1 - Configurable Subtype & Quota Exemption (Priority: P1)
**As an** HR Manager,  
**I want to** add a new leave or permission subtype (e.g. "إجازة امتحانات" or "إجازة حج") in the Web Dashboard, set whether it deducts from balance and whether an attachment is mandatory,  
**So that** employees can submit this request on mobile without deducting from their annual leave or causing a permission-denied error.

**Acceptance Scenarios**:
1. **Given** HR adds subtype "إجازة امتحان" with `deductsFromQuota: false` and `requiresAttachment: true` in the Web Dashboard,
   **When** an employee opens the mobile app,
   **Then** "إجازة امتحان" appears in the leave subtypes list, requires attaching a schedule file, and does not deduct from their annual balance.
2. **Given** existing leave records in Firestore,
   **When** new subtypes are added,
   **Then** all historical leave records remain unaffected and readable.

---

### User Story 2 - Dynamic Custom Form Fields (Priority: P1)
**As an** HR Manager,  
**I want to** add custom questions/fields to a request template in the Web Dashboard,  
**So that** the employee is prompted for specific required info (e.g. "اسم الجامعة", "رقم المقرر") on mobile.

**Acceptance Scenarios**:
1. **Given** a request template configured with custom fields,
   **When** an employee selects this request,
   **Then** dynamic form fields render smoothly, validate required constraints, and serialize answers into the request payload.

---

### User Story 3 - Create New Custom Request Type (Priority: P2)
**As an** HR Manager,  
**I want to** create a completely new request type (e.g. "طلب فحص طبي دوري"),  
**So that** it becomes immediately accessible to employees in the mobile app.

**Acceptance Scenarios**:
1. **Given** HR saves a new active custom request type with approval steps,
   **When** employees open the requests screen,
   **Then** the new request card/tab appears with its name and icon, allowing submissions that route through the designated approvers.

---

### User Story 4 - Dynamic Approval Routing (Priority: P2)
**As an** Organization Administrator,  
**I want to** adjust who approves requests based on duration or amount,  
**So that** simple requests are approved quickly by direct managers while large requests escalate to CEO/Finance.

**Acceptance Scenarios**:
1. **Given** a leave chain requiring CEO approval only for leaves > 3 days,
   **When** an employee submits a 2-day leave,
   **Then** the route terminates at HR approval without requiring CEO action.
2. **When** an employee submits a 5-day leave,
   **Then** the route forwards to CEO after HR approval.

---

## 4. Edge Cases & Safety Constraints

1. **Network Disconnection / Offline Mode**:
   - The app caches the latest `customRequestTypes` stream in local memory/cache. If offline, the employee can still view and draft cached request types.
2. **Deleted or Deactivated Subtypes**:
   - If an HR admin deletes or deactivates a subtype, existing historical requests submitted with that subtype retain their original snapshot and do not fail to render.
3. **Firestore Security Rules**:
   - Dynamic templates must not bypass security rules. Permissions continue to map to canonical `permissionType` (`early_leave`, `late_arrival`, `mid_shift_exit`), while leaves and custom requests preserve valid status progressions.
4. **Payroll Integrity**:
   - Payroll calculations rely strictly on `isQuotaExempt` / `deductsFromQuota` flags stored at request creation time, ensuring historical payroll runs are never retroactively corrupted.
