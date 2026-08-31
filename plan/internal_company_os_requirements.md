# Requirements Specification: Internal IT Management System & Internal Company OS

**Document Version**: 1.0.0  
**Target Path**: `plan/internal_company_os_requirements.md`  
**Status**: Approved Specification  

---

## 🎯 Overview & Vision

This specification defines the requirements for the **Internal IT Management System**, designed to evolve into the **Internal Company OS**. 

The system provides a centralized internal portal where employees can request support, access permissions, financial services, and hardware/software assets. It equips IT, Finance, HR, and Management teams with a unified operational environment to manage all company assets, accounts, licenses, tickets, and employee workflows.

---

## 👥 User Roles & Access Matrix (RBAC)

| Role | Core Responsibilities & Scope |
|---|---|
| **Employee** | View personal profile, assigned assets, and software accesses; submit & track IT & Finance tickets; submit access & financial requests; access Knowledge Base. |
| **IT Support** | Manage assigned IT tickets, update issue statuses, add internal notes, manage hardware assets, and track software licenses. |
| **IT Manager** | Oversee all IT tickets, assign tasks to IT engineers, manage company assets & system permissions, approve access requests, and view IT performance dashboards & SLA metrics. |
| **Finance / Accountant** | Review employee financial requests (advances, reimbursements, custodies), manage monthly payslips, track payroll deductions, and handle Finance Tickets. |
| **Manager / Department Head** | Review and approve/reject first-level requests (Access, Expense, Leave, Advances) submitted by team members. |
| **Admin / Super Admin** | Full access to all system modules, configurations, role permissions, master data, and complete system audit logs. |

---

## 📦 Required MVP Modules

### 1. Dashboard Module
Role-tailored dashboards providing immediate operational insights.

#### IT Dashboard Metrics:
* Open Tickets / Critical Tickets / Tickets Created Today
* Average Resolution Time & SLA Performance
* Total Company Devices / Available Devices / Devices Under Maintenance
* Active Software Licenses / Licenses Expiring Soon
* Pending Access Requests

#### IT Visual Charts:
* Tickets by Status (New, In Progress, Waiting, Resolved, Closed)
* Tickets by Category (Laptop, Network, Software, etc.)
* Tickets by Department
* Ticket Resolution & SLA Performance Trend

---

### 2. Employee Management Module

#### Employee Profile Information:
* Full Name, Employee ID, Department, Job Title, Direct Manager, Work Email, Phone Number, Location/Branch, Employment Status.

#### Profile Linked Views:
* Assigned Hardware Devices & Serial Numbers
* Active Software Subscriptions & Systems Access
* System Permissions
* Active & Past IT & Finance Tickets
* Submitted Access & Financial Requests

---

### 3. IT Support & Ticketing Module

#### Ticket Fields:
* Ticket ID (Auto-generated), Employee, Department, Category, Subject, Description, Priority, Attachments, Assigned IT Engineer, Created Date, Due Date / SLA, Status.

#### Categories:
* `Laptop`, `Internet`, `Email`, `Software`, `Password`, `Printer`, `Network`, `Server`, `Access`, `Other`

#### Priority Levels:
* `Low`, `Medium`, `High`, `Critical`

#### Ticket Lifecycle Workflow:
```text
New ──► Assigned ──► In Progress ──► Waiting for Employee ──► Resolved ──► Closed
```

#### Inner Ticket Elements:
* Employee & IT Comments Thread
* Internal Private IT Notes
* Document & Screenshot Attachments
* Activity Timeline & Audit Log
* Resolution Details & Solution Notes

---

### 4. Assets Management Module

#### Asset Types:
* `Laptop`, `Desktop`, `Mobile`, `Monitor`, `Router`, `Server`, `Printer`, `SIM Card`, `Other`

#### Asset Attributes:
* Asset ID, Asset Name, Type, Brand, Model, Serial Number, Purchase Date, Purchase Price, Warranty Expiry Date, Physical Location, Assigned Employee, Asset Status.

#### Asset Statuses:
* `Available`, `Assigned`, `Maintenance`, `Damaged`, `Retired`

#### Asset Profile History:
* Current Assigned Employee & Previous Handover History
* Maintenance & Repair Record Timeline
* Related IT Tickets

---

### 5. Asset Assignment Module
Tracks hardware allocation and return without deleting historical evidence.

#### Asset Handover (Assign Device ──► Employee):
* Logged Fields: Assigned By, Assignment Date, Target Employee, Asset ID, Condition Notes.

#### Asset Return (Return Device ──► Inventory):
* Logged Fields: Return Date, Device Condition, Return Reason, Inspection Notes.
* *Rule*: Full assignment and maintenance history is permanently retained.

---

### 6. Software & Licenses Management

Tracks software subscriptions, SaaS tools, and licenses across the organization (e.g., Microsoft 365, Google Workspace, Adobe Creative Cloud, Canva, ChatGPT Enterprise, Antivirus, CRM, Hosting).

#### Software Profile Attributes:
* Software Name, Vendor, License Type (Per Seat / Concurrent / Site), Total Licenses Purchased, Used Licenses Count, Available Licenses Count, Monthly/Annual Renewal Cost, Renewal Expiry Date, License Owner/Admin, Status.

#### User Tracking:
* Detailed view listing every employee currently assigned a license seat.

---

### 7. Access Requests Module

Allows employees to request system permissions or software access.

#### Access Targets:
* `Google Drive Folders`, `CRM System`, `ERP / HR System`, `Shared Network Folders`, `Company Email / Alias`, `Database Access`, `Software Seat`, `Admin Rights`

#### Request Attributes:
* Employee, Access Type, Target System, Business Reason, Submission Date, Manager Approval Status, IT Approval Status, Overall Status.

