import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/entities/custom_request_template.dart';
import '../domain/repositories/custom_request_template_repository.dart';

class CustomRequestTemplateRepositoryImpl implements CustomRequestTemplateRepository {
  CustomRequestTemplateRepositoryImpl({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static List<CustomRequestType> get defaultCoreRequestTypes => [
    const CustomRequestType(
      id: 'core_leaves',
      nameAr: 'الإجازات (Leave Requests)',
      category: 'leave',
      descriptionAr: 'طلبات الإجازات السنوية والعارضة والمرضية بمختلف أنواعها',
      isActive: true,
      subtypes: ['إجازة سنوية (اعتيادية)', 'إجازة عارضة', 'إجازة مرضية', 'إجازة بدون راتب', 'إجازة حج / عمرة', 'إجازة وضع / رعاية'],
      subtypeConfigs: [
        CustomSubtypeConfig(nameAr: 'إجازة سنوية (اعتيادية)', deductsFromQuota: true, quotaKey: 'daysOff'),
        CustomSubtypeConfig(nameAr: 'إجازة عارضة', deductsFromQuota: true, quotaKey: 'casual'),
        CustomSubtypeConfig(nameAr: 'إجازة مرضية', deductsFromQuota: false, quotaKey: 'none', requiresAttachment: true),
        CustomSubtypeConfig(nameAr: 'إجازة بدون راتب', deductsFromQuota: false, quotaKey: 'none'),
        CustomSubtypeConfig(nameAr: 'إجازة حج / عمرة', deductsFromQuota: false, quotaKey: 'none'),
        CustomSubtypeConfig(nameAr: 'إجازة وضع / رعاية', deductsFromQuota: false, quotaKey: 'none', requiresAttachment: true),
      ],
      fields: [
        CustomRequestField(key: 'startDate', labelAr: 'تاريخ بداية الإجازة', type: 'date', isRequired: true),
        CustomRequestField(key: 'endDate', labelAr: 'تاريخ نهاية الإجازة', type: 'date', isRequired: true),
        CustomRequestField(key: 'reason', labelAr: 'سبب أو تفاصيل الإجازة', type: 'text', isRequired: false),
      ],
      approvalSteps: [
        ApprovalChainStep(stepId: 'step_1', order: 1, approverType: 'direct_manager', labelAr: 'المدير المباشر'),
        ApprovalChainStep(stepId: 'step_2', order: 2, approverType: 'hr', department: 'hr', labelAr: 'الموارد البشرية (HR)'),
        ApprovalChainStep(stepId: 'step_3', order: 3, approverType: 'ceo', labelAr: 'الرئيس التنفيذي (CEO - للطلبات الأكثر من 3 أيام)', conditionType: 'days_threshold', minDays: 3),
      ],
    ),
    const CustomRequestType(
      id: 'core_permissions',
      nameAr: 'الأذونات والاستئذان (Permission Requests)',
      category: 'permission',
      descriptionAr: 'طلبات التأخير الصباحي والخروج المبكر وساعات الإذن الشهرية',
      isActive: true,
      monthlyQuotaCount: 2,
      monthlyQuotaHours: 4.0,
      subtypes: ['إذن تأخير صباحي', 'إذن انصراف مبكر', 'إذن خروج مؤقت أثناء العمل'],
      subtypeConfigs: [
        CustomSubtypeConfig(nameAr: 'إذن تأخير صباحي', deductsFromQuota: true, quotaKey: 'permissions'),
        CustomSubtypeConfig(nameAr: 'إذن انصراف مبكر', deductsFromQuota: true, quotaKey: 'permissions'),
        CustomSubtypeConfig(nameAr: 'إذن خروج مؤقت أثناء العمل', deductsFromQuota: true, quotaKey: 'permissions'),
      ],
      fields: [
        CustomRequestField(key: 'date', labelAr: 'تاريخ الإذن', type: 'date', isRequired: true),
        CustomRequestField(key: 'hours', labelAr: 'عدد الساعات المطلوبة', type: 'number', isRequired: true),
        CustomRequestField(key: 'reason', labelAr: 'السبب', type: 'text', isRequired: true),
      ],
      approvalSteps: [
        ApprovalChainStep(stepId: 'step_1', order: 1, approverType: 'direct_manager', labelAr: 'المدير المباشر'),
        ApprovalChainStep(stepId: 'step_2', order: 2, approverType: 'hr', department: 'hr', labelAr: 'الموارد البشرية (HR)'),
      ],
    ),
    const CustomRequestType(
      id: 'core_advances',
      nameAr: 'السلف المالية (Salary Advance Requests)',
      category: 'financial',
      descriptionAr: 'طلبات السلف على الراتب وجدولة الاستقطاع الشهري',
      isActive: true,
      subtypes: ['سلفة راتب شهرية', 'سلفة علاجية / طارئة', 'سلفة شراء أجهزة'],
      subtypeConfigs: [
        CustomSubtypeConfig(nameAr: 'سلفة راتب شهرية', deductsFromQuota: false, quotaKey: 'none'),
        CustomSubtypeConfig(nameAr: 'سلفة علاجية / طارئة', deductsFromQuota: false, quotaKey: 'none', requiresAttachment: true),
        CustomSubtypeConfig(nameAr: 'سلفة شراء أجهزة', deductsFromQuota: false, quotaKey: 'none'),
      ],
      fields: [
        CustomRequestField(key: 'amount', labelAr: 'المبلغ المطلوب', type: 'number', isRequired: true),
        CustomRequestField(key: 'repaymentMonths', labelAr: 'عدد شهور التقسيط', type: 'number', isRequired: true),
        CustomRequestField(key: 'reason', labelAr: 'سبب السلفة', type: 'text', isRequired: false),
      ],
      approvalSteps: [
        ApprovalChainStep(stepId: 'step_1', order: 1, approverType: 'direct_manager', labelAr: 'المدير المباشر'),
        ApprovalChainStep(stepId: 'step_2', order: 2, approverType: 'hr', department: 'hr', labelAr: 'الموارد البشرية (HR)'),
        ApprovalChainStep(stepId: 'step_3', order: 3, approverType: 'accounting', department: 'accounting', labelAr: 'الحسابات والمالية'),
        ApprovalChainStep(stepId: 'step_4', order: 4, approverType: 'ceo', labelAr: 'الرئيس التنفيذي (CEO - للمبالغ أكثر من 5000)', conditionType: 'amount_threshold', minAmount: 5000),
      ],
    ),
    const CustomRequestType(
      id: 'core_resignations',
      nameAr: 'الاستقالات ونهاية الخدمة (Exit / Resignation Requests)',
      category: 'general',
      descriptionAr: 'طلبات إنهاء التعاقد وإجراءات تسليم العهد وتصفية المستحقات',
      isActive: true,
      subtypes: ['استقالة عادية مع فترة إشعار', 'إنهاء تعاقد فوري بالتراضي', 'عدم الرغبة في تجديد العقد السنوي'],
      fields: [
        CustomRequestField(key: 'lastWorkingDay', labelAr: 'آخر يوم عمل مرغوب', type: 'date', isRequired: true),
        CustomRequestField(key: 'reason', labelAr: 'أسباب الاستقالة / إنهاء الخدمة', type: 'text', isRequired: true),
        CustomRequestField(key: 'handoverNotes', labelAr: 'خطة تسليم المهام والعهد', type: 'text', isRequired: false),
      ],
      approvalSteps: [
        ApprovalChainStep(stepId: 'step_1', order: 1, approverType: 'direct_manager', labelAr: 'المدير المباشر'),
        ApprovalChainStep(stepId: 'step_2', order: 2, approverType: 'hr', department: 'hr', labelAr: 'الموارد البشرية (HR - إخلاء طرف)'),
        ApprovalChainStep(stepId: 'step_3', order: 3, approverType: 'accounting', department: 'accounting', labelAr: 'الحسابات (المستحقات والمخالصة)'),
        ApprovalChainStep(stepId: 'step_4', order: 4, approverType: 'ceo', labelAr: 'الرئيس التنفيذي (الاعتماد النهائي)'),
      ],
    ),
    const CustomRequestType(
      id: 'core_field_missions',
      nameAr: 'المأموريات والمهام الميدانية (Field Missions)',
      category: 'general',
      descriptionAr: 'طلبات التكليف بمهام عمل ميدانية أو زيارات عملاء خارج مقر الشركة',
      isActive: true,
      subtypes: ['مأمورية محلية (داخل النطاق)', 'مأمورية سفر (خارجية)', 'زيارة عميل / موقع ميداني'],
      fields: [
        CustomRequestField(key: 'date', labelAr: 'تاريخ المأمورية', type: 'date', isRequired: true),
        CustomRequestField(key: 'location', labelAr: 'مكان / وجهة المأمورية', type: 'text', isRequired: true),
        CustomRequestField(key: 'purpose', labelAr: 'الهدف من المأمورية', type: 'text', isRequired: true),
      ],
      approvalSteps: [
        ApprovalChainStep(stepId: 'step_1', order: 1, approverType: 'direct_manager', labelAr: 'المدير المباشر'),
        ApprovalChainStep(stepId: 'step_2', order: 2, approverType: 'hr', department: 'hr', labelAr: 'الموارد البشرية (HR)'),
        ApprovalChainStep(stepId: 'step_3', order: 3, approverType: 'coo', labelAr: 'المدير التنفيذي للعمليات (COO)'),
      ],
    ),
    const CustomRequestType(
      id: 'core_attendance_correction',
      nameAr: 'تصحيح البصمة والحضور (Attendance Correction)',
      category: 'permission',
      descriptionAr: 'طلبات تصحيح نسيان تسجيل البصمة أو معالجة الأعطال الفنية',
      isActive: true,
      subtypes: ['نسيان تسجيل دخول', 'نسيان تسجيل خروج', 'عطل بجهاز البصمة أو التطبيق'],
      fields: [
        CustomRequestField(key: 'date', labelAr: 'تاريخ اليوم المطلوب تصحيحه', type: 'date', isRequired: true),
        CustomRequestField(key: 'exactTime', labelAr: 'الوقت الفعلي المطلوب إثباته', type: 'text', isRequired: true),
        CustomRequestField(key: 'reason', labelAr: 'سبب عدم التسجيل', type: 'text', isRequired: true),
      ],
      approvalSteps: [
        ApprovalChainStep(stepId: 'step_1', order: 1, approverType: 'direct_manager', labelAr: 'المدير المباشر'),
        ApprovalChainStep(stepId: 'step_2', order: 2, approverType: 'hr', department: 'hr', labelAr: 'الموارد البشرية (HR)'),
      ],
    ),
    const CustomRequestType(
      id: 'core_complaints',
      nameAr: 'الشكاوى والتظلمات الإدارية (Complaints & Grievances)',
      category: 'general',
      descriptionAr: 'تقديم شكاوى إدارية أو تظلمات من جزاءات أو بيئة العمل',
      isActive: true,
      subtypes: ['تظلم من جزاء أو خصم', 'شكوى بخصوص بيئة العمل', 'اقتراح إداري سري'],
      fields: [
        CustomRequestField(key: 'subject', labelAr: 'موضوع الشكوى أو التظلم', type: 'text', isRequired: true),
        CustomRequestField(key: 'details', labelAr: 'تفاصيل الواقعة أو الطلب', type: 'text', isRequired: true),
      ],
      approvalSteps: [
        ApprovalChainStep(stepId: 'step_1', order: 1, approverType: 'hr', department: 'hr', labelAr: 'الموارد البشرية (HR)'),
        ApprovalChainStep(stepId: 'step_2', order: 2, approverType: 'ceo', labelAr: 'الرئيس التنفيذي (CEO)'),
      ],
    ),
    const CustomRequestType(
      id: 'core_administrative',
      nameAr: 'الطلبات والشهادات الإدارية (Administrative Requests)',
      category: 'administrative',
      descriptionAr: 'طلب شهادة خبرة، بيان مفردات مرتب، أو خطابات رسمية للجهات',
      isActive: true,
      subtypes: ['شهادة خبرة', 'بيان مفردات مرتب موجه لبنك', 'خطاب تعريف بالعمل', 'طلب مستندات رسمية'],
      subtypeConfigs: [
        CustomSubtypeConfig(nameAr: 'شهادة خبرة', deductsFromQuota: false, quotaKey: 'none'),
        CustomSubtypeConfig(nameAr: 'بيان مفردات مرتب موجه لبنك', deductsFromQuota: false, quotaKey: 'none'),
        CustomSubtypeConfig(nameAr: 'خطاب تعريف بالعمل', deductsFromQuota: false, quotaKey: 'none'),
        CustomSubtypeConfig(nameAr: 'طلب مستندات رسمية', deductsFromQuota: false, quotaKey: 'none'),
      ],
      fields: [
        CustomRequestField(key: 'addressedTo', labelAr: 'الجهة الموجه إليها الخطاب', type: 'text', isRequired: true),
        CustomRequestField(key: 'notes', labelAr: 'ملاحظات إضافية', type: 'text', isRequired: false),
      ],
      approvalSteps: [
        ApprovalChainStep(stepId: 'step_1', order: 1, approverType: 'hr', department: 'hr', labelAr: 'الموارد البشرية (HR)'),
      ],
    ),
    const CustomRequestType(
      id: 'core_it_support',
      nameAr: 'طلبات تقنية المعلومات والأجهزة (IT Support & Assets)',
      category: 'general',
      descriptionAr: 'طلب جهاز عمل أو لابتوب جديد، صلاحيات وصول للأنظمة، أو صيانة ودعم فني IT',
      isActive: true,
      subtypes: ['طلب جهاز لابتوب / كمبيوتر عمل', 'طلب صلاحيات وصول لأنظمة الشركة', 'طلب بريد إلكتروني أو رخصة برمجية', 'صيانة واستبدال جهاز تالف'],
      fields: [
        CustomRequestField(key: 'requestDetail', labelAr: 'تفاصيل الطلب أو الجهاز المطلوب', type: 'text', isRequired: true),
        CustomRequestField(key: 'reason', labelAr: 'سبب الاحتياج ومبرر العمل', type: 'text', isRequired: true),
      ],
      approvalSteps: [
        ApprovalChainStep(stepId: 'step_1', order: 1, approverType: 'direct_manager', labelAr: 'المدير المباشر'),
        ApprovalChainStep(stepId: 'step_2', order: 2, approverType: 'it', department: 'it', labelAr: 'إدارة تقنية المعلومات (IT)'),
        ApprovalChainStep(stepId: 'step_3', order: 3, approverType: 'hr', department: 'hr', labelAr: 'الموارد البشرية (HR)'),
      ],
    ),
  ];

  @override
  Future<List<CustomRequestType>> loadRequestTypes() async {
    final snap = await _firestore.collection('customRequestTypes').get();
    final customTypes = snap.docs
        .map((doc) => CustomRequestType.fromMap(doc.data(), doc.id))
        .toList();

    final savedMap = {for (final t in customTypes) t.id: t};
    final merged = <CustomRequestType>[];

    for (final defaultType in defaultCoreRequestTypes) {
      if (savedMap.containsKey(defaultType.id)) {
        merged.add(savedMap[defaultType.id]!);
      } else {
        merged.add(defaultType);
      }
    }

    for (final custom in customTypes) {
      if (!merged.any((m) => m.id == custom.id)) {
        merged.add(custom);
      }
    }

    return merged;
  }

  @override
  Future<void> saveRequestType(CustomRequestType requestType) async {
    final ref = requestType.id.isEmpty
        ? _firestore.collection('customRequestTypes').doc()
        : _firestore.collection('customRequestTypes').doc(requestType.id);

    final toSave = CustomRequestType(
      id: ref.id,
      nameAr: requestType.nameAr,
      category: requestType.category,
      descriptionAr: requestType.descriptionAr,
      isActive: requestType.isActive,
      subtypes: requestType.subtypes,
      subtypeConfigs: requestType.subtypeConfigs,
      fields: requestType.fields,
      approvalSteps: requestType.approvalSteps,
      monthlyQuotaCount: requestType.monthlyQuotaCount,
      monthlyQuotaHours: requestType.monthlyQuotaHours,
      updatedAt: DateTime.now(),
    );

    await ref.set(toSave.toMap(), SetOptions(merge: true));
  }

  @override
  Future<void> deleteRequestType(String id) async {
    await _firestore.collection('customRequestTypes').doc(id).delete();
  }
}
