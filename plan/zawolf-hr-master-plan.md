# 🐺 ZaWolf HR System — Master Development Plan v2.0
> **For:** AI Agent / Development Pipeline  
> **Company:** ZaWolf.AI · zawolf.ai  
> **Stack:** Flutter · Firebase (Spark Plan) · Google Stitch MCP · Secure CSV export  
> **Target:** Android APK + PWA (iOS & Web)  
> **Timeline:** 8 Weeks → 8 Phases  
> **⚠️ Constraint:** No Cloud Functions (Firebase Spark — no billing account). All logic runs client-side or via Firestore listeners.

---

## 🎨 Brand Identity & Design System

```yaml
Brand:
  name: ZaWolf.AI
  logo: wolf_head_geometric.png
  description: Geometric angular wolf, cyan-to-blue gradient (#00D4FF → #0073FF)
  tagline: "Intelligent HR. Unleashed."
  language_support: Arabic (RTL primary) + English (LTR)

Color Palette:
  primary_cyan:    "#00D4FF"     # CTAs, highlights, active states
  primary_blue:    "#0073FF"     # Gradient end, secondary actions
  gradient:        "linear-gradient(135deg, #00D4FF 0%, #0073FF 100%)"
  bg_dark:         "#07070F"     # App background
  surface_01:      "#0F1020"     # Cards, panels
  surface_02:      "#171830"     # Modals, elevated
  border_glow:     "#00D4FF22"   # 8% opacity glowing borders
  text_primary:    "#FFFFFF"
  text_secondary:  "#8BA3C7"
  text_muted:      "#4A5A74"
  success:         "#00E676"     # Approved, present, on-time
  warning:         "#FFB300"     # Pending, late, warning
  error:           "#FF3D3D"     # Rejected, check-out, denied
  permission_teal: "#00BFA5"     # Permission (إذن) request color
  dayoff_purple:   "#7C4DFF"     # Day-off requests
  perf_gold:       "#FFC107"     # Performance ratings

Typography:
  display_font: "Rajdhani"         # Headers — angular, matches logo
  body_font:    "Inter"            # Body text — clean, data-dense
  mono_font:    "JetBrains Mono"   # Times, IDs, numbers

Component Tokens:
  border_radius_card:   16px
  border_radius_button: 12px
  border_radius_chip:   24px
  border_radius_avatar: 50%
  wolf_glow_shadow:     "0 0 20px rgba(0,212,255,0.15)"
  spacing_scale:        [4, 8, 12, 16, 20, 24, 32, 40, 48, 64]
```

---

## 🗺️ Master Plan Overview

```
PHASE 0  ──▶  UI Design (Google Stitch MCP) — All screens + components
PHASE 1  ──▶  Firebase Foundation — Project setup, all collections, roles
PHASE 2  ──▶  Auth System — Admin creates accounts, employee changes password
PHASE 3  ──▶  Multi-Location Geofencing — Multiple company sites
PHASE 4  ──▶  Core Employee Features — Attendance, Permissions, Leaves, Day-off
PHASE 5  ──▶  Manager Dashboard — Approvals, Team, Requests
PHASE 6  ──▶  HR Admin Panel — All staff, Reports, Settings
PHASE 7  ──▶  Performance System — Scores, KPIs, Monthly reviews
PHASE 8  ──▶  Notifications (No Functions) + Build + Deploy
```

---

## 👥 Role System (3 Roles)

```
┌─────────────────────────────────────────────────────────────────────┐
│                        ROLE HIERARCHY                               │
│                                                                     │
│   HR Admin (موارد بشرية)   ──▶ Highest — sees everything, all sites│
│         │                                                           │
│   Manager (مدير)           ──▶ Mid — sees their team only          │
│         │                                                           │
│   Employee (موظف)          ──▶ Base — sees only their own data     │
└─────────────────────────────────────────────────────────────────────┘
```

### Permission Matrix

| Feature | Employee | Manager | HR Admin |
|---------|:--------:|:-------:|:--------:|
| Check in/out (own) | ✅ | ✅ | ✅ |
| View own attendance | ✅ | ✅ | ✅ |
| Request leave (إجازة) | ✅ | ✅ | ✅ |
| Request permission (إذن) | ✅ | ✅ | ✅ |
| Request day off | ✅ | ✅ | ✅ |
| Change own password | ✅ | ✅ | ✅ |
| View own performance | ✅ | ✅ | ✅ |
| View team attendance | ❌ | ✅ | ✅ |
| View team leaves/requests | ❌ | ✅ | ✅ |
| Approve/reject leaves | ❌ | ✅ | ✅ |
| Approve/reject permissions | ❌ | ✅ | ✅ |
| Approve/reject day-offs | ❌ | ✅ | ✅ |
| Rate employee performance | ❌ | ✅ | ✅ |
| View all employees (all sites) | ❌ | ❌ | ✅ |
| Create/edit employee accounts | ❌ | ❌ | ✅ |
| Manage company locations | ❌ | ❌ | ✅ |
| Export reports to Sheets | ❌ | ✅ (team only) | ✅ (all) |
| Override any request | ❌ | ❌ | ✅ |
| Manage leave balances | ❌ | ❌ | ✅ |
| View all performance | ❌ | ✅ (team) | ✅ (all) |
| Send announcements | ❌ | ✅ (team) | ✅ (all) |

---

## PHASE 0 — UI Design with Google Stitch MCP

### 📌 Complete Google Stitch Prompt

