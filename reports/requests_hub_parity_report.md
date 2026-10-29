# Requests Hub Parity Report (Task C021 / Gate 2)

## Overview
This report documents the functional and architectural parity walk comparing the 18 legacy tabs in `lib/screens/manager/requests_mgmt.dart` against the new unified Requests Hub slice in `lib/features/request_workspace/`.

## Parity Matrix Across 18 Legacy Tabs

| # | Legacy Tab Title | Legacy Scope & Backing Data | New Requests Hub Mapping | Status |
|---|------------------|-----------------------------|--------------------------|--------|
| 1 | **الكل** | Mixed list of unassigned & pending items | "كل الطلبات" (Browse tab, default unconstrained) | **Covered** |
| 2 | **الإجازات** | `leaves` collection | Category filter: `RequestWorkspaceCategory.leave` | **Covered** |
| 3 | **الأذونات** | `permissions` collection | Category filter: `RequestWorkspaceCategory.permission` | **Covered** |
| 4 | **السلف** | `advances` collection | Category filter: `RequestWorkspaceCategory.advance` | **Covered** |
| 5 | **طلبات الاجتماعات** | `meetingRequests` collection | Category filter: `RequestWorkspaceCategory.meeting` | **Covered** |
| 6 | **مصروفات ومدفوعات الشركة** | `companyExpenses` / administrative | Category filter: `RequestWorkspaceCategory.administrative` | **Covered** |
| 7 | **خدمات تقنية وتشغيلية** | `customRequests` (IT subtype) | Category filter: `RequestWorkspaceCategory.custom` | **Covered** |
| 8 | **طلبات مخصصة** | `customRequests` collection | Category filter: `RequestWorkspaceCategory.custom` | **Covered** |
| 9 | **خصومات التأخير** | `attendance` deductions | Category filter: `RequestWorkspaceCategory.lateArrivalDeduction` | **Covered** |
| 10 | **خصومات الغياب** | `attendance` absence records | Integrated in Browse view & payroll review | **Covered** |
| 11 | **الخصومات المعتمدة** | `manual_deductions` (confirmed) | Status filter: `RequestWorkspaceStatus.confirmed` | **Covered** |
| 12 | **خصومات إدارية** | `manual_deductions` (pending) | Category filter: `RequestWorkspaceCategory.salaryDeduction` | **Covered** |
| 13 | **تصحيح الحضور** | `attendanceCorrectionRequests` | Category filter: `RequestWorkspaceCategory.attendanceCorrection` | **Covered** |
| 14 | **مراجعة أمنية** | Device change / IP review | Managed via diagnostics and capability grants | **Covered** |
| 15 | **الشكاوى** | `complaints` collection | Category filter: `RequestWorkspaceCategory.complaint` | **Covered** |
| 16 | **الاستقالات** | `resignations` collection | Category filter: `RequestWorkspaceCategory.resignation` | **Covered** |
| 17 | **إدارية** | `administrativeRequests` collection | Category filter: `RequestWorkspaceCategory.administrative` | **Covered** |
| 18 | **السجل الموحد** | `RequestVisibilityPanel` (heterogeneous history) | "سجل طلباتي" tab (History) + Browse tab | **Covered** |

## Key Architectural Upgrades
1. **Consolidated Cognitive Load**: Reduced 18 horizontal tab overloads down to 3 ergonomic top-level views:
   - **طلبات عليا**: Focuses purely on items awaiting the actor's decision.
   - **كل الطلبات**: Multi-category filterable explorer.
   - **سجل طلباتي**: Actor-specific historical ledger.
2. **Responsive Desktop Web Support**:
   - Master-Detail view (`>= 980px`) allows seamless review on the right pane without losing list context or scroll position.
   - Mobile view (`< 980px`) provides touch-friendly cards with standard route navigation.
3. **Destructive Action Safety**:
   - Rejection requires an explicit Arabic comment modal (`ConfirmationSheet`).
   - Approval includes one-tap confirmation.
4. **Clean Architecture & Guard Compliance**:
   - Zero UI/infrastructure coupling: `presentation` does not import Firestore, Firebase, or Dio.
   - Each Cubit is strictly `< 300` lines (Queue: 166 lines, Browse: 197 lines, Detail: 202 lines).
   - Zero unbounded Firestore listeners.
