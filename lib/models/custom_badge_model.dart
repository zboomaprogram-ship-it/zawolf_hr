import 'package:cloud_firestore/cloud_firestore.dart';

final class CustomBadgeModel {
  final String id;
  final String title;
  final String description;
  final String iconName;
  final String colorHex;
  final String targetGoalType; // 'manual', 'punctuality', 'tasks', 'discipline'
  final int targetGoalValue;
  final String createdBy;
  final String createdByName;
  final DateTime? createdAt;

  const CustomBadgeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    required this.colorHex,
    this.targetGoalType = 'manual',
    this.targetGoalValue = 1,
    required this.createdBy,
    required this.createdByName,
    this.createdAt,
  });

  factory CustomBadgeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CustomBadgeModel(
      id: doc.id,
      title: data['title'] as String? ?? 'شارة جديدة',
      description: data['description'] as String? ?? '',
      iconName: data['iconName'] as String? ?? 'emoji_events',
      colorHex: data['colorHex'] as String? ?? '#FFD700',
      targetGoalType: data['targetGoalType'] as String? ?? 'manual',
      targetGoalValue: (data['targetGoalValue'] as num?)?.toInt() ?? 1,
      createdBy: data['createdBy'] as String? ?? '',
      createdByName: data['createdByName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'iconName': iconName,
      'colorHex': colorHex,
      'targetGoalType': targetGoalType,
      'targetGoalValue': targetGoalValue,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