```
STITCH DESIGN PROMPT — ZAWOLF HR SYSTEM v2
==========================================

App: ZaWolf HR — Human Resources System for ZaWolf.AI
Language: Arabic (RTL) primary, with English toggle
Dark mode only.

BRAND:
- Company: ZaWolf.AI — AI-powered, geometric wolf mascot
- Logo: Angular wolf head, cyan (#00D4FF) → blue (#0073FF) gradient
- Feel: Precision military-tech meets modern corporate. Like a wolf pack: coordinated, fast, powerful.

DESIGN TOKENS:
  bg:           #07070F
  surface:      #0F1020
  surface-2:    #171830
  primary:      #00D4FF
  blue:         #0073FF
  success:      #00E676
  warning:      #FFB300
  error:        #FF3D3D
  permission:   #00BFA5
  dayoff:       #7C4DFF
  perf-gold:    #FFC107
  text:         #FFFFFF
  muted:        #8BA3C7

FONTS: Rajdhani (headers), Inter (body), JetBrains Mono (numbers)
RADIUS: 16px cards, 12px buttons, 24px chips
SHADOW: 0 0 20px rgba(0,212,255,0.15) on active cards

─────────────────────────────────────────────
SCREENS TO DESIGN:
─────────────────────────────────────────────

1. SPLASH SCREEN
   Wolf logo centered, pulsing cyan glow animation
   "ZaWolf HR" in Rajdhani Bold below logo
   Gradient progress bar at bottom
   Very dark background (#07070F)

2. LOGIN SCREEN
   - Wolf logo top (smaller, 80px)
   - "مرحباً بعودتك" / "Welcome Back" heading in Rajdhani
   - Email/Username field (cyan focus glow border)
   - Password field with show/hide eye icon
   - "تذكرني" / "Remember Me" toggle switch (cyan)
   - Gradient primary button "دخول" / "LOGIN"
   - Note: No "Forgot Password" flow — admin resets passwords
   - Subtle wolf silhouette watermark at 5% opacity in background

3. EMPLOYEE DASHBOARD (Home)
   Top bar: employee avatar (right), wolf logo (center), notification bell (left)
   TODAY CARD: Large card, shows check-in status, date, time
   BIG WOLF BUTTON: 120px circle, gradient border glow
     - IDLE: Green glow, wolf paw icon, "تسجيل حضور"
     - CHECKED IN: Red glow, "تسجيل انصراف"
     - Location shown: "📍 فرع القاهرة"
   QUICK STATS: 3 mini cards — [رصيد الإجازات] [أيام الحضور] [الانضباط %]
   QUICK ACTIONS ROW: [طلب إذن] [طلب إجازة] [يوم إجازة] — 3 icon buttons
   RECENT ACTIVITY: last 5 records

4. CHECK-IN CONFIRMATION SCREEN
   - Full overlay modal
   - Large animated ✓ (cyan)
   - "تم تسجيل الحضور ✓"
   - Time in large mono font: "09:02 ص"
   - Location: "📍 ZaWolf HQ — داخل النطاق"
   - Badge: "في الميعاد" (green) OR "متأخر 12 دقيقة" (amber)

5. PERMISSION REQUEST SCREEN (إذن)
   Header: "طلب إذن"
   Teal (#00BFA5) accent color for this screen
   
   MONTHLY QUOTA BANNER:
   Shows: "استخدمت 0/2 إذن هذا الشهر | المتبقي: 5:00 ساعة"
   Progress bar (teal) showing used hours vs 5hr limit
   
   Permission Type chips:
   ◉ مغادرة مبكرة (Early Leave)
   ◉ تأخير حضور (Late Arrival)
   
   ⚠️ WARNING BANNER for "تأخير حضور":
   Yellow card: "يجب تقديم طلب تأخير الحضور قبل موعد العمل الرسمي"
   
   Time picker: "وقت المغادرة / وقت الحضور المتوقع"
   Duration auto-calculated (shown in teal chip)
   Reason textarea
   
   IF QUOTA EXCEEDED (>2 permissions OR >5 hours):
   Red warning: "تجاوزت الحد الشهري — يستلزم موافقة إضافية وقد يُخصم من الراتب"
   
   Submit button (teal gradient): "إرسال الطلب"

6. DAY-OFF REQUEST SCREEN (يوم إجازة)
   Header: "طلب يوم إجازة"
   Purple (#7C4DFF) accent
   
   BALANCE CARD: "رصيد أيام الإجازة السنوية: 18 يوم متبقي من 21"
   Progress ring showing used vs total
   
   Date picker (single day or multi-day)
   Days count auto-shown: "3 أيام"
   Reason field (optional)
   
   IF insufficient balance: Red warning shown
   
   Submit button (purple gradient): "إرسال الطلب"

7. LEAVE REQUEST SCREEN (إجازة رسمية)
   Header: "طلب إجازة"
   
   Leave type chips:
   ◉ سنوية  ◉ مرضية  ◉ عارضة
   
   Date range picker
   Duration auto-calculated
   Reason + optional attachment (medical cert)
   
   BALANCE shown per type
   Submit button (gradient)

8. MY REQUESTS SCREEN
   3-tab navigation: الإجازات | الأذونات | أيام الإجازة
   Each tab: Pending / Approved / Rejected segments
   
   Cards show:
   - Type icon + colored badge
   - Date/time range
   - Status badge (color-coded)
   - Duration
   - Manager response (if reviewed)
   - "إلغاء" button for pending items only

9. PERFORMANCE SCREEN (Employee view)
   Header: "أدائي"
   Gold (#FFC107) accent
   
   CURRENT MONTH CARD:
   - Overall score: Large number "87/100" in gold
   - Grade badge: "ممتاز" / "جيد جداً" / "جيد" / "مقبول"
   - Breakdown donut chart
   
   KPI CARDS ROW:
   - نسبة الحضور: 96%
   - الانضباط: 88%
   - الالتزام بالمواعيد: 85%
   
   HISTORY: Monthly scores as bar chart (last 6 months)
   MANAGER NOTES: expandable card with latest review note

10. EMPLOYEE PROFILE SCREEN
    Wolf-ring avatar with cyan glow border
    Name, Department, Employee ID badge
    Location/Branch chip
    Manager name
    
    INFO CARDS:
    - تاريخ الانضمام, المسمى الوظيفي
    
    SETTINGS SECTION:
    - تغيير كلمة المرور (prominent — user can always do this)
    - اللغة (AR/EN toggle)
    - الإشعارات

11. CHANGE PASSWORD SCREEN
    - Current password field
    - New password field (with strength meter: weak/medium/strong)
    - Confirm new password field
    - Save button
    - Note: "لا يمكن للإدارة الاطلاع على كلمة مرورك"

─────────────────────────────────────────────
MANAGER SCREENS:
─────────────────────────────────────────────

12. MANAGER DASHBOARD
    Header: "لوحة المدير" with team avatar row
    
    TODAY SUMMARY ROW:
    [حاضر X] [غائب X] [متأخر X] [إجازة X]
    as colored mini cards
    
    PENDING REQUESTS BANNER:
    "3 طلبات تنتظر موافقتك" — orange badge, tap to expand
    Request type breakdown chips: إذن × 1 | إجازة × 2
    
    TEAM ATTENDANCE LIST: today's live list with status badges
    
    QUICK ACTIONS: [تقييم الأداء] [تقرير الفريق] [إشعار للفريق]

13. REQUESTS MANAGEMENT SCREEN (Manager)
    Tab bar: الإجازات | الأذونات | أيام الإجازة
    
    Each request card:
    - Employee avatar + name
    - Request type + dates/time
    - Quota info (for permissions: "2nd permission this month")
    - ⚠️ Exceeded quota warning if applicable
    - APPROVE ✓ (green) | REJECT ✗ (red) buttons
    - Optional comment field on rejection
    
    ⚠️ LATE ARRIVAL PERMISSION RULE:
    Show banner: "تم تقديم بعد بداية وقت العمل — لا يُعتد به وفق اللائحة"
    Highlighted in red if submitted after work start time

14. TEAM ATTENDANCE SCREEN (Manager)
    Filter bar: اليوم | الأسبوع | الشهر
    Filter chips: الكل | حاضر | غائب | متأخر | إجازة
    Employee list with attendance details
    Tap → employee detail

15. PERFORMANCE MANAGEMENT SCREEN (Manager)
    Team performance overview
    Each employee: mini score bar + current rating
    Tap → performance review screen
    
    REVIEW SCREEN:
    - Employee photo + name
    - Month picker
    - Sliders for: الحضور | الانضباط | الجودة | التعاون (0-100)
    - Overall score auto-calculated
    - Grade auto-assigned
    - Notes textarea
    - Save button

─────────────────────────────────────────────
HR ADMIN SCREENS:
─────────────────────────────────────────────

16. HR ADMIN DASHBOARD
    Header: "مركز التحكم — ZaWolf" with wolf logo
    
    LOCATION TABS: All locations OR filter by branch
    
    SUMMARY CARDS: [إجمالي الموظفين] [حاضر اليوم] [غائب] [في إجازة]
    
    REQUESTS ALERT BANNER: "5 طلبات معلقة للمراجعة"
    
    QUICK ACTIONS:
    [إضافة موظف] [تصدير تقرير] [إدارة المواقع] [إشعار عام]

17. ADD/EDIT EMPLOYEE SCREEN
    Wolf avatar uploader
    Fields:
    - الاسم الكامل (Full name)
    - البريد الإلكتروني / اسم المستخدم (auto-generate or custom)
    - كلمة المرور الأولية (Initial password — shown once)
    - القسم / الإدارة
    - المسمى الوظيفي
    - الدور: موظف | مدير | موارد بشرية
    - الفرع / الموقع (dropdown from locations)
    - المدير المباشر (dropdown — managers only)
    - تاريخ الانضمام
    
    LEAVE BALANCE SECTION:
    - إجازة سنوية: [___] يوم
    - إجازة مرضية: [___] يوم  
    - إجازة عارضة: [___] يوم
    - أيام إجازة سنوية: [___] يوم
    
    Save → "تم إنشاء الحساب — الكلمة الأولية: ZW@2025"

18. EMPLOYEE LIST SCREEN (HR)
    Search bar
    Location filter tabs
    Department filter chips
    
    Employee cards: avatar, name, role badge, department, location, status
    Tap → Employee detail / edit

19. LOCATIONS MANAGEMENT SCREEN
    Map view showing all company locations as wolf-pin markers
    
    Location cards:
    - Branch name
    - Address
    - Geofence radius (editable)
    - Employee count at this branch
    
    [+ إضافة موقع] button → opens Add Location screen:
    - Branch name
    - Address
    - Select on map (pin drop)
    - Geofence radius slider (25m – 200m)

20. REPORT EXPORT SCREEN
    Month/year picker
    Location filter (all or specific branch)
    Report type: الحضور | الإجازات | الأذونات | الأداء | شامل
    Preview stats
    [تصدير CSV آمن] gradient button

21. ANNOUNCEMENT SCREEN
    Title field
    Message body
    Target: الكل | موقع معين | قسم معين | موظف معين
    Priority: عادي | عاجل (urgent changes card color to red)
    [إرسال الإشعار]

─────────────────────────────────────────────
COMPONENT LIBRARY:
─────────────────────────────────────────────

Buttons:
- WolfButton.primary (gradient cyan→blue)
- WolfButton.teal (permissions — teal)
- WolfButton.purple (day-off — purple)
- WolfButton.danger (red)
- WolfButton.outline (bordered)

Status Badges (chips):
- حاضر (green) | غائب (red) | متأخر (amber) | إجازة (blue)
- معلق (amber) | مقبول (green) | مرفوض (red) | ملغي (gray)

Request Type Chips:
- إجازة سنوية (blue) | إجازة مرضية (orange) | إجازة عارضة (purple)
- إذن مغادرة (teal) | إذن تأخير (amber)
- يوم إجازة (purple)

Performance Grade Badges:
- ممتاز 90-100 (gold) | جيد جداً 75-89 (cyan) | جيد 60-74 (green) | مقبول 50-59 (amber)

Navigation:
- Employee bottom bar: الرئيسية | طلباتي | أدائي | حسابي
- Manager bottom bar: لوحتي | الطلبات | فريقي | الأداء
- HR bottom bar: لوحتي | الموظفون | المواقع | التقارير

Empty States: Sleeping wolf illustration for no data
Loading: Wolf paw spinning animation

OUTPUT: Flutter widget code per screen, Material 3 + custom ZaWolf theme.
```