#### Approval Workflow:
```text
Employee Request ──► Manager Approval ──► IT Approval ──► Access Granted & Provisioned
```

#### Statuses:
* `Pending`, `Approved`, `Rejected`, `Completed`

---

### 8. IT Knowledge Base Module

Self-service knowledge repository and troubleshooting guides.

#### Categories:
* `Email`, `Internet & Wi-Fi`, `Password Reset`, `Software Setup`, `VPN Access`, `Printer Setup`, `Security Best Practices`

#### Article Attributes:
* Article ID, Title, Category, Rich Text Content, Created By, Last Updated Date, Global Search Index.

---

### 9. Employee Financial Services / Finance Module 💰

Transforms the portal into an **Internal Company OS** for financial requests and employee accounting.

#### Unified Financial Workflow:
```text
Employee Request ──► Direct Manager Approval ──► Finance Review ──► Final Approval ──► Payment / Payroll Processing ──► Closed
```

#### Key Financial Services:

1. **Salary & Payslips**:
   * View breakdown of basic salary, allowances, overtime, bonuses, deductions, and net payable.
   * Download official monthly PDF Payslip.

2. **Salary Advance (سلفة)**:
   * Fields: Amount, Reason, Repayment Method, Number of Installments.
   * Auto-deduction integration with future payroll cycles.

3. **Expense Reimbursement**:
   * Employee uploads receipts for out-of-pocket business expenses.
   * Fields: Expense Category, Amount, Currency, Receipt Attachments.

4. **Employee Custody (عهدة مالية)**:
   * Issue funds for missions, travel, or procurement tasks.
   * Settlement Workflow: Employee submits final invoices, returns remaining cash balance, and settles custody.

5. **Payment Requests (طلبات صرف)**:
   * Requests for vendor payments, operational purchases, travel expenses, or operational line items.

6. **Bonuses & Deductions**:
   * Verified records of performance bonuses or administrative/attendance deductions with documented reasons and approvals.

7. **Employee Financial Account (كشف حساب الموظف)**:
   * Internal ledger showing advances, remaining installments, open custodies, submitted reimbursements, earnings, and deductions.

8. **Finance Tickets**:
   * Inquiry ticketing system for financial questions (e.g., "Salary discrepancy", "Missing allowance").

---

### 10. System Notifications Module

Real-time in-app & email notifications for critical events:
* New Ticket Assigned to IT Engineer
* Ticket Status / Comment Updated
* Access Request Approved / Rejected
* Hardware Asset Assigned / Handed Over
* Software License Expiring in 30 Days
* Ticket SLA Nearing Expiry Deadline
* Financial Request Approved / Payment Processed

---

### 11. Immutable Audit Log Module

Comprehensive security and operational logging. Every mutation must be recorded.

#### Logged Information:
* Actor (User ID & Name)
* Action Performed (e.g., `User Created`, `Access Granted`, `Asset Assigned`, `Asset Returned`, `Ticket Closed`, `Expense Approved`)
* Date & Timestamp (Server Local / Cairo)
* Target Entity / Object ID
* Previous Value Snapshot
* New Value Snapshot

---

## 🎨 UI & Layout Requirements

Modern, responsive SaaS Admin Portal design.

### Sidebar Navigation:
```text
Dashboard ──► Employees ──► HR ──► Finance ──► IT ──► Requests ──► Assets ──► Approvals ──► Knowledge Base ──► Reports ──► Settings
```

### Top Navigation Bar:
* **Global Search Bar**: Searches across Employees, Hardware Assets (by Serial Number), IT Tickets (by Ticket ID), and Software.
* **Notification Center & Bell Icon**
* **User Profile & Role Indicator**

### Data Table Standards:
Every data table must support:
* Full-text Search
* Column-based Filters & Status Chips
* Sorting (Ascending / Descending)
* Pagination (10, 25, 50, 100 per page)
* Export Options (CSV / Excel / PDF)

---

## 📊 Initial Analytics & Reports

1. **Tickets Report**: Total count, Average resolution time, Performance by IT Engineer, Tickets by Department, Tickets by Category.
2. **Assets Report**: Total inventory count, Assigned assets ratio, Available stock, Assets under maintenance.
3. **Software & Cost Report**: Software expenditure totals, License utilization rates, Unused seat count, Upcoming renewal alerts.

---

## 🏗️ Technical Architecture & Database Entities

Designed with a modular architecture for seamless expansion into HR, Finance, Procurement, Cybersecurity, AI Assistant, and Device Monitoring.

### Core Database Entities:
* `User`
* `Employee`
* `Department`
* `Role`
* `Permission`
* `Ticket`
* `TicketComment`
* `Asset`
* `AssetAssignment`
* `AssetMaintenance`
* `Software`
* `License`
* `SoftwareAssignment`
* `AccessRequest`
* `FinancialRequest` (Advance, Reimbursement, Custody, Payment)
* `FinancialLedger`
* `KnowledgeArticle`
* `Notification`
* `AuditLog`

---

## 🚀 Phase 1 MVP Scope & Goals

The primary goal of Phase 1 is delivering a fully functional system that the IT & Finance teams can immediately use for daily operations:

1. **Authentication & Identity Management**
2. **RBAC Roles & Permissions** (Employee, IT Support, IT Manager, Finance, Admin)
3. **Role-Tailored Dashboards**
4. **Employee Management Profiles**
5. **IT Ticketing System**
6. **Assets & Hardware Management**
7. **Asset Assignment & Handover History**
8. **Software & License Tracking**
9. **Access Requests Workflow**
10. **Employee Financial Services (Advances, Expenses, Payslips, Custody)**
11. **System Notifications & In-App Alerts**
12. **Immutable System Audit Log**
