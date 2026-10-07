/// Configuration model for dynamic request types and custom approval workflows.
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
  final String approverType; // 'direct_manager', 'department_pool', 'coo', 'ceo', 'specific_user'
  final String labelAr;
  final String? department; // e.g. 'it', 'hr', 'legal', 'accounting'
  final String? specificUserId;
  final String? specificUserName;

  const ApprovalChainStep({
    required this.stepId,
    required this.order,
    required this.approverType,
    required this.labelAr,
    this.department,
    this.specificUserId,
    this.specificUserName,
  });

  Map<String, dynamic> toMap() => {
    'stepId': stepId,
    'order': order,
    'approverType': approverType,
    'labelAr': labelAr,
    'department': department,
    'specificUserId': specificUserId,
    'specificUserName': specificUserName,
  };

  factory ApprovalChainStep.fromMap(Map<String, dynamic> map) => ApprovalChainStep(
    stepId: map['stepId'] as String? ?? '',
    order: (map['order'] as num?)?.toInt() ?? 0,
    approverType: map['approverType'] as String? ?? 'direct_manager',
    labelAr: map['labelAr'] as String? ?? '',
    department: map['department'] as String?,
    specificUserId: map['specificUserId'] as String?,
    specificUserName: map['specificUserName'] as String?,
  );
}

class CustomRequestType {
  final String id;
  final String nameAr;
  final String category; // 'leave', 'permission', 'general', 'financial'
  final String descriptionAr;
  final bool isActive;
  final List<String> subtypes; // e.g. ['إجازة حج', 'إجازة وفاة / حداد', 'إجازة زواج']
  final List<CustomRequestField> fields;
  final List<ApprovalChainStep> approvalSteps;
  final DateTime? updatedAt;

  const CustomRequestType({
    required this.id,
    required this.nameAr,
    required this.category,
    this.descriptionAr = '',
    this.isActive = true,
    this.subtypes = const [],
    this.fields = const [],
    this.approvalSteps = const [],
    this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'nameAr': nameAr,
    'category': category,
    'descriptionAr': descriptionAr,
    'isActive': isActive,
    'subtypes': subtypes,
    'fields': fields.map((f) => f.toMap()).toList(),
    'approvalSteps': approvalSteps.map((s) => s.toMap()).toList(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory CustomRequestType.fromMap(Map<String, dynamic> map, String docId) => CustomRequestType(
    id: docId,
    nameAr: map['nameAr'] as String? ?? '',
    category: map['category'] as String? ?? 'general',
    descriptionAr: map['descriptionAr'] as String? ?? '',
    isActive: map['isActive'] as bool? ?? true,
    subtypes: (map['subtypes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
    fields: (map['fields'] as List<dynamic>?)?.map((f) => CustomRequestField.fromMap(f as Map<String, dynamic>)).toList() ?? const [],
    approvalSteps: (map['approvalSteps'] as List<dynamic>?)?.map((s) => ApprovalChainStep.fromMap(s as Map<String, dynamic>)).toList() ?? const [],
    updatedAt: map['updatedAt'] != null ? DateTime.tryParse(map['updatedAt'].toString()) : null,
  );
}