---

## PHASE 1 — Firebase Foundation (Spark Plan)

### 1.1 Firebase MCP Setup

```bash
# Firebase Project: zawolf-hr-system
# Services to enable (ALL free on Spark):
✅ Authentication (Email/Password)
✅ Firestore Database
✅ Firebase Storage (5GB free)
✅ Firebase Hosting (10GB/month free)
✅ Firebase Realtime Database (for presence/notifications)
❌ Cloud Functions — DISABLED (requires billing)
❌ Cloud Messaging (FCM) — replaced with Firestore-listener approach
```

### 1.2 Complete Firestore Schema

#### Collection: `companies/{companyId}`
```json
{
  "companyId": "zawolf",
  "name": "ZaWolf.AI",
  "workSchedule": {
    "startTime": "09:00",
    "endTime": "17:00",
    "workDays": [0, 1, 2, 3, 4],
    "fridayHalf": false
  },
  "permissionPolicy": {
    "maxPermissionsPerMonth": 2,
    "maxPermissionHoursPerMonth": 5,
    "lateArrivalDeadline": "before_work_start"
  },
  "leaveDefaults": {
    "annual": 21,
    "sick": 14,
    "casual": 7,
    "daysOff": 21
  },
  "createdAt": "TIMESTAMP"
}
```

#### Collection: `locations/{locationId}`
```json
{
  "locationId": "STRING — UUID",
  "companyId": "zawolf",
  "name": "STRING — e.g. المقر الرئيسي / فرع المعادي",
  "address": "STRING",
  "latitude": "NUMBER",
  "longitude": "NUMBER",
  "geofenceRadiusMeters": "NUMBER (25–200, default 50)",
  "isActive": "BOOLEAN",
  "employeeCount": "NUMBER — denormalized, updated on assignment",
  "createdAt": "TIMESTAMP",
  "updatedAt": "TIMESTAMP"
}
```

#### Collection: `users/{userId}`
```json
{
  "uid": "STRING — Firebase Auth UID",
  "email": "STRING — set by admin (can be custom domain)",
  "displayName": "STRING",
  "photoURL": "STRING | null",
  "role": "STRING — 'employee' | 'manager' | 'hr_admin'",
  "employeeId": "STRING — e.g. ZW-0042",
  "department": "STRING",
  "position": "STRING",
  "locationId": "STRING — assigned branch ID",
  "locationName": "STRING — denormalized",
  "managerId": "STRING | null — UID of direct manager",
  "managerName": "STRING | null — denormalized",
  "isActive": "BOOLEAN",
  "joinDate": "TIMESTAMP",
  "workSchedule": {
    "startTime": "STRING — override company default or null",
    "endTime": "STRING",
    "workDays": "ARRAY<NUMBER> | null"
  },
  "leaveBalance": {
    "annual": "NUMBER",
    "sick": "NUMBER",
    "casual": "NUMBER",
    "daysOff": "NUMBER — separate annual day-off pool"
  },
  "permissionBalance": {
    "usedThisMonth": "NUMBER — resets each month",
    "usedHoursThisMonth": "NUMBER — resets each month",
    "lastResetMonth": "STRING — YYYY-MM"
  },
  "notificationTokens": "ARRAY<STRING> — for Realtime DB approach",
  "unreadNotifications": "NUMBER — badge count",
  "createdAt": "TIMESTAMP",
  "updatedAt": "TIMESTAMP",
  "passwordChangedAt": "TIMESTAMP | null"
}
```

#### Collection: `attendance/{attendanceId}`
```json
{
  "attendanceId": "STRING",
  "userId": "STRING",
  "employeeId": "STRING — denormalized",
  "employeeName": "STRING — denormalized",
  "locationId": "STRING — which branch",
  "locationName": "STRING — denormalized",
  "managerId": "STRING — denormalized for manager queries",
  "date": "STRING — YYYY-MM-DD",
  "checkInTime": "TIMESTAMP — serverTimestamp()",
  "checkOutTime": "TIMESTAMP | null",
  "checkInLocation": { "latitude": "NUMBER", "longitude": "NUMBER" },
  "checkOutLocation": { "latitude": "NUMBER", "longitude": "NUMBER | null" },
  "localCheckInTime": "TIMESTAMP — device time (anti-tamper audit)",
  "localCheckOutTime": "TIMESTAMP | null",
  "isWithinGeofence": "BOOLEAN",
  "isLate": "BOOLEAN",
  "lateMinutes": "NUMBER",
  "totalWorkHours": "NUMBER | null",
  "status": "STRING — 'present' | 'late' | 'absent' | 'half-day' | 'on-leave'"
}
```

#### Collection: `leaves/{leaveId}`
```json
{
  "leaveId": "STRING",
  "userId": "STRING",
  "employeeId": "STRING",
  "employeeName": "STRING",
  "department": "STRING",
  "locationId": "STRING",
  "managerId": "STRING",
  "leaveType": "STRING — 'annual' | 'sick' | 'casual'",
  "startDate": "TIMESTAMP",
  "endDate": "TIMESTAMP",
  "numberOfDays": "NUMBER",
  "reason": "STRING | null",
  "attachmentUrl": "STRING | null",
  "status": "STRING — 'pending' | 'approved' | 'rejected' | 'cancelled'",
  "submittedAt": "TIMESTAMP",
  "reviewedAt": "TIMESTAMP | null",
  "reviewedBy": "STRING | null — manager/HR UID",
  "reviewerComment": "STRING | null",
  "isRead": "BOOLEAN — has manager seen this request"
}
```

#### Collection: `permissions/{permissionId}`
> **إذن** — Permission requests (early leave or late arrival)

```json
{
  "permissionId": "STRING",
  "userId": "STRING",
  "employeeId": "STRING",
  "employeeName": "STRING",
  "department": "STRING",
  "locationId": "STRING",
  "managerId": "STRING",
  "permissionType": "STRING — 'early_leave' | 'late_arrival'",
  "requestDate": "STRING — YYYY-MM-DD (which work day)",
  "expectedTime": "STRING — HH:mm (when leaving / when arriving)",
  "durationMinutes": "NUMBER — how long the permission is",
  "reason": "STRING",
  "status": "STRING — 'pending' | 'approved' | 'rejected' | 'cancelled' | 'invalid_late'",
  "isExceedingQuota": "BOOLEAN — true if >2 permissions or >5hrs this month",
  "submittedAt": "TIMESTAMP",
  "isSubmittedAfterWorkStart": "BOOLEAN — true if late-arrival submitted after 09:00",
  "monthKey": "STRING — YYYY-MM (for monthly quota queries)",
  "reviewedAt": "TIMESTAMP | null",
  "reviewedBy": "STRING | null",
  "reviewerComment": "STRING | null",
  "isRead": "BOOLEAN"
}
```

