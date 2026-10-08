/// Configuration model for dynamic request types and custom approval workflows.
class CustomSubtypeConfig {
  final String nameAr;
  final bool deductsFromQuota;
  final String quotaKey; // 'daysOff', 'casual', 'none'
  final bool requiresAttachment;
  final int? maxDays;

  const CustomSubtypeConfig({
    required this.nameAr,
    this.deductsFromQuota = true,
    this.quotaKey = 'daysOff',
    this.requiresAttachment = false,
    this.maxDays,
  });

  Map<String, dynamic> toMap() => {
    'nameAr': nameAr,
    'deductsFromQuota': deductsFromQuota,
    'quotaKey': quotaKey,
    'requiresAttachment': requiresAttachment,
    'maxDays': maxDays,
  };

  factory CustomSubtypeConfig.fromMap(Map<String, dynamic> map) => CustomSubtypeConfig(
    nameAr: map['nameAr'] as String? ?? '',
    deductsFromQuota: map['deductsFromQuota'] as bool? ?? true,
    quotaKey: map['quotaKey'] as String? ?? 'daysOff',
    requiresAttachment: map['requiresAttachment'] as bool? ?? false,
    maxDays: (map['maxDays'] as num?)?.toInt(),
  );
}

class CustomRequestField {
  final String key;
  final String labelAr;
  final String type; // 'text', 'number', 'date', 'checkbox', 'dropdown', 'upload'
  final bool isRequired;
  final List<String> dropdownOptions;

  const CustomRequestField({
    required this.key,
    required this.labelAr,
    this.type = 'text',
    this.isRequired = false,
    this.dropdownOptions = const [],
  });

  Map<String, dynamic> toMap() => {
    'key': key,
    'labelAr': labelAr,
    'type': type,
    'isRequired': isRequired,
    'dropdownOptions': dropdownOptions,
  };

  factory CustomRequestField.fromMap(Map<String, dynamic> map) => CustomRequestField(
    key: map['key'] as String? ?? '',
    labelAr: map['labelAr'] as String? ?? '',
    type: map['type'] as String? ?? 'text',
    isRequired: map['isRequired'] as bool? ?? false,
    dropdownOptions: (map['dropdownOptions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
  );
}

class ApprovalChainStep {
  final String stepId;
  final int order;
  final String approverType; // 'direct_manager', 'department_pool', 'coo', 'ceo', 'specific_user', 'hr', 'accounting', 'legal', 'it'
  final String labelAr;
  final String? department; // e.g. 'it', 'hr', 'legal', 'accounting'
  final String? specificUserId;
  final String? specificUserName;
  final String conditionType; // 'always', 'days_threshold', 'amount_threshold'
  final int? minDays;
  final int? maxDays;
  final double? minAmount;
  final double? maxAmount;
  final List<String> applicableSubtypes;

  const ApprovalChainStep({
    required this.stepId,
    required this.order,
    required this.approverType,
    required this.labelAr,
    this.department,
    this.specificUserId,
    this.specificUserName,
    this.conditionType = 'always',
    this.minDays,
    this.maxDays,
    this.minAmount,
    this.maxAmount,
    this.applicableSubtypes = const [],
  });

  Map<String, dynamic> toMap() => {
    'stepId': stepId,
    'order': order,
    'approverType': approverType,
    'labelAr': labelAr,
    'department': department,
    'specificUserId': specificUserId,
    'specificUserName': specificUserName,
    'conditionType': conditionType,
    'minDays': minDays,
    'maxDays': maxDays,
    'minAmount': minAmount,
    'maxAmount': maxAmount,
    'applicableSubtypes': applicableSubtypes,
  };

  factory ApprovalChainStep.fromMap(Map<String, dynamic> map) => ApprovalChainStep(
    stepId: map['stepId'] as String? ?? '',
    order: (map['order'] as num?)?.toInt() ?? 0,
    approverType: map['approverType'] as String? ?? 'direct_manager',
    labelAr: map['labelAr'] as String? ?? '',
    department: map['department'] as String?,
    specificUserId: map['specificUserId'] as String?,
    specificUserName: map['specificUserName'] as String?,
    conditionType: map['conditionType'] as String? ?? 'always',
    minDays: (map['minDays'] as num?)?.toInt(),
    maxDays: (map['maxDays'] as num?)?.toInt(),
    minAmount: (map['minAmount'] as num?)?.toDouble(),
    maxAmount: (map['maxAmount'] as num?)?.toDouble(),
    applicableSubtypes: (map['applicableSubtypes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
  );
}

class CustomRequestType {
  final String id;
  final String nameAr;
  final String category; // 'leave', 'permission', 'general', 'financial', 'administrative'
  final String descriptionAr;
  final bool isActive;
  final List<String> subtypes;
  final List<CustomSubtypeConfig> subtypeConfigs;
  final List<CustomRequestField> fields;
  final List<ApprovalChainStep> approvalSteps;
  final int? monthlyQuotaCount;
  final double? monthlyQuotaHours;
  final DateTime? updatedAt;

  const CustomRequestType({
    required this.id,
    required this.nameAr,
    required this.category,
    this.descriptionAr = '',
    this.isActive = true,
    this.subtypes = const [],
    this.subtypeConfigs = const [],
    this.fields = const [],
    this.approvalSteps = const [],
    this.monthlyQuotaCount,
    this.monthlyQuotaHours,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'nameAr': nameAr,
    'category': category,
    'descriptionAr': descriptionAr,
    'isActive': isActive,
    'subtypes': subtypes.isNotEmpty ? subtypes : subtypeConfigs.map((s) => s.nameAr).toList(),
    'subtypeConfigs': subtypeConfigs.map((s) => s.toMap()).toList(),
    'fields': fields.map((f) => f.toMap()).toList(),
    'approvalSteps': approvalSteps.map((s) => s.toMap()).toList(),
    'monthlyQuotaCount': monthlyQuotaCount,
    'monthlyQuotaHours': monthlyQuotaHours,
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory CustomRequestType.fromMap(Map<String, dynamic> map, String docId) {
    final rawSubtypes = (map['subtypes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const <String>[];
    final rawConfigs = (map['subtypeConfigs'] as List<dynamic>?)
        ?.whereType<Map<String, dynamic>>()
        .map((c) => CustomSubtypeConfig.fromMap(c))
        .toList();

    List<CustomSubtypeConfig> configs;
    if (rawConfigs != null && rawConfigs.isNotEmpty) {
      configs = rawConfigs;
    } else {
      configs = rawSubtypes.map((st) => CustomSubtypeConfig(nameAr: st)).toList();
    }

    final subtypesList = rawSubtypes.isNotEmpty
        ? rawSubtypes
        : configs.map((c) => c.nameAr).toList();

    return CustomRequestType(
      id: docId,
      nameAr: map['nameAr'] as String? ?? '',
      category: map['category'] as String? ?? 'general',
      descriptionAr: map['descriptionAr'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
      subtypes: subtypesList,
      subtypeConfigs: configs,
      fields: (map['fields'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map((f) => CustomRequestField.fromMap(f))
              .toList() ??
          const [],
      approvalSteps: (map['approvalSteps'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map((s) => ApprovalChainStep.fromMap(s))
              .toList() ??
          const [],
      monthlyQuotaCount: (map['monthlyQuotaCount'] as num?)?.toInt(),
      monthlyQuotaHours: (map['monthlyQuotaHours'] as num?)?.toDouble(),
      updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt'].toString()) : null,
    );
  }
}
