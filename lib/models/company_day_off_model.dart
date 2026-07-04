import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;

class CompanyDayOffModel {
  final String dayOffId;
  final String date;
  final String title;
  final bool isActive;
  final String createdBy;
  final DateTime? createdAt;

  const CompanyDayOffModel({
    required this.dayOffId,
    required this.date,
    required this.title,
    required this.isActive,
    required this.createdBy,
    this.createdAt,
  });

  factory CompanyDayOffModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CompanyDayOffModel(
      dayOffId: doc.id,
      date: data['date'] as String? ?? doc.id,
      title: data['title'] as String? ?? 'عطلة رسمية',
      isActive: data['isActive'] as bool? ?? true,
      createdBy: data['createdBy'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'date': date,
      'title': title,
      'isActive': isActive,
      'createdBy': createdBy,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
    };
  }

  static String keyFor(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
}