#### Collection: `daysoff/{dayoffId}`
> **أيام الإجازة** — Personal day-off requests (separate from formal leave)

```json
{
  "dayoffId": "STRING",
  "userId": "STRING",
  "employeeId": "STRING",
  "employeeName": "STRING",
  "department": "STRING",
  "locationId": "STRING",
  "managerId": "STRING",
  "startDate": "TIMESTAMP",
  "endDate": "TIMESTAMP",
  "numberOfDays": "NUMBER",
  "reason": "STRING | null",
  "status": "STRING — 'pending' | 'approved' | 'rejected' | 'cancelled'",
  "submittedAt": "TIMESTAMP",
  "reviewedAt": "TIMESTAMP | null",
  "reviewedBy": "STRING | null",
  "reviewerComment": "STRING | null",
  "isRead": "BOOLEAN"
}
```

#### Collection: `performance/{performanceId}`
```json
{
  "performanceId": "STRING",
  "userId": "STRING",
  "employeeId": "STRING",
  "employeeName": "STRING",
  "managerId": "STRING",
  "locationId": "STRING",
  "department": "STRING",
  "monthKey": "STRING — YYYY-MM",
  "scores": {
    "attendance": "NUMBER 0-100 — auto-calculated",
    "punctuality": "NUMBER 0-100 — auto-calculated",
    "quality": "NUMBER 0-100 — manager-rated",
    "teamwork": "NUMBER 0-100 — manager-rated",
    "commitment": "NUMBER 0-100 — manager-rated"
  },
  "weights": {
    "attendance": 0.25,
    "punctuality": 0.25,
    "quality": 0.20,
    "teamwork": 0.15,
    "commitment": 0.15
  },
  "overallScore": "NUMBER 0-100 — weighted average",
  "grade": "STRING — 'ممتاز' | 'جيد جداً' | 'جيد' | 'مقبول'",
  "managerNotes": "STRING | null",
  "isPublished": "BOOLEAN — true = employee can see",
  "createdAt": "TIMESTAMP",
  "updatedAt": "TIMESTAMP"
}
```

#### Collection: `notifications/{notificationId}`
> Used instead of FCM Cloud Functions — Firestore listeners replace server push

```json
{
  "notificationId": "STRING",
  "recipientId": "STRING — target user UID",
  "senderId": "STRING | null",
  "senderName": "STRING | null",
  "type": "STRING — see types below",
  "title": "STRING",
  "body": "STRING",
  "data": "MAP — context payload (requestId, type, etc.)",
  "isRead": "BOOLEAN",
  "createdAt": "TIMESTAMP"
}
```

```
Notification Types:
  leave_request_submitted     → manager receives
  leave_approved              → employee receives
  leave_rejected              → employee receives
  permission_request_submitted → manager receives
  permission_approved         → employee receives
  permission_rejected         → employee receives
  permission_invalid_late     → employee receives (auto)
  dayoff_request_submitted    → manager receives
  dayoff_approved             → employee receives
  dayoff_rejected             → employee receives
  performance_published       → employee receives
  announcement                → all / group
  quota_warning               → employee receives (auto, on 2nd permission)
```

---

## PHASE 2 — Authentication & Account Management

### 2.1 Account Creation Flow (HR Admin Only)

```dart
// HR Admin creates employee account
// Employee CANNOT self-register — no sign-up screen

class AccountCreationService {

  Future<UserModel> createEmployeeAccount({
    required String email,
    required String displayName,
    required String role,
    required String locationId,
    String? managerId,
    required Map<String, int> leaveBalance,
  }) async {
    // 1. Generate initial password: ZW@[EmployeeID] e.g. "ZW@0042"
    final initialPassword = 'ZW@${employeeId}';

    // 2. Create Firebase Auth user using Admin SDK
    //    ⚠️ Without Cloud Functions, use Firebase Auth REST API:
    final authUser = await FirebaseAuth.instance
        .createUserWithEmailAndPassword(
          email: email,
          password: initialPassword,
        );

    // 3. Create Firestore user document
    await FirebaseFirestore.instance
        .collection('users')
        .doc(authUser.user!.uid)
        .set(UserModel(
          uid: authUser.user!.uid,
          email: email,
          displayName: displayName,
          role: role,
          employeeId: employeeId,
          locationId: locationId,
          managerId: managerId,
          leaveBalance: leaveBalance,
          permissionBalance: {
            'usedThisMonth': 0,
            'usedHoursThisMonth': 0.0,
            'lastResetMonth': DateFormat('yyyy-MM').format(DateTime.now()),
          },
          isActive: true,
          joinDate: Timestamp.now(),
        ).toFirestore());

    // 4. Show initial password to HR admin ONCE — they share with employee
    return UserModel(initialPassword: initialPassword, ...);
  }
}
```

### 2.2 Employee Password Change

```dart
// Employee changes their own password — always available in profile
class PasswordChangeService {
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = FirebaseAuth.instance.currentUser!;
    
    // Re-authenticate first (security best practice)
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
    
    // Update password
    await user.updatePassword(newPassword);
    
    // Log the change in Firestore
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'passwordChangedAt': FieldValue.serverTimestamp()});
  }
}
```

### 2.3 HR Admin Password Reset (for locked employees)

```dart
// HR admin sends password reset email — Firebase Auth handles it
Future<void> resetEmployeePassword(String employeeEmail) async {
  await FirebaseAuth.instance.sendPasswordResetEmail(email: employeeEmail);
  // Or: HR sets a new temp password directly via REST API
}
```

### 2.4 Role-Based Routing (go_router)

```dart
// After login, check role → route accordingly
switch (user.role) {
  case 'employee':
    return '/employee/dashboard';
  case 'manager':
    return '/manager/dashboard';
  case 'hr_admin':
    return '/hr/dashboard';
}

// Guards: manager routes redirect to /employee/* if role is employee
// HR routes redirect to /manager/* if role is manager
```

---

## PHASE 3 — Multi-Location Geofencing

### 3.1 Location Assignment Logic

```dart
// Each employee has ONE assigned locationId
// On check-in, validate against THEIR assigned location's geofence
// HR can have employees assigned to different branches

class GeofenceService {
  
  Future<GeofenceResult> validateCheckIn(UserModel employee) async {
    // 1. Fetch employee's assigned location from Firestore
    final locationDoc = await FirebaseFirestore.instance
        .collection('locations')
        .doc(employee.locationId)
        .get();
    
    final location = LocationModel.fromFirestore(locationDoc);
    
    // 2. Get device GPS
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );
    
    // 3. Haversine distance calculation
    final distanceMeters = Geolocator.distanceBetween(
      position.latitude, position.longitude,
      location.latitude, location.longitude,
    );
    
    // 4. Check against this location's specific radius
    final isWithin = distanceMeters <= location.geofenceRadiusMeters;
    
    return GeofenceResult(
      isWithinZone: isWithin,
      distanceMeters: distanceMeters,
      locationName: location.name,
      allowedRadius: location.geofenceRadiusMeters,
      position: position,
    );
  }
}
```

### 3.2 Location Management (HR Admin)

```dart
// HR Admin can add/edit/delete locations
// Each location has its own geofence radius

class LocationService {
  
  Future<void> addLocation(LocationModel location) async {
    final docRef = FirebaseFirestore.instance.collection('locations').doc();
    await docRef.set(location.copyWith(locationId: docRef.id).toFirestore());
  }
  
  Future<void> updateGeofenceRadius(String locationId, double meters) async {
    await FirebaseFirestore.instance
        .collection('locations')
        .doc(locationId)
        .update({'geofenceRadiusMeters': meters, 'updatedAt': FieldValue.serverTimestamp()});
  }
  
  Stream<List<LocationModel>> watchAllLocations() {
    return FirebaseFirestore.instance
        .collection('locations')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map(LocationModel.fromFirestore).toList());
  }
}
```

---

## PHASE 4 — Core Employee Features

### 4.1 Attendance Logic

