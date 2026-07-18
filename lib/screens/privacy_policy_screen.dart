import 'package:flutter/material.dart';

import '../theme/theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _sections = <(String, String)>[
    (
      'البيانات التي نعالجها',
      'يعالج ZaWolf HR بيانات الحساب والعمل التي تقدمها الشركة، مثل الاسم والبريد الإلكتروني والرقم الوظيفي والقسم والمسمى الوظيفي والمدير والطلبات والمهام والحضور والرواتب والتقييمات. وقد يعالج معرف الجهاز المرتبط بالحضور لحماية الحساب من الاستخدام غير المصرح به.',
    ),
    (
      'الموقع',
      'نطلب الموقع الدقيق فقط أثناء فتح شاشة الحضور وبدء تسجيل الحضور أو الانصراف يدوياً، للتحقق من وجودك داخل نطاق فرع العمل. لا يستخدم الإصدار العام الموقع لتتبعك باستمرار في الخلفية، ولا نستخدمه للإعلانات.',
    ),
    (
      'البصمة وFace ID',
      'تتم المصادقة الحيوية بواسطة نظام تشغيل الهاتف. لا يستلم التطبيق ولا يخزن صورة بصمتك أو وجهك.',
    ),
    (
      'الإشعارات والمنبه',
      'يمكنك اختيار تفعيل إشعارات العمل ومنبه الحضور. رفض الإذن لا يمنع استخدام التطبيق. قد تشمل الرسائل تذكيرات الحضور، وتحديثات الطلبات، والمهام. يمكنك تعديل الأذونات من إعدادات الهاتف.',
    ),
    (
      'مقدمو الخدمة',
      'نستخدم Firebase للمصادقة وقاعدة البيانات والملفات، وOneSignal لتوصيل الإشعارات، وخدمات الخرائط والموقع من Google وApple حسب جهازك. تعالج هذه الجهات البيانات بالقدر اللازم لتقديم الخدمة ووفق سياساتها.',
    ),
    (
      'المشاركة والاحتفاظ والأمان',
      'لا نبيع بيانات الموظفين. تتاح البيانات فقط للأدوار المخولة داخل الشركة ولمقدمي الخدمة اللازمين للتشغيل. نحتفظ بها وفق متطلبات العمل والقانون، ونستخدم صلاحيات وصول وربط الجهاز ووسائل حماية تقنية للحد من الوصول غير المصرح به.',
    ),
    (
      'حقوقك والتواصل',
      'لطلب الوصول إلى بياناتك أو تصحيحها أو حذفها، تواصل مع إدارة الموارد البشرية في شركتك أو عبر البريد zbooma.program@gmail.com. قد نحتفظ ببعض السجلات عندما يفرض القانون أو متطلبات الرواتب ذلك.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('سياسة الخصوصية')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'ZaWolf HR',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: ZaWolfColors.primaryCyan,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text('آخر تحديث: 18 يوليو 2026'),
            const SizedBox(height: 20),
            for (final section in _sections) ...[
              Text(
                section.$1,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(section.$2, style: const TextStyle(height: 1.65)),
              const SizedBox(height: 18),
            ],
          ],
        ),
      ),
    );
  }
}
