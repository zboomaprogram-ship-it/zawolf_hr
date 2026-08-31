# إصدار Phase 006 — مركز ملفات الشركة

## نطاق الإصدار

- نشر Flutter Hosting فقط لا يغيّر قواعد Firestore ولا ينقل بيانات.
- حزمة Hostinger المرافقة يجب أن تحتوي `workspace/` وكل وحدات Node المطلوبة.
- يظل `company_workspace_v2` مغلقاً افتراضياً؛ لا يبدّل هذا الإصدار المستخدمين
  إلى المسار الجديد تلقائياً.

## ترتيب النشر

1. ارفع حزمة Hostinger الجديدة، ثم نفّذ `npm install` و`npm start` من لوحة
   Node.js في Hostinger.
2. تحقق من `https://notification.zawolf.ai/health`. يلزم أن تكون خدمة Google
   مهيأة، وألا يظهر خطأ حديث في `diagnostics.workspace`.
3. انشر واجهة Flutter إلى Firebase Hosting.
4. نفّذ تجربة بحساب Pilot على مجلد Google تجريبي فقط: عرض، تعديل خلية، إضافة
   صف/عمود/ورقة، رفع ملف، وتنزيله، ثم أنشئ تقرير النشاط.
5. راجع ملف التقرير وسجل التدقيق قبل توسيع نطاق الـ Pilot.

## متغيرات Hostinger المطلوبة

- `FIREBASE_SERVICE_ACCOUNT`
- `GOOGLE_SHEETS_SERVICE_ACCOUNT`
- `GOOGLE_WORKSPACE_ROOT_FOLDER_ID`
- `GOOGLE_WORKSPACE_ALLOWED_ORIGINS` عند وجود نطاق واجهة إضافي
- متغيرات الإشعارات الحالية كما هي.

لا تُدرج أي مفاتيح أو ملف حساب خدمة في ZIP أو Flutter أو Git.

## التراجع

إذا فشل اختبار Workspace V2، أوقف الـ pilot feature flag؛ يبقى مركز الملفات
القديم متاحاً. وإذا كان عطل Hostinger متعلقاً بالحزمة الجديدة، أعد رفع حزمة
Hostinger السابقة ثم أعد تشغيل Node.js. لا يلزم حذف بيانات أو تغيير قواعد
Firestore للتراجع.