```dart
Future<void> handleCheckIn(UserModel employee) async {
  // 1. Geofence check
  final geo = await GeofenceService().validateCheckIn(employee);
  if (!geo.isWithinZone) {
    throw AppException(
      '🐺 أنت خارج نطاق ${geo.locationName}\n'
      'المسافة: ${geo.distanceMeters.toInt()} متر\n'
      'النطاق المسموح: ${geo.allowedRadius.toInt()} متر'
    );
  }

  // 2. Check if already checked in today
  final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final existing = await FirebaseFirestore.instance
      .collection('attendance')
      .where('userId', isEqualTo: employee.uid)
      .where('date', isEqualTo: today)
      .limit(1)
      .get();

  if (existing.docs.isEmpty) {
    // Check IN
    final schedule = employee.workSchedule ?? company.workSchedule;
    final workStart = _parseTime(schedule.startTime);
    final isLate = DateTime.now().isAfter(workStart);
    
    await FirebaseFirestore.instance.collection('attendance').add({
      'userId': employee.uid,
      'employeeId': employee.employeeId,
      'employeeName': employee.displayName,
      'locationId': employee.locationId,
      'locationName': employee.locationName,
      'managerId': employee.managerId,
      'date': today,
      'checkInTime': FieldValue.serverTimestamp(),    // ✅ server time
      'localCheckInTime': Timestamp.now(),             // device time (audit)
      'checkInLocation': GeoPoint(geo.position.latitude, geo.position.longitude),
      'isWithinGeofence': true,
      'isLate': isLate,
      'lateMinutes': isLate ? DateTime.now().difference(workStart).inMinutes : 0,
      'status': isLate ? 'late' : 'present',
    });
  } else {
    // Check OUT
    final doc = existing.docs.first;
    final checkIn = (doc.data()['checkInTime'] as Timestamp).toDate();
    final now = DateTime.now();
    final workHours = now.difference(checkIn).inMinutes / 60.0;
    
    await doc.reference.update({
      'checkOutTime': FieldValue.serverTimestamp(),
      'localCheckOutTime': Timestamp.now(),
      'checkOutLocation': GeoPoint(geo.position.latitude, geo.position.longitude),
      'totalWorkHours': workHours,
    });
  }
}
```

### 4.2 Permission (إذن) System — Full Logic

```dart
class PermissionService {

  // Validate and submit a permission request
  Future<void> submitPermission(PermissionRequestModel req) async {
    final now = DateTime.now();
    final monthKey = DateFormat('yyyy-MM').format(now);

    // ── Rule 1: Check monthly quota ──────────────────────
    final monthPerms = await FirebaseFirestore.instance
        .collection('permissions')
        .where('userId', isEqualTo: req.userId)
        .where('monthKey', isEqualTo: monthKey)
        .where('status', whereIn: ['approved', 'pending'])
        .get();

    final usedCount = monthPerms.docs.length;
    final usedHours = monthPerms.docs.fold<double>(
      0, (sum, d) => sum + (d.data()['durationMinutes'] as num) / 60.0
    );
    final newHours = req.durationMinutes / 60.0;
    
    final isExceedingQuota = usedCount >= 2 || (usedHours + newHours) > 5.0;

    // ── Rule 2: Late arrival MUST be before work start ──
    bool isLateSubmission = false;
    if (req.permissionType == 'late_arrival') {
      final workStartStr = employee.workSchedule?.startTime ?? '09:00';
      final workStart = _parseTimeToday(workStartStr);
      isLateSubmission = now.isAfter(workStart);
    }

    // ── Save to Firestore ────────────────────────────────
    final permRef = FirebaseFirestore.instance.collection('permissions').doc();
    await permRef.set({
      ...req.toMap(),
      'permissionId': permRef.id,
      'monthKey': monthKey,
      'isExceedingQuota': isExceedingQuota,
      'isSubmittedAfterWorkStart': isLateSubmission,
      'status': isLateSubmission ? 'invalid_late' : 'pending',
      'submittedAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    // ── Auto-notification to manager (via Firestore) ─────
    if (isLateSubmission) {
      // Notify employee it was auto-rejected
      await _createNotification(
        recipientId: req.userId,
        type: 'permission_invalid_late',
        title: 'طلب إذن غير مقبول',
        body: 'لا يُعتد بطلب تأخير الحضور المقدَّم بعد بداية وقت العمل وفق اللائحة',
      );
    } else {
      // Notify manager
      await _createNotification(
        recipientId: req.managerId,
        type: 'permission_request_submitted',
        title: 'طلب إذن جديد 🐺',
        body: '${req.employeeName} يطلب ${_permTypeLabel(req.permissionType)} '
              '${isExceedingQuota ? "⚠️ تجاوز الحد الشهري" : ""}',
        data: {'permissionId': permRef.id},
      );
    }
  }

  // Manager approves a permission
  Future<void> approvePermission(String permissionId, String managerId) async {
    final permDoc = await FirebaseFirestore.instance
        .collection('permissions').doc(permissionId).get();
    final perm = PermissionModel.fromFirestore(permDoc);
    
    // Update permission status
    await permDoc.reference.update({
      'status': 'approved',
      'reviewedBy': managerId,
      'reviewedAt': FieldValue.serverTimestamp(),
    });
    
    // Update employee's monthly usage counter
    await FirebaseFirestore.instance
        .collection('users').doc(perm.userId)
        .update({
          'permissionBalance.usedThisMonth': FieldValue.increment(1),
          'permissionBalance.usedHoursThisMonth':
              FieldValue.increment(perm.durationMinutes / 60.0),
        });
    
    // Notify employee
    await _createNotification(
      recipientId: perm.userId,
      type: 'permission_approved',
      title: 'تم قبول الإذن ✅',
      body: 'تمت الموافقة على ${_permTypeLabel(perm.permissionType)} ليوم ${perm.requestDate}',
    );
  }
}
```

### 4.3 Monthly Permission Quota Reset

```dart
// Since we have no Cloud Functions, reset is done CLIENT-SIDE
// When user opens the app, check if it's a new month and reset

Future<void> checkAndResetMonthlyPermissionQuota(UserModel user) async {
  final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
  
  if (user.permissionBalance['lastResetMonth'] != currentMonth) {
    await FirebaseFirestore.instance
        .collection('users').doc(user.uid)
        .update({
          'permissionBalance.usedThisMonth': 0,
          'permissionBalance.usedHoursThisMonth': 0.0,
          'permissionBalance.lastResetMonth': currentMonth,
        });
  }
}
// Called in app startup / splash screen for logged-in users
```

### 4.4 Day-Off Request Logic

```dart
Future<void> submitDayOffRequest(DayOffModel req) async {
  // 1. Validate balance
  final user = await getUserById(req.userId);
  if (req.numberOfDays > user.leaveBalance['daysOff']!) {
    throw AppException(
      'رصيدك من أيام الإجازة غير كافٍ. '
      'المتاح: ${user.leaveBalance['daysOff']} يوم'
    );
  }

  // 2. Check no overlapping day-off or leave
  // [Query check omitted for brevity — similar to leave overlap check]

  // 3. Save
  final ref = FirebaseFirestore.instance.collection('daysoff').doc();
  await ref.set({...req.toMap(), 'dayoffId': ref.id, 'status': 'pending'});

  // 4. Notify manager
  await _createNotification(
    recipientId: req.managerId,
    type: 'dayoff_request_submitted',
    title: 'طلب يوم إجازة جديد',
    body: '${req.employeeName} يطلب ${req.numberOfDays} يوم إجازة',
    data: {'dayoffId': ref.id},
  );
}

// Manager approves — atomically deduct from balance
Future<void> approveDayOff(String dayoffId, String managerId) async {
  final dayoffDoc = await FirebaseFirestore.instance
      .collection('daysoff').doc(dayoffId).get();
  final dayoff = DayOffModel.fromFirestore(dayoffDoc);
  
  final batch = FirebaseFirestore.instance.batch();
  
  // Update request status
  batch.update(dayoffDoc.reference, {
    'status': 'approved',
    'reviewedBy': managerId,
    'reviewedAt': FieldValue.serverTimestamp(),
  });
  
  // Deduct from leave balance
  batch.update(
    FirebaseFirestore.instance.collection('users').doc(dayoff.userId),
    {'leaveBalance.daysOff': FieldValue.increment(-dayoff.numberOfDays)},
  );
  
  await batch.commit();
  
  // Notify employee
  await _createNotification(
    recipientId: dayoff.userId,
    type: 'dayoff_approved',
    title: 'تم قبول يوم الإجازة ✅',
    body: 'تمت الموافقة على ${dayoff.numberOfDays} يوم إجازة',
  );
}
```

---

## PHASE 5 — Manager Dashboard

### 5.1 Manager Queries (Spark-Safe)

```dart
// Manager sees ONLY their team (employees where managerId == manager.uid)

// Team attendance today:
FirebaseFirestore.instance
    .collection('attendance')
    .where('managerId', isEqualTo: manager.uid)
    .where('date', isEqualTo: today)
    .get()  // Use get() not snapshots() to save quota

// Pending requests (all types):
Future<Map<String, List>> getAllPendingRequests(String managerId) async {
  final results = await Future.wait([
    FirebaseFirestore.instance.collection('leaves')
        .where('managerId', isEqualTo: managerId)
        .where('status', isEqualTo: 'pending').get(),
    FirebaseFirestore.instance.collection('permissions')
        .where('managerId', isEqualTo: managerId)
        .where('status', isEqualTo: 'pending').get(),
    FirebaseFirestore.instance.collection('daysoff')
        .where('managerId', isEqualTo: managerId)
        .where('status', isEqualTo: 'pending').get(),
  ]);
  
  return {
    'leaves': results[0].docs.map(LeaveModel.fromFirestore).toList(),
    'permissions': results[1].docs.map(PermissionModel.fromFirestore).toList(),
    'daysoff': results[2].docs.map(DayOffModel.fromFirestore).toList(),
  };
}
```

### 5.2 Permission Validation Display for Manager

```dart
// When manager sees a permission request, show context:
Widget buildPermissionRequestCard(PermissionModel perm) {
  return WolfCard(
    child: Column(children: [
      
      // ⚠️ Invalid late submission warning
      if (perm.isSubmittedAfterWorkStart)
        WarningBanner(
          color: AppColors.error,
          text: '⚠️ تم تقديم طلب التأخير بعد بداية وقت العمل — لا يُعتد به وفق اللائحة',
        ),
      
      // ⚠️ Quota exceeded warning
      if (perm.isExceedingQuota)
        WarningBanner(
          color: AppColors.warning,
          text: '⚠️ تجاوز الحد الشهري (إذنان / 5 ساعات) — الموافقة تستلزم خصم راتب',
        ),
      
      EmployeeInfoRow(perm),
      PermissionTypeChip(perm.permissionType),
      DateTimeRow(perm.requestDate, perm.expectedTime, perm.durationMinutes),
      ReasonText(perm.reason),
      
      // Approve/Reject only allowed if NOT invalid_late
      if (perm.status != 'invalid_late')
        ApproveRejectRow(
          onApprove: () => permissionService.approvePermission(perm.id, manager.uid),
          onReject: () => showRejectDialog(perm.id),
        ),
    ]),
  );
}
```

---

## PHASE 6 — HR Admin Panel

### 6.1 HR Data Access

```dart
// HR Admin sees ALL employees across ALL locations
// No managerId filter — sees everything

// All attendance today (all branches):
FirebaseFirestore.instance
    .collection('attendance')
    .where('date', isEqualTo: today)
    .orderBy('checkInTime', descending: false)
    .get()

// Filter by location:
.where('locationId', isEqualTo: selectedLocationId)
```

### 6.2 Secure CSV Export (No Client-Side Secrets)

```dart
class SheetsExportService {
  Future<String> exportAttendanceCsv(List<AttendanceModel> logs) async {
    final headers = [
      'كود الموظف', 'الاسم', 'القسم', 'الفرع', 'التاريخ',
      'وقت الحضور', 'وقت الانصراف', 'الحالة', 'التأخير (دقيقة)', 'ساعات العمل'
    ];

    final rows = logs.map((log) => [
      log.employeeId, log.employeeName, log.locationName, log.date,
      _formatTime(log.checkInTime), _formatTime(log.checkOutTime),
      _translateStatus(log.status), log.lateMinutes.toString(),
      (log.totalWorkHours ?? 0).toStringAsFixed(1),
    ]);

    return _toCsv([headers, ...rows]);
  }
}
```

> Direct Google Sheets writing must use a trusted backend/proxy. Do not bundle a Google Service Account key in the APK/PWA.

---

## PHASE 7 — Performance System

### 7.1 Auto-Calculated KPIs

```dart
class PerformanceService {
  
  // Auto-calculate attendance and punctuality scores from Firestore data
  Future<Map<String, double>> calculateAutoScores({
    required String userId,
    required String monthKey,
  }) async {
    final year = int.parse(monthKey.split('-')[0]);
    final month = int.parse(monthKey.split('-')[1]);
    
    // Count working days in the month (excluding Fridays/weekends)
    final totalWorkDays = _countWorkDays(year, month, employee.workSchedule.workDays);
    
    // Query attendance for the month
    final attendanceDocs = await FirebaseFirestore.instance
        .collection('attendance')
        .where('userId', isEqualTo: userId)
        .where('date', isGreaterThanOrEqualTo: '$monthKey-01')
        .where('date', isLessThanOrEqualTo: '$monthKey-31')
        .get();
    
    final presentDays = attendanceDocs.docs
        .where((d) => d.data()['status'] != 'absent')
        .length;
    
    final lateDays = attendanceDocs.docs
        .where((d) => d.data()['isLate'] == true)
        .length;
    
    final attendanceScore = (presentDays / totalWorkDays * 100).clamp(0, 100);
    final punctualityScore = presentDays > 0
        ? ((presentDays - lateDays) / presentDays * 100).clamp(0, 100)
        : 0.0;
    
    return {
      'attendance': attendanceScore,
      'punctuality': punctualityScore,
    };
  }
  
  // Manager publishes monthly review
  Future<void> publishPerformanceReview({
    required String userId,
    required String monthKey,
    required Map<String, double> managerScores, // quality, teamwork, commitment
    required String? notes,
    required String managerId,
  }) async {
    final autoScores = await calculateAutoScores(userId: userId, monthKey: monthKey);
    
    final allScores = {...autoScores, ...managerScores};
    final weights = {'attendance': 0.25, 'punctuality': 0.25, 'quality': 0.20, 'teamwork': 0.15, 'commitment': 0.15};
    
    final overallScore = weights.entries.fold<double>(
      0, (sum, e) => sum + (allScores[e.key] ?? 0) * e.value
    );
    
    final grade = overallScore >= 90 ? 'ممتاز'
        : overallScore >= 75 ? 'جيد جداً'
        : overallScore >= 60 ? 'جيد'
        : 'مقبول';
    
    final perfRef = FirebaseFirestore.instance
        .collection('performance')
        .doc('${userId}_$monthKey');
    
    await perfRef.set({
      'userId': userId,
      'managerId': managerId,
      'monthKey': monthKey,
      'scores': allScores,
      'overallScore': overallScore,
      'grade': grade,
      'managerNotes': notes,
      'isPublished': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    
    // Notify employee
    await _createNotification(
      recipientId: userId,
      type: 'performance_published',
      title: 'تقرير أدائك متاح الآن 📊',
      body: 'تم نشر تقييم أداء شهر ${_monthAr(monthKey)} — درجتك: ${overallScore.toStringAsFixed(0)}/100 ($grade)',
    );
  }
}
```

---

## PHASE 8 — Notifications (No Cloud Functions) + Build + Deploy

### 8.1 Notification Architecture (Spark Plan — No Functions)

```
STRATEGY: Firestore as notification bus + flutter_local_notifications

HOW IT WORKS:
┌──────────────────────────────────────────────────────────────────┐
│  When Event Occurs (submit leave, approve, etc.)                 │
│  → App writes to notifications/{recipientId}/items/{id}          │
│                                                                   │
│  Recipient's App (foreground/background):                        │
│  → Firestore .snapshots() listener detects new document          │
│  → Triggers flutter_local_notifications.show()                   │
│  → Shows system notification on device                           │
│                                                                   │
│  When App is CLOSED (terminated):                                │
│  → Use WorkManager (workmanager package) to poll every 15 min    │
│  → If new unread notifications found → show local notification   │
└──────────────────────────────────────────────────────────────────┘
```

### 8.2 Notification Collection Structure

```
notifications/{userId}/items/{notificationId}
  ↑ subcollection per user — Firestore listener is per-user, not global
  ↑ Security rule: only the owner can read their own notifications
```

### 8.3 Notification Implementation

```dart
// ── CREATING a notification (called from any service) ──────────
Future<void> createNotification({
  required String recipientId,
  required String type,
  required String title,
  required String body,
  Map<String, dynamic>? data,
  String? senderId,
  String? senderName,
}) async {
  final ref = FirebaseFirestore.instance
      .collection('notifications')
      .doc(recipientId)
      .collection('items')
      .doc();
  
  await ref.set({
    'notificationId': ref.id,
    'type': type,
    'title': title,
    'body': body,
    'data': data ?? {},
    'senderId': senderId,
    'senderName': senderName,
    'isRead': false,
    'createdAt': FieldValue.serverTimestamp(),
  });
  
  // Increment badge count
  await FirebaseFirestore.instance
      .collection('users').doc(recipientId)
      .update({'unreadNotifications': FieldValue.increment(1)});
}

// ── LISTENING for notifications (in NotificationService) ───────
class NotificationService {
  StreamSubscription? _subscription;
  
  void startListening(String userId) {
    _subscription = FirebaseFirestore.instance
        .collection('notifications')
        .doc(userId)
        .collection('items')
        .where('isRead', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
          for (final change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final notif = change.doc.data()!;
              _showLocalNotification(
                id: notif['notificationId'].hashCode,
                title: notif['title'],
                body: notif['body'],
                payload: jsonEncode(notif['data']),
              );
            }
          }
        });
  }
  
  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'zawolf_hr_channel',
      'ZaWolf HR',
      channelDescription: 'HR notifications',
      importance: Importance.high,
      priority: Priority.high,
      color: Color(0xFF00D4FF),
      icon: '@mipmap/wolf_notification',
    );
    
    await FlutterLocalNotificationsPlugin().show(
      id, title, body,
      const NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }
  
  // Mark notification as read
  Future<void> markAsRead(String userId, String notificationId) async {
    await FirebaseFirestore.instance
        .collection('notifications').doc(userId)
        .collection('items').doc(notificationId)
        .update({'isRead': true});
    
    await FirebaseFirestore.instance
        .collection('users').doc(userId)
        .update({'unreadNotifications': FieldValue.increment(-1)});
  }
}

// ── BACKGROUND polling with WorkManager (when app is closed) ───
// In main.dart:
Workmanager().initialize(callbackDispatcher);
Workmanager().registerPeriodicTask(
  'notification_poll',
  'checkNotifications',
  frequency: const Duration(minutes: 15),
  constraints: Constraints(networkType: NetworkType.connected),
);

// Background callback:
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    await Firebase.initializeApp();
    final userId = await SecureStorage.read('userId');
    if (userId == null) return Future.value(true);
    
    final snap = await FirebaseFirestore.instance
        .collection('notifications').doc(userId)
        .collection('items')
        .where('isRead', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(5)
        .get();
    
    for (final doc in snap.docs) {
      await NotificationService()._showLocalNotification(
        id: doc.id.hashCode,
        title: doc.data()['title'],
        body: doc.data()['body'],
      );
    }
    return Future.value(true);
  });
}
```

### 8.4 Updated pubspec.yaml

```yaml
dependencies:
  # ... (all previous dependencies) ...
  
  # Notifications (replaces FCM Cloud Functions)
  flutter_local_notifications: ^16.1.0
  workmanager: ^0.5.2

  # Realtime notifications badge
  badges: ^3.1.2
```

### 8.5 Firestore Security Rules (Complete — All Features)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    function isAuth() { return request.auth != null; }
    function uid() { return request.auth.uid; }
    function userDoc() {
      return get(/databases/$(database)/documents/users/$(uid())).data;
    }
    function role() { return userDoc().role; }
    function isEmployee() { return role() == 'employee'; }
    function isManager() { return role() == 'manager' || role() == 'hr_admin'; }
    function isHR() { return role() == 'hr_admin'; }
    function isOwner(docUserId) { return uid() == docUserId; }
    function isMyManager(managerId) { return uid() == managerId; }
    
    // ── COMPANY ──────────────────────────────────────────
    match /companies/{companyId} {
      allow read: if isAuth();
      allow write: if isAuth() && isHR();
    }
    
    // ── LOCATIONS ────────────────────────────────────────
    match /locations/{locationId} {
      allow read: if isAuth();
      allow write: if isAuth() && isHR();
    }
    
    // ── USERS ────────────────────────────────────────────
    match /users/{userId} {
      allow read: if isAuth() && (isOwner(userId) || isManager());
      // Employee can update own: password, photoURL, deviceToken, permissionBalance
      allow update: if isAuth() && isOwner(userId)
          && request.resource.data.diff(resource.data)
             .affectedKeys().hasOnly([
               'passwordChangedAt', 'photoURL', 'unreadNotifications',
               'permissionBalance', 'notificationTokens'
             ]);
      // HR can do full write
      allow write: if isAuth() && isHR();
    }
    
    // ── ATTENDANCE ───────────────────────────────────────
    match /attendance/{attendanceId} {
      allow read: if isAuth() && (
        isOwner(resource.data.userId) ||
        isMyManager(resource.data.managerId) ||
        isHR()
      );
      allow create: if isAuth() && request.resource.data.userId == uid();
      allow update: if isAuth() && (
        (isOwner(resource.data.userId) &&
         request.resource.data.diff(resource.data)
           .affectedKeys().hasOnly(['checkOutTime','localCheckOutTime','checkOutLocation','totalWorkHours'])) ||
        isHR()
      );
      allow delete: if isAuth() && isHR();
    }
    
    // ── LEAVES ───────────────────────────────────────────
    match /leaves/{leaveId} {
      allow read: if isAuth() && (
        isOwner(resource.data.userId) ||
        isMyManager(resource.data.managerId) ||
        isHR()
      );
      allow create: if isAuth() && request.resource.data.userId == uid();
      allow update: if isAuth() && (
        (isOwner(resource.data.userId) && resource.data.status == 'pending'
         && request.resource.data.status == 'cancelled') ||
        isMyManager(resource.data.managerId) ||
        isHR()
      );
      allow delete: if isAuth() && isHR();
    }
    
    // ── PERMISSIONS (إذن) ─────────────────────────────────
    match /permissions/{permissionId} {
      allow read: if isAuth() && (
        isOwner(resource.data.userId) ||
        isMyManager(resource.data.managerId) ||
        isHR()
      );
      allow create: if isAuth() && request.resource.data.userId == uid();
      allow update: if isAuth() && (
        (isOwner(resource.data.userId) && resource.data.status == 'pending'
         && request.resource.data.status == 'cancelled') ||
        isMyManager(resource.data.managerId) ||
        isHR()
      );
      allow delete: if isAuth() && isHR();
    }
    
    // ── DAYS OFF ──────────────────────────────────────────
    match /daysoff/{dayoffId} {
      allow read: if isAuth() && (
        isOwner(resource.data.userId) ||
        isMyManager(resource.data.managerId) ||
        isHR()
      );
      allow create: if isAuth() && request.resource.data.userId == uid();
      allow update: if isAuth() && (
        (isOwner(resource.data.userId) && resource.data.status == 'pending'
         && request.resource.data.status == 'cancelled') ||
        isMyManager(resource.data.managerId) ||
        isHR()
      );
    }
    
    // ── PERFORMANCE ───────────────────────────────────────
    match /performance/{performanceId} {
      allow read: if isAuth() && (
        isOwner(resource.data.userId) ||
        isMyManager(resource.data.managerId) ||
        isHR()
      );
      // Only managers/HR can create or update performance reviews
      allow write: if isAuth() && isManager();
    }
    
    // ── NOTIFICATIONS ─────────────────────────────────────
    match /notifications/{userId}/items/{notificationId} {
      // Only the recipient can read their own notifications
      allow read: if isAuth() && uid() == userId;
      // Anyone authenticated can create a notification for anyone
      // (controlled by app logic — manager creates for employee, etc.)
      allow create: if isAuth();
      // Only recipient can mark as read
      allow update: if isAuth() && uid() == userId
          && request.resource.data.diff(resource.data)
             .affectedKeys().hasOnly(['isRead']);
      allow delete: if isAuth() && uid() == userId;
    }
  }
}
```

### 8.6 Firebase Quota Budget (Spark Plan Monitoring)

```
DAILY FIRESTORE READ BUDGET: 50,000 reads

Estimated consumption for 50 employees:
├── Login (fetch user doc):         50 reads/day
├── Employee dashboard open:        50 reads/day
├── Check-in today query:           50 reads/day
├── Manager team attendance:        5 reads × 5 managers = 25/day
├── Pending requests (manager):     15 reads × 5 managers = 75/day
├── Notification checks (listener): ~100 reads/day (real-time)
├── HR dashboard queries:           50 reads/day
├── Leave balance checks:           100 reads/day
└── TOTAL ESTIMATE:                 ≈ 500 reads/day for 50 employees
                                    (well under 50,000 limit ✅)

MONTHLY EXPORT:
├── 50 employees × 31 days = 1,550 reads once/month ✅

SAFE THRESHOLDS:
- Keep individual user listeners minimal
- Use .get() for list screens, .snapshots() only for notifications
- Archive attendance > 90 days old via CSV export before deleting from Firestore
```

### 8.7 Offline Persistence

```dart
// Enable in main.dart before runApp
FirebaseFirestore.instance.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
);

// Anti-tamper: always use serverTimestamp()
// Store localTimestamp separately for audit
// If gap between local and server > 10 minutes → flag record as suspicious
```

### 8.8 Android Build & Distribution

```bash
# Generate release keystore
keytool -genkey -v -keystore zawolf-hr.keystore \
  -alias zawolf -keyalg RSA -keysize 2048 -validity 10000

# Build release APK with obfuscation
flutter build apk --release \
  --obfuscate \
  --split-debug-info=build/debug-info \
  --split-per-abi

# Recommended file to distribute:
# build/app/outputs/apk/release/app-arm64-v8a-release.apk

# Share via:
# 1. Google Drive company folder → QR code
# 2. WhatsApp group download link
```

### 8.9 PWA / iOS Deployment

```bash
flutter build web --release --web-renderer canvaskit --pwa-strategy offline-first
firebase init hosting   # public dir: build/web
firebase deploy --only hosting

# App URL: https://hr.zawolf.ai (custom domain via Firebase Hosting)
# iOS: Safari → Share → Add to Home Screen
# Works offline for cached screens
```

---

## 🤖 AI Agent — Step-by-Step Execution Prompt

```
═══════════════════════════════════════════════════════
AGENT: BUILD ZAWOLF HR SYSTEM — EXECUTE IN ORDER
═══════════════════════════════════════════════════════

STEP 1 [Google Stitch MCP]
Run the Stitch Prompt from Phase 0.
Design all 21 screens with ZaWolf brand tokens.
Export Flutter widget code for each screen.

STEP 2 [Flutter Setup]
flutter create zawolf_hr
Apply project structure from Phase 1.
Add all pubspec.yaml dependencies and install.
Configure flutter_launcher_icons with wolf logo.
Configure flutter_native_splash (dark bg #07070F).

STEP 3 [Firebase MCP]
Connect Firebase MCP.
Create all Firestore collections with schemas from Phase 1.
Seed: 1 company doc, 2 test locations, 3 test users (1 each role).
Apply Security Rules from Phase 8.5.
Enable Firestore offline persistence.

STEP 4 [Theme & Components]
Create zawolf_theme.dart with all tokens from Brand System.
Build: WolfButton (5 variants), WolfCard, WolfInputField,
StatusBadge, PermissionBadge, DayOffBadge, GradeChip,
WolfBottomNav (3 variants per role), WolfAppBar.
Integrate all Stitch screen exports.

STEP 5 [Auth System — Phase 2]
Build login screen (no self-register).
AuthService: signIn → fetch role → route to correct dashboard.
PasswordChangeService: reauth → update → log.
HR: AccountCreationService with initial password generator.
go_router: role guards for all route groups.

STEP 6 [Multi-Location Geofencing — Phase 3]
LocationService: CRUD for locations collection.
GeofenceService: per-employee location validation.
Build locations management screen for HR admin.
Map view with wolf-pin markers per branch.

STEP 7 [Employee Features — Phase 4]
Attendance: check-in/out with geofence + late detection.
PermissionService: full إذن system with quota, validation,
                   auto-rejection of late-submitted late-arrival.
DayOffService: request + balance deduction on approval.
LeaveService: annual/sick/casual with attachment upload.
Monthly quota reset on app launch.

STEP 8 [Notifications — Phase 8]
NotificationService: createNotification() helper.
Firestore listener: notifications/{uid}/items → flutter_local_notifications.
WorkManager: 15-min background poll for closed-app notifications.
Wire all services to call createNotification() on every state change.

STEP 9 [Manager Dashboard — Phase 5]
Manager home: team summary, pending requests banner.
Requests screen: unified tabs for leaves/permissions/daysoff.
Permission card: show invalid-late banner, quota-exceeded warning.
Team attendance screen with filters.
Performance management: sliders + auto-score + publish.

STEP 10 [HR Admin Panel — Phase 6]
HR dashboard: all-locations summary, filterable.
Add/edit employee: full form with role + location + balance setup.
Locations management: add/edit/delete with geofence radius.
SheetsExportService: attendance + leave + performance exports.
Announcement system: write to notifications collection.

STEP 11 [Performance System — Phase 7]
PerformanceService: auto-calculate attendance + punctuality.
Manager review: quality + teamwork + commitment sliders.
Overall score: weighted formula.
Grade assignment + publish to employee.
Employee performance screen: score card + KPIs + history chart.

STEP 12 [Security & Testing]
Apply all Firestore rules from Phase 8.5.
Test: employee cannot read another's data.
Test: late-arrival permission submitted after 09:00 → auto-invalid.
Test: 3rd permission → isExceedingQuota = true → warning shown.
Test: day-off approval → balance deducted atomically.
Test: offline check-in → syncs on reconnect.
App Check: enable PlayIntegrity for Android.

STEP 13 [Build & Deploy]
Android: flutter build apk --release (arm64, obfuscated).
PWA: flutter build web → firebase deploy --only hosting.
Generate QR code for APK link.
Create employee PDF guide (Arabic).
Create HR admin PDF guide (Arabic).

═══════════════════════════════════════════════════════
DELIVER WHEN COMPLETE:
- Full Flutter project (all source code)
- Firebase security rules file (firestore.rules)
- Secure CSV export instructions
- 2 PDF guides (Employee + HR Admin, Arabic)
- APK file + PWA deployment URL
═══════════════════════════════════════════════════════
```

---

## 📋 Quick Reference

### Collections Summary
| Collection | Key Fields | Who Creates | Listeners Used? |
|-----------|-----------|-------------|----------------|
| `companies` | workSchedule, permissionPolicy | HR | get() only |
| `locations` | lat/lng, geofenceRadius | HR | get() only |
| `users` | role, leaveBalance, permissionBalance | HR | get() on login |
| `attendance` | date, status, isLate | Employee | get() |
| `leaves` | leaveType, status, days | Employee | get() |
| `permissions` | permissionType, quota flags | Employee | get() |
| `daysoff` | numberOfDays, status | Employee | get() |
| `performance` | scores, grade, isPublished | Manager | get() |
| `notifications/{uid}/items` | type, isRead | Any | **.snapshots() ← only here** |

### Monthly Costs
| Service | Limit | Our Usage | Cost |
|---------|-------|-----------|------|
| Firestore reads | 50K/day | ~500/day | **FREE** |
| Firestore writes | 20K/day | ~200/day | **FREE** |
| Hosting | 10GB/month | <1GB | **FREE** |
| Storage | 5GB | ~500MB | **FREE** |
| Auth | Unlimited | 50 users | **FREE** |
| **TOTAL** | | | **$0/month** |

---

*ZaWolf HR System — Master Plan v2.0*  
*ZaWolf.AI · zawolf.ai*  
*Flutter · Firebase Spark · Google Stitch · Secure CSV export · No backend server*

API Keys:
[REDACTED_API_KEY]
OneSignal App ID :
b1f85662-d1d6-4629-969c-ed843350baed



hr:
Email: hr@zawolf.com
Password: ZW@admin
employee :
Email: employee2@zawolf.com
Password: ZW@0002
Manger:
Email: manger1@zawolf.com
Password: ZW@0003
Super admin:
Email: ceo@zawolf.com
Password: ZW@0000